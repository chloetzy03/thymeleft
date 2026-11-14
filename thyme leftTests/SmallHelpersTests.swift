import Testing
import Foundation
@testable import thyme_left

struct ExpiryTextFormatterTests {
    private let formatter = ExpiryTextFormatter()

    @Test(arguments: [
        (-3, "Expired"), (0, "Today"), (1, "1 day"), (2, "2 days"),
        (59, "59 days"), (60, "2 months"), (120, "4 months")
    ])
    func badgeText(days: Int, expected: String) {
        #expect(formatter.badgeText(daysRemaining: days) == expected)
    }

    @Test(arguments: [
        (-1, "expired yesterday"), (-3, "expired 3 days ago"),
        (0, "expires today"), (1, "expires tomorrow"), (4, "expires in 4 days")
    ])
    func spokenText(days: Int, expected: String) {
        #expect(formatter.spokenText(daysRemaining: days) == expected)
    }
}

struct EmojiFoodIconProviderTests {
    private let provider = EmojiFoodIconProvider()

    @Test(arguments: [
        ("Milk", "🥛"), ("  FULL CREAM MILK ", "🥛"), ("Eggplant", "🍆"), ("Eggs", "🥚"),
        ("Peanut butter", "🥜"), ("Frozen peas", "🫛"),
        ("Mystery sauce", "🥫"), ("Xyzzy", EmojiFoodIconProvider.fallback)
    ])
    func picksTheRightEmoji(name: String, expected: String) {
        #expect(provider.emoji(for: name) == expected)
    }
}

@MainActor
struct RepositoryTests {
    @Test func inMemorySaveUpdateDelete() throws {
        let repo = InMemoryPantryRepository()
        var milk = PantryItem(name: "Milk", location: .fridge, expiryDate: .now)
        try repo.save(milk)
        milk.quantity = 3
        try repo.save(milk) // same id, so it updates instead of adding a second copy
        #expect(try repo.fetchAll().count == 1)
        #expect(try repo.fetchAll().first?.quantity == 3)
        try repo.delete(id: milk.id)
        #expect(try repo.fetchAll().isEmpty)
    }
}
