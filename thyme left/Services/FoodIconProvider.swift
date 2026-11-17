import Foundation

/// Picks an emoji for a food from its name.
/// (Translation: type "milk" and you get 🥛. Unknown foods get a plate 🍽️.)
protocol FoodIconProviding {
    func emoji(for foodName: String) -> String
}

struct EmojiFoodIconProvider: FoodIconProviding {

    static let fallback = "🍽️"

    /// Keyword -> emoji. Order matters: the first keyword found in the name wins,
    /// so specific words ("peanut butter") sit above general ones ("butter").
    private let table: [(keyword: String, emoji: String)] = [
        ("peanut butter", "🥜"), ("ice cream", "🍨"), ("sweet potato", "🍠"),
        ("eggplant", "🍆"), ("aubergine", "🍆"),
        ("milk", "🥛"), ("cheese", "🧀"), ("butter", "🧈"), ("yogurt", "🥛"), ("yoghurt", "🥛"),
        ("egg", "🥚"), ("bread", "🍞"), ("toast", "🍞"), ("bagel", "🥯"), ("croissant", "🥐"),
        ("avocado", "🥑"), ("tomato", "🍅"), ("potato", "🥔"), ("carrot", "🥕"), ("corn", "🌽"),
        ("onion", "🧅"), ("garlic", "🧄"), ("broccoli", "🥦"), ("spinach", "🥬"), ("lettuce", "🥬"),
        ("salad", "🥗"), ("cucumber", "🥒"), ("pepper", "🫑"), ("chilli", "🌶️"), ("chili", "🌶️"),
        ("mushroom", "🍄"),
        ("apple", "🍎"), ("banana", "🍌"), ("orange", "🍊"), ("lemon", "🍋"), ("lime", "🍋"),
        ("grape", "🍇"), ("strawberr", "🍓"), ("blueberr", "🫐"), ("peach", "🍑"), ("pear", "🍐"),
        ("mango", "🥭"), ("pineapple", "🍍"), ("watermelon", "🍉"), ("cherry", "🍒"), ("coconut", "🥥"),
        ("chicken", "🍗"), ("beef", "🥩"), ("steak", "🥩"), ("pork", "🥩"), ("bacon", "🥓"),
        ("sausage", "🌭"), ("ham", "🍖"), ("fish", "🐟"), ("salmon", "🐟"), ("tuna", "🐟"),
        ("shrimp", "🍤"), ("prawn", "🍤"),
        ("peas", "🫛"), ("pasta", "🍝"), ("noodle", "🍜"), ("rice", "🍚"), ("pizza", "🍕"), ("burger", "🍔"),
        ("cereal", "🥣"), ("oat", "🥣"), ("soup", "🍲"), ("sauce", "🥫"), ("beans", "🫘"),
        ("juice", "🧃"), ("water", "💧"), ("coffee", "☕"), ("tea", "🍵"), ("wine", "🍷"), ("beer", "🍺"),
        ("chocolate", "🍫"), ("cookie", "🍪"), ("cake", "🍰"), ("honey", "🍯"), ("jam", "🍓"),
        ("nut", "🥜"), ("salt", "🧂"), ("oil", "🫒"), ("olive", "🫒")
    ]

    func emoji(for foodName: String) -> String {
        // "牛奶" is understood as "milk" first, so Chinese names get the right emoji too.
        let lowered = FoodNameTranslator.shared.english(for: foodName).lowercased()
        return table.first { lowered.contains($0.keyword) }?.emoji ?? Self.fallback
    }
}
