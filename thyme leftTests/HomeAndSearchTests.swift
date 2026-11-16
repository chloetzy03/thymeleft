import XCTest
@testable import thyme_left

// MARK: - Home: week strip and tonight's idea

@MainActor
final class HomeWeekAndIdeaTests: XCTestCase {

    private final class OutputSpy: HomeInteractorOutput {
        var snapshots: [HomeSnapshot] = []
        func didLoad(_ snapshot: HomeSnapshot) { snapshots.append(snapshot) }
        func didFail() {}
    }

    private let now = TestCalendar.date(2026, 11, 15)

    private func item(_ name: String, days: Int) -> PantryItem {
        PantryItem(name: name, location: .fridge,
                   expiryDate: TestCalendar.utc.date(byAdding: .day, value: days, to: now)!)
    }

    private func load(items: [PantryItem], cache: InMemoryRecipeCache? = nil) -> HomeSnapshot? {
        let sut = HomeInteractor(repository: InMemoryPantryRepository(items: items),
                                 outcomes: InMemoryOutcomeRepository(),
                                 settingsStore: InMemorySettingsStore(),
                                 dateProvider: FixedDateProvider(now: now),
                                 recipeCache: cache, calendar: TestCalendar.utc)
        let output = OutputSpy()
        sut.output = output
        sut.loadHome()
        return output.snapshots.first
    }

    func test_week_countsItemsOnEachOfTheNextSevenDays() async {
        let snapshot = load(items: [item("Milk", days: 0), item("Yoghurt", days: 0), item("Eggs", days: 3),
                                    item("Cheese", days: 9), item("Bread", days: -2)])

        XCTAssertEqual(snapshot?.week.map(\.count), [2, 0, 0, 1, 0, 0, 0])
        XCTAssertEqual(snapshot?.week.first?.date, TestCalendar.utc.startOfDay(for: now))
        XCTAssertEqual(snapshot?.pastCount, 1, "the expired bread is counted separately")
    }

    func test_week_dayStatusFollowsTheRedAmberRules() async {
        let snapshot = load(items: [])

        XCTAssertEqual(snapshot?.week.map(\.status), [.urgent, .urgent, .soon, .soon, .soon, .soon, .fresh])
    }

    func test_idea_isTheBestSavedRecipeForYourUrgentFood() async {
        let cache = InMemoryRecipeCache()
        cache.store([RecipeFixtures.recipe("1", "Milk Pudding", ingredients: ["Milk", "Sugar"]),
                     RecipeFixtures.recipe("2", "Plain Rice", ingredients: ["Rice"])])

        let snapshot = load(items: [item("Milk", days: 1), item("Rice", days: 60)], cache: cache)

        XCTAssertEqual(snapshot?.recipeIdea?.name, "Milk Pudding")
        XCTAssertEqual(snapshot?.recipeIdea?.usedItemNames, ["Milk"])
        XCTAssertEqual(snapshot?.recipeIdea?.missingCount, 1)
    }

    func test_idea_isAbsentWithoutSavedRecipes_orWhenNothingIsUrgent() async {
        let cache = InMemoryRecipeCache()
        cache.store([RecipeFixtures.recipe("1", "Milk Pudding", ingredients: ["Milk", "Sugar"])])

        XCTAssertNil(load(items: [item("Milk", days: 1)], cache: InMemoryRecipeCache())?.recipeIdea, "no saved recipes")
        XCTAssertNil(load(items: [item("Milk", days: 40)], cache: cache)?.recipeIdea, "nothing urgent")
    }

    func test_idea_neverUsesExpiredFood() async {
        let cache = InMemoryRecipeCache()
        cache.store([RecipeFixtures.recipe("1", "Milk Pudding", ingredients: ["Milk", "Sugar"])])

        XCTAssertNil(load(items: [item("Milk", days: -1)], cache: cache)?.recipeIdea)
    }
}

@MainActor
final class HomeWeekAndIdeaPresenterTests: XCTestCase {

