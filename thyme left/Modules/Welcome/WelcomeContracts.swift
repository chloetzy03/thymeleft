import Foundation

// The "who may ask whom" rulebook for the Welcome tour.

/// One slide of the tour.
struct WelcomeSlideViewModel: Equatable {
    let symbol: String      // an SF Symbol name (Apple's built-in icons)
    let title: String
    let message: String
}

/// What the bottom of the screen shows for the current slide.
struct WelcomePageViewModel: Equatable {
    let index: Int
    let count: Int
    let primaryTitle: String       // "Next" or, on the last slide, "Turn on reminders"
    let secondaryTitle: String     // "Skip" or, on the last slide, "Maybe later"
    let pageAccessibilityText: String   // "Page 1 of 3"
}

// MARK: - View (the waiter)

@MainActor
protocol WelcomeViewProtocol: AnyObject {
    func showSlides(_ slides: [WelcomeSlideViewModel])
    func showPage(_ page: WelcomePageViewModel, animated: Bool)
}

// MARK: - Presenter (the manager)

@MainActor
protocol WelcomePresenterProtocol: AnyObject {
    func viewDidLoad()
    /// The user swiped or tapped a dot to reach this slide.
    func didChangePage(to index: Int)
    func didTapPrimary()
    func didTapSecondary()
}

// MARK: - Interactor (the chef)

@MainActor
protocol WelcomeInteractorInput: AnyObject {
    /// Remembers that the tour was seen. When `askForReminders` is true, iOS's reminder question is asked too.
    func finish(askForReminders: Bool)
}

@MainActor
protocol WelcomeInteractorOutput: AnyObject {
    func didFinish()
}

// MARK: - Router (the host)

@MainActor
protocol WelcomeRouterProtocol: AnyObject {
    func close()
}
