import Testing
import Foundation
@testable import thyme_left

@MainActor
struct PantryListPresenterTests {

    // MARK: Pretend neighbours (so we test ONLY the Presenter)

    final class ViewSpy: PantryListViewProtocol {
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

    final class InteractorSpy: PantryListInteractorInput {
        var requestedLocations: [StorageLocation?] = []
        var deletedIDs: [UUID] = []
        func loadItems(in location: StorageLocation?) { requestedLocations.append(location) }
        func deleteItem(id: UUID) { deletedIDs.append(id) }
    }

    final class RouterSpy: PantryListRouterProtocol {
        var addItemCount = 0
        func showAddItem() { addItemCount += 1 }
    }

    private func makeSUT() -> (PantryListPresenter, ViewSpy, InteractorSpy, RouterSpy) {
        let view = ViewSpy(), interactor = InteractorSpy(), router = RouterSpy()
        let sut = PantryListPresenter(view: view, interactor: interactor, router: router,
                                      iconProvider: EmojiFoodIconProvider())
        return (sut, view, interactor, router)
    }

    private func entry(_ name: String, days: Int, status: ExpiryStatus,
                       place: StorageLocation = .fridge, quantity: Int = 1) -> ExpiringItem {
        ExpiringItem(item: PantryItem(name: name, quantity: quantity, location: place, expiryDate: Date()),
                     daysRemaining: days, status: status)
    }

    // MARK: Tests

    @Test func viewDidLoadShowsAllFilterChipsWithAllSelected() {
        let (sut, view, _, _) = makeSUT()
        sut.viewDidLoad()
        #expect(view.filterTitles == ["All", "Fridge", "Pantry", "Freezer", "Counter"])
        #expect(view.selectedFilter == 0)
    }

    @Test func refreshAsksForEveryLocationByDefault() {
        let (sut, _, interactor, _) = makeSUT()
        sut.refreshRequested()
        #expect(interactor.requestedLocations == [nil])
    }

    @Test func selectingAChipReloadsThatLocation() {
        let (sut, view, interactor, _) = makeSUT()
        sut.viewDidLoad()
        sut.didSelectFilter(at: 1)
        #expect(view.selectedFilter == 1)
        #expect(interactor.requestedLocations == [.fridge])
    }

    @Test func selectingTheSameOrInvalidChipDoesNothing() {
        let (sut, _, interactor, _) = makeSUT()
        sut.didSelectFilter(at: 0)
        sut.didSelectFilter(at: 99)
        #expect(interactor.requestedLocations.isEmpty)
    }

    @Test func splitsIntoUseSoonAndFreshSections() {
        let (sut, view, _, _) = makeSUT()
        sut.didLoad([
            entry("Yoghurt", days: -1, status: .expired),
            entry("Milk", days: 3, status: .soon),
            entry("Pasta", days: 120, status: .fresh)
        ])
        #expect(view.sections.map(\.title) == ["USE SOON", "FRESH"])
        #expect(view.sections[0].rows.map(\.title) == ["Yoghurt", "Milk"])
        #expect(view.sections[1].rows.map(\.title) == ["Pasta"])
    }

    @Test func omitsEmptySections() {
        let (sut, view, _, _) = makeSUT()
        sut.didLoad([entry("Pasta", days: 120, status: .fresh)])
        #expect(view.sections.map(\.title) == ["FRESH"])
    }

    @Test func rowsContainFriendlyText() throws {
        let (sut, view, _, _) = makeSUT()
        sut.didLoad([entry("Milk", days: 1, status: .urgent, place: .fridge, quantity: 2)])
        let row = try #require(view.sections.first?.rows.first)
        #expect(row.emoji == "🥛")
        #expect(row.subtitle == "Fridge · x2")
        #expect(row.badgeText == "1 day")
        #expect(row.accessibilityText == "Milk, Fridge, quantity 2, expires tomorrow")
    }

    @Test func emptyPantryOffersToAddFirstItem() {
        let (sut, view, _, _) = makeSUT()
        sut.didLoad([])
        #expect(view.emptyState?.buttonTitle == "Add first item")
    }

    @Test func emptyFilterNamesTheLocationAndHasNoButton() {
        let (sut, view, _, _) = makeSUT()
        sut.didSelectFilter(at: 3) // Freezer
        sut.didLoad([])
        #expect(view.emptyState?.title == "Nothing in the freezer")
        #expect(view.emptyState?.buttonTitle == nil)
    }

    @Test func tappingAddAsksTheRouter() {
        let (sut, _, _, router) = makeSUT()
        sut.didTapAdd()
        #expect(router.addItemCount == 1)
    }

    @Test func deletingAsksInteractorThenReloadsCurrentFilter() {
        let (sut, _, interactor, _) = makeSUT()
        let id = UUID()
        sut.didSelectFilter(at: 2) // Pantry
        sut.didDeleteRow(id: id)
        sut.didDeleteItem()
        #expect(interactor.deletedIDs == [id])
        #expect(interactor.requestedLocations.last == .pantry)
    }

    @Test func failureShowsAFriendlyMessage() {
        let (sut, view, _, _) = makeSUT()
        sut.didFail(NSError(domain: "test", code: 1))
        #expect(view.errorMessage != nil)
    }
}
