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

public struct ProviderStatus: Identifiable, Equatable, Sendable {
    public let id: String
    public let status: String
    public let isActive: Bool

    public init(id: String, status: String, isActive: Bool) {
        self.id = id
        self.status = status
        self.isActive = isActive
    }

    public var compactLabel: String {
        "\(id) \(status)"
    }

    public var iconName: String {
        switch id {
        case "Codex": return "cpu.fill"
        case "Antigravity": return "sparkles"
        case "Claude Code": return "terminal.fill"
        default: return "circle.dashed"
        }
    }

    public var iconResourceName: String? {
        switch id {
        case "Codex": return "codex"
        case "Antigravity": return "antigravity"
        case "Claude Code": return "white-claude-logo_svgstack_com_36961787112891"
        default: return nil
        }
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
    @Published public private(set) var liveActivityModel: String?
    @Published public private(set) var providerStatuses: [String: ProviderStatus] = [:]
    private var lastKnownProviderID: String?

    /// Every provider gets its own transcript. `chatMessages` is only the
    /// transcript for the currently selected provider so a provider switch
    /// can never leak messages into another application's conversation.
    private var conversationMessages: [String: [ChatMessageItem]] = [:]
    private var conversationClarifications: [String: ClarificationItem] = [:]

    public init() {}

    public func transition(to newState: NotchState) {
        guard currentState != newState else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.currentState = newState
            self.liveActivityModel = nil
        }
    }

    public func showLiveActivity(title: String, countdown: String, for modelID: String? = nil) {
        if let modelID {
            setProviderStatus(
                modelID,
                status: inferredProviderStatus(title: title, countdown: countdown).status,
                isActive: inferredProviderStatus(title: title, countdown: countdown).isActive
            )
        }
        transition(to: .liveActivity(title: title, countdown: countdown))
        liveActivityModel = modelID
    }

    public func setProviderStatus(_ modelID: String, status: String, isActive: Bool) {
        lastKnownProviderID = modelID
        providerStatuses[modelID] = ProviderStatus(
            id: modelID,
            status: status,
            isActive: isActive
        )
    }

    /// Active providers rotate in the compact notch. When nothing is running,
    /// only the currently selected provider is shown with its ready state.
    public var compactProviderStatuses: [ProviderStatus] {
        let order = ["Codex", "Antigravity", "Claude Code"]
        let active = order.compactMap { providerStatuses[$0] }.filter(\.isActive)
        if !active.isEmpty {
            return active
        }

        let fallbackID = lastKnownProviderID ?? activeAIModel
        let selected = providerStatuses[fallbackID]
            ?? ProviderStatus(id: fallbackID, status: "Ready", isActive: false)
        return [selected]
    }

    public func openLiveActivity() {
        if let liveActivityModel {
            selectAIModel(liveActivityModel)
        }
        transition(to: .expanded)
    }

    public func selectTab(_ tab: NotchFeatureTab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.activeTab = tab
        }
    }

    public func selectAIModel(_ modelID: String) {
        lastKnownProviderID = modelID
        guard modelID != activeAIModel else { return }

        conversationMessages[activeAIModel] = chatMessages
        activeAIModel = modelID
        chatMessages = conversationMessages[modelID] ?? []
        pendingClarification = conversationClarifications[modelID]
        commandPrompt = ""
    }

    public func appendChatMessage(sender: String, text: String, isUser: Bool) {
        appendChatMessage(sender: sender, text: text, isUser: isUser, for: activeAIModel)
    }

    public func appendChatMessage(
        sender: String,
        text: String,
        isUser: Bool,
        for modelID: String
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: Date())
        let item = ChatMessageItem(sender: sender, text: text, isUser: isUser, timestamp: timeStr)
        if conversationMessages[modelID]?.last?.sender == sender,
           conversationMessages[modelID]?.last?.text == text,
           conversationMessages[modelID]?.last?.isUser == isUser {
            return
        }
        conversationMessages[modelID, default: []].append(item)
        if modelID == activeAIModel {
            chatMessages.append(item)
        }
    }

    public func replaceChatMessages(_ messages: [ChatMessageItem], for modelID: String) {
        conversationMessages[modelID] = messages
        if modelID == activeAIModel {
            chatMessages = messages
        }
    }

    public func setClarification(question: String, options: [String]?) {
        setClarification(question: question, options: options, for: activeAIModel)
    }

    public func setClarification(question: String, options: [String]?, for modelID: String) {
        let item = ClarificationItem(question: question, options: options)
        conversationClarifications[modelID] = item
        if modelID == activeAIModel {
            pendingClarification = item
        }
    }

    public func clearClarification() {
        clearClarification(for: activeAIModel)
    }

    public func clearClarification(for modelID: String) {
        conversationClarifications[modelID] = nil
        if modelID == activeAIModel {
            pendingClarification = nil
        }
    }

    private func inferredProviderStatus(title: String, countdown: String) -> (status: String, isActive: Bool) {
        let value = "\(title) \(countdown)".lowercased()
        if value.contains("error") || value.contains("failed") {
            return ("Error", false)
        }
        if value.contains("ready") || value.contains("done") || value.contains("complete") {
            return ("Ready", false)
        }
        if value.contains("waiting") || value.contains("question") || value.contains("clarif") {
            return ("Waiting", true)
        }
        return ("Working", true)
    }
}
