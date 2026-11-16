import XCTest
@testable import thyme_left

// MARK: - Recipes Interactor

@MainActor
final class RecipesInteractorTests: XCTestCase {

    private final class OutputSpy: RecipesInteractorOutput {
        var loads: [(matches: [RecipeMatch], rescue: [String], offline: Bool)] = []
        var noPantry = 0, noRecipes = 0
        var failures: [RecipesFailure] = []
        var expectation: XCTestExpectation?

        /// Each expectation may only be fulfilled once, so let go of it straight after.
        private func signal() { expectation?.fulfill(); expectation = nil }

        func didLoad(matches: [RecipeMatch], rescueItemNames: [String], isOffline: Bool) {
            loads.append((matches, rescueItemNames, isOffline)); signal()
        }
        func didFindNoPantryItems() { noPantry += 1; signal() }
        func didFindNoRecipes() { noRecipes += 1; signal() }
        func didFail(_ failure: RecipesFailure) { failures.append(failure); signal() }
        func didLoadSearch(matches: [RecipeMatch], query: String, isOffline: Bool) {}
        func didFindNoSearchResults(query: String) {}
        func didFailSearch(_ failure: RecipesFailure) {}
    }

    private struct Fixture {
        let sut: RecipesInteractor
        let output: OutputSpy
        let service: StubRecipeService
        let cache: InMemoryRecipeCache
    }

    private let today = TestCalendar.date(2026, 11, 15)

    private func item(_ name: String, days: Int) -> PantryItem {
        PantryItem(name: name, location: .fridge,
                   expiryDate: TestCalendar.utc.date(byAdding: .day, value: days, to: today)!)
    }

    private func makeFixture(items: [PantryItem], service: StubRecipeService? = nil,
                             cache: InMemoryRecipeCache? = nil) -> Fixture {
        let cache = cache ?? InMemoryRecipeCache()
        let spinachSoup = RecipeFixtures.recipe("1", "Spinach Soup", ingredients: ["Spinach", "Stock"])
        let pudding = RecipeFixtures.recipe("2", "Milk Pudding", ingredients: ["Milk", "Sugar"])
        let service = service ?? StubRecipeService(
            known: ["Spinach", "Milk", "Eggs", "Peas"],
            summariesByIngredient: ["Spinach": [RecipeSummary(id: "1", name: "Spinach Soup")],
                                    "Milk": [RecipeSummary(id: "2", name: "Milk Pudding")]],
            recipes: ["1": spinachSoup, "2": pudding])
        let sut = RecipesInteractor(repository: InMemoryPantryRepository(items: items),
                                    settingsStore: InMemorySettingsStore(),
                                    dateProvider: FixedDateProvider(now: today),
                                    service: service, cache: cache, calendar: TestCalendar.utc)
        let output = OutputSpy()
        sut.output = output
        return Fixture(sut: sut, output: output, service: service, cache: cache)
    }

    /// Starts a load and waits until the Interactor reports something.
    private func load(_ fixture: Fixture, sort: RecipeSortMode = .useItUpFirst) async {
        let done = expectation(description: "reported")
        fixture.output.expectation = done
        fixture.sut.loadRecipes(sort: sort)
        await fulfillment(of: [done], timeout: 3)
    }

    func test_load_searchesYourItems_fetchesDetails_andRanksByUrgency() async throws {
        // Arrange: spinach is due tomorrow, milk in 4 days
        let fixture = makeFixture(items: [item("Spinach", days: 1), item("Milk", days: 4)])

        // Act
        await load(fixture)

        // Assert
        let loaded = try XCTUnwrap(fixture.output.loads.first)
        XCTAssertEqual(loaded.matches.map(\.recipe.name), ["Spinach Soup", "Milk Pudding"])
        XCTAssertFalse(loaded.offline)
        XCTAssertEqual(loaded.rescue, ["Spinach", "Milk"])
    }

    func test_load_rescueSummaryListsEachFoodOnce() async {
        // Arrange: two cartons of milk
        let fixture = makeFixture(items: [item("Milk", days: 1), item("Milk", days: 2), item("Spinach", days: 3)])

        // Act
        await load(fixture)

        // Assert
        XCTAssertEqual(fixture.output.loads.first?.rescue, ["Milk", "Spinach"])
    }

