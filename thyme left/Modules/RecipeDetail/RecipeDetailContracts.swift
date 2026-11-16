import Foundation

// The Recipe detail screen has no business logic of its own (the match is worked out earlier),
// so it has no Interactor. VIPER allows that: only add a part when it has a job.

struct RecipeDetailViewModel: Equatable {
    struct IngredientRow: Equatable {
        let text: String   // "Spinach - 1 bag"
        let have: Bool
        let accessibilityText: String
    }
    let title: String
    let subtitle: String?
    let imageURL: URL?
    let haveSummary: String      // "You have 3 of 4 ingredients"
    let ingredients: [IngredientRow]
    let steps: [String]
    let sourceButtonTitle: String?
    let videoButtonTitle: String?
}

@MainActor
protocol RecipeDetailViewProtocol: AnyObject {
    func showRecipe(_ detail: RecipeDetailViewModel)
}

@MainActor
protocol RecipeDetailPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didTapSource()
    func didTapVideo()
}

@MainActor
protocol RecipeDetailRouterProtocol: AnyObject {
    func open(_ url: URL)
}
