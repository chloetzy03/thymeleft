import XCTest
@testable import thyme_left

final class ReminderPlannerTests: XCTestCase {

    private let planner = ReminderPlanner()
    private let calendar = TestCalendar.utc
    /// "Now" for every test: 15 Nov 2026, 08:00.
    private let now = TestCalendar.date(2026, 11, 15, hour: 8)

    private func item(_ name: String = "Milk",
                      expires: Date,
                      reminder: ReminderPreference = .useDefault) -> PantryItem {
        PantryItem(name: name, quantity: 2, location: .fridge, expiryDate: expires, reminder: reminder)
    }

    private func plan(_ items: [PantryItem], settings: AppSettings = AppSettings()) -> [PlannedReminder] {
        planner.plan(items: items, settings: settings, now: now, calendar: calendar)
    }

    // MARK: When reminders fire

    func test_plan_withDefaultSettings_remindsOneDayBeforeAtNineAM() throws {
        // Arrange
        let milk = item(expires: TestCalendar.date(2026, 11, 20))

        // Act
        let reminders = plan([milk])

        // Assert
        let reminder = try XCTUnwrap(reminders.first)
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminder.fireDate, TestCalendar.date(2026, 11, 19, hour: 9))
    }

    func test_plan_usesTheReminderTimeFromSettings() throws {
        // Arrange
        var settings = AppSettings()
        settings.reminderHour = 18
        settings.reminderMinute = 30

        // Act
        let reminders = plan([item(expires: TestCalendar.date(2026, 11, 20))], settings: settings)

        // Assert
        XCTAssertEqual(try XCTUnwrap(reminders.first).fireDate, TestCalendar.date(2026, 11, 19, hour: 18, minute: 30))
    }

    func test_plan_usesTheDefaultDaysBeforeFromSettings() throws {
        // Arrange
        var settings = AppSettings()
        settings.defaultReminderDaysBefore = 3

        // Act
        let reminders = plan([item(expires: TestCalendar.date(2026, 11, 20))], settings: settings)

        // Assert
        XCTAssertEqual(try XCTUnwrap(reminders.first).fireDate, TestCalendar.date(2026, 11, 17, hour: 9))
    }

    func test_plan_anItemsOwnChoiceBeatsTheDefault() throws {
        // Arrange
        let sameDay = item(expires: TestCalendar.date(2026, 11, 20), reminder: .daysBefore(0))

        // Act
        let reminders = plan([sameDay])

        // Assert
        XCTAssertEqual(try XCTUnwrap(reminders.first).fireDate, TestCalendar.date(2026, 11, 20, hour: 9))
    }

    func test_plan_ignoresTheTimeOfDayOfTheExpiryDate() throws {
        // Arrange: the same day, expiring at 00:05 vs 23:55
        let early = item("Early", expires: TestCalendar.date(2026, 11, 20, hour: 0, minute: 5))
        let late = item("Late", expires: TestCalendar.date(2026, 11, 20, hour: 23, minute: 55))

        // Act
        let reminders = plan([early, late])

        // Assert
        XCTAssertEqual(Set(reminders.map(\.fireDate)), [TestCalendar.date(2026, 11, 19, hour: 9)])
    }

    // MARK: When there is nothing to send

    func test_plan_neverRemind_producesNothing() {
        XCTAssertTrue(plan([item(expires: TestCalendar.date(2026, 11, 20), reminder: .never)]).isEmpty)
    }

    func test_plan_whenNotificationsAreOff_producesNothing() {
        // Arrange
        var settings = AppSettings()
        settings.notificationsEnabled = false

        // Act + Assert
        XCTAssertTrue(plan([item(expires: TestCalendar.date(2026, 11, 20))], settings: settings).isEmpty)
    }

    func test_plan_skipsRemindersWhoseTimeHasAlreadyPassed() {
        // Arrange
        let expiresTomorrow = item("Tomorrow", expires: TestCalendar.date(2026, 11, 16)) // 1 day before = today 09:00 (still ahead)
        let expiresToday = item("Today", expires: TestCalendar.date(2026, 11, 15))        // 1 day before = yesterday
        let alreadyExpired = item("Old", expires: TestCalendar.date(2026, 11, 10))

        // Act
        let reminders = plan([expiresTomorrow, expiresToday, alreadyExpired])

        // Assert
        XCTAssertEqual(reminders.map(\.title), ["Tomorrow expires tomorrow"])
    }

    func test_plan_skipsTodaysReminderIfTheTimeHasPassed() {
        // Arrange: it is 08:00 and the reminder time is 07:00
        var settings = AppSettings()
        settings.reminderHour = 7
        settings.defaultReminderDaysBefore = 0

        // Act
        let reminders = plan([item(expires: TestCalendar.date(2026, 11, 15))], settings: settings)

        // Assert
        XCTAssertTrue(reminders.isEmpty)
    }

    // MARK: Wording, identity, ordering, limits

    func test_plan_writesAFriendlyMessage() throws {
        // Arrange
        let sameDay = item("Milk", expires: TestCalendar.date(2026, 11, 20), reminder: .daysBefore(0))
        let tomorrow = item("Eggs", expires: TestCalendar.date(2026, 11, 20), reminder: .daysBefore(1))
        let inThree = item("Peas", expires: TestCalendar.date(2026, 11, 20), reminder: .daysBefore(3))

        // Act
        let reminders = plan([sameDay, tomorrow, inThree])

        // Assert
        XCTAssertEqual(reminders.map(\.title), ["Peas expires in 3 days", "Eggs expires tomorrow", "Milk expires today"])
        XCTAssertEqual(reminders.last?.body, "Fridge · x2. Use it up before it goes off 🌿")
    }

    func test_plan_giveseachItemItsOwnIdentityEvenWithTheSameName() {
        // Arrange: two milks with different dates
        let first = item("Milk", expires: TestCalendar.date(2026, 11, 20))
        let second = item("Milk", expires: TestCalendar.date(2026, 11, 25))

        // Act
        let reminders = plan([first, second])

        // Assert
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(Set(reminders.map(\.id)).count, 2)
        XCTAssertEqual(Set(reminders.map(\.id)),
                       [ReminderPlanner.identifier(for: first.id), ReminderPlanner.identifier(for: second.id)])
    }

    func test_plan_sortsEarliestFirst() {
        // Arrange
        let later = item("Later", expires: TestCalendar.date(2026, 12, 1))
        let sooner = item("Sooner", expires: TestCalendar.date(2026, 11, 18))

        // Act
        let reminders = plan([later, sooner])

        // Assert
        XCTAssertEqual(reminders.map { $0.title.components(separatedBy: " ").first }, ["Sooner", "Later"])
    }

    func test_plan_keepsOnlyTheSoonestRemindersThatIOSCanHold() {
        // Arrange: 70 items, one expiring on each of the next 70 days
        let items = (3..<73).map { day in
            item("Item \(day)", expires: calendar.date(byAdding: .day, value: day, to: now)!)
        }

        // Act
        let reminders = plan(items)

        // Assert
        XCTAssertEqual(reminders.count, ReminderPlanner.maxReminders)
        XCTAssertEqual(reminders.map(\.fireDate), reminders.map(\.fireDate).sorted())
        XCTAssertTrue(reminders.contains { $0.title.hasPrefix("Item 3 ") }, "the soonest item must be kept")
        XCTAssertFalse(reminders.contains { $0.title.hasPrefix("Item 72 ") }, "the furthest item is dropped")
    }
}
