import Foundation
import UserNotifications

/// A "job description" for anything that can schedule reminders on the phone.
/// (Translation: the real one talks to iOS; a pretend one lets tests and UI tests run without
/// pop-ups.)
@MainActor
protocol NotificationScheduling: AnyObject {
    func currentPermission() async -> NotificationPermission
    /// Shows the iOS "Allow notifications?" pop-up (only the first time).
    func requestPermission() async -> NotificationPermission
    /// Throws away our old reminders and schedules exactly these.
    func replaceAllReminders(with reminders: [PlannedReminder]) async
}

/// The real thing: uses iOS's notification centre.
@MainActor
final class UserNotificationScheduler: NotificationScheduling {

    private let center = UNUserNotificationCenter.current()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func currentPermission() async -> NotificationPermission {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        @unknown default: return .denied
        }
    }

    func requestPermission() async -> NotificationPermission {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        return await currentPermission()
    }

    func replaceAllReminders(with reminders: [PlannedReminder]) async {
        // Remove only OUR reminders (ids start with "expiry-"), then add the fresh list.
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix("expiry-") }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = "expiry" // iOS stacks these together on the lock screen

            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}

/// A pretend scheduler: remembers what it was asked and never shows a pop-up.
/// Used by UI tests and as a safe stand-in.
@MainActor
final class StubNotificationScheduler: NotificationScheduling {

    var permission: NotificationPermission
    private(set) var scheduled: [PlannedReminder] = []

    init(permission: NotificationPermission = .authorized) {
        self.permission = permission
    }

    func currentPermission() async -> NotificationPermission { permission }

    func requestPermission() async -> NotificationPermission {
        if permission == .notDetermined { permission = .authorized }
        return permission
    }

    func replaceAllReminders(with reminders: [PlannedReminder]) async {
        scheduled = reminders
    }
}
