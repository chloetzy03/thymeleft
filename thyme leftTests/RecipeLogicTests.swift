import XCTest
@testable import thyme_left

// MARK: - Matching your food to recipe ingredients

final class IngredientMatcherTests: XCTestCase {

    private let matcher = IngredientMatcher()

    func test_matches_sameFoodWrittenDifferently() {
        // Arrange: (pantry name, recipe ingredient)
        let same: [(String, String)] = [
            ("Milk", "milk"), ("Full cream milk", "Milk"), ("Tomatoes", "Tomato"), ("Frozen peas", "Peas"),
            ("Greek yoghurt", "Yogurt"), ("Chopped tomatoes", "Tomato"), ("Eggs", "Egg"),
            ("Free range EGGS", "eggs"), ("Cherries", "Cherry"), ("Potatoes", "Potato"), ("Aubergine", "Eggplant")
        ]

        for (pantry, recipe) in same {
            // Act + Assert
            XCTAssertTrue(matcher.matches(pantryName: pantry, recipeIngredient: recipe), "\(pantry) vs \(recipe)")
        }
    }

    func test_matches_differentFoodsDoNotMatch() {
        let different: [(String, String)] = [
            ("Milk", "Coconut Milk"), ("Tomatoes", "Tomato Puree"), ("Butter", "Peanut Butter"),
            ("Chicken", "Chicken Stock"), ("Pasta", "Pasta Sauce"), ("Rice", "Rice Vinegar"), ("", "Egg"), ("Egg", "")
        ]
        for (pantry, recipe) in different {
            XCTAssertFalse(matcher.matches(pantryName: pantry, recipeIngredient: recipe), "\(pantry) vs \(recipe)")
        }
    }

    func test_isStaple_recognisesBasics() {
        XCTAssertTrue(matcher.isStaple("Salt"))
        XCTAssertTrue(matcher.isStaple("Water"))
        XCTAssertTrue(matcher.isStaple("Olive Oil"))
        XCTAssertTrue(matcher.isStaple("Black Pepper"))
        XCTAssertFalse(matcher.isStaple("Butter"))
    }

    func test_searchKeyword_picksTheMostSpecificKnownIngredient() {
        // Arrange
        let known = ["Milk", "Coconut Milk", "Peas", "Chicken", "Chicken Breast", "Yogurt", "Tomato"]

        // Act + Assert
        XCTAssertEqual(matcher.searchKeyword(for: "Full cream milk", knownIngredients: known), "Milk")
        XCTAssertEqual(matcher.searchKeyword(for: "Frozen peas", knownIngredients: known), "Peas")
        XCTAssertEqual(matcher.searchKeyword(for: "Chicken breast fillets", knownIngredients: known), "Chicken Breast")
        XCTAssertEqual(matcher.searchKeyword(for: "Greek yoghurt", knownIngredients: known), "Yogurt")
        XCTAssertEqual(matcher.searchKeyword(for: "Coconut milk", knownIngredients: known), "Coconut Milk")
        XCTAssertNil(matcher.searchKeyword(for: "Mystery sauce", knownIngredients: known))
        XCTAssertNil(matcher.searchKeyword(for: "", knownIngredients: known))
    }
}

// MARK: - Ordering recipes

final class RecipeRankerTests: XCTestCase {

    private let ranker = RecipeRanker()
    private typealias Fixtures = RecipeFixtures

    func test_rank_dropsRecipesThatUseNothingYouHave() {
        // Arrange
        let recipes = [Fixtures.recipe("1", "Steak", ingredients: ["Beef", "Salt"])]

        // Act
        let result = ranker.rank(recipes: recipes, pantry: [Fixtures.entry("Milk", days: 3)], mode: .useItUpFirst)

        // Assert
        XCTAssertTrue(result.isEmpty)
    }

    func test_rank_reportsWhatYouUseAndWhatIsMissing_assumingStaples() throws {
        // Arrange
        let recipes = [Fixtures.recipe("1", "Quiche", ingredients: ["Eggs", "Spinach", "Cream", "Salt", "Water"])]
        let pantry = [Fixtures.entry("Spinach", days: 2), Fixtures.entry("Eggs", days: 10)]

        // Act
        let match = try XCTUnwrap(ranker.rank(recipes: recipes, pantry: pantry, mode: .useItUpFirst).first)

        // Assert
        XCTAssertEqual(match.usedItemNames, ["Spinach", "Eggs"])
        XCTAssertEqual(match.missingIngredients, ["Cream"], "salt and water are assumed")
        XCTAssertEqual(match.ingredientAvailability.map(\.have), [true, true, false, true, true])
    }

    func test_rank_useItUpFirst_putsTheRecipeThatRescuesTheSoonestItemFirst() {
        // Arrange: spinach is due tomorrow; rice has ages
        let pantry = [Fixtures.entry("Spinach", days: 1), Fixtures.entry("Rice", days: 200)]
        let soup = Fixtures.recipe("1", "Spinach Soup", ingredients: ["Spinach", "Stock", "Onion"])
        let pilaf = Fixtures.recipe("2", "Rice Pilaf", ingredients: ["Rice"])

        // Act
        let result = ranker.rank(recipes: [pilaf, soup], pantry: pantry, mode: .useItUpFirst)

        // Assert: pilaf has fewer missing items, but soup saves the spinach
        XCTAssertEqual(result.map(\.recipe.name), ["Spinach Soup", "Rice Pilaf"])
    }

