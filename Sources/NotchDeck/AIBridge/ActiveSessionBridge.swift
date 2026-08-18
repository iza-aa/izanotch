import Foundation

public enum ActiveSessionError: Error, LocalizedError, Sendable {
    case sessionNotRunning
    case writeFailed(String)
    case executionFailed(Int32)
    case sessionDirectoryNotFound

    public var errorDescription: String? {
        switch self {
        case .sessionNotRunning:
            return "No active interactive AI session is currently running."
        case .writeFailed(let msg):
            return "Failed to write input to active session: \(msg)"
        case .executionFailed(let code):
            return "Interactive session exited with error code \(code)."
        case .sessionDirectoryNotFound:
            return "Active session directory could not be located."
        }
    }
}

public actor ActiveSessionBridge {
    public static let shared = ActiveSessionBridge()

    private var activeSubprocess = AISubprocessBridge()
    private var isSessionRunning = false

    public var isInteractiveSessionActive: Bool {
        isSessionRunning
    }

    public init() {}

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
            try activeSubprocess.sendInput(prompt + "\n")
        }
    }

    public func sendClarificationResponse(
        _ response: String,
        sessionDirectory: URL? = nil
    ) async throws {
        var dispatched = false

        // 1. Write to interactive subprocess stdin (without closing the pipe!)
        if isSessionRunning {
            do {
                try activeSubprocess.sendInput(response + "\n")
                dispatched = true
            } catch {
                throw ActiveSessionError.writeFailed("Subprocess stdin error: \(error.localizedDescription)")
            }
        }

        // 2. Write to session transcript log (if session directory is provided)
        if let sessionDir = sessionDirectory {
            let logFile = sessionDir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            if FileManager.default.fileExists(atPath: logFile.path) {
                guard let handle = try? FileHandle(forWritingTo: logFile) else {
                    throw ActiveSessionError.writeFailed("Cannot open transcript file for writing.")
                }

                let eventDict: [String: Any] = [
                    "step_index": Int(Date().timeIntervalSince1970),
                    "source": "USER_EXPLICIT",
                    "type": "USER_INPUT",
                    "status": "DONE",
                    "content": response
                ]

                guard let jsonData = try? JSONSerialization.data(withJSONObject: eventDict, options: []),
                      var jsonString = String(data: jsonData, encoding: .utf8) else {
                    try? handle.close()
                    throw ActiveSessionError.writeFailed("Failed to encode user input event JSON.")
                }

                jsonString += "\n"
                guard let lineData = jsonString.data(using: .utf8) else {
                    try? handle.close()
                    throw ActiveSessionError.writeFailed("Failed to convert JSON to UTF-8 data.")
                }

                _ = try? handle.seekToEnd()
                try handle.write(contentsOf: lineData)
                try? handle.close()
                dispatched = true
            }
        }

        if !dispatched && !isSessionRunning && sessionDirectory == nil {
            throw ActiveSessionError.sessionNotRunning
        }
    }

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
