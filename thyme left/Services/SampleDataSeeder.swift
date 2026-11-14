#if DEBUG
import Foundation

/// Fills an empty pantry with example food so we can SEE the list while building.
/// (Translation: only exists in developer builds, never in the App Store version.
/// We'll delete it once the "Add item" screen exists.)
@MainActor
enum SampleDataSeeder {

    private static let seededKey = "didSeedSampleData"

    static func seedIfNeeded(repository: PantryRepository,
                             now: Date,
                             defaults: UserDefaults = .standard,
                             calendar: Calendar = .current) {
        guard !defaults.bool(forKey: seededKey),
              (try? repository.fetchAll().isEmpty) == true else { return }

        func item(_ name: String, _ qty: Int, _ place: StorageLocation, daysFromNow: Int) -> PantryItem {
            let date = calendar.date(byAdding: .day, value: daysFromNow, to: now) ?? now
            return PantryItem(name: name, quantity: qty, location: place, expiryDate: date)
        }

        let samples = [
            item("Yoghurt", 2, .fridge, daysFromNow: -1),
            item("Avocado", 2, .counter, daysFromNow: 1),
            item("Tomatoes", 4, .counter, daysFromNow: 2),
            item("Milk", 1, .fridge, daysFromNow: 3),
            item("Spinach", 1, .fridge, daysFromNow: 4),
            item("Eggs", 6, .fridge, daysFromNow: 12),
            item("Frozen peas", 1, .freezer, daysFromNow: 90),
            item("Pasta", 2, .pantry, daysFromNow: 120),
            item("Mystery sauce", 1, .pantry, daysFromNow: 200)
        ]
        samples.forEach { try? repository.save($0) }
        defaults.set(true, forKey: seededKey)
    }
}
#endif
