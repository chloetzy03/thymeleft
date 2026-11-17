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
    func didTapScan() { router.showScan() }
    func didTapAdd() { router.showAddItem() }
    func didTapWeek() { router.showPantry() }
    func didTapIdea() { router.showRecipes() }

    // MARK: From the Interactor

    func didLoad(_ snapshot: HomeSnapshot) {
        view?.showHome(HomeViewModel(
            greeting: greeting(),
            tagline: String(localized: "Make good food go further."),
            summary: summary(for: snapshot),
            tiles: snapshot.useSoon.map(tile(for:)),
            cookTitle: String(localized: "✨ What can I cook?"),
            cookSubtitle: String(localized: "Recipes using your existing ingredients"),
            addFirstTitle: snapshot.pantryCount == 0 ? String(localized: "Add your first item") : nil,
            week: snapshot.pantryCount == 0 ? nil : weekModel(for: snapshot),
            idea: snapshot.recipeIdea.map(ideaModel(for:)),
            savedTitle: String(localized: "Saved from the bin"),
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
        case 5..<12: return String(localized: "Good morning, chef!")
        case 12..<18: return String(localized: "Good afternoon, chef!")
        default: return String(localized: "Good evening, chef!")
        }
    }

    private func summary(for snapshot: HomeSnapshot) -> String {
        if snapshot.pantryCount == 0 { return String(localized: "Your pantry is empty. Add something and we'll watch the dates.") }
        switch snapshot.attentionCount {
        case 0: return String(localized: "Nothing is about to expire. Nice work!")
        case 1: return String(localized: "You've got 1 ingredient to use soon.")
        default: return String(localized: "You've got \(snapshot.attentionCount) ingredients to use soon.")
        }
    }

    private func tile(for entry: ExpiringItem) -> HomeTileViewModel {
        let badge = textFormatter.badgeText(daysRemaining: entry.daysRemaining, dateType: entry.item.dateType)
        return HomeTileViewModel(
            id: entry.item.id,
            emoji: iconProvider.emoji(for: entry.item.name),
            photoFileName: entry.item.photoFileName,
            name: entry.item.name,
            badgeText: badge,
            status: entry.status,
            accessibilityText: "\(entry.item.name), \(textFormatter.spokenText(daysRemaining: entry.daysRemaining, dateType: entry.item.dateType))")
    }

    /// "Today", then short weekday names; empty days show a quiet dot.
    private func weekModel(for snapshot: HomeSnapshot) -> HomeWeekViewModel {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("EEE")

        let days = snapshot.week.enumerated().map { index, day -> HomeWeekDayViewModel in
            HomeWeekDayViewModel(label: index == 0 ? String(localized: "Today") : formatter.string(from: day.date),
                                 countText: day.count == 0 ? "\u{00B7}" : "\(day.count)",
                                 count: day.count,
                                 status: day.count == 0 ? .fresh : day.status)
        }
        let total = snapshot.week.reduce(0) { $0 + $1.count }
        let subtitle: String
        switch total {
        case 0: subtitle = String(localized: "Nothing runs out in the next 7 days.")
        case 1: subtitle = String(localized: "1 item runs out in the next 7 days.")
        default: subtitle = String(localized: "\(total) items run out in the next 7 days.")
        }
        var footnote: String?
        if snapshot.pastCount == 1 { footnote = String(localized: "1 item is already past its date.") }
        if snapshot.pastCount > 1 { footnote = String(localized: "\(snapshot.pastCount) items are already past their date.") }

        let spoken = days.map { $0.count == 0 ? String(localized: "\($0.label), none") : "\($0.label), \($0.count)" }.joined(separator: ". ")
        return HomeWeekViewModel(title: String(localized: "This week"), subtitle: subtitle, days: days, footnote: footnote,
                                 accessibilityText: String(localized: "This week. \(subtitle) \(spoken). \(footnote ?? "")"))
    }

    private func ideaModel(for idea: HomeRecipeIdea) -> HomeIdeaViewModel {
        let uses = Array(idea.usedItemNames.prefix(3)).joinedForDisplay()
        var subtitle = String(localized: "Uses \(uses)")
        if idea.missingCount == 0 { subtitle += String(localized: " · you have everything") }
        else { subtitle += String(localized: " · \(idea.missingCount) more to find") }
        return HomeIdeaViewModel(caption: String(localized: "Tonight's idea"), title: idea.name, subtitle: subtitle,
                                 accessibilityText: String(localized: "Tonight's idea: \(idea.name). \(subtitle)"))
    }

    private func savedText(for snapshot: HomeSnapshot) -> String {
        guard snapshot.usedThisMonth > 0 else {
            return String(localized: "Swipe a pantry item and tap \"Used it\" when you finish it. It counts here.")
        }
        let items = snapshot.usedThisMonth == 1 ? String(localized: "1 item") : String(localized: "\(snapshot.usedThisMonth) items")
        var text = String(localized: "\(items) used up this month")
        if let value = snapshot.savedValue { text += String(localized: " · about \(MoneyFormatter.string(value, locale: locale))") }
        return text
    }
}
