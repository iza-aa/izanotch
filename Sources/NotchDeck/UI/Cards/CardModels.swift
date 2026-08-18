import Foundation

public enum CardCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case clipboard = "Clipboard"
    case prompts = "Prompts"
    case schedule = "Schedule"
    case dropzone = "Dropzone"

    public var id: String { rawValue }
}

public struct CardItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let category: CardCategory
    public let badge: String
    public let timestamp: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String,
        category: CardCategory,
        badge: String,
        timestamp: String = "Just now"
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.badge = badge
        self.timestamp = timestamp
    }
}
