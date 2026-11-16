import XCTest
@testable import thyme_left

@MainActor
final class PantryListPresenterTests: XCTestCase {

    // MARK: Pretend neighbours (so we test ONLY the Presenter)

    private final class ViewSpy: PantryListViewProtocol {
        var filterTitles: [String] = []
        var selectedFilter = -1
        var sections: [PantrySectionViewModel] = []
        var emptyState: PantryEmptyStateViewModel?
        var errorMessage: String?

        func showFilters(titles: [String], selectedIndex: Int) { filterTitles = titles; selectedFilter = selectedIndex }
        func showSections(_ sections: [PantrySectionViewModel]) { self.sections = sections; emptyState = nil }
        func showEmptyState(_ state: PantryEmptyStateViewModel) { emptyState = state; sections = [] }
        func showError(message: String) { errorMessage = message }
    }

    private final class InteractorSpy: PantryListInteractorInput {
        var requestedLocations: [StorageLocation?] = []
        var finished: [(id: UUID, outcome: ItemOutcome)] = []

        func loadItems(in location: StorageLocation?) { requestedLocations.append(location) }
        func finishItem(id: UUID, as outcome: ItemOutcome) { finished.append((id, outcome)) }
    }

    private final class RouterSpy: PantryListRouterProtocol {
        var addItemCount = 0
        var editedItems: [PantryItem] = []
        var lastOnSaved: (() -> Void)?

        func showAddItem(onSaved: @escaping () -> Void) { addItemCount += 1; lastOnSaved = onSaved }
        func showEditItem(_ item: PantryItem, onSaved: @escaping () -> Void) { editedItems.append(item); lastOnSaved = onSaved }
    }

    // MARK: Helpers

    private func makeSUT() -> (sut: PantryListPresenter, view: ViewSpy, interactor: InteractorSpy, router: RouterSpy) {
        let view = ViewSpy()
        let interactor = InteractorSpy()
        let router = RouterSpy()
        var settings = AppSettings()
        settings.dateFormat = .dayMonthYear // a fixed format keeps the expected text predictable
        let dateFormatter = ExpiryDateFormatter(settingsStore: InMemorySettingsStore(settings: settings))
        let sut = PantryListPresenter(view: view, interactor: interactor, router: router,
                                      iconProvider: EmojiFoodIconProvider(), dateFormatter: dateFormatter)
        return (sut, view, interactor, router)
    }

    private func makeEntry(_ name: String, days: Int, status: ExpiryStatus,
                           place: StorageLocation = .fridge, quantity: Int = 1) -> ExpiringItem {
        let expiry = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
        return ExpiringItem(item: PantryItem(name: name, quantity: quantity, location: place, expiryDate: expiry),
                     daysRemaining: days, status: status)
    }

    // MARK: Filters

    func test_viewDidLoad_showsAllFilterChipsWithAllSelected() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.viewDidLoad()

