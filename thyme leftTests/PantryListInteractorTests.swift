import XCTest
@testable import thyme_left

/// A clock that always says the same moment. (Translation: "today" never changes in tests.)
struct FixedDateProvider: DateProviding {
    let now: Date
}

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
    private func makeSUT(items: [PantryItem]) -> (sut: PantryListInteractor, output: InteractorOutputSpy) {
        let sut = PantryListInteractor(repository: InMemoryPantryRepository(items: items),
                                       policy: ExpiryPolicy(urgentDays: 1, soonDays: 5),
                                       dateProvider: FixedDateProvider(now: today),
                                       calendar: calendar)
        let output = InteractorOutputSpy()
        sut.output = output
        return (sut, output)
    }

    // MARK: Tests

    func test_loadItems_withMixedDates_sortsSoonestFirstWithExpiredOnTop() async {
        // Arrange
        let (sut, output) = makeSUT(items: [
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
        let (sut, output) = makeSUT(items: [
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
        let (sut, output) = makeSUT(items: [
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
        let (sut, output) = makeSUT(items: [makeItem("Avocado", daysFromToday: 1)])

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
        let (sut, output) = makeSUT(items: [milk])

        // Act
        sut.deleteItem(id: milk.id)
        sut.loadItems(in: nil)

        // Assert
        XCTAssertEqual(output.deleteCount, 1)
        XCTAssertTrue(output.loaded.isEmpty)
    }
}
