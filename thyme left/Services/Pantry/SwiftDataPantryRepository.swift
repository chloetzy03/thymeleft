import Foundation
import SwiftData

/// The real storage: saves pantry items to the phone using SwiftData.
@MainActor
final class SwiftDataPantryRepository: PantryRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [PantryItem] {
        try context.fetch(FetchDescriptor<PantryItemRecord>()).map(\.entity)
    }

    func save(_ item: PantryItem) throws {
        if let existing = try record(for: item.id) {
            existing.update(from: item)
        } else {
            context.insert(PantryItemRecord(item))
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let existing = try record(for: id) else { return }
        context.delete(existing)
        try context.save()
    }

    /// Finds the stored copy of an item by its id.
    private func record(for id: UUID) throws -> PantryItemRecord? {
        var descriptor = FetchDescriptor<PantryItemRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
