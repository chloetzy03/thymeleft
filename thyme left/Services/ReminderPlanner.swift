import Foundation

/// Decides WHICH reminders to send and WHEN. It only does maths; it never talks to iOS.
/// (Translation: given your items and settings, it hands back a to-do list of reminders.
/// Because it's pure logic, we can test every rule quickly.)
struct ReminderPlanner {

    /// iOS keeps at most 64 pending notifications, so we plan the soonest 60.
    static let maxReminders = 60

    private let formatter = ExpiryTextFormatter()

    func plan(items: [PantryItem],
              settings: AppSettings,
              now: Date,
              calendar: Calendar = .current) -> [PlannedReminder] {
        guard settings.notificationsEnabled else { return [] }

        let reminders = items.compactMap { item in
            reminder(for: item, settings: settings, now: now, calendar: calendar)
        }

        // Earliest first, ties by name, then keep only what iOS can hold.
        return reminders
            .sorted {
                if $0.fireDate != $1.fireDate { return $0.fireDate < $1.fireDate }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            .prefix(Self.maxReminders)
            .map { $0 }
    }

    private func reminder(for item: PantryItem,
                          settings: AppSettings,
                          now: Date,
                          calendar: Calendar) -> PlannedReminder? {
        let daysBefore: Int
        switch item.reminder {
        case .never: return nil
        case .useDefault: daysBefore = settings.defaultReminderDaysBefore
        case .daysBefore(let days): daysBefore = days
        }

        // Count back from the expiry DAY (not the hour), then set the time of day.
        let expiryDay = calendar.startOfDay(for: item.expiryDate)
        guard let reminderDay = calendar.date(byAdding: .day, value: -daysBefore, to: expiryDay),
              let fireDate = calendar.date(bySettingHour: settings.reminderHour,
                                           minute: settings.reminderMinute,
                                           second: 0, of: reminderDay),
              fireDate > now else { return nil } // already in the past: nothing to send

        return PlannedReminder(
            id: Self.identifier(for: item.id),
            fireDate: fireDate,
            title: String(localized: "\(item.name) \(formatter.spokenText(daysRemaining: daysBefore))"),
            body: String(localized: "\(item.location.displayName) · x\(item.quantity). Use it up before it goes off 🌿"))
    }

    /// The reminder's name is built from the item's id (not its name), so renaming an item or
    /// owning two items called "Milk" can never make reminders collide.
    static func identifier(for itemID: UUID) -> String {
        "expiry-\(itemID.uuidString)"
    }
}
