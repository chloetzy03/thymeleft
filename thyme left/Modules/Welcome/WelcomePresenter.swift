import Foundation

/// The manager of the Welcome tour: the slides' words, and what each button does.
@MainActor
final class WelcomePresenter: WelcomePresenterProtocol, WelcomeInteractorOutput {

    private weak var view: WelcomeViewProtocol?
    private let interactor: WelcomeInteractorInput
    private let router: WelcomeRouterProtocol

    private var currentPage = 0

    init(view: WelcomeViewProtocol, interactor: WelcomeInteractorInput, router: WelcomeRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    /// The three slides. (Scan it, swipe it, get reminded.)
    static var slides: [WelcomeSlideViewModel] {
        [
            WelcomeSlideViewModel(
                symbol: "viewfinder",
                title: String(localized: "Scan the date"),
                message: String(localized: "Point your camera at the date on the pack. We read it for you, so no typing.")),
            WelcomeSlideViewModel(
                symbol: "hand.point.left.fill",
                title: String(localized: "Swipe when you're done"),
                message: String(localized: "Slide a food to the left and tap “Used it”. Watch your savings grow.")),
            WelcomeSlideViewModel(
                symbol: "bell.badge.fill",
                title: String(localized: "We'll remind you"),
                message: String(localized: "Get a friendly nudge before things expire, so good food never goes to waste."))
        ]
    }

    private var isLastPage: Bool { currentPage == Self.slides.count - 1 }

    // MARK: From the View

    func viewDidLoad() {
        view?.showSlides(Self.slides)
        showCurrentPage(animated: false)
    }

    func didChangePage(to index: Int) {
        guard (0..<Self.slides.count).contains(index), index != currentPage else { return }
        currentPage = index
        showCurrentPage(animated: true)
    }

    func didTapPrimary() {
        if isLastPage {
            interactor.finish(askForReminders: true)
        } else {
            currentPage += 1
            showCurrentPage(animated: true)
        }
    }

    func didTapSecondary() {
        interactor.finish(askForReminders: false) // "Skip" or "Maybe later": both just close the tour
    }

    // MARK: From the Interactor

    func didFinish() {
        router.close()
    }

    // MARK: Helpers

    private func showCurrentPage(animated: Bool) {
        let count = Self.slides.count
        view?.showPage(WelcomePageViewModel(
            index: currentPage,
            count: count,
            primaryTitle: isLastPage ? String(localized: "Turn on reminders") : String(localized: "Next"),
            secondaryTitle: isLastPage ? String(localized: "Maybe later") : String(localized: "Skip"),
            pageAccessibilityText: String(localized: "Page \(currentPage + 1) of \(count)")),
                       animated: animated)
    }
}
