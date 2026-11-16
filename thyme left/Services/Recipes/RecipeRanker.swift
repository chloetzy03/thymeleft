import Foundation

/// Compares recipes with your pantry and orders them. Pure maths, no network.
struct RecipeRanker {

    private let matcher = IngredientMatcher()

    /// - Parameter pantry: your usable (not expired) items, soonest-to-expire first.
    func rank(recipes: [Recipe], pantry: [ExpiringItem], mode: RecipeSortMode) -> [RecipeMatch] {
        recipes
            .compactMap { match($0, pantry: pantry) }
            .sorted { lhs, rhs in
                switch mode {
                case .useItUpFirst:
                    // Rescuing food matters most, but a recipe needing a big shop is worth less.
                    if lhs.rescueScore != rhs.rescueScore { return lhs.rescueScore > rhs.rescueScore }
                    if lhs.missingIngredients.count != rhs.missingIngredients.count {
                        return lhs.missingIngredients.count < rhs.missingIngredients.count
                    }
                case .bestMatch:
                    if lhs.missingIngredients.count != rhs.missingIngredients.count {
                        return lhs.missingIngredients.count < rhs.missingIngredients.count
                    }
                    if lhs.usedItemNames.count != rhs.usedItemNames.count {
                        return lhs.usedItemNames.count > rhs.usedItemNames.count
                    }
                    if lhs.urgencyScore != rhs.urgencyScore { return lhs.urgencyScore > rhs.urgencyScore }
                }
                return lhs.recipe.name.localizedCaseInsensitiveCompare(rhs.recipe.name) == .orderedAscending
            }
    }

    /// Compares EVERY recipe with your pantry (used for search, where the user chose the dish),
    /// even recipes that use nothing you have. Order is kept as given.
    func compareAll(recipes: [Recipe], pantry: [ExpiringItem]) -> [RecipeMatch] {
        recipes.map { makeMatch($0, pantry: pantry) }
    }

    /// nil when the recipe uses nothing from your pantry.
    private func match(_ recipe: Recipe, pantry: [ExpiringItem]) -> RecipeMatch? {
        let result = makeMatch(recipe, pantry: pantry)
        return result.usedItemNames.isEmpty ? nil : result
    }

    private func makeMatch(_ recipe: Recipe, pantry: [ExpiringItem]) -> RecipeMatch {
        // Two cartons of milk are one "Milk" to a recipe. The pantry is soonest-first,
        // so the first one we meet is the one that expires first.
        var used: [ExpiringItem] = []
        var usedNames = Set<String>()
        for entry in pantry where recipe.ingredients.contains(where: {
            matcher.matches(pantryName: entry.item.name, recipeIngredient: $0.name)
        }) {
            if usedNames.insert(entry.item.name.lowercased()).inserted { used.append(entry) }
        }

        let availability = recipe.ingredients.map { ingredient in
            let have = matcher.isStaple(ingredient.name)
                || pantry.contains { matcher.matches(pantryName: $0.item.name, recipeIngredient: ingredient.name) }
            return RecipeMatch.IngredientAvailability(ingredient: ingredient, have: have)
        }
        // An item due today is worth 1.0, tomorrow 0.5, in 2 days 0.33, and so on.
        let urgency = used.reduce(0.0) { $0 + 1.0 / Double(1 + max($1.daysRemaining, 0)) }

        return RecipeMatch(recipe: recipe,
                           usedItemNames: used.map(\.item.name),
                           missingIngredients: availability.filter { !$0.have }.map(\.ingredient.name),
                           ingredientAvailability: availability,
                           urgencyScore: urgency)
    }
}
