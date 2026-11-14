import UIKit

extension Theme {
    /// Paints the top navigation bar (the bar with the big screen title) in our style.
    /// Call once when the app starts.
    @MainActor
    static func applyAppearance() {
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = Colors.background
        bar.shadowColor = .clear
        bar.titleTextAttributes = [.foregroundColor: Colors.ink]
        bar.largeTitleTextAttributes = [
            .foregroundColor: Colors.ink,
            .font: Typography.screenTitle.font
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = bar
        navigationBar.scrollEdgeAppearance = bar
        navigationBar.compactAppearance = bar
        navigationBar.tintColor = Colors.brand
    }
}
