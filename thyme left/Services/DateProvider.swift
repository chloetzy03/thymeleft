import Foundation

/// Answers "what is the date right now?".
/// (Translation: instead of every file asking the system clock directly, they ask this.
/// In tests we hand in a fake clock so "today" never changes under our feet.)
protocol DateProviding {
    var now: Date { get }
}

struct SystemDateProvider: DateProviding {
    var now: Date { Date() }
}
