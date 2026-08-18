import SwiftUI
import Combine

public enum NotchFeatureTab: String, CaseIterable, Identifiable, Sendable {
    case aiChat = "AI Chat"
    case notes = "Notes"
    case schedule = "Schedule"
    case music = "Music"
    case clipboard = "Clipboard"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .aiChat: return "bubble.left.and.bubble.right.fill"
        case .notes: return "note.text"
        case .schedule: return "calendar"
        case .music: return "music.note"
        case .clipboard: return "doc.on.clipboard"
        }
    }
}

public enum NotchState: Equatable, Sendable {
    case hidden
    case collapsed
    case voiceActive
    case liveActivity(title: String, countdown: String)
    case expanded
}

public struct ClarificationItem: Equatable, Sendable {
    public let question: String
    public let options: [String]?

    public init(question: String, options: [String]? = nil) {
        self.question = question
        self.options = options
    }
}

public struct ChatMessageItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let sender: String
    public let text: String
    public let isUser: Bool
    public let timestamp: String

    public init(
        id: String = UUID().uuidString,
        sender: String,
        text: String,
        isUser: Bool,
        timestamp: String = "Just now"
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

@MainActor
public final class NotchStateController: ObservableObject {
    @Published public var currentState: NotchState = .collapsed
    @Published public var activeTab: NotchFeatureTab = .aiChat
    @Published public var activeAIModel: String = "Antigravity"
    @Published public var commandPrompt: String = ""
    @Published public var pendingClarification: ClarificationItem?
    @Published public var systemStatusMessage: String?
    @Published public var chatMessages: [ChatMessageItem] = []

    public init() {}

    public func transition(to newState: NotchState) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.currentState = newState
        }
    }

    public func selectTab(_ tab: NotchFeatureTab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.activeTab = tab
        }
    }

    public func appendChatMessage(sender: String, text: String, isUser: Bool) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: Date())
        let item = ChatMessageItem(sender: sender, text: text, isUser: isUser, timestamp: timeStr)
        self.chatMessages.append(item)
    }

    public func setClarification(question: String, options: [String]?) {
        self.pendingClarification = ClarificationItem(question: question, options: options)
    }

    public func clearClarification() {
        self.pendingClarification = nil
    }
}
