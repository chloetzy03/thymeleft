import Foundation

/// ONE thing in your pantry, e.g. "Milk, 1, Fridge, expires 18 Nov".
/// (Translation: just a labelled bundle of facts. It does no thinking and knows nothing
/// about screens or databases. That is what makes it an "Entity".)
struct PantryItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var quantity: Int
    var location: StorageLocation
    var expiryDate: Date
    var dateType: DateType
    /// What the user paid, if they told us. Nil means "use the average value instead".
    var price: Double?
    var reminder: ReminderPreference
    /// Name of the photo file on the phone, or nil when the item has no photo (we show an emoji).
    var photoFileName: String?
    let createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         quantity: Int = 1,
         location: StorageLocation,
         expiryDate: Date,
         dateType: DateType = .bestBefore,
         price: Double? = nil,
         reminder: ReminderPreference = .useDefault,
         photoFileName: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.location = location
        self.expiryDate = expiryDate
        self.dateType = dateType
        self.price = price
        self.reminder = reminder
        self.photoFileName = photoFileName
        self.createdAt = createdAt
    }
}
