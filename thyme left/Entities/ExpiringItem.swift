import Foundation

/// A pantry item together with its countdown.
/// (Translation: the item plus "3 days left, amber" worked out by the Interactor.)
struct ExpiringItem: Equatable {
    let item: PantryItem
    let daysRemaining: Int
    let status: ExpiryStatus
}
