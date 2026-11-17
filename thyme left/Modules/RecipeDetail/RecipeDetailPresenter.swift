import Foundation

/// The manager of the Recipe detail screen: turns a recipe into tidy text.
@MainActor
final class RecipeDetailPresenter: RecipeDetailPresenterProtocol {

    private weak var view: RecipeDetailViewProtocol?
    private let router: RecipeDetailRouterProtocol
    private let match: RecipeMatch

    init(view: RecipeDetailViewProtocol, router: RecipeDetailRouterProtocol, match: RecipeMatch) {
        self.view = view
        self.router = router
        self.match = match
    }

    func viewDidLoad() {
        let recipe = match.recipe
        let have = match.ingredientAvailability.filter(\.have).count
        let total = match.ingredientAvailability.count

        view?.showRecipe(RecipeDetailViewModel(
            title: recipe.name,
            subtitle: [recipe.category, recipe.area].compactMap { $0 }.joined(separator: " · ").nilIfEmpty,
            imageURL: recipe.imageURL,
            haveSummary: total == 0 ? String(localized: "No ingredient list available") : String(localized: "You have \(have) of \(total) ingredients"),
            ingredients: match.ingredientAvailability.map(row(for:)),
            steps: Self.steps(from: recipe.instructions),
            sourceButtonTitle: recipe.sourceURL == nil ? nil : String(localized: "Open the original recipe"),
            videoButtonTitle: recipe.videoURL == nil ? nil : String(localized: "Watch the video")))
    }

    func didTapSource() {
        if let url = match.recipe.sourceURL { router.open(url) }
    }

    func didTapVideo() {
        if let url = match.recipe.videoURL { router.open(url) }
    }

    // MARK: Helpers

    private func row(for item: RecipeMatch.IngredientAvailability) -> RecipeDetailViewModel.IngredientRow {
        let measure = item.ingredient.measure.isEmpty ? "" : " - \(item.ingredient.measure)"
        let name = FoodNameTranslator.shared.displayName(forIngredient: item.ingredient.name)
        return .init(text: name + measure,
                     have: item.have,
                     accessibilityText: "\(name)\(measure), " + (item.have ? String(localized: "you have it") : String(localized: "you need to get this")))
    }

    /// Splits the instructions into steps, dropping lines like "STEP 2" or "3." that only label a step.
    static func steps(from instructions: String) -> [String] {
        instructions
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                !line.isEmpty
                    && line.range(of: #"^(step\s*)?\d+[.:)]?$"#, options: [.regularExpression, .caseInsensitive]) == nil
            }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
