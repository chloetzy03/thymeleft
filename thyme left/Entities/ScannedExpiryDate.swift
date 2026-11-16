import Foundation

/// A date the scanner found on a pack.
struct ScannedExpiryDate: Equatable {
    let date: Date
    /// The line of text it came from, e.g. "EXP 18/11/26" (shown so the user can check it).
    let sourceText: String
    /// When day and month could be swapped (like 03/04/26), the OTHER reading. Otherwise nil.
    let alternative: Date?
    /// True when the pack only showed a month and year ("NOV 2027"), so we assumed the last day of that month.
    var dayWasGuessed = false
}

/// What the scanner hands back once the user taps "Use this date".
struct ScanResult: Equatable {
    let date: Date
    /// A photo of the pack, when the user chose to keep one.
    let photoData: Data?
}

extension DateFormatPreference {
    /// Does this preference write the DAY before the month? (Used to read dates like 03/04/26.)
    /// "Match my phone" looks at the phone's region: en_GB is day-first, en_US is month-first.
    func isDayFirst(locale: Locale = .current) -> Bool {
        switch self {
        case .dayMonthYear, .yearMonthDay: return true
        case .monthDayYear: return false
        case .system:
            let pattern = DateFormatter.dateFormat(fromTemplate: "yMd", options: 0, locale: locale) ?? "dd/MM/y"
            guard let day = pattern.firstIndex(of: "d"), let month = pattern.firstIndex(of: "M") else { return true }
            return day < month
        }
    }
}
