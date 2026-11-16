import Foundation

/// Why an item left your pantry.
enum ItemOutcome: String, Codable, Equatable {
    case used      // you ate or cooked it: counts as food saved
    case wasted    // you threw it away
    case removed   // a plain delete, e.g. you added it by mistake: counts as neither
}

/// One line in your history: "Milk was used up on 14 Nov".
/// (Translation: we keep only the name and the date, not the whole item, so history stays tiny.)
struct OutcomeEntry: Identifiable, Equatable {
    let id: UUID
    let itemName: String
    /// Only `.used` and `.wasted` are ever recorded.
    let outcome: ItemOutcome
    let date: Date
    /// What the item cost, if the user told us at the time. Nil means "use the average".
    let value: Double?

    init(id: UUID = UUID(), itemName: String, outcome: ItemOutcome, date: Date, value: Double? = nil) {
        self.id = id
        self.itemName = itemName
        self.outcome = outcome
        self.date = date
        self.value = value
    }
}
