import SwiftUI

@MainActor
public final class CardDataStore: ObservableObject {
    public static let shared = CardDataStore()

    @Published public var selectedCategory: CardCategory = .all
    @Published public var items: [CardItem] = []

    public init() {
        self.items = [
            CardItem(title: "struct ContentView: View", subtitle: "SwiftUI Root Component", category: .clipboard, badge: "Swift", timestamp: "2m ago"),
            CardItem(title: "Meeting Tim Backend", subtitle: "Jam 14:00 (10 menit sebelum)", category: .schedule, badge: "13:50", timestamp: "5m ago"),
            CardItem(title: "Antigravity Code Review", subtitle: "Generated unit tests for auth", category: .prompts, badge: "AI Done", timestamp: "12m ago"),
            CardItem(title: "Assets Staging", subtitle: "Drop screenshots or assets here", category: .dropzone, badge: "Drop Target", timestamp: "Ready")
        ]
    }

    public func filteredItems() -> [CardItem] {
        if selectedCategory == .all {
            return items
        }
        return items.filter { $0.category == selectedCategory }
    }

    public func addItem(_ item: CardItem) {
        items.insert(item, at: 0)
    }

    public func removeItem(id: String) {
        items.removeAll { $0.id == id }
    }

    public func addClipboardItem(text: String) {
        let analysis = ClipboardManager.analyze(text: text)
        let newItem = CardItem(
            title: analysis.cardBadge,
            subtitle: analysis.maskedPreview,
            category: .clipboard,
            badge: analysis.hasSecret ? "Secret" : "Copied",
            timestamp: "Just now"
        )
        items.insert(newItem, at: 0)
    }
}
