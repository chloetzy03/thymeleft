import XCTest
import SwiftData
@testable import thyme_left

// MARK: - Home Interactor

@MainActor
final class HomeInteractorTests: XCTestCase {

    private final class OutputSpy: HomeInteractorOutput {
        var snapshots: [HomeSnapshot] = []
        var failureCount = 0
        func didLoad(_ snapshot: HomeSnapshot) { snapshots.append(snapshot) }
        func didFail() { failureCount += 1 }
    }

    /// "Now" is 15 Nov 2026.
    private let now = TestCalendar.date(2026, 11, 15)

    private func item(_ name: String, days: Int) -> PantryItem {
        PantryItem(name: name, location: .fridge, expiryDate: TestCalendar.utc.date(byAdding: .day, value: days, to: now)!)
    }

    private func makeSUT(items: [PantryItem] = [], history: [OutcomeEntry] = [], settings: AppSettings = AppSettings())
        -> (sut: HomeInteractor, output: OutputSpy) {
        let sut = HomeInteractor(repository: InMemoryPantryRepository(items: items),
                                 outcomes: InMemoryOutcomeRepository(entries: history),
                                 settingsStore: InMemorySettingsStore(settings: settings),
                                 dateProvider: FixedDateProvider(now: now), calendar: TestCalendar.utc)
        let output = OutputSpy()
        sut.output = output
        return (sut, output)
    }

    private func used(_ name: String = "Milk", on date: Date) -> OutcomeEntry {
        OutcomeEntry(itemName: name, outcome: .used, date: date)
    }

    func test_loadHome_showsTheThreeSoonestItems_andCountsAllThatNeedAttention() async throws {
        // Arrange: 5 items need attention (one expired), 1 is fresh
        let (sut, output) = makeSUT(items: [item("Pasta", days: 100), item("Milk", days: 3), item("Yoghurt", days: -1),
                                            item("Avocado", days: 1), item("Spinach", days: 4), item("Eggs", days: 5)])

        // Act
        sut.loadHome()

        // Assert
        let snapshot = try XCTUnwrap(output.snapshots.first)
        XCTAssertEqual(snapshot.useSoon.map(\.item.name), ["Yoghurt", "Avocado", "Milk"])
        XCTAssertEqual(snapshot.attentionCount, 5)
        XCTAssertEqual(snapshot.pantryCount, 6)
    }

    func test_loadHome_withNothingExpiringSoon_hasNoTiles() async throws {
        let (sut, output) = makeSUT(items: [item("Pasta", days: 100)])
        sut.loadHome()
        let snapshot = try XCTUnwrap(output.snapshots.first)
        XCTAssertTrue(snapshot.useSoon.isEmpty)
        XCTAssertEqual(snapshot.attentionCount, 0)
        XCTAssertEqual(snapshot.pantryCount, 1)
    }

    func test_loadHome_countsOnlyFoodUsedThisCalendarMonth() async throws {
        // Arrange: used twice in November, once in October, plus one thrown away this month
        let history = [used(on: TestCalendar.date(2026, 11, 1)), used(on: TestCalendar.date(2026, 11, 14)),
                       used(on: TestCalendar.date(2026, 10, 31)),
                       OutcomeEntry(itemName: "Bread", outcome: .wasted, date: TestCalendar.date(2026, 11, 10))]
        let (sut, output) = makeSUT(history: history)

        // Act
        sut.loadHome()

        // Assert
        XCTAssertEqual(output.snapshots.first?.usedThisMonth, 2)
    }

    func test_loadHome_sameMonthInAnotherYear_doesNotCount() async throws {
        let (sut, output) = makeSUT(history: [used(on: TestCalendar.date(2025, 11, 15))])
        sut.loadHome()
        XCTAssertEqual(output.snapshots.first?.usedThisMonth, 0)
    }

    func test_loadHome_estimatesMoneyFromTheUsersValue_orHidesItWhenTurnedOff() async throws {
        // Arrange
        var priced = AppSettings()
        priced.averageItemValue = 5
        var hidden = AppSettings()
        hidden.showMoneySaved = false
        let history = [used(on: now), used(on: now), used(on: now)]
        let withMoney = makeSUT(history: history, settings: priced)
        let withoutMoney = makeSUT(history: history, settings: hidden)

        // Act
        withMoney.sut.loadHome()
        withoutMoney.sut.loadHome()

        // Assert
        XCTAssertEqual(withMoney.output.snapshots.first?.savedValue, 15)
        XCTAssertNil(withoutMoney.output.snapshots.first?.savedValue)
    }