    func test_rank_bestMatch_putsTheRecipeWithFewestMissingFirst() {
        // Arrange
        let pantry = [Fixtures.entry("Spinach", days: 1), Fixtures.entry("Rice", days: 200)]
        let soup = Fixtures.recipe("1", "Spinach Soup", ingredients: ["Spinach", "Stock", "Onion"])
        let pilaf = Fixtures.recipe("2", "Rice Pilaf", ingredients: ["Rice"])

        // Act
        let result = ranker.rank(recipes: [soup, pilaf], pantry: pantry, mode: .bestMatch)

        // Assert
        XCTAssertEqual(result.map(\.recipe.name), ["Rice Pilaf", "Spinach Soup"])
    }

    func test_rank_usingSeveralExpiringItemsBeatsUsingOne() {
        // Arrange
        let pantry = [Fixtures.entry("Spinach", days: 1), Fixtures.entry("Eggs", days: 1), Fixtures.entry("Milk", days: 1)]
        let one = Fixtures.recipe("1", "A", ingredients: ["Milk"])
        let three = Fixtures.recipe("2", "B", ingredients: ["Milk", "Eggs", "Spinach"])

        // Act
        let result = ranker.rank(recipes: [one, three], pantry: pantry, mode: .useItUpFirst)

        // Assert
        XCTAssertEqual(result.map(\.recipe.name), ["B", "A"])
    }

    func test_rank_tiesAreSortedAlphabetically() {
        // Arrange
        let pantry = [Fixtures.entry("Milk", days: 3)]
        let zebra = Fixtures.recipe("1", "Zebra Pudding", ingredients: ["Milk"])
        let apple = Fixtures.recipe("2", "apple Pudding", ingredients: ["Milk"])

        // Act + Assert
        for mode in RecipeSortMode.allCases {
            XCTAssertEqual(ranker.rank(recipes: [zebra, apple], pantry: pantry, mode: mode).map(\.recipe.name),
                           ["apple Pudding", "Zebra Pudding"], "\(mode)")
        }
    }

    func test_rank_urgencyIsHigherForSoonerExpiry() throws {
        // Arrange
        let recipe = Fixtures.recipe("1", "A", ingredients: ["Milk"])

        // Act
        let today = try XCTUnwrap(ranker.rank(recipes: [recipe], pantry: [Fixtures.entry("Milk", days: 0)], mode: .useItUpFirst).first)
        let later = try XCTUnwrap(ranker.rank(recipes: [recipe], pantry: [Fixtures.entry("Milk", days: 9)], mode: .useItUpFirst).first)

        // Assert
        XCTAssertEqual(today.urgencyScore, 1.0, accuracy: 0.001)
        XCTAssertEqual(later.urgencyScore, 0.1, accuracy: 0.001)
    }
}

// MARK: - Recipe cache

@MainActor
final class RecipeCacheTests: XCTestCase {

    private var file: URL!

    override func setUp() async throws {
        try await super.setUp()
        file = FileManager.default.temporaryDirectory.appendingPathComponent("recipes-\(UUID().uuidString).json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: file)
        try await super.tearDown()
    }

    func test_storedRecipes_surviveRestartingTheApp() async {
        // Arrange
        let first = FileSystemRecipeCache(fileURL: file)
        first.store([RecipeFixtures.recipe("1", "Soup", ingredients: ["Milk"], source: "https://example.com/soup")])

        // Act: a brand-new cache object reads the same file
        let second = FileSystemRecipeCache(fileURL: file)

        // Assert
        XCTAssertEqual(second.allRecipes().map(\.name), ["Soup"])
        XCTAssertEqual(second.allRecipes().first?.sourceURL?.absoluteString, "https://example.com/soup")
    }

    func test_store_replacesARecipeWithTheSameId() async {
        // Arrange
        let cache = FileSystemRecipeCache(fileURL: file)
        cache.store([RecipeFixtures.recipe("1", "Old name", ingredients: [])])

        // Act
        cache.store([RecipeFixtures.recipe("1", "New name", ingredients: [])])

        // Assert
        XCTAssertEqual(cache.allRecipes().map(\.name), ["New name"])
    }

    func test_store_keepsOnlyTheNewestRecipes() async {
        // Arrange
        let cache = FileSystemRecipeCache(fileURL: file)
        let many = (0..<(FileSystemRecipeCache.maxRecipes + 10)).map { RecipeFixtures.recipe("\($0)", "R\($0)", ingredients: []) }

        // Act
        cache.store(many)

        // Assert
        XCTAssertEqual(cache.allRecipes().count, FileSystemRecipeCache.maxRecipes)
        XCTAssertEqual(cache.allRecipes().last?.id, "\(FileSystemRecipeCache.maxRecipes + 9)")
    }

    func test_corruptFile_startsEmptyInsteadOfCrashing() async throws {
        // Arrange
        try Data("not json".utf8).write(to: file)

        // Act + Assert
        XCTAssertTrue(FileSystemRecipeCache(fileURL: file).allRecipes().isEmpty)
    }
}
