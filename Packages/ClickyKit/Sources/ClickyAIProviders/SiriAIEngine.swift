import ClickyFoundation
//
//  SiriAIEngine.swift
//  izaNotch (Izanotchy)
//
//  Native Apple Foundation Models (AFM) On-Device Engine (Pillar 1)
//  Communicates with macOS 27 native /usr/bin/fm serve on http://127.0.0.1:1976
//  Runs 100% on Apple Silicon Neural Engine (NPU) with zero external cloud dependency.
//

import AppKit
import ClickyFoundation
import ClickyPlatform
import Defaults
import Foundation

public final class SiriAIEngine: @unchecked Sendable {
    public static let shared = SiriAIEngine()

    public static let defaultPort = 1976
    private let binaryPath = "/usr/bin/fm"
    private var daemonProcess: Process?
    private let engineLock = NSRecursiveLock()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopDaemon()
        }
    }

    deinit {
        stopDaemon()
    }

    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: binaryPath)
    }

    public var isDaemonRunning: Bool {
        engineLock.lock()
        defer { engineLock.unlock() }
        return (daemonProcess?.isRunning ?? false) || isPortListening(port: Self.defaultPort)
    }

    public func stopDaemon() {
        engineLock.lock()
        defer { engineLock.unlock() }
        if let proc = daemonProcess, proc.isRunning {
            proc.terminate()
            ClickyLogger.info("[SIRI_AI]", "Stopped Apple Foundation Models daemon (PID \(proc.processIdentifier))")
        }
        daemonProcess = nil
    }

    public func warmUp() {
        Task.detached(priority: .utility) { [weak self] in
            try? self?.ensureRunning()
        }
    }

    public func ensureRunning() throws {
        engineLock.lock()
        defer { engineLock.unlock() }

        // 1. If internal daemon process is already running, we are good
        if let proc = daemonProcess, proc.isRunning {
            return
        }

        // 2. Check if binary is present
        guard isAvailable else {
            throw NSError(
                domain: "SiriAIEngine",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Apple Foundation Models binary not found at \(binaryPath)"]
            )
        }

        // 3. Check if an fm serve instance is already active on the port
        if isPortListening(port: Self.defaultPort) {
            return
        }

        // 4. Launch daemon process
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = ["serve", "--host", "127.0.0.1", "--port", "\(Self.defaultPort)"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        try proc.run()
        self.daemonProcess = proc
        ClickyLogger.success("[SIRI_AI]", "Launched native Apple Foundation Models daemon on port \(Self.defaultPort) (PID \(proc.processIdentifier))")

        // Wait briefly for server ready
        for _ in 0..<15 {
            if isPortListening(port: Self.defaultPort) {
                ClickyLogger.success("[SIRI_AI]", "Apple Foundation Models server is ready and responding at port \(Self.defaultPort)")
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func isPortListening(port: Int) -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0.5
        let semaphore = DispatchSemaphore(value: 0)
        var isHealthy = false
        session.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                isHealthy = true
            }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 0.6)
        return isHealthy
    }

    /// Primary streaming execution compatible with ClaudeTurnResult & CompanionManager ReAct loop
    public func analyzeMessagesWithToolsStreaming(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [[String: Any]] = [],
        maxTokens: Int = 1024,
        onTextChunk: @escaping @Sendable (String) -> Void
    ) async throws -> ClaudeTurnResult {
        try ensureRunning()

        let startTime = Date()
        let endpoint = URL(string: "http://127.0.0.1:\(Self.defaultPort)/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert Anthropic-style message payload to OpenAI/AFM format
        var openAIMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for msg in messages {
            let role = msg["role"] as? String ?? "user"

            if let str = msg["content"] as? String {
                if !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    openAIMessages.append([
                        "role": role == "assistant" ? "assistant" : "user",
                        "content": str
                    ])
                }
            } else if let blocks = msg["content"] as? [[String: Any]] {
                var openAIContentBlocks: [[String: Any]] = []

                for block in blocks {
                    let bType = block["type"] as? String ?? ""
                    if bType == "text", let t = block["text"] as? String, !t.isEmpty {
                        openAIContentBlocks.append([
                            "type": "text",
                            "text": t
                        ])
                    } else if bType == "image",
                              let source = block["source"] as? [String: Any],
                              let b64Data = source["data"] as? String {
                        let mediaType = source["media_type"] as? String ?? "image/jpeg"
                        openAIContentBlocks.append([
                            "type": "image_url",
                            "image_url": [
                                "url": "data:\(mediaType);base64,\(b64Data)"
                            ]
                        ])
                    } else if bType == "tool_result" {
                        if let resContent = block["content"] as? [[String: Any]] {
                            for rb in resContent {
                                if let rt = rb["text"] as? String {
                                    openAIContentBlocks.append([
                                        "type": "text",
                                        "text": "[Hasil Alat: \(rt)]"
                                    ])
                                }
                            }
                        } else if let strRes = block["content"] as? String {
                            openAIContentBlocks.append([
                                "type": "text",
                                "text": "[Hasil Alat: \(strRes)]"
                            ])
                        }
                    }
                }

                if !openAIContentBlocks.isEmpty {
                    openAIMessages.append([
                        "role": role == "assistant" ? "assistant" : "user",
                        "content": openAIContentBlocks
                    ])
                }
            }
        }

        var body: [String: Any] = [
            "model": "system",
            "messages": openAIMessages,
            "stream": true,
            "max_tokens": maxTokens,
            "temperature": 0.0
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData

        let (byteStream, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "SiriAIEngine", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code) from fm serve"])
        }

        var accumulatedText = ""

        for try await line in byteStream.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { break }

            guard let pData = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: pData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let delta = firstChoice["delta"] as? [String: Any] else {
                continue
            }

            if let content = delta["content"] as? String, !content.isEmpty {
                accumulatedText += content
                onTextChunk(content)
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        ClickyLogger.success("[SIRI_AI]", "On-device AFM completed response in \(String(format: "%.2f", duration))s (\(accumulatedText.count) chars)")

        return ClaudeTurnResult(
            text: accumulatedText,
            toolCalls: [],
            stopReason: "stop",
            duration: duration
        )
    }
}

// MARK: - Typing Intent Model & Parser

public struct SiriAITypingIntent: Codable, Sendable {
    public let appName: String?
    public let targetField: String?
    public let textToType: String

    enum CodingKeys: String, CodingKey {
        case appName = "app_name"
        case targetField = "target_field"
        case textToType = "text_to_type"
    }

    public init(appName: String?, targetField: String?, textToType: String) {
        self.appName = appName
        self.targetField = targetField
        self.textToType = textToType
    }
}

extension SiriAIEngine {
    /// Parses typing instructions via on-device Apple Foundation Models (/usr/bin/fm respond)
    /// with zero external cloud cost and sub-second latency on the Apple Neural Engine.
    public func parseTypingIntent(command: String) async -> SiriAITypingIntent {
        guard isAvailable else {
            return fallbackRegexParseTypingIntent(command: command)
        }

        let systemPrompt = SiriAIPolicy.typingIntentSystemPrompt
        let prompt = "\(systemPrompt)\n\nPerintah: \(command)"

        let rawOutput: String? = await Task.detached(priority: .userInitiated) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/fm")
            proc.arguments = ["respond", prompt]

            let stdoutPipe = Pipe()
            proc.standardOutput = stdoutPipe
            proc.standardError = FileHandle.nullDevice

            do {
                try proc.run()

                // 3.5s safety timeout
                let timeoutTask = Task {
                    try? await Task.sleep(for: .milliseconds(3500))
                    if proc.isRunning {
                        proc.terminate()
                    }
                }

                proc.waitUntilExit()
                timeoutTask.cancel()

                if proc.terminationStatus == 0 {
                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                ClickyLogger.warning("[SIRI_AI]", "fm respond execution error: \(error.localizedDescription)")
            }
            return nil
        }.value

        if let raw = rawOutput, !raw.isEmpty {
            let jsonString: String = {
                if let start = raw.range(of: "{"), let end = raw.range(of: "}", options: .backwards), start.lowerBound <= end.lowerBound {
                    return String(raw[start.lowerBound...end.lowerBound])
                }
                return raw
            }()

            if let data = jsonString.data(using: .utf8),
               let intent = try? JSONDecoder().decode(SiriAITypingIntent.self, from: data) {
                ClickyLogger.success("[SIRI_AI]", "Parsed typing intent via Siri AI: app=\(intent.appName ?? "none"), field=\(intent.targetField ?? "none"), text='\(intent.textToType)'")
                return intent
            }
        }

        ClickyLogger.info("[SIRI_AI]", "Falling back to deterministic regex typing parser")
        return fallbackRegexParseTypingIntent(command: command)
    }

    private func fallbackRegexParseTypingIntent(command: String) -> SiriAITypingIntent {
        var text = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        // Deteksi jika hanya mencari tombol fisik / UI element (bukan mengetik)
        let uiPointingWords = ["tombol", "button", "ikon", "icon", "tab", "menu", "dropdown"]
        if (lower.hasPrefix("cari ") || lower.hasPrefix("carikan ") || lower.hasPrefix("tunjuk")) &&
           uiPointingWords.contains(where: { lower.contains($0) }) {
            return SiriAITypingIntent(appName: nil, targetField: nil, textToType: "")
        }

        let triggers = [
            "tolong ketikkan", "bisa ketikkan", "tolong ketik", "bisa ketik", "ketikkan", "ketik", "type",
            "cari disearch bar", "cari di search bar", "cari di kolom pencarian", "cari di search",
            "cari disearch", "carikan di search bar", "carikan di search", "cari di", "carikan", "cari", "search"
        ]
        var targetField: String? = nil
        var appName: String? = nil

        for trig in triggers {
            if text.lowercased().hasPrefix(trig) {
                if trig.contains("search bar") || trig.contains("pencarian") || trig.contains("search") || trig.contains("disearch") {
                    targetField = "search bar"
                }
                text = String(text.dropFirst(trig.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        var cleanText = text
        if let diRange = text.range(of: " di ", options: .backwards) {
            let potentialTarget = String(text[diRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let candidateText = String(text[..<diRange.lowerBound]).trimmingCharacters(in: .whitespaces)

            let lowerTarget = potentialTarget.lowercased()
            if lowerTarget.contains("search") || lowerTarget.contains("kolom") || lowerTarget.contains("field") {
                targetField = potentialTarget
                cleanText = candidateText
            } else if let resolvedApp = DynamicAppResolver.shared.resolveApplication(query: potentialTarget) {
                appName = resolvedApp.displayName
                cleanText = candidateText
            }
        }

        return SiriAITypingIntent(
            appName: appName,
            targetField: targetField,
            textToType: cleanText.isEmpty ? command : cleanText
        )
    }

    /// Decomposes complex multi-step instructions using Apple Foundation Models on Apple Neural Engine.
    public func decomposeChainedInstructions(command: String) async -> [String]? {
        guard isAvailable else { return nil }

        let systemPrompt = SiriAIPolicy.chainedInstructionsSystemPrompt
        let prompt = "\(systemPrompt)\n\nInstruksi: \(command)"

        let rawOutput: String? = await Task.detached(priority: .userInitiated) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/fm")
            proc.arguments = ["respond", prompt]

            let stdoutPipe = Pipe()
            proc.standardOutput = stdoutPipe
            proc.standardError = FileHandle.nullDevice

            do {
                try proc.run()
                let timeoutTask = Task {
                    try? await Task.sleep(for: .milliseconds(3500))
                    if proc.isRunning { proc.terminate() }
                }
                proc.waitUntilExit()
                timeoutTask.cancel()

                if proc.terminationStatus == 0 {
                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                ClickyLogger.warning("[SIRI_AI]", "Decompose execution failed: \(error.localizedDescription)")
            }
            return nil
        }.value

        guard let raw = rawOutput, !raw.isEmpty else { return nil }

        let jsonString: String = {
            if let start = raw.range(of: "["), let end = raw.range(of: "]", options: .backwards), start.lowerBound <= end.lowerBound {
                return String(raw[start.lowerBound...end.lowerBound])
            }
            return raw
        }()

        if let data = jsonString.data(using: .utf8),
           let rawSteps = try? JSONDecoder().decode([String].self, from: data) {
            let cleanedSteps = rawSteps.compactMap { step -> String? in
                var s = step.trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove outer quotes
                if (s.hasPrefix("\"") && s.hasSuffix("\"")) || (s.hasPrefix("'") && s.hasSuffix("'")) {
                    s = String(s.dropFirst().dropLast())
                }
                // Strip inner quotes after "ketik"
                if s.lowercased().hasPrefix("ketik '") && s.hasSuffix("'") {
                    s = "ketik " + String(s.dropFirst(7).dropLast())
                } else if s.lowercased().hasPrefix("ketik \"") && s.hasSuffix("\"") {
                    s = "ketik " + String(s.dropFirst(7).dropLast())
                }
                // Strip conjunction prefixes if any slipped through
                s = s.replacingOccurrences(of: "^(?:setelah itu|lalu|terus|kemudian|dan)\\s+", with: "", options: [.regularExpression, .caseInsensitive])
                s = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return s.isEmpty ? nil : s
            }
            if cleanedSteps.count > 1 {
                ClickyLogger.success("[SIRI_AI]", "Decomposed \(cleanedSteps.count) steps via Siri AI fallback: \(cleanedSteps)")
                return cleanedSteps
            }
        }

        return nil
    }
}