    func test_loadHome_countsEachItemAtItsOwnPrice_andOthersAtTheAverage() async throws {
        // Arrange: two priced items and one without a price
        var settings = AppSettings()
        settings.averageItemValue = 5
        let history = [OutcomeEntry(itemName: "Steak", outcome: .used, date: now, value: 12.5),
                       OutcomeEntry(itemName: "Carrot", outcome: .used, date: now, value: 0.5),
                       used(on: now)]
        let made = makeSUT(history: history, settings: settings)

        // Act
        made.sut.loadHome()

        // Assert: 12.5 + 0.5 + the 5 average
        XCTAssertEqual(made.output.snapshots.first?.savedValue, 18)
    }

    func test_loadHome_usesTheRedAmberThresholdsFromSettings() async throws {
        // Arrange: with a 10-day amber window, an item due in 8 days needs attention
        var settings = AppSettings()
        settings.soonDays = 10
        let (sut, output) = makeSUT(items: [item("Cheese", days: 8)], settings: settings)

        // Act
        sut.loadHome()

        // Assert
        XCTAssertEqual(output.snapshots.first?.attentionCount, 1)
    }
}

// MARK: - Home Presenter

@MainActor
final class HomePresenterTests: XCTestCase {

    private final class ViewSpy: HomeViewProtocol {
        var home: HomeViewModel?
        func showHome(_ home: HomeViewModel) { self.home = home }
    }

    private final class InteractorSpy: HomeInteractorInput {
        var loadCount = 0
        func loadHome() { loadCount += 1 }
    }

    private final class RouterSpy: HomeRouterProtocol {
        var recipesCount = 0, pantryCount = 0, scanCount = 0, addCount = 0
        func showRecipes() { recipesCount += 1 }
        func showPantry() { pantryCount += 1 }
        func showScan() { scanCount += 1 }
        func showAddItem() { addCount += 1 }
    }

    private func makeSUT(hour: Int = 9) -> (sut: HomePresenter, view: ViewSpy, interactor: InteractorSpy, router: RouterSpy) {
        let view = ViewSpy(), interactor = InteractorSpy(), router = RouterSpy()
        let sut = HomePresenter(view: view, interactor: interactor, router: router,
                                iconProvider: EmojiFoodIconProvider(),
                                dateProvider: FixedDateProvider(now: TestCalendar.date(2026, 11, 15, hour: hour)),
                                calendar: TestCalendar.utc, locale: Locale(identifier: "en_US"))
        return (sut, view, interactor, router)
    }

    private func entry(_ name: String, days: Int, status: ExpiryStatus) -> ExpiringItem {
        ExpiringItem(item: PantryItem(name: name, location: .fridge, expiryDate: Date()), daysRemaining: days, status: status)
    }

    private func snapshot(soon: [ExpiringItem] = [], attention: Int? = nil, pantry: Int = 5,
                          used: Int = 0, value: Double? = nil) -> HomeSnapshot {
        HomeSnapshot(useSoon: soon, attentionCount: attention ?? soon.count, pantryCount: pantry,
                     usedThisMonth: used, savedValue: value)
    }

    func test_greeting_changesWithTheTimeOfDay() async {
        // Arrange: (hour, expected greeting) at every boundary
        let cases: [(Int, String)] = [(0, "Good evening, chef!"), (4, "Good evening, chef!"), (5, "Good morning, chef!"),
                                      (11, "Good morning, chef!"), (12, "Good afternoon, chef!"),
                                      (17, "Good afternoon, chef!"), (18, "Good evening, chef!"), (23, "Good evening, chef!")]

        for (hour, expected) in cases {
            // Act
            let (sut, _, _, _) = makeSUT(hour: hour)

            // Assert
            XCTAssertEqual(sut.greeting(), expected, "hour \(hour)")
        }
    }

    func test_viewWillAppear_asksTheInteractorToLoad() async {
        let (sut, _, interactor, _) = makeSUT()
        sut.viewWillAppear()
        XCTAssertEqual(interactor.loadCount, 1)
    }

    func test_didLoad_describesWhatToUseSoon() async throws {
        // Arrange
        let (sut, view, _, _) = makeSUT()
        let soon = [entry("Avocado", days: 1, status: .urgent), entry("Milk", days: 3, status: .soon)]

        // Act
        sut.didLoad(snapshot(soon: soon, attention: 4))

        // Assert
        let home = try XCTUnwrap(view.home)
        XCTAssertEqual(home.summary, "You've got 4 ingredients to use soon.")
        XCTAssertEqual(home.tiles.map(\.name), ["Avocado", "Milk"])
        XCTAssertEqual(home.tiles.map(\.emoji), ["🥑", "🥛"])
        XCTAssertEqual(home.tiles.map(\.badgeText), ["1 day", "3 days"])
        XCTAssertEqual(home.tiles[0].accessibilityText, "Avocado, expires tomorrow")
        XCTAssertNil(home.addFirstTitle)
    }