    func test_load_neverSuggestsRecipesForExpiredFood() async {
        // Arrange
        let fixture = makeFixture(items: [item("Spinach", days: -2), item("Milk", days: 3)])

        // Act
        await load(fixture)

        // Assert
        XCTAssertEqual(fixture.service.searchedIngredients, ["Milk"])
        XCTAssertEqual(fixture.output.loads.first?.matches.map(\.recipe.name), ["Milk Pudding"])
    }

    func test_load_withAnEmptyOrAllExpiredPantry_saysThereIsNothingToCookWith() async {
        let empty = makeFixture(items: [])
        await load(empty)
        XCTAssertEqual(empty.output.noPantry, 1)
        XCTAssertTrue(empty.service.searchedIngredients.isEmpty, "no network calls needed")

        let expired = makeFixture(items: [item("Milk", days: -1)])
        await load(expired)
        XCTAssertEqual(expired.output.noPantry, 1)
    }

    func test_load_searchesEachIngredientOnlyOnce_andSkipsFoodsItDoesNotKnow() async {
        // Arrange: two milks, and a food the recipe service has never heard of
        let fixture = makeFixture(items: [item("Milk", days: 1), item("Full cream milk", days: 2),
                                          item("Mystery sauce", days: 1)])

        // Act
        await load(fixture)

        // Assert
        XCTAssertEqual(fixture.service.searchedIngredients, ["Milk"])
    }

    func test_load_searchesAtMostEightIngredients_soonestFirst() async {
        // Arrange: 12 distinct known foods (letters only: the matcher ignores digits)
        let names = ["Apple", "Banana", "Carrot", "Dates", "Eggplant", "Figs", "Grapes", "Honey", "Kale", "Lentils", "Mango", "Nutmeg"]
        let service = StubRecipeService(known: names)
        let items = names.enumerated().map { item($1, days: $0 + 1) }
        let fixture = makeFixture(items: items, service: service)

        // Act
        await load(fixture)

        // Assert
        XCTAssertEqual(service.searchedIngredients, Array(names.prefix(RecipesInteractor.maxSearchedItems)))
    }

    func test_load_savesWhatItFetched_andReusesSavedDetailsNextTime() async {
        // Arrange
        let fixture = makeFixture(items: [item("Spinach", days: 1)])

        // Act
        await load(fixture)
        let fetchedFirstTime = fixture.service.fetchedRecipeIDs
        await load(fixture)

        // Assert
        XCTAssertEqual(fixture.cache.allRecipes().map(\.id), ["1"])
        XCTAssertEqual(fetchedFirstTime, ["1"])
        XCTAssertEqual(fixture.service.fetchedRecipeIDs, ["1"], "the second load used the saved copy")
    }

    func test_load_whenNothingMatches_saysNoRecipes() async {
        // Arrange: the item is known but no recipe uses it
        let fixture = makeFixture(items: [item("Peas", days: 1)])

        // Act
        await load(fixture)

        // Assert
        XCTAssertEqual(fixture.output.noRecipes, 1)
    }

    func test_load_whenOffline_showsSavedRecipesAndSaysSo() async throws {
        // Arrange: we saved a recipe earlier, then lost the internet
        let cache = InMemoryRecipeCache()
        cache.store([RecipeFixtures.recipe("9", "Saved Milk Rice", ingredients: ["Milk", "Rice"])])
        let fixture = makeFixture(items: [item("Milk", days: 2)],
                                  service: StubRecipeService(error: .offline), cache: cache)

        // Act
        await load(fixture)

        // Assert
        let loaded = try XCTUnwrap(fixture.output.loads.first)
        XCTAssertTrue(loaded.offline)
        XCTAssertEqual(loaded.matches.map(\.recipe.name), ["Saved Milk Rice"])
    }

    func test_load_whenOfflineWithNothingSaved_failsWithAFriendlyReason() async {
        // Arrange
        let fixture = makeFixture(items: [item("Milk", days: 2)], service: StubRecipeService(error: .offline))

        // Act
        await load(fixture)

        // Assert
        XCTAssertEqual(fixture.output.failures, [.offlineAndNothingSaved])
    }

