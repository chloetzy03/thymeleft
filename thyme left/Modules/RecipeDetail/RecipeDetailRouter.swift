import UIKit

/// The host of the Recipe detail screen: opens links in Safari.
@MainActor
final class RecipeDetailRouter: RecipeDetailRouterProtocol {

    func open(_ url: URL) {
        // Only web links, so a strange address from the recipe source can't open something else.
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return }
        UIApplication.shared.open(url)
    }
}

@MainActor
enum RecipeDetailBuilder {

    static func build(match: RecipeMatch, imageLoader: RemoteImageLoading) -> UIViewController {
        let view = RecipeDetailViewController(imageLoader: imageLoader)
        let presenter = RecipeDetailPresenter(view: view, router: RecipeDetailRouter(), match: match)
        view.presenter = presenter
        return view
    }
}
