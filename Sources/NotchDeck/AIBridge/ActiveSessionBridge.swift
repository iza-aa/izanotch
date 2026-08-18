import Foundation

public enum ActiveSessionError: Error, LocalizedError, Sendable {
    case sessionNotRunning
    case writeFailed(String)
    case executionFailed(Int32)
    case sessionDirectoryNotFound

    public var errorDescription: String? {
        switch self {
        case .sessionNotRunning:
            return "No active Antigravity session is running. Start the agent first."
        case .writeFailed(let msg):
            return "Failed to deliver input to active session: \(msg)"
        case .executionFailed(let code):
            return "Interactive session exited with error code \(code)."
        case .sessionDirectoryNotFound:
            return "Active session directory or transcript could not be located."
        }
    }
}

/// Delivery result for a `sendInput()` call.
/// Callers must inspect this and NOT treat `.unconfirmed` as success.
public enum DispatchResult: Sendable {
    /// Input was written to the subprocess stdin pipe.
    /// Note: this does NOT confirm the agent consumed or processed the message.
    case sent
    /// No interactive session is running. Input was NOT delivered anywhere.
    case noSession
}

public actor ActiveSessionBridge {
    public static let shared = ActiveSessionBridge()

    private var activeSubprocess = AISubprocessBridge()
    private var isSessionRunning = false

    public var isInteractiveSessionActive: Bool {
        isSessionRunning
    }

    public init() {}

    // MARK: - Subprocess Lifecycle

    public func startInteractiveSession(
        executable: String,
        arguments: [String],
        initialPrompt: String? = nil,
        onOutput: @escaping @Sendable (String) -> Void
    ) throws {
        if isSessionRunning {
            terminateInteractiveSession()
        }

        try activeSubprocess.startInteractive(
            executable: executable,
            arguments: arguments,
            onOutput: onOutput
        )
        isSessionRunning = true

        if let prompt = initialPrompt, !prompt.isEmpty {
            do {
                try activeSubprocess.sendInput(prompt + "\n")
            } catch {
                isSessionRunning = false
                activeSubprocess.terminate()
                throw ActiveSessionError.writeFailed("Failed to send initial prompt to stdin: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Input Dispatch (Subprocess stdin only)

    /// Sends text to the active subprocess stdin.
    ///
    /// Returns `.sent` if the write to the stdin pipe succeeded.
    /// Returns `.noSession` if no subprocess is running — the caller MUST surface this as an error.
    ///
    /// IMPORTANT: `.sent` means the pipe write succeeded, NOT that the agent received or processed
    /// the message. Do not report delivery as confirmed based on this result alone.
    public func sendInput(_ text: String) async throws -> DispatchResult {
        guard isSessionRunning else {
            return .noSession
        }

        do {
            try activeSubprocess.sendInput(text + "\n")
            return .sent
        } catch {
            throw ActiveSessionError.writeFailed("Subprocess stdin write failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Legacy compatibility (session clarification path)

    /// Delivers a clarification response to the active subprocess only.
    ///
    /// - Throws `ActiveSessionError.sessionNotRunning` if no subprocess is active.
    /// - Does NOT write to transcript.jsonl — transcript is an output/history stream,
    ///   not an input channel. Writing to it does not deliver input to the agent.
    public func sendClarificationResponse(
        _ response: String,
        sessionDirectory: URL? = nil
    ) async throws {
        // Validate session directory if provided (for informational purposes only — not for writing)
        if let sessionDir = sessionDirectory {
            guard FileManager.default.fileExists(atPath: sessionDir.path) else {
                throw ActiveSessionError.sessionDirectoryNotFound
            }
        }

        guard isSessionRunning else {
            throw ActiveSessionError.sessionNotRunning
        }

        do {
            try activeSubprocess.sendInput(response + "\n")
        } catch {
            throw ActiveSessionError.writeFailed("Subprocess stdin error: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Control

    public func closeInteractiveInput() {
        if isSessionRunning {
            activeSubprocess.closeInput()
        }
    }

    public func waitForInteractiveSessionExit() async throws -> Int32 {
        guard isSessionRunning else { return 0 }
        defer { isSessionRunning = false }
        let exitCode = try await activeSubprocess.waitForExit()
        guard exitCode == 0 else {
            throw ActiveSessionError.executionFailed(exitCode)
        }
        return exitCode
    }

    public func terminateInteractiveSession() {
        if isSessionRunning {
            activeSubprocess.terminate()
            isSessionRunning = false
        }
    }
}
