import UIKit

/// Which colours each traffic-light status uses.
/// (Translation: the Entity stays colour-blind on purpose; the look is decided here.)
extension ExpiryStatus {
    var badgeBackgroundColor: UIColor {
        switch self {
        case .expired, .urgent: return Theme.Colors.urgentBackground
        case .soon: return Theme.Colors.soonBackground
        case .fresh: return Theme.Colors.freshBackground
        }
    }

    var badgeTextColor: UIColor {
        switch self {
        case .expired, .urgent: return Theme.Colors.urgentText
        case .soon: return Theme.Colors.soonText
        case .fresh: return Theme.Colors.freshText
        }
    }
}
