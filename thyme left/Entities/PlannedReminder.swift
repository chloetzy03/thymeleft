import Foundation

/// A reminder we've decided to send, and when.
struct PlannedReminder: Equatable {
    /// One per pantry item, so a changed item replaces its old reminder instead of adding a second.
    let id: String
    let fireDate: Date
    let title: String
    let body: String
}

/// Whether the user let us send notifications.
enum NotificationPermission: Equatable {
    case notDetermined // never asked yet
    case denied
    case authorized
}
