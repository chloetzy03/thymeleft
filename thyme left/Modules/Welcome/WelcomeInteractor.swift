import Foundation

/// The chef of the Welcome tour: remembers it was seen, and can ask about reminders.
@MainActor
final class WelcomeInteractor: WelcomeInteractorInput {

    weak var output: WelcomeInteractorOutput?

    private let store: WelcomeStore
    private let reminders: ReminderServicing

    init(store: WelcomeStore, reminders: ReminderServicing) {
        self.store = store
        self.reminders = reminders
    }

    func finish(askForReminders: Bool) {
        // Remember first, so even if the app is closed during the iOS question, the tour won't come back.
        store.markWelcomeSeen()
        guard askForReminders else {
            output?.didFinish()
            return
        }
        Task {
            // iOS shows its own pop-up here. Whatever the answer, we carry on.
            _ = await reminders.requestPermission()
            reminders.reschedule()
            output?.didFinish()
        }
    }
}
