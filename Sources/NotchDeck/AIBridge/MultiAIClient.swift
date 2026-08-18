import Foundation

public enum AIProvider: String, CaseIterable, Identifiable, Sendable {
    case antigravity = "Antigravity"
    case claudeCode = "Claude Code"
    case gemini = "Gemini Flash"
    case codex = "Codex"

    public var id: String { rawValue }
}

public struct MultiAIResponse: Sendable {
    public let text: String
    public let provider: AIProvider
    public let executionTimeMs: Int
}

public final class MultiAIClient: @unchecked Sendable {
    public static let shared = MultiAIClient()
    private let urlSession: URLSession
    private let sessionBridge: ActiveSessionBridge

    public init(
        urlSession: URLSession = .shared,
        sessionBridge: ActiveSessionBridge = .shared
    ) {
        self.urlSession = urlSession
        self.sessionBridge = sessionBridge
    }

    // MARK: - Request Builders (Zero Shell Injection)

    public static func buildClaudeRequest(
        apiKey: String,
        prompt: String,
        model: String = "claude-3-5-sonnet-20241022",
        maxTokens: Int = 1024
    ) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    public static func buildGeminiRequest(
        apiKey: String,
        prompt: String,
        model: String = "gemini-2.5-flash"
    ) -> URLRequest {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    public static func buildOpenAIRequest(
        apiKey: String,
        prompt: String,
        model: String = "gpt-4o"
    ) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    public static func buildClaudeCLIArguments(prompt: String) -> [String] {
        return ["-p", prompt]
    }

    public static func buildCodexCLIArguments(prompt: String) -> [String] {
        return ["exec", prompt]
    }

    // MARK: - Safe Binary Locator (No Shell Interpolation)

    public static func findExecutable(named name: String) -> String? {
        let standardPaths = [
            "/usr/local/bin/" + name,
            "/opt/homebrew/bin/" + name,
            "/usr/bin/" + name,
            "/bin/" + name
        ]
        for path in standardPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    // MARK: - Prompt Execution Router

    public func prompt(
        text: String,
        provider: AIProvider,
        geminiApiKey: String? = nil,
        claudeApiKey: String? = nil,
        openAiApiKey: String? = nil,
        activeBrainSessionDir: URL? = nil
    ) async throws -> MultiAIResponse {
        let startTime = Date()

        switch provider {
        case .gemini:
            guard let key = geminiApiKey, !key.isEmpty else {
                throw AIClientError.missingAPIKey
            }
            let req = Self.buildGeminiRequest(apiKey: key, prompt: text)
            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 500
                throw AIClientError.httpError(statusCode: code, message: "Gemini HTTP error")
            }
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let candidates = json["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]]
            let responseText = parts?.first?["text"] as? String ?? "No response from Gemini"
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            return MultiAIResponse(text: responseText, provider: .gemini, executionTimeMs: duration)

        case .claudeCode:
            if let key = claudeApiKey, !key.isEmpty {
                let req = Self.buildClaudeRequest(apiKey: key, prompt: text)
                let (data, response) = try await urlSession.data(for: req)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 500
                    throw AIClientError.httpError(statusCode: code, message: "Claude HTTP error")
                }
                let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let contentBlocks = json["content"] as? [[String: Any]]
                let responseText = contentBlocks?.first?["text"] as? String ?? "No response from Claude"
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                return MultiAIResponse(text: responseText, provider: .claudeCode, executionTimeMs: duration)
            } else if let claudeBin = Self.findExecutable(named: "claude") {
                let acc = OutputAccumulator()
                try await sessionBridge.startInteractiveSession(
                    executable: claudeBin,
                    arguments: Self.buildClaudeCLIArguments(prompt: text),
                    initialPrompt: nil
                ) { chunk in
                    acc.append(chunk)
                }
                let exitCode = try await sessionBridge.waitForInteractiveSessionExit()
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                let cliOutput = acc.get()
                return MultiAIResponse(
                    text: cliOutput.isEmpty ? "Claude CLI execution complete (exit \(exitCode))." : cliOutput,
                    provider: .claudeCode,
                    executionTimeMs: duration
                )
            } else {
                throw AIClientError.missingAPIKey
            }

        case .codex:
            if let key = openAiApiKey, !key.isEmpty {
                let req = Self.buildOpenAIRequest(apiKey: key, prompt: text)
                let (data, response) = try await urlSession.data(for: req)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 500
                    throw AIClientError.httpError(statusCode: code, message: "OpenAI/Codex HTTP error")
                }
                let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let choices = json["choices"] as? [[String: Any]]
                let message = choices?.first?["message"] as? [String: Any]
                let responseText = message?["content"] as? String ?? "No response from Codex"
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                return MultiAIResponse(text: responseText, provider: .codex, executionTimeMs: duration)
            } else if let codexBin = Self.findExecutable(named: "codex") {
                let acc = OutputAccumulator()
                try await sessionBridge.startInteractiveSession(
                    executable: codexBin,
                    arguments: Self.buildCodexCLIArguments(prompt: text),
                    initialPrompt: nil
                ) { chunk in
                    acc.append(chunk)
                }
                let exitCode = try await sessionBridge.waitForInteractiveSessionExit()
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                return MultiAIResponse(
                    text: acc.get().isEmpty ? "Codex execution complete (exit \(exitCode))." : acc.get(),
                    provider: .codex,
                    executionTimeMs: duration
                )
            } else {
                throw AIClientError.missingAPIKey
            }

        case .antigravity:
            // Only dispatch if an interactive subprocess session is running.
            // We cannot guarantee delivery without an active subprocess to accept stdin.
            guard await sessionBridge.isInteractiveSessionActive else {
                // Per handoff rule: do not report delivery without confirmation.
                // Surface the failure clearly so the UI can show "No active session".
                throw AIClientError.sessionUnavailable
            }
            // Attempt to send via subprocess stdin.
            // sendInput() returns .sent (pipe write OK) or throws on write failure.
            let result = try await sessionBridge.sendInput(text)
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            switch result {
            case .sent:
                // Pipe write succeeded. Note: this does NOT confirm the agent consumed the message.
                // The response text is intentionally honest about delivery state.
                return MultiAIResponse(
                    text: "Sent to Antigravity session — awaiting agent response.",
                    provider: .antigravity,
                    executionTimeMs: duration
                )
            case .noSession:
                throw AIClientError.sessionUnavailable
            }
        }
    }
}