        // Assert
        XCTAssertEqual(view.filterTitles, ["All", "Fridge", "Pantry", "Freezer", "Counter"])
        XCTAssertEqual(view.selectedFilter, 0)
    }

    func test_refreshRequested_asksForEveryLocationByDefault() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()

        // Act
        sut.refreshRequested()

        // Assert
        XCTAssertEqual(interactor.requestedLocations, [nil])
    }

    func test_didSelectFilter_reloadsThatLocation() async {
        // Arrange
        let (sut, view, interactor, _) = makeSUT()
        sut.viewDidLoad()

        // Act
        sut.didSelectFilter(at: 1)

        // Assert
        XCTAssertEqual(view.selectedFilter, 1)
        XCTAssertEqual(interactor.requestedLocations, [.fridge])
    }

    func test_didSelectFilter_withSameOrInvalidIndex_doesNothing() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()

        // Act
        sut.didSelectFilter(at: 0)
        sut.didSelectFilter(at: 99)

        // Assert
        XCTAssertTrue(interactor.requestedLocations.isEmpty)
    }

    // MARK: Sections and rows

    func test_didLoad_splitsIntoUseSoonAndFreshSections() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()
        let entries = [
            makeEntry("Yoghurt", days: -1, status: .expired),
            makeEntry("Milk", days: 3, status: .soon),
            makeEntry("Pasta", days: 120, status: .fresh)
        ]

        // Act
        sut.didLoad(entries)

        // Assert
        XCTAssertEqual(view.sections.map(\.title), ["USE SOON", "FRESH"])
        XCTAssertEqual(view.sections[0].rows.map(\.title), ["Yoghurt", "Milk"])
        XCTAssertEqual(view.sections[1].rows.map(\.title), ["Pasta"])
    }

    func test_didLoad_withOnlyFreshItems_omitsTheUseSoonSection() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.didLoad([makeEntry("Pasta", days: 120, status: .fresh)])

        // Assert
        XCTAssertEqual(view.sections.map(\.title), ["FRESH"])
    }

    func test_didLoad_buildsRowsWithFriendlyText() async throws {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.didLoad([makeEntry("Milk", days: 1, status: .urgent, place: .fridge, quantity: 2)])

        // Assert
        let row = try XCTUnwrap(view.sections.first?.rows.first)
        XCTAssertEqual(row.emoji, "🥛")
        XCTAssertEqual(row.subtitle, "Fridge · x2 · 18/11/2026")
        XCTAssertEqual(row.badgeText, "1 day")
        XCTAssertEqual(row.accessibilityText, "Milk, Fridge, quantity 2, expires tomorrow")
    }

    func test_didLoad_forAPastUseByItem_saysItClearlyAndWarns() async throws {
        // Arrange
        let (sut, view, _, _) = makeSUT()
        let expiry = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
        let chicken = ExpiringItem(
            item: PantryItem(name: "Chicken", location: .fridge, expiryDate: expiry, dateType: .useBy),
            daysRemaining: -2, status: .expired)

        // Act
        sut.didLoad([chicken])

        // Assert
        let row = try XCTUnwrap(view.sections.first?.rows.first)
        XCTAssertEqual(row.subtitle, "Fridge · x1 · Use by 18/11/2026")
        XCTAssertEqual(row.badgeText, "Past use-by")
        XCTAssertEqual(row.accessibilityText,
                       "Chicken, Fridge, quantity 1, past its use by date, 2 days ago. Do not eat")
    }

    func test_didLoad_forAPastBestBeforeItem_suggestsCheckingFirst() async throws {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.didLoad([makeEntry("Pasta", days: -3, status: .expired)])

        // Assert
        let row = try XCTUnwrap(view.sections.first?.rows.first)
        XCTAssertEqual(row.badgeText, "Past date")
        XCTAssertTrue(row.accessibilityText.hasSuffix("Check before eating"))
    }

    func test_didLoad_carriesTheItemsPhotoNameIntoTheRow() async throws {
        // Arrange
        let (sut, view, _, _) = makeSUT()
        let withPhoto = ExpiringItem(
            item: PantryItem(name: "Milk", location: .fridge, expiryDate: Date(), photoFileName: "abc.jpg"),
            daysRemaining: 3, status: .soon)

        // Act
        sut.didLoad([withPhoto, makeEntry("Pasta", days: 120, status: .fresh)])

        // Assert
        XCTAssertEqual(view.sections[0].rows.first?.photoFileName, "abc.jpg")
        XCTAssertNil(view.sections[1].rows.first?.photoFileName)
    }

    // MARK: Empty states

    func test_didLoad_withNoItems_offersToAddTheFirstItem() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.didLoad([])

        // Assert
        XCTAssertEqual(view.emptyState?.buttonTitle, "Add first item")
    }

    func test_didLoad_withNoItemsInAFilter_namesTheLocationAndHasNoButton() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()
        sut.didSelectFilter(at: 3) // Freezer

        // Act
        sut.didLoad([])

        // Assert
        XCTAssertEqual(view.emptyState?.title, "Nothing in the freezer")
        XCTAssertNil(view.emptyState?.buttonTitle)
    }

    // MARK: Actions

    func test_didTapAdd_asksTheRouterToShowAddItem() async {
        // Arrange
        let (sut, _, _, router) = makeSUT()

        // Act
        sut.didTapAdd()

        // Assert
        XCTAssertEqual(router.addItemCount, 1)
    }

    func test_didSelectRow_opensTheEditorForThatItem() async {
        // Arrange
        let (sut, _, _, router) = makeSUT()
        let milk = makeEntry("Milk", days: 3, status: .soon)
        sut.didLoad([milk, makeEntry("Pasta", days: 120, status: .fresh)])

        // Act
        sut.didSelectRow(id: milk.item.id)

        // Assert
        XCTAssertEqual(router.editedItems, [milk.item])
    }

    func test_didSelectRow_withUnknownId_doesNothing() async {
        // Arrange
        let (sut, _, _, router) = makeSUT()
        sut.didLoad([makeEntry("Milk", days: 3, status: .soon)])

        // Act
        sut.didSelectRow(id: UUID())

        // Assert
        XCTAssertTrue(router.editedItems.isEmpty)
    }

    func test_afterSavingInTheForm_theListReloads() async {
        // Arrange
        let (sut, _, interactor, router) = makeSUT()
        sut.didTapAdd()

        // Act: the form reports "saved"
        router.lastOnSaved?()

        // Assert
        XCTAssertEqual(interactor.requestedLocations, [nil])
    }

    func test_didFinishRow_passesTheChosenOutcome_thenReloadsTheCurrentFilter() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()
        let id = UUID()
        sut.didSelectFilter(at: 2) // Pantry

        // Act
        sut.didFinishRow(id: id, as: .used)
        sut.didDeleteItem()

        // Assert
        XCTAssertEqual(interactor.finished.map(\.id), [id])
        XCTAssertEqual(interactor.finished.map(\.outcome), [.used])
        XCTAssertEqual(interactor.requestedLocations.last, .pantry)
    }

    func test_didFail_showsAFriendlyMessage() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.didFail(NSError(domain: "test", code: 1))

        // Assert
        XCTAssertNotNil(view.errorMessage)
    }
}
