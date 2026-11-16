import Foundation

/// One ingredient line in a recipe, e.g. "soy sauce" - "3/4 cup".
struct RecipeIngredient: Equatable, Codable {
    let name: String
    let measure: String
}

/// A full recipe.
struct Recipe: Equatable, Codable, Identifiable {
    let id: String
    let name: String
    let category: String?
    let area: String?          // the cuisine, e.g. "Italian"
    let instructions: String
    let imageURL: URL?
    let sourceURL: URL?
    let videoURL: URL?
    let ingredients: [RecipeIngredient]
}

/// A short recipe entry from a search (before we fetch the full recipe).
struct RecipeSummary: Equatable {
    let id: String
    let name: String
}

/// How to order the suggestions.
enum RecipeSortMode: Int, CaseIterable {
    case useItUpFirst   // recipes using the soonest-to-expire items come first
    case bestMatch      // recipes where you already have the most ingredients come first

    var title: String {
        switch self {
        case .useItUpFirst: return "Use up first"
        case .bestMatch: return "Best match"
        }
    }
}

/// A recipe compared with what's in your pantry.
struct RecipeMatch: Equatable {
    let recipe: Recipe
    /// Names of YOUR items this recipe uses, soonest-to-expire first.
    let usedItemNames: [String]
    /// Recipe ingredients you don't have (basics like water and salt are assumed).
    let missingIngredients: [String]
    /// Every recipe ingredient, with whether you have it, for the detail screen.
    let ingredientAvailability: [IngredientAvailability]
    /// Higher = rescues more food that is about to go off.
    let urgencyScore: Double

    struct IngredientAvailability: Equatable {
        let ingredient: RecipeIngredient
        let have: Bool
    }
}
