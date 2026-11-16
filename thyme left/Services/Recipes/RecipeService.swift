import Foundation

/// A "job description" for anything that can find recipes.
/// (Translation: today it's TheMealDB; a pretend one lets tests and UI tests run offline.)
@MainActor
protocol RecipeService: AnyObject {
    /// Every ingredient name the recipe source understands.
    func knownIngredientNames() async throws -> [String]
    /// Recipes that use this ONE ingredient.
    func recipeSummaries(withIngredient name: String) async throws -> [RecipeSummary]
    func recipe(id: String) async throws -> Recipe
    /// Full recipes whose NAME contains these words, e.g. "pasta" or "chicken curry".
    func searchRecipes(named query: String) async throws -> [Recipe]
}

enum RecipeServiceError: Error, Equatable {
    case offline            // no internet
    case badResponse        // the server answered with something unexpected
    case notFound
}

/// Talks to TheMealDB (themealdb.com). The "1" in the address is their free test key.
@MainActor
final class MealDBRecipeService: RecipeService {

    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession = .shared,
         baseURL: URL = URL(string: "https://www.themealdb.com/api/json/v1/1")!) {
        self.session = session
        self.baseURL = baseURL
    }

    func knownIngredientNames() async throws -> [String] {
        let meals = try await fetchMeals(path: "list.php", query: [URLQueryItem(name: "i", value: "list")])
        return meals.compactMap { $0["strIngredient"] ?? nil }
    }

    func recipeSummaries(withIngredient name: String) async throws -> [RecipeSummary] {
        // The service wants "chicken_breast", not "chicken breast".
        let word = name.lowercased().replacingOccurrences(of: " ", with: "_")
        let meals = try await fetchMeals(path: "filter.php", query: [URLQueryItem(name: "i", value: word)])
        return meals.compactMap { meal in
            guard let id = meal["idMeal"] ?? nil, let title = meal["strMeal"] ?? nil else { return nil }
            return RecipeSummary(id: id, name: title)
        }
    }

    func searchRecipes(named query: String) async throws -> [Recipe] {
        let meals = try await fetchMeals(path: "search.php", query: [URLQueryItem(name: "s", value: query)])
        return meals.compactMap(Self.recipe(from:))
    }

    func recipe(id: String) async throws -> Recipe {
        let meals = try await fetchMeals(path: "lookup.php", query: [URLQueryItem(name: "i", value: id)])
        guard let meal = meals.first else { throw RecipeServiceError.notFound }
        guard let recipe = Self.recipe(from: meal) else { throw RecipeServiceError.badResponse }
        return recipe
    }

    // MARK: - Talking to the server

    /// The server answers `{"meals": null}` (not an empty list) when nothing matches.
    private func fetchMeals(path: String, query: [URLQueryItem]) async throws -> [[String: String?]] {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = query
        guard let url = components?.url else { throw RecipeServiceError.badResponse }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError where Self.isOffline(error) {
            throw RecipeServiceError.offline
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw RecipeServiceError.badResponse }

        struct Envelope: Decodable { let meals: [[String: String?]]? }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            throw RecipeServiceError.badResponse
        }
        return envelope.meals ?? []
    }

    private static func isOffline(_ error: URLError) -> Bool {
        [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
         .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff].contains(error.code)
    }

    // MARK: - Reading a recipe

    /// The server sends ingredients as strIngredient1...20 and strMeasure1...20.
    static func recipe(from meal: [String: String?]) -> Recipe? {
        func text(_ key: String) -> String? {
            guard let value = meal[key] ?? nil else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        func url(_ key: String) -> URL? { text(key).flatMap(URL.init(string:)) }

        guard let id = text("idMeal"), let name = text("strMeal") else { return nil }

        let ingredients = (1...20).compactMap { number -> RecipeIngredient? in
            guard let ingredient = text("strIngredient\(number)") else { return nil }
            return RecipeIngredient(name: ingredient, measure: text("strMeasure\(number)") ?? "")
        }
        return Recipe(id: id, name: name, category: text("strCategory"), area: text("strArea"),
                      instructions: text("strInstructions") ?? "",
                      imageURL: url("strMealThumb"), sourceURL: url("strSource"), videoURL: url("strYoutube"),
                      ingredients: ingredients)
    }
}

/// A pretend recipe source with fixed answers. Used by UI tests so they never touch the internet.
@MainActor
final class StubRecipeService: RecipeService {

    var known: [String]
    var summariesByIngredient: [String: [RecipeSummary]]
    var recipes: [String: Recipe]
    var error: RecipeServiceError?
    /// What was asked, so tests can check we only searched what we should.
    private(set) var searchedIngredients: [String] = []
    private(set) var fetchedRecipeIDs: [String] = []
    private(set) var searchedNames: [String] = []

    init(known: [String] = [], summariesByIngredient: [String: [RecipeSummary]] = [:],
         recipes: [String: Recipe] = [:], error: RecipeServiceError? = nil) {
        self.known = known
        self.summariesByIngredient = summariesByIngredient
        self.recipes = recipes
        self.error = error
    }

    func knownIngredientNames() async throws -> [String] {
        if let error { throw error }
        return known
    }

    func recipeSummaries(withIngredient name: String) async throws -> [RecipeSummary] {
        searchedIngredients.append(name)
        if let error { throw error }
        return summariesByIngredient[name] ?? []
    }

    func searchRecipes(named query: String) async throws -> [Recipe] {
        searchedNames.append(query)
        if let error { throw error }
        return recipes.values
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name < $1.name }
    }

    func recipe(id: String) async throws -> Recipe {
        fetchedRecipeIDs.append(id)
        if let error { throw error }
        guard let recipe = recipes[id] else { throw RecipeServiceError.notFound }
        return recipe
    }
}

extension StubRecipeService {
    /// Fixed sample recipes for UI tests (Spinach, Eggs and Milk are the foods it knows).
    static func uiTestingSample(error: RecipeServiceError? = nil) -> StubRecipeService {
        func recipe(_ id: String, _ name: String, _ ingredients: [(String, String)], source: String?) -> Recipe {
            Recipe(id: id, name: name, category: "Breakfast", area: "French",
                   instructions: "STEP 1\nWhisk everything together.\nSTEP 2\nCook gently and serve warm.",
                   imageURL: nil, sourceURL: source.flatMap(URL.init(string:)), videoURL: nil,
                   ingredients: ingredients.map { RecipeIngredient(name: $0.0, measure: $0.1) })
        }
        let omelette = recipe("1", "Spinach Omelette",
                              [("Spinach", "1 bag"), ("Eggs", "3"), ("Cheese", "50g"), ("Salt", "1 pinch")],
                              source: "https://example.com/omelette")
        let pudding = recipe("2", "Milk Pudding", [("Milk", "500ml"), ("Sugar", "50g")], source: nil)
        return StubRecipeService(
            known: ["Milk", "Spinach", "Eggs"],
            summariesByIngredient: [
                "Spinach": [RecipeSummary(id: "1", name: omelette.name)],
                "Eggs": [RecipeSummary(id: "1", name: omelette.name)],
                "Milk": [RecipeSummary(id: "2", name: pudding.name)]
            ],
            recipes: ["1": omelette, "2": pudding],
            error: error)
    }
}
