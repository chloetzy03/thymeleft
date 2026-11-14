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
    var reminder: ReminderPreference
    let createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         quantity: Int = 1,
         location: StorageLocation,
         expiryDate: Date,
         reminder: ReminderPreference = .useDefault,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.location = location
        self.expiryDate = expiryDate
        self.reminder = reminder
        self.createdAt = createdAt
    }
}
