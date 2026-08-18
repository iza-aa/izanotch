import SwiftUI

@MainActor
public final class CardDataStore: ObservableObject {
    public static let shared = CardDataStore()

    @Published public var selectedCategory: CardCategory = .all
    @Published public var items: [CardItem] = []

    public init() {
        self.items = []
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
