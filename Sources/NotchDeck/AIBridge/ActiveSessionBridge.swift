import Foundation

public actor ActiveSessionBridge {
    public static let shared = ActiveSessionBridge()

    private var activeSubprocess = AISubprocessBridge()
    private var isSessionRunning = false

    public init() {}

    public func sendClarificationResponse(
        _ response: String,
        sessionDirectory: URL? = nil
    ) async throws {
        // 1. If an interactive subprocess is running, write directly to standardInput
        if isSessionRunning {
            try? activeSubprocess.sendInput(response + "\n")
        }

        // 2. If a session directory is provided, write properly escaped JSONL entry
        if let sessionDir = sessionDirectory {
            let logFile = sessionDir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            if FileManager.default.fileExists(atPath: logFile.path),
               let handle = try? FileHandle(forWritingTo: logFile) {
                let eventDict: [String: Any] = [
                    "step_index": Int(Date().timeIntervalSince1970),
                    "source": "USER_EXPLICIT",
                    "type": "USER_INPUT",
                    "status": "DONE",
                    "content": response
                ]

                if let jsonData = try? JSONSerialization.data(withJSONObject: eventDict, options: []),
                   var jsonString = String(data: jsonData, encoding: .utf8) {
                    jsonString += "\n"
                    if let lineData = jsonString.data(using: .utf8) {
                        _ = try? handle.seekToEnd()
                        try? handle.write(contentsOf: lineData)
                        try? handle.close()
                    }
                }
            }
        }
    }

    public func dispatchPromptInteractive(
        executable: String,
        arguments: [String],
        initialPrompt: String,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        isSessionRunning = true
        defer { isSessionRunning = false }

        try activeSubprocess.startInteractive(
            executable: executable,
            arguments: arguments,
            onOutput: onOutput
        )

        try activeSubprocess.sendInput(initialPrompt + "\n")
        activeSubprocess.closeInput()

        let exitCode = try await activeSubprocess.waitForExit()
        guard exitCode == 0 else {
            throw AIClientError.httpError(statusCode: Int(exitCode), message: "Subprocess execution failed with exit code \(exitCode)")
        }
        return exitCode
    }
}
