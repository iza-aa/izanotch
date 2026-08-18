import Foundation

/// Bridge to Antigravity 2.0's agentapi CLI.
/// Allows NotchDeck to send messages directly into an active Antigravity conversation
/// using the official `agentapi send-message <conversation_id> <content>` interface.
public actor AntigravityAgentAPI {
    public static let shared = AntigravityAgentAPI()

    private let agentAPIPath = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".gemini/antigravity/bin/agentapi")

    private var _currentConversationID: String?

    public init() {}

    // MARK: - Conversation ID

    /// Update the active conversation ID whenever the watcher detects a new session.
    /// The conversation ID is the last path component of the session directory (UUID string).
    public func setActiveConversation(sessionDirectory: URL) {
        _currentConversationID = sessionDirectory.lastPathComponent
    }

    public var currentConversationID: String? {
        _currentConversationID
    }

    // MARK: - Send Message

    public enum AgentAPIError: Error, LocalizedError {
        case noBinaryFound
        case noActiveConversation
        case executionFailed(Int32, String)

        public var errorDescription: String? {
            switch self {
            case .noBinaryFound:
                return "agentapi binary not found at ~/.gemini/antigravity/bin/agentapi"
            case .noActiveConversation:
                return "No active Antigravity conversation detected."
            case .executionFailed(let code, let output):
                return "agentapi exited with code \(code): \(output)"
            }
        }
    }

    /// Send a message to the currently active Antigravity 2.0 conversation.
    /// Uses the official `agentapi send-message <conversation_id> <content>` command.
    public func sendMessage(_ text: String, conversationID: String? = nil) async throws {
        guard FileManager.default.isExecutableFile(atPath: agentAPIPath.path) else {
            throw AgentAPIError.noBinaryFound
        }

        let targetID = conversationID ?? _currentConversationID
        guard let cid = targetID, !cid.isEmpty else {
            throw AgentAPIError.noActiveConversation
        }

        let process = Process()
        process.executableURL = agentAPIPath
        process.arguments = ["send-message", cid, text]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw AgentAPIError.executionFailed(process.terminationStatus, output)
        }
    }
}
