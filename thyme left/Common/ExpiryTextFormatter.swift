import Foundation

/// Turns "3 days left" (a number) into words people read.
/// (Translation: the one place that decides to say "Today", "1 day" or "4 months".)
struct ExpiryTextFormatter {

    /// Short text for the coloured badge, e.g. "3 days".
    func badgeText(daysRemaining days: Int) -> String {
        switch days {
        case ..<0: return "Expired"
        case 0: return "Today"
        case 1: return "1 day"
        case 2..<60: return "\(days) days"
        default:
            let months = days / 30
            return months == 1 ? "1 month" : "\(months) months"
        }
    }

    /// Longer sentence for VoiceOver, e.g. "expires in 3 days".
    func spokenText(daysRemaining days: Int) -> String {
        switch days {
        case ..<0:
            let ago = -days
            return ago == 1 ? "expired yesterday" : "expired \(ago) days ago"
        case 0: return "expires today"
        case 1: return "expires tomorrow"
        default: return "expires in \(badgeText(daysRemaining: days))"
        }
    }

    /// Badge text that knows what kind of date it is. Only the "already passed" case differs.
    func badgeText(daysRemaining days: Int, dateType: DateType) -> String {
        guard days < 0 else { return badgeText(daysRemaining: days) }
        // "Expired" sounds final. These say what actually passed.
        return dateType == .useBy ? "Past use-by" : "Past date"
    }

    /// VoiceOver sentence that knows the date type, including a gentle safety hint once it has passed.
    /// (Translation: "best before" gets "check before eating"; "use by" gets "do not eat".)
    func spokenText(daysRemaining days: Int, dateType: DateType) -> String {
        let when: String
        switch days {
        case ..<0:
            let ago = -days
            when = ago == 1 ? "yesterday" : "\(ago) days ago"
        case 0: when = "today"
        case 1: when = "tomorrow"
        default: when = "in \(badgeText(daysRemaining: days))"
        }
        switch (dateType, days < 0) {
        case (.useBy, true): return "past its use by date, \(when). Do not eat"
        case (.bestBefore, true): return "past its best before date, \(when). Check before eating"
        case (.useBy, false): return "use by \(when)"
        case (.bestBefore, false): return spokenText(daysRemaining: days)
        }
    }

    /// How early a reminder is, e.g. "1 day before", "1 week before", "Same day".
    func reminderLeadText(daysBefore days: Int) -> String {
        switch days {
        case 0: return "Same day"
        case 1: return "1 day before"
        case 7: return "1 week before"
        default: return "\(days) days before"
        }
    }
}
