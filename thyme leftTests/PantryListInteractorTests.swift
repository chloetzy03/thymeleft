import XCTest
@testable import thyme_left

/// Writes down what the Interactor reported. (Translation: a pretend Presenter.)
@MainActor
final class InteractorOutputSpy: PantryListInteractorOutput {
    var loaded: [ExpiringItem] = []
    var deleteCount = 0
    var failureCount = 0

    func didLoad(_ items: [ExpiringItem]) { loaded = items }
    func didDeleteItem() { deleteCount += 1 }
    func didFail(_ error: Error) { failureCount += 1 }
}

@MainActor
final class PantryListInteractorTests: XCTestCase {

    // MARK: Helpers

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 9))!
    }

    private func makeItem(_ name: String, in place: StorageLocation = .fridge, daysFromToday: Int) -> PantryItem {
        let expiry = calendar.date(byAdding: .day, value: daysFromToday, to: today)!
        return PantryItem(name: name, location: place, expiryDate: expiry)
    }

    /// Builds the Interactor under test, plus its pretend neighbours.
    private func makeSUT(items: [PantryItem], settings: AppSettings = AppSettings(),
                         photoStore: InMemoryPhotoStore? = nil,
                         outcomes: InMemoryOutcomeRepository? = nil)
        -> (sut: PantryListInteractor, output: InteractorOutputSpy, reminders: ReminderServiceSpy) {
        let reminders = ReminderServiceSpy()
        let sut = PantryListInteractor(repository: InMemoryPantryRepository(items: items),
                                       settingsStore: InMemorySettingsStore(settings: settings),
                                       dateProvider: FixedDateProvider(now: today),
                                       reminders: reminders,
                                       photoStore: photoStore ?? InMemoryPhotoStore(),
                                       outcomes: outcomes ?? InMemoryOutcomeRepository(),
                                       calendar: calendar)
        let output = InteractorOutputSpy()
        sut.output = output
        return (sut, output, reminders)
    }

    // MARK: Tests

    func test_loadItems_withMixedDates_sortsSoonestFirstWithExpiredOnTop() async {
        // Arrange
        let (sut, output, _) = makeSUT(items: [
            makeItem("Pasta", daysFromToday: 120),
            makeItem("Milk", daysFromToday: 3),
            makeItem("Yoghurt", daysFromToday: -1)
        ])

        // Act
        sut.loadItems(in: nil)

        // Assert
        XCTAssertEqual(output.loaded.map(\.item.name), ["Yoghurt", "Milk", "Pasta"])
    }

    func test_loadItems_withSameExpiryDay_sortsAlphabetically() async {
        // Arrange
        let (sut, output, _) = makeSUT(items: [
            makeItem("Tomatoes", daysFromToday: 2),
            makeItem("apples", daysFromToday: 2)
        ])

        // Act
        sut.loadItems(in: nil)

        // Assert
        XCTAssertEqual(output.loaded.map(\.item.name), ["apples", "Tomatoes"])
    }

    func test_loadItems_withLocationFilter_returnsOnlyThatLocation() async {
        // Arrange
        let (sut, output, _) = makeSUT(items: [
            makeItem("Milk", in: .fridge, daysFromToday: 3),
            makeItem("Peas", in: .freezer, daysFromToday: 90)
        ])

        // Act
        sut.loadItems(in: .freezer)

        // Assert
        XCTAssertEqual(output.loaded.map(\.item.name), ["Peas"])
    }

    func test_loadItems_attachesCountdownAndStatus() async throws {
        // Arrange
        let (sut, output, _) = makeSUT(items: [makeItem("Avocado", daysFromToday: 1)])

        // Act
        sut.loadItems(in: nil)

        // Assert
        let entry = try XCTUnwrap(output.loaded.first)
        XCTAssertEqual(entry.daysRemaining, 1)
        XCTAssertEqual(entry.status, .urgent)
    }

    func test_deleteItem_removesItAndTellsOutput() async {
        // Arrange
        let milk = makeItem("Milk", daysFromToday: 3)
        let (sut, output, _) = makeSUT(items: [milk])

        // Act
        sut.finishItem(id: milk.id, as: .removed)
        sut.loadItems(in: nil)

        // Assert
        XCTAssertEqual(output.deleteCount, 1)
        XCTAssertTrue(output.loaded.isEmpty)
    }

    func test_deleteItem_alsoDeletesItsPhotoFile() async throws {
        // Arrange
        let photos = InMemoryPhotoStore()
        let name = try photos.savePhoto(Data([1, 2, 3]))
        let withPhoto = PantryItem(name: "Milk", location: .fridge, expiryDate: today, photoFileName: name)
        let (sut, _, _) = makeSUT(items: [withPhoto], photoStore: photos)

        // Act
        sut.finishItem(id: withPhoto.id, as: .removed)

        // Assert
        XCTAssertTrue(photos.photos.isEmpty)
    }

    func test_deleteItem_replansReminders() async {
        // Arrange
        let milk = makeItem("Milk", daysFromToday: 3)
        let (sut, _, reminders) = makeSUT(items: [milk])

        // Act
        sut.finishItem(id: milk.id, as: .removed)

        // Assert
        XCTAssertEqual(reminders.rescheduleCount, 1)
    }

    func test_loadItems_usesTheThresholdsFromSettings() async throws {
        // Arrange: the user made "red" last 3 days instead of 1
        var settings = AppSettings()
        settings.urgentDays = 3
        let (sut, output, _) = makeSUT(items: [makeItem("Milk", daysFromToday: 3)], settings: settings)

        // Act
        sut.loadItems(in: nil)

        // Assert
        XCTAssertEqual(try XCTUnwrap(output.loaded.first).status, .urgent)
    }

    // MARK: Outcomes (used / threw away / delete)

    func test_finishItem_used_recordsHistoryAndRemovesTheItem() async throws {
        // Arrange
        let milk = makeItem("Milk", daysFromToday: 2)
        let history = InMemoryOutcomeRepository()
        let (sut, output, _) = makeSUT(items: [milk], outcomes: history)

        // Act
        sut.finishItem(id: milk.id, as: .used)
        sut.loadItems(in: nil)

        // Assert
        let entry = try XCTUnwrap(try history.fetchAll().first)
        XCTAssertEqual(entry.itemName, "Milk")
        XCTAssertEqual(entry.outcome, .used)
        XCTAssertEqual(entry.date, today)
        XCTAssertTrue(output.loaded.isEmpty)
    }

    func test_finishItem_used_rememberstheItemsPrice() async throws {
        // Arrange
        let steak = PantryItem(name: "Steak", location: .fridge, expiryDate: today, price: 12)
        let history = InMemoryOutcomeRepository()
        let (sut, _, _) = makeSUT(items: [steak], outcomes: history)

        // Act
        sut.finishItem(id: steak.id, as: .used)

        // Assert
        XCTAssertEqual(try history.fetchAll().first?.value, 12)
    }

    func test_finishItem_threwAway_recordsItAsWasted() async throws {
        // Arrange
        let milk = makeItem("Milk", daysFromToday: -1)
        let history = InMemoryOutcomeRepository()
        let (sut, _, _) = makeSUT(items: [milk], outcomes: history)

        // Act
        sut.finishItem(id: milk.id, as: .wasted)

        // Assert
        XCTAssertEqual(try history.fetchAll().map(\.outcome), [.wasted])
    }

    func test_finishItem_plainDelete_recordsNothing() async throws {
        // Arrange
        let milk = makeItem("Milk", daysFromToday: 2)
        let history = InMemoryOutcomeRepository()
        let (sut, output, _) = makeSUT(items: [milk], outcomes: history)

        // Act
        sut.finishItem(id: milk.id, as: .removed)

        // Assert
        XCTAssertTrue(try history.fetchAll().isEmpty)
        XCTAssertEqual(output.deleteCount, 1)
    }

    func test_finishItem_whenHistoryCannotBeSaved_keepsTheItem() async throws {
        // Arrange
        let milk = makeItem("Milk", daysFromToday: 2)
        let history = InMemoryOutcomeRepository()
        history.shouldFailToRecord = true
        let (sut, output, _) = makeSUT(items: [milk], outcomes: history)

        // Act
        sut.finishItem(id: milk.id, as: .used)
        sut.loadItems(in: nil)

        // Assert: nothing vanishes without a record
        XCTAssertEqual(output.failureCount, 1)
        XCTAssertEqual(output.loaded.map(\.item.name), ["Milk"])
    }
}
