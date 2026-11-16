import Foundation
import SwiftData
import os

/// The one place where the app's real parts are created and handed out.
/// (Translation: a "toolbox" built at start-up. Every screen is given the tools it needs,
/// instead of reaching out and grabbing them itself. If we want a different database or a
/// fake clock, this is the only file that changes.)
@MainActor
final class AppContainer {

    let pantryRepository: PantryRepository
    let settingsStore: SettingsStore
    let reminders: ReminderServicing
    let dateFormatter: ExpiryDateFormatter
    let photoStore: PhotoStoring
    let photoCache: PhotoImageCache
    let textRecognizer: TextRecognizing
    let recipeService: RecipeService
    let recipeCache: RecipeCaching
    let imageLoader: RemoteImageLoading
    let dateProvider: DateProviding
    let foodIconProvider: FoodIconProviding

    /// Kept so the database stays open for as long as the app runs.
    private let modelContainer: ModelContainer?

    private static let logger = Logger(subsystem: "com.fp.thyme-left", category: "storage")

    /// - Parameter arguments: the launch arguments. UI tests start the app with `-uiTesting`
    ///   to get an empty pantry, throw-away settings and no real notification pop-ups.
    ///   Adding `-uiTestingPermissionUndetermined` pretends iOS hasn't been asked yet.
    init(dateProvider: DateProviding = SystemDateProvider(),
         foodIconProvider: FoodIconProviding = EmojiFoodIconProvider(),
         arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.dateProvider = dateProvider
        self.foodIconProvider = foodIconProvider

        let isUITesting = arguments.contains("-uiTesting")

        // Where the pantry is stored
        var container: ModelContainer?
        let repository: PantryRepository
        if isUITesting {
            repository = InMemoryPantryRepository()
        } else {
            do {
                let opened = try ModelContainer(for: PantryItemRecord.self)
                container = opened
                repository = SwiftDataPantryRepository(context: opened.mainContext)
            } catch {
                // Safety net: if the database can't open, keep the app usable (items just won't be saved).
                Self.logger.error("Could not open database: \(error.localizedDescription)")
                repository = InMemoryPantryRepository()
            }
        }
        modelContainer = container
        pantryRepository = repository

        // Settings and reminders
        let settingsStore: SettingsStore = isUITesting ? InMemorySettingsStore() : UserDefaultsSettingsStore()
        let scheduler: NotificationScheduling = isUITesting
            ? StubNotificationScheduler(permission: arguments.contains("-uiTestingPermissionUndetermined")
                                        ? .notDetermined : .authorized)
            : UserNotificationScheduler()
        self.settingsStore = settingsStore
        reminders = ReminderService(repository: repository, settingsStore: settingsStore,
                                    scheduler: scheduler, dateProvider: dateProvider)
        dateFormatter = ExpiryDateFormatter(settingsStore: settingsStore)

        // Photos live as small files on the phone (in memory only for UI tests).
        let photoStore: PhotoStoring = isUITesting ? InMemoryPhotoStore() : FileSystemPhotoStore()
        self.photoStore = photoStore
        photoCache = PhotoImageCache(photoStore: photoStore)
        // Recipes: the real TheMealDB service, or fixed sample recipes for UI tests.
        // `-uiTestingRecipesOffline` makes the sample service act like there's no internet.
        if isUITesting {
            recipeService = StubRecipeService.uiTestingSample(
                error: arguments.contains("-uiTestingRecipesOffline") ? .offline : nil)
            recipeCache = InMemoryRecipeCache()
            imageLoader = NoImageLoader()
        } else {
            recipeService = MealDBRecipeService()
            recipeCache = FileSystemRecipeCache()
            imageLoader = URLSessionImageLoader()
        }

        // UI tests can pass `-uiTestingScanText "line one|line two"` to fake what the camera reads.
        if isUITesting, let flag = arguments.firstIndex(of: "-uiTestingScanText"), arguments.indices.contains(flag + 1) {
            textRecognizer = StubTextRecognizer(lines: arguments[flag + 1].components(separatedBy: "|"))
        } else {
            textRecognizer = VisionTextRecognizer()
        }
    }
}
