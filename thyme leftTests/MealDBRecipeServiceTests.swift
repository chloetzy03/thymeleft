import XCTest
@testable import thyme_left

/// Replaces the internet: answers every request with whatever we queued up.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data)?)?
    nonisolated(unsafe) static var failure: URLError?
    nonisolated(unsafe) static var requestedURLs: [URL] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        if let url = request.url { Self.requestedURLs.append(url) }
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let (status, data) = Self.handler?(request) ?? (404, Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

@MainActor
final class MealDBRecipeServiceTests: XCTestCase {

    private var sut: MealDBRecipeService!

    override func setUp() async throws {
        try await super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        sut = MealDBRecipeService(session: URLSession(configuration: configuration),
                                  baseURL: URL(string: "https://example.test/api")!)
        StubURLProtocol.handler = nil
        StubURLProtocol.failure = nil
        StubURLProtocol.requestedURLs = []
    }

    private func respond(_ json: String, status: Int = 200) {
        StubURLProtocol.handler = { _ in (status, Data(json.utf8)) }
    }

    func test_knownIngredientNames_readsTheList() async throws {
        // Arrange
        respond(#"{"meals":[{"strIngredient":"Chicken"},{"strIngredient":"Salmon"}]}"#)

        // Act
        let names = try await sut.knownIngredientNames()

        // Assert
        XCTAssertEqual(names, ["Chicken", "Salmon"])
        XCTAssertEqual(StubURLProtocol.requestedURLs.first?.absoluteString, "https://example.test/api/list.php?i=list")
    }

    func test_recipeSummaries_turnsSpacesIntoUnderscoresAndReadsResults() async throws {
        // Arrange
        respond(#"{"meals":[{"strMeal":"Curry","idMeal":"1"},{"strMeal":"Stew","idMeal":"2"}]}"#)

        // Act
        let summaries = try await sut.recipeSummaries(withIngredient: "Chicken Breast")

        // Assert
        XCTAssertEqual(summaries, [RecipeSummary(id: "1", name: "Curry"), RecipeSummary(id: "2", name: "Stew")])
        XCTAssertEqual(StubURLProtocol.requestedURLs.first?.absoluteString, "https://example.test/api/filter.php?i=chicken_breast")
    }

    func test_recipeSummaries_whenNothingMatches_returnsEmptyNotAnError() async throws {
        // Arrange: the real server says {"meals":null}
        respond(#"{"meals":null}"#)

        // Act
        let summaries = try await sut.recipeSummaries(withIngredient: "zzz")

        // Assert
        XCTAssertTrue(summaries.isEmpty)
    }

    func test_recipe_readsAllTheDetails_andSkipsBlankIngredients() async throws {
        // Arrange
        respond(#"""
        {"meals":[{"idMeal":"52772","strMeal":"Teriyaki","strCategory":"Chicken","strArea":"Japanese",
        "strInstructions":"Cook it.\r\nServe it.","strMealThumb":"https://example.com/t.jpg",
        "strSource":null,"strYoutube":"https://youtube.com/watch?v=abc",
        "strIngredient1":"soy sauce","strMeasure1":"3/4 cup","strIngredient2":"Chicken","strMeasure2":" ",
        "strIngredient3":"","strMeasure3":"","strIngredient4":null,"strMeasure4":null}]}
        """#)

        // Act
        let recipe = try await sut.recipe(id: "52772")

        // Assert
        XCTAssertEqual(recipe.name, "Teriyaki")
        XCTAssertEqual(recipe.area, "Japanese")
        XCTAssertEqual(recipe.ingredients, [RecipeIngredient(name: "soy sauce", measure: "3/4 cup"),
                                            RecipeIngredient(name: "Chicken", measure: "")])
        XCTAssertNil(recipe.sourceURL, "the source can be missing")
        XCTAssertEqual(recipe.videoURL?.absoluteString, "https://youtube.com/watch?v=abc")
        XCTAssertEqual(recipe.imageURL?.absoluteString, "https://example.com/t.jpg")
    }

    func test_recipe_whenTheServerKnowsNothing_throwsNotFound() async {
        respond(#"{"meals":null}"#)
        do { _ = try await sut.recipe(id: "0"); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? RecipeServiceError, .notFound) }
    }

    func test_noInternet_throwsOffline() async {
        // Arrange
        StubURLProtocol.failure = URLError(.notConnectedToInternet)

        // Act + Assert
        do { _ = try await sut.knownIngredientNames(); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? RecipeServiceError, .offline) }
    }

    func test_serverErrorsAndGarbage_throwBadResponse() async {
        respond("Server on fire", status: 200)
        do { _ = try await sut.knownIngredientNames(); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? RecipeServiceError, .badResponse) }

        respond("{}", status: 500)
        do { _ = try await sut.knownIngredientNames(); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? RecipeServiceError, .badResponse) }
    }
}
