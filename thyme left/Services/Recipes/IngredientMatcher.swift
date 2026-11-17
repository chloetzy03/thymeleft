import Foundation

/// Decides whether "Greek yoghurt" in your pantry is the "Yogurt" in a recipe.
/// (Translation: it simplifies words - lower case, singular, no "fresh/frozen/chopped" - and
/// then compares. Pure rules, so we can test lots of examples.)
struct IngredientMatcher {

    /// Words that describe the state of a food, not the food itself.
    private static let ignoredWords: Set<String> = [
        "fresh", "frozen", "organic", "large", "small", "medium", "whole", "chopped", "diced", "sliced",
        "minced", "dried", "ripe", "raw", "cooked", "canned", "tinned", "of", "the", "a"
    ]

    /// Different spellings of the same food.
    private static let synonyms: [String: String] = [
        "yoghurt": "yogurt", "aubergine": "eggplant", "courgette": "zucchini", "coriander": "cilantro",
        "capsicum": "pepper", "prawn": "shrimp", "mince": "beef"
    ]

    /// Foods nearly everyone has, so a recipe isn't called "missing" them.
    static let assumedStaples: Set<String> = ["water", "salt", "pepper", "black pepper", "oil", "olive oil", "vegetable oil"]

    /// "Frozen Peas" -> ["pea"]
    static func tokens(_ text: String) -> [String] {
        // Chinese food names ("牛奶") are first turned into English ("milk") so they can be compared.
        FoodNameTranslator.shared.english(for: text).lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty && !ignoredWords.contains($0) }
            .map(singular)
            .map { synonyms[$0] ?? $0 }
    }

    private static func singular(_ word: String) -> String {
        if word.hasSuffix("ies"), word.count > 4 { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("oes"), word.count > 4 { return String(word.dropLast(2)) }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 3 { return String(word.dropLast()) }
        return word
    }

    /// Is this pantry item the same food as this recipe ingredient?
    /// Yes when every word of the recipe ingredient appears in the pantry name
    /// ("Full cream milk" has "milk"), or both mean exactly the same.
    func matches(pantryName: String, recipeIngredient: String) -> Bool {
        let recipe = Self.tokens(recipeIngredient)
        let pantry = Self.tokens(pantryName)
        guard !recipe.isEmpty, !pantry.isEmpty else { return false }
        return Set(recipe).isSubset(of: Set(pantry))
    }

    func isStaple(_ ingredient: String) -> Bool {
        Self.assumedStaples.contains(Self.tokens(ingredient).joined(separator: " "))
            || Self.assumedStaples.contains(ingredient.lowercased())
    }

    /// The recipe database's name for one of your items, e.g. "Frozen peas" -> "Peas".
    /// Picks the most specific known ingredient whose words all appear in your item's name.
    func searchKeyword(for pantryName: String, knownIngredients: [String]) -> String? {
        let pantry = Set(Self.tokens(pantryName))
        guard !pantry.isEmpty else { return nil }
        return knownIngredients
            .compactMap { known -> (name: String, words: Int)? in
                let words = Self.tokens(known)
                guard !words.isEmpty, Set(words).isSubset(of: pantry) else { return nil }
                return (known, words.count)
            }
            .max { $0.words < $1.words }?
            .name
    }
}
