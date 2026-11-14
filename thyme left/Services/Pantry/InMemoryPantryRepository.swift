import Foundation

/// Keeps items in memory only (gone when the app closes).
/// (Translation: a pretend database. Perfect for tests, previews, and as a safety net
/// if the real database ever fails to open.)
@MainActor
final class InMemoryPantryRepository: PantryRepository {

    private var items: [PantryItem]

    init(items: [PantryItem] = []) {
        self.items = items
    }

    func fetchAll() throws -> [PantryItem] { items }

    func save(_ item: PantryItem) throws {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func delete(id: UUID) throws {
        items.removeAll { $0.id == id }
    }
}
