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
    /// The next 7 days (today first) and how many items expire on each.
    var week: [HomeWeekDay] = []
    /// How many items are already past their date.
    var pastCount = 0
    /// A saved recipe that uses your most urgent food, if we have one.
    var recipeIdea: HomeRecipeIdea? = nil
}

struct HomeWeekDay: Equatable {
    let date: Date
    let count: Int
    /// How urgent a day is: today is red, a few days away amber, and so on.
    let status: ExpiryStatus
}

struct HomeRecipeIdea: Equatable {
    let name: String
    let usedItemNames: [String]
    let missingCount: Int
}

struct HomeWeekDayViewModel: Equatable {
    let label: String       // "Today", "Tue"
    let countText: String   // "3" or "·" for none
    let count: Int
    let status: ExpiryStatus
}

struct HomeWeekViewModel: Equatable {
    let title: String
    let subtitle: String
    let days: [HomeWeekDayViewModel]
    let footnote: String?   // "2 items are already past their date"
    let accessibilityText: String
}

struct HomeIdeaViewModel: Equatable {
    let caption: String     // "Tonight's idea"
    let title: String       // recipe name
    let subtitle: String    // "Uses Milk and Spinach"
    let accessibilityText: String
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
    let week: HomeWeekViewModel?  // nil while the pantry is empty
    let idea: HomeIdeaViewModel?  // nil when we have no saved recipe that fits
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
    func didTapScan()
    func didTapAdd()
    func didTapWeek()
    func didTapIdea()
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
    func showScan()
    func showAddItem()
}
