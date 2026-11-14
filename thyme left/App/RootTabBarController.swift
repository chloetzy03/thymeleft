import UIKit

/// The bottom bar with four tabs: Home, Scan, Pantry, Recipes.
/// (Translation: the "front door" of the app. Each tab opens one screen.)
final class RootTabBarController: UITabBarController {

    private var symbols: [String: String] = [:] // tab title -> icon name

    override func viewDidLoad() {
        super.viewDidLoad()

        viewControllers = [
            makeTab(title: "Home", symbol: "house",
                    message: "Your daily summary is coming in a later milestone."),
            makeTab(title: "Scan", symbol: "viewfinder",
                    message: "Date scanning arrives in Milestone 4."),
            makeTab(title: "Pantry", symbol: "refrigerator",
                    message: "Your pantry list arrives in Milestone 1."),
            makeTab(title: "Recipes", symbol: "fork.knife",
                    message: "Recipe ideas arrive in Milestone 5.")
        ]
        selectedIndex = 2 // open on Pantry, the heart of the app
        styleTabBar()

        // When the phone switches between light and dark mode, repaint the icons.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.refreshIcons()
        }
    }

    private func makeTab(title: String, symbol: String, message: String) -> UIViewController {
        let screen = PlaceholderViewController(title: title, message: message)
        symbols[title] = symbol
        screen.tabBarItem = UITabBarItem(title: title,
                                         image: icon(symbol, color: Theme.Colors.muted),
                                         selectedImage: icon(symbol, color: Theme.Colors.brand))
        return screen
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
