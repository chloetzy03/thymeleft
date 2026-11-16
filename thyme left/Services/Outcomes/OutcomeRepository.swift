import Foundation
import SwiftData

/// A "job description" for anything that can remember what happened to your food.
@MainActor
protocol OutcomeRepository: AnyObject {
    func record(_ entry: OutcomeEntry) throws
    func fetchAll() throws -> [OutcomeEntry]
}

@MainActor
final class InMemoryOutcomeRepository: OutcomeRepository {

    private var entries: [OutcomeEntry]
    var shouldFailToRecord = false

    init(entries: [OutcomeEntry] = []) {
        self.entries = entries
    }

    struct Failure: Error {}

    func record(_ entry: OutcomeEntry) throws {
        if shouldFailToRecord { throw Failure() }
        entries.append(entry)
    }

    func fetchAll() throws -> [OutcomeEntry] { entries }
}

/// How SwiftData stores one history line.
@Model
final class OutcomeRecord {
    @Attribute(.unique) var id: UUID
    var itemName: String
    var outcomeRawValue: String
    var date: Date
    var value: Double?

    init(id: UUID, itemName: String, outcomeRawValue: String, date: Date, value: Double? = nil) {
        self.id = id
        self.itemName = itemName
        self.outcomeRawValue = outcomeRawValue
        self.date = date
        self.value = value
    }

    var entry: OutcomeEntry {
        OutcomeEntry(id: id, itemName: itemName, outcome: ItemOutcome(rawValue: outcomeRawValue) ?? .removed, date: date, value: value)
    }
}

@MainActor
final class SwiftDataOutcomeRepository: OutcomeRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func record(_ entry: OutcomeEntry) throws {
        context.insert(OutcomeRecord(id: entry.id, itemName: entry.itemName,
                                      outcomeRawValue: entry.outcome.rawValue, date: entry.date, value: entry.value))
        try context.save()
    }

    func fetchAll() throws -> [OutcomeEntry] {
        try context.fetch(FetchDescriptor<OutcomeRecord>(sortBy: [SortDescriptor(\.date)])).map(\.entry)
    }
}