    func test_summary_forEachSituation() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act + Assert
        sut.didLoad(snapshot(pantry: 0))
        XCTAssertEqual(view.home?.summary, "Your pantry is empty. Add something and we'll watch the dates.")
        XCTAssertEqual(view.home?.addFirstTitle, "Add your first item")

        sut.didLoad(snapshot(attention: 0, pantry: 3))
        XCTAssertEqual(view.home?.summary, "Nothing is about to expire. Nice work!")

        sut.didLoad(snapshot(soon: [entry("Milk", days: 1, status: .urgent)]))
        XCTAssertEqual(view.home?.summary, "You've got 1 ingredient to use soon.")
    }

    func test_savedText_forEachSituation() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act + Assert
        sut.didLoad(snapshot(used: 0))
        XCTAssertEqual(view.home?.savedText, "Swipe a pantry item and tap \"Used it\" when you finish it. It counts here.")

        sut.didLoad(snapshot(used: 1, value: 3))
        XCTAssertEqual(view.home?.savedText, "1 item used up this month · about $3")

        sut.didLoad(snapshot(used: 12, value: 36))
        XCTAssertEqual(view.home?.savedText, "12 items used up this month · about $36")

        sut.didLoad(snapshot(used: 12, value: nil))
        XCTAssertEqual(view.home?.savedText, "12 items used up this month", "the money estimate is off")
    }

    func test_buttons_switchToTheRightTab() async {
        // Arrange
        let (sut, _, _, router) = makeSUT()

        // Act
        sut.didTapCook()
        sut.didTapTile(id: UUID())
        sut.didTapAddFirst()

        // Assert
        XCTAssertEqual(router.recipesCount, 1)
        XCTAssertEqual(router.pantryCount, 2)
    }

    func test_didFail_showsACalmEmptyHome() async {
        let (sut, view, _, _) = makeSUT()
        sut.didFail()
        XCTAssertNotNil(view.home)
        XCTAssertTrue(view.home?.tiles.isEmpty ?? false)
    }
}

// MARK: - Saved data and money formatting

@MainActor
final class OutcomeAndPersistenceTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: PantryItemRecord.self, OutcomeRecord.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func test_swiftDataOutcomes_saveAndLoadInOrder() async throws {
        // Arrange
        let container = try makeContainer() // must stay alive while its context is used
        let repository = SwiftDataOutcomeRepository(context: container.mainContext)
        let first = OutcomeEntry(itemName: "Milk", outcome: .used, date: TestCalendar.date(2026, 11, 1))
        let second = OutcomeEntry(itemName: "Bread", outcome: .wasted, date: TestCalendar.date(2026, 11, 5))

        // Act: saved out of order
        try repository.record(second)
        try repository.record(first)
        let loaded = try repository.fetchAll()

