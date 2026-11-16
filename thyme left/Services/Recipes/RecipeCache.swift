import Foundation

/// A "job description" for remembering recipes we've fetched, so they still show offline.
@MainActor
protocol RecipeCaching: AnyObject {
    func store(_ recipes: [Recipe])
    func allRecipes() -> [Recipe]
}

/// Keeps recipes in one small file on the phone. Oldest are dropped once there are too many.
@MainActor
final class FileSystemRecipeCache: RecipeCaching {

    static let maxRecipes = 150

    private let fileURL: URL
    private var recipes: [Recipe]   // oldest first

    init(fileURL: URL? = nil) {
        let url = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recipe-cache.json")
        self.fileURL = url
        self.recipes = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Recipe].self, from: $0) } ?? []
    }

    func store(_ newRecipes: [Recipe]) {
        for recipe in newRecipes {
            recipes.removeAll { $0.id == recipe.id } // a refreshed copy replaces the old one
            recipes.append(recipe)
        }
        recipes = Array(recipes.suffix(Self.maxRecipes))
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(recipes) { try? data.write(to: fileURL, options: .atomic) }
    }

    func allRecipes() -> [Recipe] { recipes }
}

@MainActor
final class InMemoryRecipeCache: RecipeCaching {
    private var recipes: [Recipe] = []

    func store(_ newRecipes: [Recipe]) {
        for recipe in newRecipes {
            recipes.removeAll { $0.id == recipe.id }
            recipes.append(recipe)
        }
    }
    func allRecipes() -> [Recipe] { recipes }
}
