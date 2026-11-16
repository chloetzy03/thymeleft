import UIKit

extension Theme {

    /// Paints the top navigation bar (the bar with the big screen title) in our style.
    /// Call once when the app starts.
    @MainActor
    static func applyAppearance() {
        UINavigationBar.appearance().tintColor = Colors.brand
    }

    /// The navigation bar look for light OR dark mode.
    /// (Translation: text colours given to iOS this way don't switch automatically when the phone
    /// goes dark, so we pick the right colour for the current mode ourselves and redo it when it changes.
    /// That mix-up made the screen titles nearly invisible in dark mode.)
    @MainActor
    static func navigationBarAppearance(for traits: UITraitCollection) -> UINavigationBarAppearance {
        let ink = Colors.ink.resolvedColor(with: traits)
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = Colors.background.resolvedColor(with: traits)
        bar.shadowColor = .clear
        bar.titleTextAttributes = [.foregroundColor: ink]
        bar.largeTitleTextAttributes = [.foregroundColor: ink, .font: Typography.screenTitle.font]
        return bar
    }
}

/// A navigation controller that keeps its bar in our colours in both light and dark mode.
final class ThemedNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        applyBarAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.applyBarAppearance()
        }
    }

    private func applyBarAppearance() {
        let bar = Theme.navigationBarAppearance(for: traitCollection)
        navigationBar.standardAppearance = bar
        navigationBar.scrollEdgeAppearance = bar
        navigationBar.compactAppearance = bar
        navigationBar.tintColor = Theme.Colors.brand
    }
}