    func test_load_whenTheServerMisbehaves_failsWithAProblem_orUsesSavedRecipes() async {
        // Arrange
        let broken = makeFixture(items: [item("Milk", days: 2)], service: StubRecipeService(error: .badResponse))
        let cache = InMemoryRecipeCache()
        cache.store([RecipeFixtures.recipe("9", "Saved Milk Rice", ingredients: ["Milk"])])
        let rescued = makeFixture(items: [item("Milk", days: 2)], service: StubRecipeService(error: .badResponse), cache: cache)

        // Act
        await load(broken)
        await load(rescued)

        // Assert
        XCTAssertEqual(broken.output.failures, [.problem])
        XCTAssertEqual(rescued.output.loads.first?.offline, true)
    }

    func test_changeSort_reusesWhatItAlreadyHas_withoutNewNetworkCalls() async {
        // Arrange
        let fixture = makeFixture(items: [item("Spinach", days: 1), item("Milk", days: 4)])
        await load(fixture)
        let searchesBefore = fixture.service.searchedIngredients.count
        let fetchesBefore = fixture.service.fetchedRecipeIDs.count

        // Act
        fixture.sut.changeSort(.bestMatch)

        // Assert
        XCTAssertEqual(fixture.output.loads.count, 2, "it reported again")
        XCTAssertEqual(fixture.service.searchedIngredients.count, searchesBefore)
        XCTAssertEqual(fixture.service.fetchedRecipeIDs.count, fetchesBefore)
    }

    func test_changeSort_beforeAnythingIsLoaded_doesNothing() async {
        let fixture = makeFixture(items: [item("Milk", days: 1)])
        fixture.sut.changeSort(.bestMatch)
        XCTAssertTrue(fixture.output.loads.isEmpty)
    }
}

// MARK: - Recipes Presenter

@MainActor
final class RecipesPresenterTests: XCTestCase {

    private final class ViewSpy: RecipesViewProtocol {
        var sortTitles: [String] = []
        var selectedSort = -1
        var loadingCount = 0
        var screen: RecipesScreenViewModel?
        var message: (emoji: String, title: String, message: String, button: String?)?

        func showSortModes(titles: [String], selectedIndex: Int) { sortTitles = titles; selectedSort = selectedIndex }
        func showLoading() { loadingCount += 1 }
        func showRecipes(_ screen: RecipesScreenViewModel) { self.screen = screen; message = nil }
        func showMessage(emoji: String, title: String, message: String, buttonTitle: String?) {
            self.message = (emoji, title, message, buttonTitle); screen = nil
        }
        var statuses: [String?] = []
        func showSearchStatus(_ text: String?) { statuses.append(text) }
    }

    private final class InteractorSpy: RecipesInteractorInput {
        var loads: [RecipeSortMode] = []
        var sorts: [RecipeSortMode] = []
        func loadRecipes(sort: RecipeSortMode) { loads.append(sort) }
        func changeSort(_ sort: RecipeSortMode) { sorts.append(sort) }
        var searches: [String] = []
        func search(query: String) { searches.append(query) }
    }

    private final class RouterSpy: RecipesRouterProtocol {
        var shown: [RecipeMatch] = []
        func showRecipe(_ match: RecipeMatch) { shown.append(match) }
    }

    private func makeSUT() -> (sut: RecipesPresenter, view: ViewSpy, interactor: InteractorSpy, router: RouterSpy) {
        let view = ViewSpy(), interactor = InteractorSpy(), router = RouterSpy()
        return (RecipesPresenter(view: view, interactor: interactor, router: router), view, interactor, router)
    }

    private func match(_ name: String, uses: [String], missing: [String]) -> RecipeMatch {
        RecipeMatch(recipe: RecipeFixtures.recipe(name, name, ingredients: []),
                    usedItemNames: uses, missingIngredients: missing, ingredientAvailability: [], urgencyScore: 1)
    }

    func test_viewDidLoad_offersBothSortModes_withUseItUpFirstSelected() async {
        let (sut, view, _, _) = makeSUT()
        sut.viewDidLoad()
        XCTAssertEqual(view.sortTitles, ["Use up first", "Best match"])
        XCTAssertEqual(view.selectedSort, 0)
    }

    func test_viewWillAppear_showsLoadingOnlyTheFirstTime_butAlwaysRefreshes() async {
        // Arrange
        let (sut, view, interactor, _) = makeSUT()

        // Act
        sut.viewWillAppear()
        sut.didLoad(matches: [match("A", uses: ["Milk"], missing: [])], rescueItemNames: [], isOffline: false)
        sut.viewWillAppear()

        // Assert
        XCTAssertEqual(view.loadingCount, 1, "no spinner flash when coming back to the tab")
        XCTAssertEqual(interactor.loads.count, 2)
    }

