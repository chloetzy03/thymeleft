import Testing
import Foundation
@testable import thyme_left

/// A clock that always says the same moment. (Translation: "today" never changes in tests.)
struct FixedDateProvider: DateProviding {
    let now: Date
}

@MainActor
struct PantryListInteractorTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    private var today: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 9))! }

    private func item(_ name: String, in place: StorageLocation = .fridge, daysFromToday: Int) -> PantryItem {
        let date = calendar.date(byAdding: .day, value: daysFromToday, to: today)!
        return PantryItem(name: name, location: place, expiryDate: date)
    }

    private func makeSUT(items: [PantryItem]) -> (PantryListInteractor, OutputSpy) {
        let repository = InMemoryPantryRepository(items: items)
        let sut = PantryListInteractor(repository: repository,
                                       policy: ExpiryPolicy(urgentDays: 1, soonDays: 5),
                                       dateProvider: FixedDateProvider(now: today),
                                       calendar: calendar)
        let spy = OutputSpy()
        sut.output = spy
        return (sut, spy)
    }

    @Test func sortsSoonestFirstWithExpiredOnTop() {
        let (sut, spy) = makeSUT(items: [
            item("Pasta", daysFromToday: 120),
            item("Milk", daysFromToday: 3),
            item("Yoghurt", daysFromToday: -1)
        ])
        sut.loadItems(in: nil)
        #expect(spy.loaded.map(\.item.name) == ["Yoghurt", "Milk", "Pasta"])
    }

    @Test func tiesAreSortedAlphabetically() {
        let (sut, spy) = makeSUT(items: [
            item("Tomatoes", daysFromToday: 2),
            item("apples", daysFromToday: 2)
        ])
        sut.loadItems(in: nil)
        #expect(spy.loaded.map(\.item.name) == ["apples", "Tomatoes"])
    }

    @Test func filtersByLocation() {
        let (sut, spy) = makeSUT(items: [
            item("Milk", in: .fridge, daysFromToday: 3),
            item("Peas", in: .freezer, daysFromToday: 90)
        ])
        sut.loadItems(in: .freezer)
        #expect(spy.loaded.map(\.item.name) == ["Peas"])
    }

    @Test func attachesCountdownAndStatus() throws {
        let (sut, spy) = makeSUT(items: [item("Avocado", daysFromToday: 1)])
        sut.loadItems(in: nil)
        let entry = try #require(spy.loaded.first)
        #expect(entry.daysRemaining == 1)
        #expect(entry.status == .urgent)
    }

    @Test func deleteRemovesItemAndTellsOutput() {
        let milk = item("Milk", daysFromToday: 3)
        let (sut, spy) = makeSUT(items: [milk])
        sut.deleteItem(id: milk.id)
        #expect(spy.deleteCount == 1)
        sut.loadItems(in: nil)
        #expect(spy.loaded.isEmpty)
    }
}

/// Records what the Interactor reported. (Translation: a pretend Presenter that just writes things down.)
@MainActor
final class OutputSpy: PantryListInteractorOutput {
    var loaded: [ExpiringItem] = []
    var deleteCount = 0
    var failureCount = 0

    func didLoad(_ items: [ExpiringItem]) { loaded = items }
    func didDeleteItem() { deleteCount += 1 }
    func didFail(_ error: Error) { failureCount += 1 }
}