    private final class ViewSpy: HomeViewProtocol {
        var home: HomeViewModel?
        func showHome(_ home: HomeViewModel) { self.home = home }
    }
    private final class InteractorSpy: HomeInteractorInput { func loadHome() {} }
    private final class RouterSpy: HomeRouterProtocol {
        var recipes = 0, pantry = 0, scan = 0, add = 0
        func showRecipes() { recipes += 1 }
        func showPantry() { pantry += 1 }
        func showScan() { scan += 1 }
        func showAddItem() { add += 1 }
    }

    private func makeSUT() -> (HomePresenter, ViewSpy, RouterSpy) {
        let view = ViewSpy(), router = RouterSpy()
        let sut = HomePresenter(view: view, interactor: InteractorSpy(), router: router,
                                iconProvider: EmojiFoodIconProvider(),
                                dateProvider: FixedDateProvider(now: TestCalendar.date(2026, 11, 15, hour: 9)),
                                calendar: TestCalendar.utc, locale: Locale(identifier: "en_US"))
        return (sut, view, router)
    }

    private func week(_ counts: [Int]) -> [HomeWeekDay] {
        counts.enumerated().map { offset, count in
            HomeWeekDay(date: TestCalendar.utc.date(byAdding: .day, value: offset, to: TestCalendar.date(2026, 11, 15))!,
                        count: count, status: offset == 0 ? .urgent : .soon)
        }
    }

