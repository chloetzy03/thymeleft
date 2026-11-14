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
}
