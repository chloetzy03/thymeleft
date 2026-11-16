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
    /// See `ReminderPreference.storedValue`. The default (-2) lets older saved items upgrade smoothly.
    var reminderStoredValue: Int = -2
    /// Optional, so items saved before photos existed upgrade smoothly.
    var photoFileName: String?
    /// Defaults let items saved before these existed upgrade smoothly.
    var dateTypeRawValue: String = "bestBefore"
    var price: Double?

    init(id: UUID, name: String, quantity: Int, locationRawValue: String, expiryDate: Date,
         reminderStoredValue: Int, photoFileName: String?,
         dateTypeRawValue: String, price: Double?, createdAt: Date) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.locationRawValue = locationRawValue
        self.expiryDate = expiryDate
        self.reminderStoredValue = reminderStoredValue
        self.photoFileName = photoFileName
        self.dateTypeRawValue = dateTypeRawValue
        self.price = price
        self.createdAt = createdAt
    }

    convenience init(_ item: PantryItem) {
        self.init(id: item.id, name: item.name, quantity: item.quantity,
                  locationRawValue: item.location.rawValue,
                  expiryDate: item.expiryDate, reminderStoredValue: item.reminder.storedValue,
                  photoFileName: item.photoFileName, dateTypeRawValue: item.dateType.rawValue,
                  price: item.price, createdAt: item.createdAt)
    }

    func update(from item: PantryItem) {
        name = item.name
        quantity = item.quantity
        locationRawValue = item.location.rawValue
        expiryDate = item.expiryDate
        reminderStoredValue = item.reminder.storedValue
        photoFileName = item.photoFileName
        dateTypeRawValue = item.dateType.rawValue
        price = item.price
    }

    /// Converts back to the plain `PantryItem` the app uses.
    var entity: PantryItem {
        PantryItem(id: id, name: name, quantity: quantity,
                   location: StorageLocation(rawValue: locationRawValue) ?? .pantry,
                   expiryDate: expiryDate, dateType: DateType(rawValue: dateTypeRawValue) ?? .bestBefore,
                   price: price, reminder: ReminderPreference(storedValue: reminderStoredValue),
                   photoFileName: photoFileName, createdAt: createdAt)
    }
}