    func test_week_labelsTodayThenWeekdays_andSaysHowManyRunOut() async throws {
        let (sut, view, _) = makeSUT()

        sut.didLoad(HomeSnapshot(useSoon: [], attentionCount: 0, pantryCount: 4, usedThisMonth: 0, savedValue: nil,
                                 week: week([2, 0, 0, 1, 0, 0, 0]), pastCount: 0))

        let model = try XCTUnwrap(view.home?.week)
        XCTAssertEqual(model.days.map(\.label), ["Today", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        XCTAssertEqual(model.days.map(\.countText), ["2", "·", "·", "1", "·", "·", "·"])
        XCTAssertEqual(model.subtitle, "3 items run out in the next 7 days.")
        XCTAssertNil(model.footnote)
    }

    func test_week_subtitleAndFootnote_forTheSpecialCases() async throws {
        let (sut, view, _) = makeSUT()

        sut.didLoad(HomeSnapshot(useSoon: [], attentionCount: 0, pantryCount: 4, usedThisMonth: 0, savedValue: nil,
                                 week: week([0, 0, 0, 0, 0, 0, 0]), pastCount: 2))
        XCTAssertEqual(view.home?.week?.subtitle, "Nothing runs out in the next 7 days.")
        XCTAssertEqual(view.home?.week?.footnote, "2 items are already past their date.")

        sut.didLoad(HomeSnapshot(useSoon: [], attentionCount: 0, pantryCount: 4, usedThisMonth: 0, savedValue: nil,
                                 week: week([1, 0, 0, 0, 0, 0, 0]), pastCount: 1))
        XCTAssertEqual(view.home?.week?.subtitle, "1 item runs out in the next 7 days.")
        XCTAssertEqual(view.home?.week?.footnote, "1 item is already past its date.")
    }

    func test_week_isHiddenWhileThePantryIsEmpty() async {
        let (sut, view, _) = makeSUT()

        sut.didLoad(HomeSnapshot(useSoon: [], attentionCount: 0, pantryCount: 0, usedThisMonth: 0, savedValue: nil,
                                 week: week([0, 0, 0, 0, 0, 0, 0])))

        XCTAssertNil(view.home?.week)
    }

    func test_idea_isDescribedInPlainWords() async throws {
        let (sut, view, _) = makeSUT()

        sut.didLoad(HomeSnapshot(useSoon: [], attentionCount: 1, pantryCount: 3, usedThisMonth: 0, savedValue: nil,
                                 recipeIdea: HomeRecipeIdea(name: "Milk Pudding", usedItemNames: ["Milk", "Eggs"], missingCount: 1)))

        let idea = try XCTUnwrap(view.home?.idea)
        XCTAssertEqual(idea.title, "Milk Pudding")
        XCTAssertEqual(idea.subtitle, "Uses Milk, Eggs · 1 more to find")
        XCTAssertEqual(idea.accessibilityText, "Tonight's idea: Milk Pudding. Uses Milk, Eggs · 1 more to find")
    }

    func test_idea_saysWhenYouHaveEverything() async throws {
        let (sut, view, _) = makeSUT()

        sut.didLoad(HomeSnapshot(useSoon: [], attentionCount: 1, pantryCount: 3, usedThisMonth: 0, savedValue: nil,
                                 recipeIdea: HomeRecipeIdea(name: "Toast", usedItemNames: ["Bread"], missingCount: 0)))

        XCTAssertEqual(view.home?.idea?.subtitle, "Uses Bread · you have everything")
    }

    func test_shortcuts_goToTheRightPlaces() async {
        let (sut, _, router) = makeSUT()

        sut.didTapScan(); sut.didTapAdd(); sut.didTapWeek(); sut.didTapIdea()

        XCTAssertEqual(router.scan, 1)
        XCTAssertEqual(router.add, 1)
        XCTAssertEqual(router.pantry, 1)
        XCTAssertEqual(router.recipes, 1)
    }
}

// MARK: - Recipe search: Interactor

@MainActor
final class RecipeSearchInteractorTests: XCTestCase {

    private final class OutputSpy: RecipesInteractorOutput {
        var results: [(matches: [RecipeMatch], query: String, offline: Bool)] = []
        var noResults: [String] = []
        var failures: [RecipesFailure] = []
        var expectation: XCTestExpectation?
        private func signal() { expectation?.fulfill(); expectation = nil }

        func didLoad(matches: [RecipeMatch], rescueItemNames: [String], isOffline: Bool) {}
        func didFindNoPantryItems() {}
        func didFindNoRecipes() {}
        func didFail(_ failure: RecipesFailure) {}
        func didLoadSearch(matches: [RecipeMatch], query: String, isOffline: Bool) {
            results.append((matches, query, isOffline)); signal()
        }
        func didFindNoSearchResults(query: String) { noResults.append(query); signal() }
        func didFailSearch(_ failure: RecipesFailure) { failures.append(failure); signal() }
    }

    private let today = TestCalendar.date(2026, 11, 15)

    private func makeSUT(items: [PantryItem] = [], service: StubRecipeService? = nil,
                         cache: InMemoryRecipeCache? = nil) -> (RecipesInteractor, OutputSpy, StubRecipeService) {
        let cache = cache ?? InMemoryRecipeCache()
        let soup = RecipeFixtures.recipe("1", "Spinach Soup", ingredients: ["Spinach", "Stock"])
        let green = RecipeFixtures.recipe("2", "Green Pie", ingredients: ["Spinach", "Flour", "Butter"])
        let pasta = RecipeFixtures.recipe("3", "Tomato Pasta", ingredients: ["Pasta", "Tomato"])
        let service = service ?? StubRecipeService(
            known: ["Spinach", "Pasta", "Tomato"],
            summariesByIngredient: ["Spinach": [RecipeSummary(id: "1", name: "Spinach Soup"), RecipeSummary(id: "2", name: "Green Pie")]],
            recipes: ["1": soup, "2": green, "3": pasta])
        let sut = RecipesInteractor(repository: InMemoryPantryRepository(items: items),
                                    settingsStore: InMemorySettingsStore(), dateProvider: FixedDateProvider(now: today),
                                    service: service, cache: cache, calendar: TestCalendar.utc)
        let output = OutputSpy()
        sut.output = output
        return (sut, output, service)
    }

    private func search(_ sut: RecipesInteractor, _ output: OutputSpy, _ query: String) async {
        let done = expectation(description: "reported")
        output.expectation = done
        sut.search(query: query)
        await fulfillment(of: [done], timeout: 3)
    }

    private func item(_ name: String, days: Int) -> PantryItem {
        PantryItem(name: name, location: .fridge,
                   expiryDate: TestCalendar.utc.date(byAdding: .day, value: days, to: today)!)
    }

    func test_search_byDishName_findsItEvenWithAnEmptyPantry() async throws {
        let (sut, output, _) = makeSUT()

        await search(sut, output, "pasta")

        let result = try XCTUnwrap(output.results.first)
        XCTAssertEqual(result.matches.map(\.recipe.name), ["Tomato Pasta"])
        XCTAssertEqual(result.matches.first?.missingIngredients, ["Pasta", "Tomato"])
        XCTAssertFalse(result.offline)
    }

    func test_search_byIngredient_addsDishesMadeWithIt_withoutDuplicates() async throws {
        let (sut, output, _) = makeSUT()

        await search(sut, output, "Spinach")

        // "Spinach Soup" matches by name; "Green Pie" only by ingredient.
        let names = try XCTUnwrap(output.results.first).matches.map(\.recipe.name)
        XCTAssertEqual(Set(names), ["Spinach Soup", "Green Pie"])
        XCTAssertEqual(names.count, 2)
    }

    func test_search_showsWhatYouAlreadyHave_andPutsTheEasiestFirst() async throws {
        let (sut, output, _) = makeSUT(items: [item("Spinach", days: 3), item("Flour", days: 9), item("Butter", days: 9)])

        await search(sut, output, "Spinach")

        let matches = try XCTUnwrap(output.results.first).matches
        XCTAssertEqual(matches.map(\.recipe.name), ["Green Pie", "Spinach Soup"], "Green Pie only misses nothing")
        XCTAssertEqual(matches.first?.missingIngredients, [])
        XCTAssertEqual(matches.last?.missingIngredients, ["Stock"])
    }

    func test_search_withNoMatches_saysSo() async {
        let (sut, output, _) = makeSUT()

        await search(sut, output, "zzzz")

        XCTAssertEqual(output.noResults, ["zzzz"])
        XCTAssertTrue(output.results.isEmpty)
    }

    func test_search_whenOffline_looksThroughSavedRecipes() async throws {
        let cache = InMemoryRecipeCache()
        cache.store([RecipeFixtures.recipe("9", "Saved Lasagne", ingredients: ["Pasta", "Beef"])])
        let (sut, output, _) = makeSUT(service: StubRecipeService(error: .offline), cache: cache)

        await search(sut, output, "pasta") // found through its ingredient list

        let result = try XCTUnwrap(output.results.first)
        XCTAssertEqual(result.matches.map(\.recipe.name), ["Saved Lasagne"])
        XCTAssertTrue(result.offline)
    }

    func test_search_whenOfflineAndNothingSaved_explainsWhy() async {
        let (sut, output, _) = makeSUT(service: StubRecipeService(error: .offline))

        await search(sut, output, "pasta")

        XCTAssertEqual(output.failures, [.offlineAndNothingSaved])
    }

    func test_search_rememberesWhatItFoundForOfflineLater() async {
        let cache = InMemoryRecipeCache()
        let (sut, output, _) = makeSUT(cache: cache)

        await search(sut, output, "pasta")

        XCTAssertEqual(cache.allRecipes().map(\.name), ["Tomato Pasta"])
    }

    func test_search_withOnlySpaces_doesNothing() async {
        let (sut, output, service) = makeSUT()

        sut.search(query: "   ")
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(output.results.isEmpty)
        XCTAssertTrue(service.searchedNames.isEmpty)
    }
}

// MARK: - Recipe search: Presenter

@MainActor
final class RecipeSearchPresenterTests: XCTestCase {

    private final class ViewSpy: RecipesViewProtocol {
        var screen: RecipesScreenViewModel?
        var message: (title: String, message: String)?
        var loadingCount = 0
        var statuses: [String?] = []
        func showSortModes(titles: [String], selectedIndex: Int) {}
        func showLoading() { loadingCount += 1 }
        func showRecipes(_ screen: RecipesScreenViewModel) { self.screen = screen; message = nil }
        func showMessage(emoji: String, title: String, message: String, buttonTitle: String?) {
            self.message = (title, message); screen = nil
        }
        func showSearchStatus(_ text: String?) { statuses.append(text) }
    }
    private final class InteractorSpy: RecipesInteractorInput {
        var loads = 0
        var searches: [String] = []
        func loadRecipes(sort: RecipeSortMode) { loads += 1 }
        func changeSort(_ sort: RecipeSortMode) {}
        func search(query: String) { searches.append(query) }
    }
    private final class RouterSpy: RecipesRouterProtocol {
        var shown: [RecipeMatch] = []
        func showRecipe(_ match: RecipeMatch) { shown.append(match) }
    }

    private func makeSUT() -> (RecipesPresenter, ViewSpy, InteractorSpy, RouterSpy) {
        let view = ViewSpy(), interactor = InteractorSpy(), router = RouterSpy()
        return (RecipesPresenter(view: view, interactor: interactor, router: router, searchDelay: .zero),
                view, interactor, router)
    }

    private func wait() async { try? await Task.sleep(for: .milliseconds(60)) }

    private func match(_ id: String, _ name: String, have: [Bool]) -> RecipeMatch {
        let ingredients = have.enumerated().map { RecipeIngredient(name: "Item \($0.offset)", measure: "1") }
        let availability = zip(ingredients, have).map { RecipeMatch.IngredientAvailability(ingredient: $0, have: $1) }
        return RecipeMatch(recipe: RecipeFixtures.recipe(id, name, ingredients: ingredients.map(\.name)),
                           usedItemNames: [], missingIngredients: availability.filter { !$0.have }.map(\.ingredient.name),
                           ingredientAvailability: availability, urgencyScore: 0)
    }

    func test_typing_waitsThenSearches_andShowsASearchingStatus() async {
        let (sut, view, interactor, _) = makeSUT()

        sut.didChangeSearchText("  pasta ")
        await wait()

        XCTAssertEqual(interactor.searches, ["pasta"])
        XCTAssertEqual(view.statuses.first ?? nil, "Searching for \u{201C}pasta\u{201D}…")
        XCTAssertEqual(view.loadingCount, 1)
    }

    func test_typingQuickly_onlySearchesForTheLastWord() async {
        let (sut, _, interactor, _) = makeSUT()
        let slow = RecipesPresenter(view: ViewSpy(), interactor: interactor, router: RouterSpy(), searchDelay: .milliseconds(150))

        slow.didChangeSearchText("p")
        slow.didChangeSearchText("pa")
        slow.didChangeSearchText("pasta")
        try? await Task.sleep(for: .milliseconds(400))

        XCTAssertEqual(interactor.searches, ["pasta"])
        _ = sut
    }

    func test_submitting_searchesAtOnce() async {
        let (sut, _, interactor, _) = makeSUT()

        sut.didSubmitSearch("rice")

        XCTAssertEqual(interactor.searches, ["rice"])
    }

    func test_results_showHowMuchYouAlreadyHave_withoutTheSortSwitch() async throws {
        let (sut, view, _, _) = makeSUT()
        sut.didSubmitSearch("pasta")

        sut.didLoadSearch(matches: [match("1", "Tomato Pasta", have: [true, false, true]),
                                    match("2", "Plain Pasta", have: [true, true])],
                          query: "pasta", isOffline: false)

        let screen = try XCTUnwrap(view.screen)
        XCTAssertEqual(screen.rescueSummary, "2 recipes for \u{201C}pasta\u{201D}")
        XCTAssertFalse(screen.showsSortControl)
        XCTAssertEqual(screen.rows.map(\.usesText), ["You have 2 of 3 ingredients", "You have 2 of 2 ingredients"])
        XCTAssertEqual(screen.rows.map(\.missingText), ["Missing: Item 1", "You have everything"])
        XCTAssertNil(screen.banner)
    }

    func test_offlineResults_explainTheyAreSavedOnes() async throws {
        let (sut, view, _, _) = makeSUT()
        sut.didSubmitSearch("pasta")

        sut.didLoadSearch(matches: [match("1", "Saved", have: [true])], query: "pasta", isOffline: true)

        XCTAssertEqual(view.screen?.banner, "You're offline, so we only searched recipes saved on your phone.")
    }

    func test_noResults_suggestsWhatToTry() async {
        let (sut, view, _, _) = makeSUT()
        sut.didSubmitSearch("zzzz")

        sut.didFindNoSearchResults(query: "zzzz")

        XCTAssertEqual(view.message?.title, "No recipes found")
        XCTAssertTrue(view.message?.message.contains("zzzz") ?? false)
    }

    func test_cancellingTheSearch_putsTheSuggestionsBack() async throws {
        let (sut, view, _, _) = makeSUT()
        sut.didLoad(matches: [match("1", "Milk Pudding", have: [true])], rescueItemNames: ["Milk"], isOffline: false)
        let suggestions = try XCTUnwrap(view.screen)
        sut.didSubmitSearch("pasta")
        sut.didLoadSearch(matches: [match("2", "Pasta", have: [false])], query: "pasta", isOffline: false)

        sut.didCancelSearch()

        XCTAssertEqual(view.screen, suggestions)
        XCTAssertEqual(view.statuses.last ?? "x", nil)
    }

    func test_clearingTheText_alsoPutsTheSuggestionsBack() async throws {
        let (sut, view, _, _) = makeSUT()
        sut.didLoad(matches: [match("1", "Milk Pudding", have: [true])], rescueItemNames: [], isOffline: false)
        let suggestions = try XCTUnwrap(view.screen)
        sut.didSubmitSearch("pasta")
        sut.didLoadSearch(matches: [match("2", "Pasta", have: [false])], query: "pasta", isOffline: false)

        sut.didChangeSearchText("")

        XCTAssertEqual(view.screen, suggestions)
    }

    func test_suggestionsArrivingLate_doNotReplaceSearchResults() async throws {
        let (sut, view, _, _) = makeSUT()
        sut.didSubmitSearch("pasta")
        sut.didLoadSearch(matches: [match("2", "Pasta", have: [false])], query: "pasta", isOffline: false)

        sut.didLoad(matches: [match("1", "Milk Pudding", have: [true])], rescueItemNames: [], isOffline: false)

        XCTAssertEqual(view.screen?.rows.map(\.title), ["Pasta"])
    }

    func test_tappingASearchResult_opensIt() async {
        let (sut, _, _, router) = makeSUT()
        sut.didSubmitSearch("pasta")
        sut.didLoadSearch(matches: [match("2", "Pasta", have: [false])], query: "pasta", isOffline: false)

        sut.didSelectRecipe(id: "2")

        XCTAssertEqual(router.shown.map(\.recipe.id), ["2"])
    }

    func test_comingBackFromARecipe_whileSearching_doesNotReloadSuggestions() async {
        let (sut, _, interactor, _) = makeSUT()
        sut.didSubmitSearch("pasta")

        sut.viewWillAppear()

        XCTAssertEqual(interactor.loads, 0)
    }

    func test_cancellingBeforeAnySuggestionsLoaded_loadsThem() async {
        let (sut, view, interactor, _) = makeSUT()
        sut.didSubmitSearch("pasta")

        sut.didCancelSearch()

        XCTAssertEqual(interactor.loads, 1)
        XCTAssertGreaterThan(view.loadingCount, 1)
    }

    func test_failedSearch_showsAFriendlyMessage() async {
        let (sut, view, _, _) = makeSUT()
        sut.didSubmitSearch("pasta")

        sut.didFailSearch(.offlineAndNothingSaved)

        XCTAssertEqual(view.message?.title, "You're offline")
    }
}
