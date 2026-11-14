import Foundation

/// Writes a date the way the user chose in Settings, e.g. "18/11/2026".
/// (Translation: screens ask this instead of formatting dates themselves, so changing the
/// setting changes every date at once.)
@MainActor
final class ExpiryDateFormatter {

    private let settingsStore: SettingsStore
    private let locale: Locale
    private var cache: [DateFormatPreference: DateFormatter] = [:]

    init(settingsStore: SettingsStore, locale: Locale = .current) {
        self.settingsStore = settingsStore
        self.locale = locale
    }

    func string(from date: Date) -> String {
        string(from: date, using: settingsStore.load().dateFormat)
    }

    func string(from date: Date, using preference: DateFormatPreference) -> String {
        formatter(for: preference).string(from: date)
    }

    /// Making a DateFormatter is slow, so we make each kind once and reuse it.
    private func formatter(for preference: DateFormatPreference) -> DateFormatter {
        if let cached = cache[preference] { return cached }

        let formatter = DateFormatter()
        formatter.locale = locale
        switch preference {
        case .system:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        case .dayMonthYear:
            formatter.locale = Locale(identifier: "en_US_POSIX") // keep digits predictable
            formatter.dateFormat = "dd/MM/yyyy"
        case .monthDayYear:
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MM/dd/yyyy"
        case .yearMonthDay:
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
        }
        cache[preference] = formatter
        return formatter
    }
}
