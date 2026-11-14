import Foundation
import SwiftData

/// How SwiftData stores one pantry item on disk.
/// (Translation: this is the database's own version of `PantryItem`. We keep it separate so
/// the rest of the app never has to know SwiftData exists.)
@Model
final class PantryItemRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Int
    var locationRawValue: String
    var expiryDate: Date
    var createdAt: Date

    init(id: UUID, name: String, quantity: Int, locationRawValue: String, expiryDate: Date, createdAt: Date) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.locationRawValue = locationRawValue
        self.expiryDate = expiryDate
        self.createdAt = createdAt
    }

    convenience init(_ item: PantryItem) {
        self.init(id: item.id, name: item.name, quantity: item.quantity,
                  locationRawValue: item.location.rawValue,
                  expiryDate: item.expiryDate, createdAt: item.createdAt)
    }

    func update(from item: PantryItem) {
        name = item.name
        quantity = item.quantity
        locationRawValue = item.location.rawValue
        expiryDate = item.expiryDate
    }

    /// Converts back to the plain `PantryItem` the app uses.
    var entity: PantryItem {
        PantryItem(id: id, name: name, quantity: quantity,
                   location: StorageLocation(rawValue: locationRawValue) ?? .pantry,
                   expiryDate: expiryDate, createdAt: createdAt)
    }
}
