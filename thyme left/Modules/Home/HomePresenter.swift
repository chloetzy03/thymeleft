import Foundation

/// The manager of the Home screen: the greeting and all the friendly sentences.
@MainActor
final class HomePresenter: HomePresenterProtocol, HomeInteractorOutput {

    private weak var view: HomeViewProtocol?
    private let interactor: HomeInteractorInput
    private let router: HomeRouterProtocol
    private let iconProvider: FoodIconProviding
    private let textFormatter: ExpiryTextFormatter
    private let dateProvider: DateProviding
    private let calendar: Calendar
    private let locale: Locale

    init(view: HomeViewProtocol,
         interactor: HomeInteractorInput,
         router: HomeRouterProtocol,
         iconProvider: FoodIconProviding,
         dateProvider: DateProviding,
         textFormatter: ExpiryTextFormatter = ExpiryTextFormatter(),
         calendar: Calendar = .current,
         locale: Locale = .current) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.iconProvider = iconProvider
        self.dateProvider = dateProvider
        self.textFormatter = textFormatter
        self.calendar = calendar
        self.locale = locale
    }

    // MARK: From the View

    func viewWillAppear() { interactor.loadHome() }
    func didTapCook() { router.showRecipes() }
    func didTapTile(id: UUID) { router.showPantry() }
    func didTapAddFirst() { router.showPantry() }

    // MARK: From the Interactor

    func didLoad(_ snapshot: HomeSnapshot) {
        view?.showHome(HomeViewModel(
            greeting: greeting(),
            tagline: "Make good food go further.",
            summary: summary(for: snapshot),
            tiles: snapshot.useSoon.map(tile(for:)),
            cookTitle: "✨ What can I cook?",
            cookSubtitle: "Recipes using your existing ingredients",
            addFirstTitle: snapshot.pantryCount == 0 ? "Add your first item" : nil,
            savedTitle: "Saved from the bin",
            savedText: savedText(for: snapshot)))
    }

    func didFail() {
        // Home is only a summary; if we can't read the data, show a calm, empty version.
        didLoad(HomeSnapshot(useSoon: [], attentionCount: 0, pantryCount: 0, usedThisMonth: 0, savedValue: nil))
    }

    // MARK: Helpers

    /// Morning until 11:59, afternoon until 17:59, evening after that (and through the night).
    func greeting() -> String {
        let hour = calendar.component(.hour, from: dateProvider.now)
        switch hour {
        case 5..<12: return "Good morning, chef!"
        case 12..<18: return "Good afternoon, chef!"
        default: return "Good evening, chef!"
        }
    }

    private func summary(for snapshot: HomeSnapshot) -> String {
        if snapshot.pantryCount == 0 { return "Your pantry is empty. Add something and we'll watch the dates." }
        switch snapshot.attentionCount {
        case 0: return "Nothing is about to expire. Nice work!"
        case 1: return "You've got 1 ingredient to use soon."
        default: return "You've got \(snapshot.attentionCount) ingredients to use soon."
        }
    }

    private func tile(for entry: ExpiringItem) -> HomeTileViewModel {
        let badge = textFormatter.badgeText(daysRemaining: entry.daysRemaining)
        return HomeTileViewModel(
            id: entry.item.id,
            emoji: iconProvider.emoji(for: entry.item.name),
            photoFileName: entry.item.photoFileName,
            name: entry.item.name,
            badgeText: badge,
            status: entry.status,
            accessibilityText: "\(entry.item.name), \(textFormatter.spokenText(daysRemaining: entry.daysRemaining))")
    }

    private func savedText(for snapshot: HomeSnapshot) -> String {
        guard snapshot.usedThisMonth > 0 else {
            return "Swipe a pantry item and tap \"Used it\" when you finish it. It counts here."
        }
        let items = snapshot.usedThisMonth == 1 ? "1 item" : "\(snapshot.usedThisMonth) items"
        var text = "\(items) used up this month"
        if let value = snapshot.savedValue { text += " · about \(MoneyFormatter.string(value, locale: locale))" }
        return text
    }
}