        // Assert
        XCTAssertEqual(loaded, [first, second])
    }

    func test_swiftDataPantry_remembersEveryFieldIncludingReminderAndPhoto() async throws {
        // Arrange
        let container = try makeContainer() // must stay alive while its context is used
        let repository = SwiftDataPantryRepository(context: container.mainContext)
        let item = PantryItem(name: "Greek yoghurt", quantity: 4, location: .freezer,
                              expiryDate: TestCalendar.date(2026, 12, 1), reminder: .daysBefore(3),
                              photoFileName: "abc.jpg", createdAt: TestCalendar.date(2026, 11, 1))

        // Act
        try repository.save(item)
        let loaded = try XCTUnwrap(try repository.fetchAll().first)

        // Assert
        XCTAssertEqual(loaded, item)
    }

    func test_swiftDataOutcomes_rememberThePriceWhenThereIsOne() async throws {
        // Arrange
        let container = try makeContainer() // must stay alive while its context is used
        let repository = SwiftDataOutcomeRepository(context: container.mainContext)
        let priced = OutcomeEntry(itemName: "Steak", outcome: .used, date: TestCalendar.date(2026, 11, 1), value: 12.5)
        let unpriced = OutcomeEntry(itemName: "Milk", outcome: .used, date: TestCalendar.date(2026, 11, 2))

        // Act
        try repository.record(priced)
        try repository.record(unpriced)

        // Assert
        let loaded = try repository.fetchAll()
        XCTAssertEqual(loaded.first?.value, 12.5)
        XCTAssertNil(loaded.last?.value)
    }

    func test_swiftDataPantry_remembersDateTypeAndPrice() async throws {
        // Arrange
        let container = try makeContainer() // must stay alive while its context is used
        let repository = SwiftDataPantryRepository(context: container.mainContext)
        let item = PantryItem(name: "Chicken", location: .fridge, expiryDate: TestCalendar.date(2026, 11, 20),
                              dateType: .useBy, price: 7.25)

        // Act
        try repository.save(item)

        // Assert
        let loaded = try XCTUnwrap(try repository.fetchAll().first)
        XCTAssertEqual(loaded.dateType, .useBy)
        XCTAssertEqual(loaded.price, 7.25)
    }

    func test_swiftDataPantry_updatesInsteadOfDuplicating_andDeletes() async throws {
        // Arrange
        let container = try makeContainer() // must stay alive while its context is used
        let repository = SwiftDataPantryRepository(context: container.mainContext)
        var item = PantryItem(name: "Milk", location: .fridge, expiryDate: TestCalendar.date(2026, 11, 20))
        try repository.save(item)

        // Act
        item.quantity = 3
        item.reminder = .never
        item.photoFileName = "new.jpg"
        try repository.save(item)

        // Assert
        let updated = try repository.fetchAll()
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(updated.first?.quantity, 3)
        XCTAssertEqual(updated.first?.reminder, .never)
        XCTAssertEqual(updated.first?.photoFileName, "new.jpg")

        // Act
        try repository.delete(id: item.id)

        // Assert
        XCTAssertTrue(try repository.fetchAll().isEmpty)
    }

    func test_moneyFormatter_usesTheLocalesCurrency_andSkipsPointlessDecimals() async {
        XCTAssertEqual(MoneyFormatter.string(3, locale: Locale(identifier: "en_US")), "$3")
        XCTAssertEqual(MoneyFormatter.string(34, locale: Locale(identifier: "en_GB")), "£34")
        XCTAssertEqual(MoneyFormatter.string(2.5, locale: Locale(identifier: "en_US")), "$2.50")
    }

    func test_oldSavedSettings_getTheNewMoneyDefaults() async throws {
        // Arrange: settings saved before the money options existed
        let old = Data(#"{"reminderHour": 8}"#.utf8)

        // Act
        let settings = try JSONDecoder().decode(AppSettings.self, from: old)

        // Assert
        XCTAssertEqual(settings.reminderHour, 8)
        XCTAssertTrue(settings.showMoneySaved)
        XCTAssertEqual(settings.averageItemValue, 3.0)
    }

    func test_settingsPresenter_offersMoneyChoices_andSavesThem() async throws {
        // Arrange
        final class ViewSpy: SettingsViewProtocol {
            var model: SettingsViewModel?
            func showSettings(_ settings: SettingsViewModel) { model = settings }
        }
        final class InteractorSpy: SettingsInteractorInput {
            var saved: [AppSettings] = []
            func loadSettings() {}
            func save(_ settings: AppSettings) { saved.append(settings) }
            func setNotificationsEnabled(_ isOn: Bool) {}
        }
        final class RouterSpy: SettingsRouterProtocol { func openSystemSettings() {} }
        let view = ViewSpy(), interactor = InteractorSpy()
        let formatter = ExpiryDateFormatter(settingsStore: InMemorySettingsStore())
        let sut = SettingsPresenter(view: view, interactor: interactor, router: RouterSpy(), dateFormatter: formatter,
                                    dateProvider: FixedDateProvider(now: TestCalendar.date(2026, 11, 15)),
                                    calendar: TestCalendar.utc, locale: Locale(identifier: "en_US"))
        sut.didLoad(settings: AppSettings(), permission: .authorized)

        // Act
        sut.didChangeShowMoneySaved(isOn: false)
        sut.didSelectItemValue(at: 3)
        sut.didSelectItemValue(at: 99)

        // Assert
        let model = try XCTUnwrap(view.model)
        XCTAssertEqual(model.itemValueTitles, ["$1", "$2", "$3", "$5", "$10"])
        XCTAssertEqual(model.selectedItemValueIndex, 2)
        XCTAssertTrue(model.showMoneySaved)
        XCTAssertEqual(interactor.saved.first?.showMoneySaved, false)
        XCTAssertEqual(interactor.saved.last?.averageItemValue, 5)
        XCTAssertEqual(interactor.saved.count, 2, "an invalid choice is ignored")
    }
}
