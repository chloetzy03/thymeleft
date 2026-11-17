import UIKit

/// The bottom bar with four tabs: Home, Scan, Pantry, Recipes.
/// (Translation: the "front door" of the app. Each tab opens one screen.)
final class RootTabBarController: UITabBarController {

    private let container: AppContainer
    private var symbols: [String: String] = [:] // tab title -> icon name

    init(container: AppContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    private static let homeIndex = 0
    private static let scanIndex = 1
    private static let pantryIndex = 2
    private static let recipesIndex = 3

    override func viewDidLoad() {
        super.viewDidLoad()

        let pantry = PantryListBuilder.build(
            repository: container.pantryRepository,
            settingsStore: container.settingsStore,
            dateProvider: container.dateProvider,
            iconProvider: container.foodIconProvider,
            dateFormatter: container.dateFormatter,
            reminders: container.reminders,
            photoStore: container.photoStore,
            photoCache: container.photoCache,
            recognizer: container.textRecognizer,
            outcomes: container.outcomeRepository)

        let home = HomeBuilder.build(
            repository: container.pantryRepository,
            outcomes: container.outcomeRepository,
            settingsStore: container.settingsStore,
            dateProvider: container.dateProvider,
            iconProvider: container.foodIconProvider,
            photoCache: container.photoCache,
            recipeCache: container.recipeCache,
            selectRecipes: { [weak self] in self?.selectedIndex = Self.recipesIndex },
            selectPantry: { [weak self] in self?.selectedIndex = Self.pantryIndex },
            selectScan: { [weak self] in self?.selectedIndex = Self.scanIndex },
            addItem: { [weak self] in self?.presentNewItem(prefilledWith: nil) })

        let recipes = RecipesBuilder.build(
            repository: container.pantryRepository,
            settingsStore: container.settingsStore,
            dateProvider: container.dateProvider,
            service: container.recipeService,
            cache: container.recipeCache,
            imageLoader: container.imageLoader)

        let scanner = ScannerBuilder.build(
            settingsStore: container.settingsStore,
            dateFormatter: container.dateFormatter,
            dateProvider: container.dateProvider,
            recognizer: container.textRecognizer,
            isPopUp: false,
            onResult: { [weak self] result in self?.presentNewItem(prefilledWith: result) })

        let settings = SettingsBuilder.build(
            settingsStore: container.settingsStore,
            reminders: container.reminders,
            dateFormatter: container.dateFormatter,
            dateProvider: container.dateProvider)

        viewControllers = [
            makeTab(title: String(localized: "Home"), symbol: "house",
                    content: home),
            // The Scan tab IS the camera screen (no pop-up). Once a date is found, a new item
            // opens with the date (and photo, if kept) already filled in.
            makeTab(title: String(localized: "Scan"), symbol: "viewfinder", content: scanner),
            // The pantry sits inside a navigation controller: it gives us the big title on top
            // and lets us push other screens (like "Add item") on top of it.
            makeTab(title: String(localized: "Pantry"), symbol: "refrigerator",
                    content: ThemedNavigationController(rootViewController: pantry)),
            makeTab(title: String(localized: "Recipes"), symbol: "fork.knife",
                    content: ThemedNavigationController(rootViewController: recipes)),
            makeTab(title: String(localized: "Me"), symbol: "person.crop.circle",
                    content: ThemedNavigationController(rootViewController: settings))
        ]
        // Real users start on Home. UI tests start on Pantry (where most of them begin)
        // unless they ask for Home with `-uiTestingStartOnHome`.
        let args = ProcessInfo.processInfo.arguments
        let startOnPantry = args.contains("-uiTesting") && !args.contains("-uiTestingStartOnHome")
        selectedIndex = startOnPantry ? Self.pantryIndex : Self.homeIndex
        styleTabBar()

        // When the phone switches between light and dark mode, repaint the icons.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.refreshIcons()
            self.styleTabBar() // label colours are fixed when set, so repaint them too
        }
    }

    /// `result` is a scanned date and photo to fill the form with, or nil for an empty form.
    private func presentNewItem(prefilledWith result: ScanResult?) {
        let form = AddEditItemBuilder.build(
            existing: nil,
            repository: container.pantryRepository,
            dateProvider: container.dateProvider,
            iconProvider: container.foodIconProvider,
            settingsStore: container.settingsStore,
            reminders: container.reminders,
            photoStore: container.photoStore,
            dateFormatter: container.dateFormatter,
            recognizer: container.textRecognizer,
            prefill: result,
            onSaved: { [weak self] in self?.showPantryAfterSaving() })
        present(ThemedNavigationController(rootViewController: form), animated: true)
    }

    /// A sheet opened over the Pantry doesn't make it "appear" again, so tell it to reload explicitly.
    private func showPantryAfterSaving() {
        selectedIndex = Self.pantryIndex
        let navigation = viewControllers?[Self.pantryIndex] as? UINavigationController
        (navigation?.viewControllers.first as? PantryListViewController)?.reload()
    }

    private func makeTab(title: String, symbol: String, content: UIViewController) -> UIViewController {
        symbols[title] = symbol
        content.tabBarItem = UITabBarItem(title: title,
                                          image: icon(symbol, color: Theme.Colors.muted),
                                          selectedImage: icon(symbol, color: Theme.Colors.brand))
        return content
    }

    /// Our own coloured icons. (Translation: iOS 26's new tab bar ignores the icon colour
    /// we ask for, so we hand it icons that are already painted the right colour.)
    private func refreshIcons() {
        for screen in viewControllers ?? [] {
            guard let title = screen.tabBarItem.title, let symbol = symbols[title] else { continue }
            screen.tabBarItem.image = icon(symbol, color: Theme.Colors.muted)
            screen.tabBarItem.selectedImage = icon(symbol, color: Theme.Colors.brand)
        }
    }

    private func icon(_ symbol: String, color: UIColor) -> UIImage? {
        // Dynamic colours must be turned into a fixed colour for the current light/dark mode.
        let fixed = color.resolvedColor(with: traitCollection)
        return UIImage(systemName: symbol)?.withTintColor(fixed, renderingMode: .alwaysOriginal)
    }

    /// Paints the tab bar in our cream-and-green colours.
    private func styleTabBar() {
        let muted = Theme.Colors.muted.resolvedColor(with: traitCollection)
        let brand = Theme.Colors.brand.resolvedColor(with: traitCollection)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.Colors.background.resolvedColor(with: traitCollection)
        appearance.shadowColor = Theme.Colors.divider.resolvedColor(with: traitCollection)

        // The bar has three layouts (phone, landscape, iPad); colour them all the same.
        for item in [appearance.stackedLayoutAppearance,
                     appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = muted
            item.normal.titleTextAttributes = [.foregroundColor: muted]
            item.selected.iconColor = brand
            item.selected.titleTextAttributes = [.foregroundColor: brand]
        }

        // iOS 26's new tab bar also needs these two for icon colours.
        tabBar.tintColor = brand
        tabBar.unselectedItemTintColor = muted

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }
}
