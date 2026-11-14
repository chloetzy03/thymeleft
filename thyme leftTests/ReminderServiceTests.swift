import XCTest
@testable import thyme_left

@MainActor
final class ReminderServiceTests: XCTestCase {

    private let now = TestCalendar.date(2026, 11, 15, hour: 8)

    private struct Fixture {
        let sut: ReminderService
        let scheduler: StubNotificationScheduler
        let repository: InMemoryPantryRepository
        let settings: InMemorySettingsStore
    }

    private func makeFixture(permission: NotificationPermission,
                             items: [PantryItem] = [],
                             settings: AppSettings = AppSettings()) -> Fixture {
        let scheduler = StubNotificationScheduler(permission: permission)
        let repository = InMemoryPantryRepository(items: items)
        let store = InMemorySettingsStore(settings: settings)
        let sut = ReminderService(repository: repository, settingsStore: store, scheduler: scheduler,
                                  dateProvider: FixedDateProvider(now: now), calendar: TestCalendar.utc)
        return Fixture(sut: sut, scheduler: scheduler, repository: repository, settings: store)
    }

    private func milk(expiresDay: Int = 20) -> PantryItem {
        PantryItem(name: "Milk", location: .fridge, expiryDate: TestCalendar.date(2026, 11, expiresDay))
    }

    func test_rescheduleNow_whenAllowed_schedulesThePlan() async {
        // Arrange
        let fixture = makeFixture(permission: .authorized, items: [milk()])
        await fixture.sut.refreshPermission()

        // Act
        await fixture.sut.rescheduleNow()

        // Assert
        XCTAssertEqual(fixture.scheduler.scheduled.count, 1)
        XCTAssertEqual(fixture.scheduler.scheduled.first?.fireDate, TestCalendar.date(2026, 11, 19, hour: 9))
    }

    func test_rescheduleNow_withoutPermission_schedulesNothing() async {
        // Arrange
        let fixture = makeFixture(permission: .denied, items: [milk()])
        await fixture.sut.refreshPermission()

        // Act
        await fixture.sut.rescheduleNow()

        // Assert
        XCTAssertTrue(fixture.scheduler.scheduled.isEmpty)
    }

    func test_rescheduleNow_replacesOldRemindersWhenTheDateChanges() async throws {
        // Arrange
        let original = milk(expiresDay: 20)
        let fixture = makeFixture(permission: .authorized, items: [original])
        await fixture.sut.refreshPermission()
        await fixture.sut.rescheduleNow()

        // Act: the user edits the item to expire later
        var edited = original
        edited.expiryDate = TestCalendar.date(2026, 11, 25)
        try fixture.repository.save(edited)
        await fixture.sut.rescheduleNow()

        // Assert: still ONE reminder for that item, at the new time
        XCTAssertEqual(fixture.scheduler.scheduled.count, 1)
        XCTAssertEqual(fixture.scheduler.scheduled.first?.fireDate, TestCalendar.date(2026, 11, 24, hour: 9))
    }

    func test_rescheduleNow_afterDeletingTheItem_clearsItsReminder() async throws {
        // Arrange
        let item = milk()
        let fixture = makeFixture(permission: .authorized, items: [item])
        await fixture.sut.refreshPermission()
        await fixture.sut.rescheduleNow()

        // Act
        try fixture.repository.delete(id: item.id)
        await fixture.sut.rescheduleNow()

        // Assert
        XCTAssertTrue(fixture.scheduler.scheduled.isEmpty)
    }

    func test_rescheduleNow_followsSettingsChanges() async {
        // Arrange
        let fixture = makeFixture(permission: .authorized, items: [milk()])
        await fixture.sut.refreshPermission()
        await fixture.sut.rescheduleNow()

        // Act: the user switches reminders off
        var off = AppSettings()
        off.notificationsEnabled = false
        fixture.settings.save(off)
        await fixture.sut.rescheduleNow()

        // Assert
        XCTAssertTrue(fixture.scheduler.scheduled.isEmpty)
    }

    func test_requestPermission_updatesTheStatusAndSchedules() async {
        // Arrange
        let fixture = makeFixture(permission: .notDetermined, items: [milk()])
        await fixture.sut.refreshPermission()
        XCTAssertEqual(fixture.sut.permission, .notDetermined)

        // Act
        let result = await fixture.sut.requestPermission()
        await fixture.sut.rescheduleNow() // let the queued background job finish deterministically

        // Assert
        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(fixture.sut.permission, .authorized)
        XCTAssertEqual(fixture.scheduler.scheduled.count, 1)
    }

    func test_syncWithSystem_picksUpAChangeMadeInIOSSettings() async {
        // Arrange: we think we're allowed, but the user then switches notifications off in iOS Settings
        let fixture = makeFixture(permission: .authorized, items: [milk()])
        await fixture.sut.refreshPermission()
        await fixture.sut.rescheduleNow()
        fixture.scheduler.permission = .denied

        // Act
        await fixture.sut.refreshPermission()
        await fixture.sut.rescheduleNow()

        // Assert
        XCTAssertEqual(fixture.sut.permission, .denied)
        XCTAssertTrue(fixture.scheduler.scheduled.isEmpty)
    }
}
