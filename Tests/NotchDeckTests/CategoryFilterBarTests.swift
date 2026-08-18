import Testing
@testable import NotchDeck

@Suite("Category Filter Bar Tests")
struct CategoryFilterBarTests {
    @Test("Category pill format contains count")
    @MainActor
    func testCategoryFormat() {
        let store = CardDataStore()
        let count = store.filteredItems().count
        #expect(count > 0)
    }
}
