import XCTest
import UserNotifications
@testable import thyme_left

/// Talks to the REAL iOS notification centre (inside the simulator), not a pretend one.
/// iOS only accepts reminders once the user has allowed notifications, so these tests
/// need "Allow" to have been tapped for thyme left in the simulator they run on. On a fresh
/// simulator they are skipped (not failed). To run them: launch the app, switch reminders
/// off and on in the Me tab, tap Allow, then run the tests on that same simulator.
@MainActor
final class UserNotificationSchedulerTests: XCTestCase {

    private let center = UNUserNotificationCenter.current()
    private var sut: UserNotificationScheduler!

    override func setUp() async throws {
        try await super.setUp()
        let status = await center.notificationSettings().authorizationStatus
        try XCTSkipUnless(status == .authorized,
                          "Notifications are not allowed for thyme left on this simulator.")
        sut = UserNotificationScheduler(calendar: TestCalendar.utc)
        await clearOurs()
    }

    override func tearDown() async throws {
        await clearOurs()
        center.removePendingNotificationRequests(withIdentifiers: ["someone-elses"])
        try await super.tearDown()
    }

    private func clearOurs() async {
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("expiry-") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func pending() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("expiry-") }
    }

    /// A reminder far in the future (so it never actually fires during the test).
    private func reminder(_ id: String, title: String = "Milk expires tomorrow") -> PlannedReminder {
        PlannedReminder(id: id, fireDate: TestCalendar.date(2036, 6, 1, hour: 9),
                        title: title, body: "Fridge · x1. Use it up before it goes off 🌿")
    }

    func test_replaceAllReminders_schedulesEachReminderWithTheRightContentAndTime() async throws {
        // Arrange
        let planned = reminder("expiry-A")

        // Act
        await sut.replaceAllReminders(with: [planned])

        // Assert
        let requests = await pending()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.identifier, "expiry-A")
        XCTAssertEqual(request.content.title, "Milk expires tomorrow")
        XCTAssertEqual(request.content.body, "Fridge · x1. Use it up before it goes off 🌿")
        XCTAssertEqual(request.content.threadIdentifier, "expiry")

        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.year, 2036)
        XCTAssertEqual(trigger.dateComponents.month, 6)
        XCTAssertEqual(trigger.dateComponents.day, 1)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
    }

    func test_replaceAllReminders_replacesTheOldListInsteadOfAddingToIt() async {
        // Arrange
        await sut.replaceAllReminders(with: [reminder("expiry-A"), reminder("expiry-B")])

        // Act
        await sut.replaceAllReminders(with: [reminder("expiry-B"), reminder("expiry-C")])

        // Assert
        let ids = await pending().map(\.identifier).sorted()
        XCTAssertEqual(ids, ["expiry-B", "expiry-C"])
    }

    func test_replaceAllReminders_updatesAnExistingRemindersText() async throws {
        // Arrange
        await sut.replaceAllReminders(with: [reminder("expiry-A", title: "Old title")])

        // Act
        await sut.replaceAllReminders(with: [reminder("expiry-A", title: "New title")])

        // Assert
        let all = await pending()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.content.title, "New title")
    }

    func test_replaceAllReminders_withAnEmptyList_clearsOurReminders() async {
        // Arrange
        await sut.replaceAllReminders(with: [reminder("expiry-A")])

        // Act
        await sut.replaceAllReminders(with: [])

        // Assert
        let remaining = await pending()
        XCTAssertTrue(remaining.isEmpty)
    }

    func test_replaceAllReminders_leavesOtherNotificationsAlone() async {
        // Arrange: a notification that is not ours
        let content = UNMutableNotificationContent()
        content.title = "Not from the reminder service"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3_600_000, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "someone-elses", content: content, trigger: trigger))

        // Act
        await sut.replaceAllReminders(with: [])

        // Assert
        let ids = await center.pendingNotificationRequests().map(\.identifier)
        XCTAssertTrue(ids.contains("someone-elses"))
    }
}
