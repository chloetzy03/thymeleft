import Foundation

/// How dates are written on screen.
enum DateFormatPreference: String, CaseIterable, Codable {
    case system        // follow the phone's region
    case dayMonthYear  // 18/11/2026
    case monthDayYear  // 11/18/2026
    case yearMonthDay  // 2026-11-18

    var displayName: String {
        switch self {
        case .system: return "Match my phone"
        case .dayMonthYear: return "DD/MM/YYYY"
        case .monthDayYear: return "MM/DD/YYYY"
        case .yearMonthDay: return "YYYY-MM-DD"
        }
    }
}

/// Everything the user can customise.
/// (Translation: one bundle of preferences. Each screen reads what it needs from here.)
struct AppSettings: Equatable, Codable {
    var notificationsEnabled = true
    /// Used by every item that says "use the default".
    var defaultReminderDaysBefore = 1
    var reminderHour = 9
    var reminderMinute = 0
    var dateFormat: DateFormatPreference = .system
    /// Red when this many days or fewer are left.
    var urgentDays = 1
    /// Amber when this many days or fewer are left.
    var soonDays = 5
    /// We only show our friendly "Get reminders?" explainer once, so we never nag.
    var hasSeenReminderPrimer = false
    /// Show an estimate of money saved on the Home tab.
    var showMoneySaved = true
    /// What one used-up item is worth, as a rough guess (in your own currency).
    var averageItemValue = 3.0

    init() {}

    /// Settings saved by an older version of the app may be missing newer fields.
    /// Reading each field separately means we keep what we have and default the rest.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        notificationsEnabled = try values.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? defaults.notificationsEnabled
        defaultReminderDaysBefore = try values.decodeIfPresent(Int.self, forKey: .defaultReminderDaysBefore) ?? defaults.defaultReminderDaysBefore
        reminderHour = try values.decodeIfPresent(Int.self, forKey: .reminderHour) ?? defaults.reminderHour
        reminderMinute = try values.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? defaults.reminderMinute
        dateFormat = try values.decodeIfPresent(DateFormatPreference.self, forKey: .dateFormat) ?? defaults.dateFormat
        urgentDays = try values.decodeIfPresent(Int.self, forKey: .urgentDays) ?? defaults.urgentDays
        soonDays = try values.decodeIfPresent(Int.self, forKey: .soonDays) ?? defaults.soonDays
        hasSeenReminderPrimer = try values.decodeIfPresent(Bool.self, forKey: .hasSeenReminderPrimer) ?? defaults.hasSeenReminderPrimer
        showMoneySaved = try values.decodeIfPresent(Bool.self, forKey: .showMoneySaved) ?? defaults.showMoneySaved
        averageItemValue = try values.decodeIfPresent(Double.self, forKey: .averageItemValue) ?? defaults.averageItemValue
    }

    /// The red/amber/green rule built from these settings.
    var expiryPolicy: ExpiryPolicy {
        ExpiryPolicy(urgentDays: urgentDays, soonDays: soonDays)
    }
}

/// The choices offered in the Settings screen. Kept here so the screen and the tests agree.
enum SettingsChoices {
    static let reminderDaysBefore = [0, 1, 2, 3, 7]
    static let urgentDays = [0, 1, 2, 3]
    static let soonDays = [3, 5, 7, 10]
    static let itemValues: [Double] = [1, 2, 3, 5, 10]
}
