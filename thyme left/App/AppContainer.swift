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
    let expiryPolicy: ExpiryPolicy
    let dateProvider: DateProviding
    let foodIconProvider: FoodIconProviding

    /// Kept so the database stays open for as long as the app runs.
    private let modelContainer: ModelContainer?

    private static let logger = Logger(subsystem: "com.fp.thyme-left", category: "storage")

    /// - Parameter inMemoryOnly: skip the real database. UI tests launch the app with
    ///   `-uiTesting` so they always start with an empty pantry and never touch real data.
    init(expiryPolicy: ExpiryPolicy = ExpiryPolicy(),
         dateProvider: DateProviding = SystemDateProvider(),
         foodIconProvider: FoodIconProviding = EmojiFoodIconProvider(),
         inMemoryOnly: Bool = ProcessInfo.processInfo.arguments.contains("-uiTesting")) {
        self.expiryPolicy = expiryPolicy
        self.dateProvider = dateProvider
        self.foodIconProvider = foodIconProvider

        if inMemoryOnly {
            modelContainer = nil
            pantryRepository = InMemoryPantryRepository()
            return
        }

        do {
            let container = try ModelContainer(for: PantryItemRecord.self)
            modelContainer = container
            pantryRepository = SwiftDataPantryRepository(context: container.mainContext)
        } catch {
            // Safety net: if the database can't open, keep the app usable (items just won't be saved).
            Self.logger.error("Could not open database: \(error.localizedDescription)")
            modelContainer = nil
            pantryRepository = InMemoryPantryRepository()
        }
    }
}
