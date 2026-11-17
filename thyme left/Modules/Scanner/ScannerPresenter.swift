import Foundation

/// The manager of the Scanner screen: words for the "found" card, and what each tap does.
@MainActor
final class ScannerPresenter: ScannerPresenterProtocol, ScannerInteractorOutput {

    private weak var view: ScannerViewProtocol?
    private let interactor: ScannerInteractorInput
    private let router: ScannerRouterProtocol
    private let dateFormatter: ExpiryDateFormatter
    private let dateProvider: DateProviding
    private let policy: () -> ExpiryPolicy
    private let textFormatter: ExpiryTextFormatter
    private let calendar: Calendar

    /// The date currently on the card, and the other reading (if day/month could swap).
    private var current: ScannedExpiryDate?
    private var showingAlternative = false

    init(view: ScannerViewProtocol,
         interactor: ScannerInteractorInput,
         router: ScannerRouterProtocol,
         dateFormatter: ExpiryDateFormatter,
         dateProvider: DateProviding,
         policy: @escaping () -> ExpiryPolicy = { ExpiryPolicy() },
         textFormatter: ExpiryTextFormatter = ExpiryTextFormatter(),
         calendar: Calendar = .current) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.dateFormatter = dateFormatter
        self.dateProvider = dateProvider
        self.policy = policy
        self.textFormatter = textFormatter
        self.calendar = calendar
    }

    // MARK: From the View

    func viewDidLoad() { view?.showSearching() }

    func didSeeLines(_ lines: [String]) {
        guard current == nil else { return } // already showing a result
        interactor.considerLiveLines(lines)
    }

    func didPickImage(_ data: Data) {
        interactor.readImage(data)
    }

    func didTapSwap() {
        guard current?.alternative != nil else { return }
        showingAlternative.toggle()
        showCard()
    }

    func didTapRetry() {
        current = nil
        showingAlternative = false
        interactor.resetLiveReading()
        view?.showSearching()
    }

    func didConfirm(photoData: Data?) {
        guard let date = shownDate else { return }
        router.finish(with: ScanResult(date: date, photoData: photoData))
    }

    func didTapCancel() { router.close() }

    // MARK: From the Interactor

    func didFind(_ found: ScannedExpiryDate) {
        current = found
        showingAlternative = false
        showCard()
    }

    func didFindNothing() {
        view?.showNothingFound(message: String(localized: "We couldn't find a date in that picture. Try a clearer photo of the printed date."))
    }

    // MARK: Helpers

    private var shownDate: Date? {
        guard let current else { return nil }
        return showingAlternative ? (current.alternative ?? current.date) : current.date
    }

    private func showCard() {
        guard let current, let date = shownDate else { return }
        let days = policy().daysRemaining(until: date, from: dateProvider.now, calendar: calendar)

        var swapText: String?
        if let alternative = current.alternative {
            let other = showingAlternative ? current.date : alternative
            swapText = String(localized: "Not right? Read it as \(dateFormatter.string(from: other)) instead")
        }
        view?.showFound(ScanFoundViewModel(
            dateText: dateFormatter.string(from: date),
            countdownText: countdown(days),
            sourceText: current.sourceText,
            swapText: swapText,
            guessNote: current.dayWasGuessed && !showingAlternative
                ? String(localized: "We couldn't see a day on the pack, so we used the last day of the month. You can change it on the next screen.")
                : nil))
    }

    private func countdown(_ days: Int) -> String {
        switch days {
        case ..<0: return String(localized: "That date has already passed")
        case 0: return String(localized: "Expires today")
        case 1: return String(localized: "Expires tomorrow")
        default: return String(localized: "Expires in \(textFormatter.badgeText(daysRemaining: days))")
        }
    }
}
