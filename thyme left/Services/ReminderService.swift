import Foundation

/// Keeps the phone's reminders in step with your pantry and settings.
/// (Translation: whenever something changes, say `reschedule()`. It re-plans everything and
/// swaps the reminders on the phone. Screens never touch notifications directly.)
@MainActor
protocol ReminderServicing: AnyObject {
    /// What we last learned about the user's notification choice.
    var permission: NotificationPermission { get }
    /// Asks iOS what the user currently allows (they may have changed it in iOS Settings).
    func refreshPermission() async
    func requestPermission() async -> NotificationPermission
    /// Re-plan and replace all reminders in the background. Safe to call as often as you like.
    func reschedule()
    /// Re-check the permission (the user may have changed it in iOS Settings), then reschedule.
    func syncWithSystem()
}

@MainActor
final class ReminderService: ReminderServicing {

    private(set) var permission: NotificationPermission = .notDetermined

    private let repository: PantryRepository
    private let settingsStore: SettingsStore
    private let scheduler: NotificationScheduling
    private let dateProvider: DateProviding
    private let planner: ReminderPlanner
    private let calendar: Calendar
    /// The most recent background job. New jobs wait for it, so two never overlap.
    private var lastJob: Task<Void, Never>?

    init(repository: PantryRepository,
         settingsStore: SettingsStore,
         scheduler: NotificationScheduling,
         dateProvider: DateProviding,
         planner: ReminderPlanner = ReminderPlanner(),
         calendar: Calendar = .current) {
        self.repository = repository
        self.settingsStore = settingsStore
        self.scheduler = scheduler
        self.dateProvider = dateProvider
        self.planner = planner
        self.calendar = calendar
    }

    func requestPermission() async -> NotificationPermission {
        permission = await scheduler.requestPermission()
        reschedule()
        return permission
    }

    func reschedule() {
        enqueue { await self.rescheduleNow() }
    }

    func syncWithSystem() {
        enqueue {
            await self.refreshPermission()
            await self.rescheduleNow()
        }
    }

    // MARK: The actual work (internal so tests can run it and wait for it)

    func refreshPermission() async {
        permission = await scheduler.currentPermission()
    }

    func rescheduleNow() async {
        // Without permission we schedule nothing (this also clears reminders if it was revoked).
        guard permission == .authorized,
              let items = try? repository.fetchAll() else {
            await scheduler.replaceAllReminders(with: [])
            return
        }
        let plan = planner.plan(items: items, settings: settingsStore.load(),
                                now: dateProvider.now, calendar: calendar)
        await scheduler.replaceAllReminders(with: plan)
    }

    /// Lines jobs up one after another.
    private func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = lastJob
        lastJob = Task {
            await previous?.value
            await work()
        }
    }
}
