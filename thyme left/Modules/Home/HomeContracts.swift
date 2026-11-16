import Foundation

// The "who may ask whom" rulebook for the Home screen.

/// The facts the Home screen needs, worked out by the Interactor.
struct HomeSnapshot: Equatable {
    /// The items closest to going off (at most 3), soonest first.
    let useSoon: [ExpiringItem]
    /// How many items need attention in total (red, amber or expired).
    let attentionCount: Int
    let pantryCount: Int
    let usedThisMonth: Int
    /// Estimated money saved this month, or nil when the user turned the estimate off.
    let savedValue: Double?
}

struct HomeTileViewModel: Equatable {
    let id: UUID
    let emoji: String
    let photoFileName: String?
    let name: String
    let badgeText: String
    let status: ExpiryStatus
    let accessibilityText: String
}

struct HomeViewModel: Equatable {
    let greeting: String          // "Good morning, chef!"
    let tagline: String           // "Make good food go further."
    let summary: String           // "You've got 3 ingredients to use soon."
    let tiles: [HomeTileViewModel]
    let cookTitle: String
    let cookSubtitle: String
    let addFirstTitle: String?    // only when the pantry is empty
    let savedTitle: String
    let savedText: String
}

// MARK: - View (the waiter)

@MainActor
protocol HomeViewProtocol: AnyObject {
    func showHome(_ home: HomeViewModel)
}

// MARK: - Presenter (the manager)

@MainActor
protocol HomePresenterProtocol: AnyObject {
    func viewWillAppear()
    func didTapCook()
    func didTapTile(id: UUID)
    func didTapAddFirst()
}

// MARK: - Interactor (the chef)

@MainActor
protocol HomeInteractorInput: AnyObject {
    func loadHome()
}

@MainActor
protocol HomeInteractorOutput: AnyObject {
    func didLoad(_ snapshot: HomeSnapshot)
    func didFail()
}

// MARK: - Router (the host)

@MainActor
protocol HomeRouterProtocol: AnyObject {
    func showRecipes()
    func showPantry()
}
