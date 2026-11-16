import XCTest
@testable import thyme_left

final class ExpiryTextFormatterTests: XCTestCase {

    private let formatter = ExpiryTextFormatter()

    func test_badgeText_forDifferentCountdowns_readsNaturally() {
        // Arrange: (days left, the words we expect)
        let cases: [(days: Int, expected: String)] = [
            (-3, "Expired"), (0, "Today"), (1, "1 day"), (2, "2 days"),
            (59, "59 days"), (60, "2 months"), (120, "4 months")
        ]

        for testCase in cases {
            // Act
            let text = formatter.badgeText(daysRemaining: testCase.days)

            // Assert
            XCTAssertEqual(text, testCase.expected, "\(testCase.days) days left")
        }
    }

    func test_spokenText_forDifferentCountdowns_readsAsASentence() {
        // Arrange
        let cases: [(days: Int, expected: String)] = [
            (-1, "expired yesterday"), (-3, "expired 3 days ago"),
            (0, "expires today"), (1, "expires tomorrow"), (4, "expires in 4 days")
        ]

        for testCase in cases {
            // Act
            let text = formatter.spokenText(daysRemaining: testCase.days)

            // Assert
            XCTAssertEqual(text, testCase.expected, "\(testCase.days) days left")
        }
    }
}

final class ExpiryTextFormatterDateTypeTests: XCTestCase {

    private let formatter = ExpiryTextFormatter()

    func test_badgeText_afterTheDate_saysWhichKindOfDatePassed() {
        XCTAssertEqual(formatter.badgeText(daysRemaining: -2, dateType: .bestBefore), "Past date")
        XCTAssertEqual(formatter.badgeText(daysRemaining: -2, dateType: .useBy), "Past use-by")
    }

    func test_badgeText_beforeTheDate_isTheSameForBothKinds() {
        XCTAssertEqual(formatter.badgeText(daysRemaining: 3, dateType: .useBy), "3 days")
        XCTAssertEqual(formatter.badgeText(daysRemaining: 0, dateType: .bestBefore), "Today")
    }

    func test_spokenText_afterTheDate_givesAGentleHintForBestBeforeAndAWarningForUseBy() {
        XCTAssertEqual(formatter.spokenText(daysRemaining: -3, dateType: .bestBefore),
                       "past its best before date, 3 days ago. Check before eating")
        XCTAssertEqual(formatter.spokenText(daysRemaining: -1, dateType: .useBy),
                       "past its use by date, yesterday. Do not eat")
    }

    func test_spokenText_beforeTheDate_mentionsUseByOnlyWhenItIsOne() {
        XCTAssertEqual(formatter.spokenText(daysRemaining: 1, dateType: .useBy), "use by tomorrow")
        XCTAssertEqual(formatter.spokenText(daysRemaining: 4, dateType: .bestBefore), "expires in 4 days")
    }
}

final class EmojiFoodIconProviderTests: XCTestCase {

    private let provider = EmojiFoodIconProvider()

    func test_emoji_forKnownAndUnknownFoods_picksTheRightOne() {
        // Arrange: (what the user typed, the emoji we expect)
        let cases: [(name: String, expected: String)] = [
            ("Milk", "🥛"), ("  FULL CREAM MILK ", "🥛"),
            ("Eggplant", "🍆"), ("Eggs", "🥚"),          // "eggplant" must win over "egg"
            ("Peanut butter", "🥜"), ("Frozen peas", "🫛"),
            ("Mystery sauce", "🥫"), ("Xyzzy", EmojiFoodIconProvider.fallback)
        ]

        for testCase in cases {
            // Act
            let emoji = provider.emoji(for: testCase.name)

            // Assert
            XCTAssertEqual(emoji, testCase.expected, testCase.name)
        }
    }
}

@MainActor
final class InMemoryPantryRepositoryTests: XCTestCase {

    func test_save_withExistingId_updatesInsteadOfDuplicating() async throws {
        // Arrange
        let repository = InMemoryPantryRepository()
        var milk = PantryItem(name: "Milk", location: .fridge, expiryDate: Date())
        try repository.save(milk)

        // Act
        milk.quantity = 3
        try repository.save(milk)

        // Assert
        let items = try repository.fetchAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.quantity, 3)
    }

    func test_delete_removesTheItem() async throws {
        // Arrange
        let repository = InMemoryPantryRepository()
        let milk = PantryItem(name: "Milk", location: .fridge, expiryDate: Date())
        try repository.save(milk)

        // Act
        try repository.delete(id: milk.id)

        // Assert
        XCTAssertTrue(try repository.fetchAll().isEmpty)
    }
}