    func test_didLoad_buildsFriendlyRows() async throws {
        // Arrange
        let (sut, view, _, _) = makeSUT()
        let matches = [match("Quiche", uses: ["Milk", "Spinach", "Eggs", "Cheese", "Ham"], missing: ["Cream", "Basil", "Garlic", "Thyme"]),
                       match("Pudding", uses: ["Milk"], missing: [])]

        // Act
        sut.didLoad(matches: matches, rescueItemNames: ["Milk", "Spinach"], isOffline: false)

        // Assert
        let screen = try XCTUnwrap(view.screen)
        XCTAssertEqual(screen.rescueSummary, "Rescue these first: Milk, Spinach")
        XCTAssertNil(screen.banner)
        XCTAssertEqual(screen.rows[0].usesText, "Uses Milk, Spinach, Eggs and 2 more")
        XCTAssertEqual(screen.rows[0].missingText, "Missing: Cream, Basil, Garlic and 1 more")
        XCTAssertEqual(screen.rows[1].missingText, "You have everything")
        XCTAssertEqual(screen.rows[1].accessibilityText, "Pudding. Uses Milk. You have everything")
    }

    func test_didLoad_withNothingExpiringSoon_hasNoRescueLine() async {
        let (sut, view, _, _) = makeSUT()
        sut.didLoad(matches: [match("A", uses: ["Rice"], missing: [])], rescueItemNames: [], isOffline: false)
        XCTAssertNil(view.screen?.rescueSummary)
    }

    func test_didLoad_whenOffline_showsABanner() async {
        let (sut, view, _, _) = makeSUT()
        sut.didLoad(matches: [match("A", uses: ["Rice"], missing: [])], rescueItemNames: [], isOffline: true)
        XCTAssertNotNil(view.screen?.banner)
    }

    func test_messages_forEachSituation() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act + Assert
        sut.didFindNoPantryItems()
        XCTAssertEqual(view.message?.title, "Add some food first")
        XCTAssertNil(view.message?.button, "nothing to retry: the user needs to add food")

        sut.didFindNoRecipes()
        XCTAssertEqual(view.message?.title, "No recipes found yet")
        XCTAssertEqual(view.message?.button, "Try again")

        sut.didFail(.offlineAndNothingSaved)
        XCTAssertEqual(view.message?.title, "You're offline")

        sut.didFail(.problem)
        XCTAssertEqual(view.message?.title, "Something went wrong")
    }

    func test_didSelectSort_reordersWithoutReloading_andIgnoresRepeats() async {
        // Arrange
        let (sut, view, interactor, _) = makeSUT()
        sut.viewDidLoad()

        // Act
        sut.didSelectSort(at: 1)
        sut.didSelectSort(at: 1)
        sut.didSelectSort(at: 9)

        // Assert
        XCTAssertEqual(interactor.sorts, [.bestMatch])
        XCTAssertEqual(view.selectedSort, 1)
        XCTAssertTrue(interactor.loads.isEmpty)
    }

    func test_afterChoosingBestMatch_laterRefreshesKeepThatChoice() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()
        sut.didSelectSort(at: 1)

        // Act
        sut.viewWillAppear()
        sut.didTapRetry()

        // Assert
        XCTAssertEqual(interactor.loads, [.bestMatch, .bestMatch])
    }

    func test_didSelectRecipe_opensItsDetail_andIgnoresUnknownIds() async {
        // Arrange
        let (sut, _, _, router) = makeSUT()
        let quiche = match("quiche", uses: ["Milk"], missing: [])
        sut.didLoad(matches: [quiche], rescueItemNames: [], isOffline: false)

        // Act
        sut.didSelectRecipe(id: "quiche")
        sut.didSelectRecipe(id: "nope")

        // Assert
        XCTAssertEqual(router.shown, [quiche])
    }
}

// MARK: - Recipe detail

@MainActor
final class RecipeDetailPresenterTests: XCTestCase {

    private final class ViewSpy: RecipeDetailViewProtocol {
        var detail: RecipeDetailViewModel?
        func showRecipe(_ detail: RecipeDetailViewModel) { self.detail = detail }
    }

