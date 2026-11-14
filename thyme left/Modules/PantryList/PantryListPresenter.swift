import Foundation

/// The manager of the Pantry screen: decides WHAT to show and in which words.
/// (Translation: gets raw results from the chef, turns them into tidy text/sections, and
/// hands them to the waiter. It never touches buttons or colours itself.)
@MainActor
final class PantryListPresenter: PantryListPresenterProtocol, PantryListInteractorOutput {

    private weak var view: PantryListViewProtocol?
    private let interactor: PantryListInteractorInput
    private let router: PantryListRouterProtocol
    private let iconProvider: FoodIconProviding
    private let dateFormatter: ExpiryDateFormatter
    private let formatter: ExpiryTextFormatter

    /// The filter chips: "All" first, then each storage location.
    private let locations: [StorageLocation?] = [nil] + StorageLocation.allCases.map { Optional($0) }
    private var selectedIndex = 0
    /// The latest items we showed, so a tapped row can be turned back into its item.
    private var latestItems: [ExpiringItem] = []

    init(view: PantryListViewProtocol,
         interactor: PantryListInteractorInput,
         router: PantryListRouterProtocol,
         iconProvider: FoodIconProviding,
         dateFormatter: ExpiryDateFormatter,
         formatter: ExpiryTextFormatter = ExpiryTextFormatter()) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.iconProvider = iconProvider
        self.dateFormatter = dateFormatter
        self.formatter = formatter
    }

    private var selectedLocation: StorageLocation? { locations[selectedIndex] }

    // MARK: Things the View tells us

    func viewDidLoad() {
        view?.showFilters(titles: filterTitles, selectedIndex: selectedIndex)
    }

    func refreshRequested() {
        interactor.loadItems(in: selectedLocation)
    }

    func didSelectFilter(at index: Int) {
        guard locations.indices.contains(index), index != selectedIndex else { return }
        selectedIndex = index
        view?.showFilters(titles: filterTitles, selectedIndex: selectedIndex)
        interactor.loadItems(in: selectedLocation)
    }

    func didTapAdd() {
        // After saving, the form calls this closure and we reload the list.
        router.showAddItem(onSaved: { [weak self] in self?.refreshRequested() })
    }

    func didSelectRow(id: UUID) {
        guard let entry = latestItems.first(where: { $0.item.id == id }) else { return }
        router.showEditItem(entry.item, onSaved: { [weak self] in self?.refreshRequested() })
    }

    func didDeleteRow(id: UUID) {
        interactor.deleteItem(id: id)
    }

    // MARK: Things the Interactor tells us

    func didLoad(_ items: [ExpiringItem]) {
        latestItems = items
        guard !items.isEmpty else {
            view?.showEmptyState(emptyState(for: selectedLocation))
            return
        }

        // Expired, urgent and soon items share one "use soon" section; the rest are "fresh".
        let needAttention = items.filter { $0.status.needsAttention }.map(row(for:))
        let fresh = items.filter { !$0.status.needsAttention }.map(row(for:))

        var sections: [PantrySectionViewModel] = []
        if !needAttention.isEmpty { sections.append(PantrySectionViewModel(title: "USE SOON", rows: needAttention)) }
        if !fresh.isEmpty { sections.append(PantrySectionViewModel(title: "FRESH", rows: fresh)) }
        view?.showSections(sections)
    }

    func didDeleteItem() {
        interactor.loadItems(in: selectedLocation)
    }

    func didFail(_ error: Error) {
        view?.showError(message: "We couldn't load your pantry. Please try again.")
    }

    // MARK: Helpers

    private var filterTitles: [String] {
        locations.map { $0?.displayName ?? "All" }
    }

    private func row(for entry: ExpiringItem) -> PantryRowViewModel {
        let item = entry.item
        let badge = formatter.badgeText(daysRemaining: entry.daysRemaining)
        return PantryRowViewModel(
            id: item.id,
            emoji: iconProvider.emoji(for: item.name),
            title: item.name,
            subtitle: "\(item.location.displayName) · x\(item.quantity) · \(dateFormatter.string(from: item.expiryDate))",
            badgeText: badge,
            status: entry.status,
            accessibilityText: "\(item.name), \(item.location.displayName), quantity \(item.quantity), "
                + formatter.spokenText(daysRemaining: entry.daysRemaining)
        )
    }

    private func emptyState(for location: StorageLocation?) -> PantryEmptyStateViewModel {
        guard let location else {
            return PantryEmptyStateViewModel(
                emoji: "🌿",
                title: "Nothing here yet",
                message: "Add your first item and we'll watch the dates for you.",
                buttonTitle: "Add first item")
        }
        return PantryEmptyStateViewModel(
            emoji: "🌿",
            title: "Nothing in the \(location.displayName.lowercased())",
            message: "Items you store in the \(location.displayName.lowercased()) will show up here.",
            buttonTitle: nil)
    }
}
