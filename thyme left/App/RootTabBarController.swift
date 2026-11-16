import UIKit

/// The bottom bar with four tabs: Home, Scan, Pantry, Recipes.
/// (Translation: the "front door" of the app. Each tab opens one screen.)
final class RootTabBarController: UITabBarController, UITabBarControllerDelegate {

    private let container: AppContainer
    private var symbols: [String: String] = [:] // tab title -> icon name

    init(container: AppContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    private static let pantryIndex = 2
    private static let scanIndex = 1

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        let pantry = PantryListBuilder.build(
            repository: container.pantryRepository,
            settingsStore: container.settingsStore,
            dateProvider: container.dateProvider,
            iconProvider: container.foodIconProvider,
            dateFormatter: container.dateFormatter,
            reminders: container.reminders,
            photoStore: container.photoStore,
            photoCache: container.photoCache,
            recognizer: container.textRecognizer)

        let recipes = RecipesBuilder.build(
            repository: container.pantryRepository,
            settingsStore: container.settingsStore,
            dateProvider: container.dateProvider,
            service: container.recipeService,
            cache: container.recipeCache,
            imageLoader: container.imageLoader)

        let settings = SettingsBuilder.build(
            settingsStore: container.settingsStore,
            reminders: container.reminders,
            dateFormatter: container.dateFormatter,
            dateProvider: container.dateProvider)

        viewControllers = [
            makeTab(title: "Home", symbol: "house",
                    content: PlaceholderViewController(
                        title: "Home", message: "Your daily summary is coming in a later milestone.")),
            makeTab(title: "Scan", symbol: "viewfinder",
                    // Never shown: tapping Scan opens the scanner instead (see `shouldSelect` below).
                    content: UIViewController()),
            // The pantry sits inside a navigation controller: it gives us the big title on top
            // and lets us push other screens (like "Add item") on top of it.
            makeTab(title: "Pantry", symbol: "refrigerator",
                    content: UINavigationController(rootViewController: pantry)),
            makeTab(title: "Recipes", symbol: "fork.knife",
                    content: UINavigationController(rootViewController: recipes)),
            makeTab(title: "Me", symbol: "person.crop.circle",
                    content: UINavigationController(rootViewController: settings))
        ]
        selectedIndex = Self.pantryIndex // open on Pantry, the heart of the app
        styleTabBar()

        // When the phone switches between light and dark mode, repaint the icons.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.refreshIcons()
        }
    }

    /// Tapping "Scan" doesn't switch tabs. It opens the scanner; once a date is found, a new item
    /// opens with that date (and photo, if kept) already filled in.
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard viewControllers?.firstIndex(of: viewController) == Self.scanIndex else { return true }

        let scanner = ScannerBuilder.build(
            settingsStore: container.settingsStore,
            dateFormatter: container.dateFormatter,
            dateProvider: container.dateProvider,
            recognizer: container.textRecognizer,
            onResult: { [weak self] result in self?.presentNewItem(prefilledWith: result) })
        present(UINavigationController(rootViewController: scanner), animated: true)
        return false
    }

    private func presentNewItem(prefilledWith result: ScanResult) {
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
        present(UINavigationController(rootViewController: form), animated: true)
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
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.Colors.background
        appearance.shadowColor = Theme.Colors.divider

        // The bar has three layouts (phone, landscape, iPad); colour them all the same.
        for item in [appearance.stackedLayoutAppearance,
                     appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = Theme.Colors.muted
            item.normal.titleTextAttributes = [.foregroundColor: Theme.Colors.muted]
            item.selected.iconColor = Theme.Colors.brand
            item.selected.titleTextAttributes = [.foregroundColor: Theme.Colors.brand]
        }

        // iOS 26's new tab bar also needs these two for icon colours.
        tabBar.tintColor = Theme.Colors.brand
        tabBar.unselectedItemTintColor = Theme.Colors.muted

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }
}
