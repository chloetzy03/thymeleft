import Foundation

extension Array where Element == String {

    /// "Milk, Eggs" in English and "牛奶、鸡蛋" in Chinese: the right comma for the app's language.
    func joinedForDisplay(chinese: Bool = FoodNameTranslator.appLanguageIsChinese) -> String {
        joined(separator: chinese ? "、" : ", ")
    }
}
