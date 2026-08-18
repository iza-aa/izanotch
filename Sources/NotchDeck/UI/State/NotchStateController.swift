import SwiftUI
import Combine

public enum NotchState: Equatable, Sendable {
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

@MainActor
public final class NotchStateController: ObservableObject {
    @Published public var currentState: NotchState = .collapsed
    @Published public var activeAIModel: String = "Antigravity"
    @Published public var commandPrompt: String = ""
    @Published public var pendingClarification: ClarificationItem?
    @Published public var systemStatusMessage: String?

    public init() {}

    public func transition(to newState: NotchState) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.currentState = newState
        }
    }

    public func setClarification(question: String, options: [String]?) {
        self.pendingClarification = ClarificationItem(question: question, options: options)
    }

    public func clearClarification() {
        self.pendingClarification = nil
    }
}
