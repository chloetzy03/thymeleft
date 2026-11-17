import Foundation

/// Understands common Chinese food names, so a pantry item called "牛奶" behaves like "Milk".
/// (Translation: our recipe source only speaks English. Before comparing, we swap Chinese food
/// words for their English twins. It also works backwards, so "Missing: Cheese" can read "还缺：奶酪".)
struct FoodNameTranslator {

    static let shared = FoodNameTranslator()

    /// Chinese word -> English word. An empty English word means "just a describing word, drop it".
    /// Where one English word has several Chinese words, the FIRST one listed is the one shown to users.
    static let entries: [(zh: String, en: String)] = [
        // dairy and eggs
        ("牛奶", "milk"), ("鲜奶", "milk"), ("酸奶油", "sour cream"), ("酸奶", "yogurt"), ("奶酪", "cheese"),
        ("芝士", "cheese"), ("淡奶油", "cream"), ("奶油", "cream"), ("黄油", "butter"), ("椰奶", "coconut milk"),
        ("鸡蛋", "egg"), ("鸭蛋", "duck egg"), ("蛋", "egg"),
        // meat
        ("鸡胸肉", "chicken breast"), ("鸡腿", "chicken thigh"), ("鸡翅", "chicken wings"), ("鸡肉", "chicken"),
        ("鸡", "chicken"), ("牛肉", "beef"), ("牛排", "steak"), ("猪肉", "pork"), ("排骨", "pork ribs"),
        ("五花肉", "pork belly"), ("培根", "bacon"), ("火腿", "ham"), ("香肠", "sausage"), ("羊肉", "lamb"),
        ("鸭肉", "duck"), ("肉末", "minced meat"),
        // fish and seafood
        ("三文鱼", "salmon"), ("金枪鱼", "tuna"), ("鱼", "fish"), ("虾", "shrimp"), ("螃蟹", "crab"),
        ("蟹", "crab"), ("鱿鱼", "squid"),
        // vegetables
        ("豆腐", "tofu"), ("西红柿", "tomato"), ("番茄", "tomato"), ("土豆", "potato"), ("马铃薯", "potato"),
        ("红薯", "sweet potato"), ("地瓜", "sweet potato"), ("洋葱", "onion"), ("大蒜", "garlic"), ("蒜", "garlic"),
        ("姜", "ginger"), ("葱", "spring onion"), ("胡萝卜", "carrot"), ("萝卜", "radish"), ("菠菜", "spinach"),
        ("西兰花", "broccoli"), ("花菜", "cauliflower"), ("白菜", "cabbage"), ("卷心菜", "cabbage"),
        ("包菜", "cabbage"), ("生菜", "lettuce"), ("黄瓜", "cucumber"), ("茄子", "eggplant"),
        ("青椒", "green pepper"), ("彩椒", "bell pepper"), ("辣椒酱", "chilli sauce"), ("辣椒", "chilli"),
        ("蘑菇", "mushroom"), ("香菇", "mushroom"), ("玉米", "corn"), ("豌豆", "peas"), ("青豆", "peas"),
        ("四季豆", "green beans"), ("豆角", "green beans"), ("芹菜", "celery"), ("南瓜", "pumpkin"),
        ("西葫芦", "zucchini"),
        // fruit
        ("牛油果", "avocado"), ("苹果", "apple"), ("香蕉", "banana"), ("橙子", "orange"), ("橙", "orange"),
        ("柠檬", "lemon"), ("青柠", "lime"), ("葡萄酒", "wine"), ("葡萄", "grape"), ("草莓", "strawberry"),
        ("蓝莓", "blueberry"), ("桃子", "peach"), ("梨", "pear"), ("芒果", "mango"), ("菠萝", "pineapple"),
        ("西瓜", "watermelon"), ("樱桃", "cherry"), ("椰子", "coconut"),
        // staples and baking
        ("米饭", "rice"), ("大米", "rice"), ("米粉", "noodle"), ("米", "rice"), ("泡面", "noodle"),
        ("面条", "noodle"), ("意大利面", "pasta"), ("意面", "pasta"), ("面粉", "flour"), ("面包", "bread"),
        ("吐司", "toast"), ("燕麦", "oats"), ("麦片", "cereal"), ("饺子", "dumpling"), ("年糕", "rice cake"),
        ("饼干", "cookie"), ("蛋糕", "cake"), ("披萨", "pizza"), ("汉堡", "burger"),
        // sauces, oils, sweet things
        ("糖", "sugar"), ("盐", "salt"), ("酱油", "soy sauce"), ("醋", "vinegar"), ("橄榄油", "olive oil"),
        ("芝麻油", "sesame oil"), ("食用油", "oil"), ("油", "oil"), ("蜂蜜", "honey"), ("果酱", "jam"),
        ("花生酱", "peanut butter"), ("花生", "peanut"), ("坚果", "nut"), ("芝麻", "sesame"),
        ("番茄酱", "tomato sauce"), ("咖喱", "curry"), ("鸡汤", "chicken stock"), ("高汤", "stock"),
        ("酱", "sauce"), ("汤", "soup"), ("巧克力", "chocolate"), ("冰淇淋", "ice cream"), ("豆", "beans"),
        // drinks
        ("咖啡", "coffee"), ("果汁", "juice"), ("啤酒", "beer"), ("红酒", "wine"), ("茶", "tea"), ("水", "water"),
        // describing words we can safely ignore
        ("新鲜", ""), ("有机", ""), ("进口", ""), ("国产", ""), ("冷冻", "frozen"), ("鲜", "")
    ]

    /// Longest Chinese words first, so "鸡胸肉" is read as one word and not as "鸡" + "胸肉".
    private let byLength: [(zh: String, en: String)]
    private let englishToChinese: [String: String]

    init() {
        byLength = Self.entries.enumerated()
            .sorted { lhs, rhs in
                lhs.element.zh.count != rhs.element.zh.count
                    ? lhs.element.zh.count > rhs.element.zh.count
                    : lhs.offset < rhs.offset
            }
            .map(\.element)

        var reverse: [String: String] = [:]
        for entry in Self.entries where !entry.en.isEmpty && entry.en != "frozen" {
            if reverse[entry.en] == nil { reverse[entry.en] = entry.zh } // first listed wins
        }
        englishToChinese = reverse
    }

    func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }

    /// "鲜牛奶" -> "milk"; "Greek 酸奶" -> "Greek yogurt". Text with no Chinese comes back unchanged.
    func english(for text: String) -> String {
        guard containsChinese(text) else { return text }
        var result = text
        for entry in byLength where result.contains(entry.zh) {
            result = result.replacingOccurrences(of: entry.zh, with: " \(entry.en) ")
        }
        return result.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// "Cheese" -> "奶酪", "Eggs" -> "鸡蛋". nil when we don't know a Chinese word for it.
    func chinese(forEnglishIngredient name: String) -> String? {
        let key = name.lowercased().trimmingCharacters(in: .whitespaces)
        if let found = englishToChinese[key] { return found }
        if key.hasSuffix("es"), let found = englishToChinese[String(key.dropLast(2))] { return found }
        if key.hasSuffix("s"), let found = englishToChinese[String(key.dropLast())] { return found }
        return nil
    }

    /// An ingredient name as the user should see it: Chinese when the app is in Chinese and we know the
    /// word, otherwise as it is.
    func displayName(forIngredient name: String, languageIsChinese: Bool = Self.appLanguageIsChinese) -> String {
        guard languageIsChinese else { return name }
        return chinese(forEnglishIngredient: name) ?? name
    }

    static var appLanguageIsChinese: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("zh") ?? false
    }
}