    private final class RouterSpy: RecipeDetailRouterProtocol {
        var opened: [URL] = []
        func open(_ url: URL) { opened.append(url) }
    }

    private func makeMatch(source: String? = "https://example.com/r", video: String? = nil, instructions: String = "Mix.\nBake.") -> RecipeMatch {
        let recipe = Recipe(id: "1", name: "Quiche", category: "Starter", area: "French", instructions: instructions,
                            imageURL: nil, sourceURL: source.flatMap(URL.init(string:)),
                            videoURL: video.flatMap(URL.init(string:)),
                            ingredients: [RecipeIngredient(name: "Eggs", measure: "3"), RecipeIngredient(name: "Cream", measure: "")])
        return RecipeMatch(recipe: recipe, usedItemNames: ["Eggs"], missingIngredients: ["Cream"],
                           ingredientAvailability: [.init(ingredient: recipe.ingredients[0], have: true),
                                                    .init(ingredient: recipe.ingredients[1], have: false)],
                           urgencyScore: 1)
    }

    private func makeSUT(_ match: RecipeMatch) -> (RecipeDetailPresenter, ViewSpy, RouterSpy) {
        let view = ViewSpy(), router = RouterSpy()
        return (RecipeDetailPresenter(view: view, router: router, match: match), view, router)
    }

    func test_viewDidLoad_describesTheRecipeAndWhatYouHave() async throws {
        // Arrange
        let (sut, view, _) = makeSUT(makeMatch())

        // Act
        sut.viewDidLoad()

        // Assert
        let detail = try XCTUnwrap(view.detail)
        XCTAssertEqual(detail.title, "Quiche")
        XCTAssertEqual(detail.subtitle, "Starter · French")
        XCTAssertEqual(detail.haveSummary, "You have 1 of 2 ingredients")
        XCTAssertEqual(detail.ingredients.map(\.text), ["Eggs - 3", "Cream"])
        XCTAssertEqual(detail.ingredients.map(\.have), [true, false])
        XCTAssertEqual(detail.ingredients[1].accessibilityText, "Cream, you need to get this")
        XCTAssertEqual(detail.steps, ["Mix.", "Bake."])
    }

    func test_buttons_appearOnlyWhenTheRecipeHasThoseLinks() async throws {
        // Arrange
        let both = makeSUT(makeMatch(source: "https://example.com/r", video: "https://youtube.com/x"))
        let neither = makeSUT(makeMatch(source: nil, video: nil))

        // Act
        both.0.viewDidLoad(); neither.0.viewDidLoad()

        // Assert
        XCTAssertNotNil(both.1.detail?.sourceButtonTitle)
        XCTAssertNotNil(both.1.detail?.videoButtonTitle)
        XCTAssertNil(neither.1.detail?.sourceButtonTitle)
        XCTAssertNil(neither.1.detail?.videoButtonTitle)
    }

    func test_tappingTheButtons_opensTheLinks() async {
        // Arrange
        let (sut, _, router) = makeSUT(makeMatch(source: "https://example.com/r", video: "https://youtube.com/x"))

        // Act
        sut.didTapSource()
        sut.didTapVideo()

        // Assert
        XCTAssertEqual(router.opened.map(\.absoluteString), ["https://example.com/r", "https://youtube.com/x"])
    }

    func test_tappingMissingLinks_doesNothing() async {
        let (sut, _, router) = makeSUT(makeMatch(source: nil, video: nil))
        sut.didTapSource(); sut.didTapVideo()
        XCTAssertTrue(router.opened.isEmpty)
    }

    func test_steps_dropLinesThatOnlyLabelAStep() async {
        // Arrange
        let raw = "STEP 1\r\nHeat the oven.\r\n\r\nstep 2\nAdd the eggs.\n3.\nServe warm.\n  \n4)"

        // Act
        let steps = RecipeDetailPresenter.steps(from: raw)

        // Assert
        XCTAssertEqual(steps, ["Heat the oven.", "Add the eggs.", "Serve warm."])
    }

    func test_steps_keepRealLinesThatStartWithNumbers() async {
        XCTAssertEqual(RecipeDetailPresenter.steps(from: "350g flour is needed.\n2 eggs, beaten."),
                       ["350g flour is needed.", "2 eggs, beaten."])
    }
}
