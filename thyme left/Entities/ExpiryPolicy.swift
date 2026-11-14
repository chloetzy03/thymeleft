import Foundation

/// The rulebook for "when is an item urgent / soon / fresh?".
/// (Translation: the thresholds live in ONE place. Later a Settings screen can hand in
/// different numbers and nothing else in the app needs to change.)
struct ExpiryPolicy: Equatable {
    /// Red when this many days or fewer are left (0 = today).
    var urgentDays: Int = 1
    /// Amber when this many days or fewer are left.
    var soonDays: Int = 5

    /// Whole days from today until the expiry date. Negative means already expired.
    /// We compare calendar days, not hours, so "tomorrow 8am" is always "1 day" away.
    func daysRemaining(until expiry: Date, from now: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let expiryDay = calendar.startOfDay(for: expiry)
        return calendar.dateComponents([.day], from: today, to: expiryDay).day ?? 0
    }

    func status(forDaysRemaining days: Int) -> ExpiryStatus {
        if days < 0 { return .expired }
        if days <= urgentDays { return .urgent }
        if days <= soonDays { return .soon }
        return .fresh
    }
}
