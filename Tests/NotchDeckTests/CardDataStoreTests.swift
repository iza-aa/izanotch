import Testing
@testable import NotchDeck

@Suite("Card Data Store Tests")
struct CardDataStoreTests {
    @Test("Filter cards by selected category")
    @MainActor
    func testFilterByCategory() {
        let store = CardDataStore()
        store.items = [
            CardItem(id: "1", title: "Code Snippet", subtitle: "SwiftUI View", category: .clipboard, badge: "Swift"),
            CardItem(id: "2", title: "Meeting Sync", subtitle: "Jam 14:00", category: .schedule, badge: "10m"),
            CardItem(id: "3", title: "Antigravity Refactor", subtitle: "Optimized function", category: .prompts, badge: "AI")
        ]

        store.selectedCategory = .all
        #expect(store.filteredItems().count == 3)

        store.selectedCategory = .clipboard
        #expect(store.filteredItems().count == 1)
        #expect(store.filteredItems().first?.title == "Code Snippet")
    }
}
