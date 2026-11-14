import Foundation

/// How close an item is to going off.
/// (Translation: a traffic light with four colours.)
enum ExpiryStatus: Equatable {
    case expired  // already past its date
    case urgent   // use it today or very soon
    case soon     // use it this week
    case fresh    // plenty of time

    /// Items that deserve the "Use soon" section.
    var needsAttention: Bool { self != .fresh }
}
