import SwiftUI

public enum NotchState: Equatable, Sendable {
    case collapsed
    case voiceActive
    case liveActivity(title: String, countdown: String)
    case expanded
}

@MainActor
public final class NotchStateController: ObservableObject {
    @Published public var currentState: NotchState = .collapsed
    @Published public var activeAIModel: String = "Antigravity"
    @Published public var commandPrompt: String = ""

    public init() {}

    public func transition(to newState: NotchState) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.currentState = newState
        }
    }
}
