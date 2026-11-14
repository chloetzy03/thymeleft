import Foundation

// This file is the "who may ask whom for what" rulebook of the Pantry screen.
// (Translation: every VIPER part only knows the OTHER parts by these short job descriptions,
// never by their real names. That keeps each part swappable and easy to test.)
//
//   View ──► Presenter ──► Interactor ──► (Repository / storage)
//    ▲           │  ▲           │
//    └───────────┘  └───────────┘      answers travel back the same way
//                Presenter ──► Router  (go to another screen)

// MARK: - What the screen shows (plain text and flags, no logic)

struct PantryRowViewModel: Equatable {
    let id: UUID
    let emoji: String
    let title: String
    let subtitle: String
    let badgeText: String
    let status: ExpiryStatus
    let accessibilityText: String
}

struct PantrySectionViewModel: Equatable {
    let title: String
    let rows: [PantryRowViewModel]
}

struct PantryEmptyStateViewModel: Equatable {
    let emoji: String
    let title: String
    let message: String
    let buttonTitle: String?
}

// MARK: - View (the waiter: shows things, passes taps along)

@MainActor
protocol PantryListViewProtocol: AnyObject {
    func showFilters(titles: [String], selectedIndex: Int)
    func showSections(_ sections: [PantrySectionViewModel])
    func showEmptyState(_ state: PantryEmptyStateViewModel)
    func showError(message: String)
}

// MARK: - Presenter (the manager: reacts to taps, prepares text for the View)

@MainActor
protocol PantryListPresenterProtocol: AnyObject {
    func viewDidLoad()
    /// "Please show me fresh information" (screen appeared, or app came back to the front).
    func refreshRequested()
    func didSelectFilter(at index: Int)
    func didTapAdd()
    func didSelectRow(id: UUID)
    func didDeleteRow(id: UUID)
}

// MARK: - Interactor (the chef: the real logic)

@MainActor
protocol PantryListInteractorInput: AnyObject {
    /// `nil` means "every location".
    func loadItems(in location: StorageLocation?)
    func deleteItem(id: UUID)
}

@MainActor
protocol PantryListInteractorOutput: AnyObject {
    func didLoad(_ items: [ExpiringItem])
    func didDeleteItem()
    func didFail(_ error: Error)
}

// MARK: - Router (the host: moves between screens)

@MainActor
protocol PantryListRouterProtocol: AnyObject {
    /// `onSaved` runs after the user saves, so this screen can refresh its list.
    func showAddItem(onSaved: @escaping () -> Void)
    func showEditItem(_ item: PantryItem, onSaved: @escaping () -> Void)
}
