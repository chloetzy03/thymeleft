import Foundation

/// The chef of the Scanner screen: turns text lines into a date.
@MainActor
final class ScannerInteractor: ScannerInteractorInput {

    weak var output: ScannerInteractorOutput?

    /// A live camera flickers, so a date must be seen this many times in a row before we trust it.
    static let sightingsNeeded = 2

    private let parser: ExpiryDateParser
    private let recognizer: TextRecognizing
    private let settingsStore: SettingsStore
    private let dateProvider: DateProviding
    private let locale: Locale

    private var lastSeenDate: Date?
    private var sightings = 0
    private var hasReported = false

    init(parser: ExpiryDateParser = ExpiryDateParser(),
         recognizer: TextRecognizing,
         settingsStore: SettingsStore,
         dateProvider: DateProviding,
         locale: Locale = .current) {
        self.parser = parser
        self.recognizer = recognizer
        self.settingsStore = settingsStore
        self.dateProvider = dateProvider
        self.locale = locale
    }

    func considerLiveLines(_ lines: [String]) {
        guard !hasReported, let found = parse(lines) else { return }

        if found.date == lastSeenDate { sightings += 1 } else { lastSeenDate = found.date; sightings = 1 }
        guard sightings >= Self.sightingsNeeded else { return }

        hasReported = true // stop reporting until the user taps Retry
        output?.didFind(found)
    }

    func readImage(_ data: Data) {
        Task {
            let lines = (try? await recognizer.recognizeLines(in: data)) ?? []
            if let found = parse(lines) {
                hasReported = true
                output?.didFind(found)
            } else {
                output?.didFindNothing()
            }
        }
    }

    func resetLiveReading() {
        lastSeenDate = nil
        sightings = 0
        hasReported = false
    }

    private func parse(_ lines: [String]) -> ScannedExpiryDate? {
        let dayFirst = settingsStore.load().dateFormat.isDayFirst(locale: locale)
        return parser.parse(lines: lines, dayFirst: dayFirst, now: dateProvider.now)
    }
}
