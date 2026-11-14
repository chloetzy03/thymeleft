import Foundation
@testable import thyme_left

/// A clock that always says the same moment. (Translation: "today" never changes in tests.)
struct FixedDateProvider: DateProviding {
    let now: Date
}

/// A pretend reminder service: writes down what it was asked and answers instantly.
@MainActor
final class ReminderServiceSpy: ReminderServicing {
    var permission: NotificationPermission
    /// What the permission becomes after `requestPermission()`.
    var permissionAfterRequest: NotificationPermission = .authorized

    private(set) var rescheduleCount = 0
    private(set) var syncCount = 0
    private(set) var refreshCount = 0
    private(set) var requestCount = 0

    init(permission: NotificationPermission = .authorized) {
        self.permission = permission
    }

    func refreshPermission() async { refreshCount += 1 }

    func requestPermission() async -> NotificationPermission {
        requestCount += 1
        permission = permissionAfterRequest
        return permission
    }

    func reschedule() { rescheduleCount += 1 }
    func syncWithSystem() { syncCount += 1 }
}

enum TestCalendar {
    /// A fixed calendar so tests give the same answer in every time zone.
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
