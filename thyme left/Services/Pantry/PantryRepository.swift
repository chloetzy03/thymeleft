import Foundation

/// A "job description" for anything that can store pantry items.
/// (Translation: the rest of the app says "I need someone who can save and load items" and
/// doesn't care whether that's SwiftData, a text file, or the cloud. Swapping the storage
/// later means writing one new type that fits this description. That is the "D" in SOLID,
/// Dependency Inversion: depend on the job description, not on the specific worker.)
@MainActor
protocol PantryRepository: AnyObject {
    func fetchAll() throws -> [PantryItem]
    /// Adds the item, or updates it if one with the same id already exists.
    func save(_ item: PantryItem) throws
    func delete(id: UUID) throws
}
