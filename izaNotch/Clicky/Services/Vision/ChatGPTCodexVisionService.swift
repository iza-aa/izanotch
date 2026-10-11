//
//  ChatGPTCodexVisionService.swift
//  izaNotch
//
//  Headless Vision Service powered by OpenAI Codex CLI & 6 Luna Medium (gpt-6-luna)
//  Executes vision coordinate extraction in background with zero GUI popups.
//

import Foundation

public struct VisionCoordinateResult: Codable {
    public let target: String
    public let x: Int
    public let y: Int
    public let confidence: Double
    
    public init(target: String, x: Int, y: Int, confidence: Double = 1.0) {
        self.target = target
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}
public struct VisualScreenState: Codable, Sendable {
    public let windowTitle: String
    public let windowType: String
    public let hasModalOrError: Bool
    public let errorOrAlertMessage: String?
    public let formFields: [String: String]
    public let visualSummary: String
    
    public init(
        windowTitle: String,
        windowType: String,
        hasModalOrError: Bool,
        errorOrAlertMessage: String?,
        formFields: [String: String],
        visualSummary: String
    ) {
        self.windowTitle = windowTitle
        self.windowType = windowType
        self.hasModalOrError = hasModalOrError
        self.errorOrAlertMessage = errorOrAlertMessage
        self.formFields = formFields
        self.visualSummary = visualSummary
    }
}

public enum VisionServiceError: LocalizedError {
    case binaryNotFound(String)
    case executionFailed(String)
    case outputNotFound(String)
    case parsingFailed(String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "ChatGPT Codex binary not found at: \(path)"
        case .executionFailed(let reason):
            return "Codex execution failed: \(reason)"
        case .outputNotFound(let path):
            return "Expected output file not found at: \(path)"
        case .parsingFailed(let reason):
            return "Failed to parse vision coordinate JSON: \(reason)"
        case .timeout:
            return "Vision inference timed out after 15 seconds"
        }
    }
}

@MainActor
public final class ChatGPTCodexVisionService: ObservableObject {
    public static let shared = ChatGPTCodexVisionService()
    
    public static var codexBinaryPath: String {
        resolveCodexBinaryPath() ?? "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
    }

    public static func resolveCodexBinaryPath() -> String? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            NSString(string: "~/.local/bin/codex").expandingTildeInPath,
            "/Applications/ChatGPT.app/Contents/Resources/codex"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static let defaultModel = "gpt-6-luna"
    public static let defaultReasoningEffort = "medium"
    
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var isVisionServiceHealthy: Bool = true
    @Published public private(set) var lastInfrastructureError: String? = nil
    @Published public private(set) var lastQueryTarget: String = ""
    @Published public private(set) var lastResult: VisionCoordinateResult?
    @Published public private(set) var lastExecutionDuration: TimeInterval = 0

    private init() {}
    
    /// Queries coordinates for a given UI target element within an image using 6 Luna Medium.
    /// - Parameters:
    ///   - imagePath: Absolute path to the captured screen/window snapshot PNG.
    ///   - targetElementPrompt: Natural language description of the element to locate (e.g. "Send button", "Search field").
    ///   - codexHome: Optional custom CODEX_HOME path for isolated multi-account failover.
    /// - Returns: Parsed `VisionCoordinateResult` with absolute X, Y coordinates.
    public func queryCoordinates(
        imagePath: String,
        targetElementPrompt: String,
        codexHome: String? = nil
    ) async throws -> VisionCoordinateResult {
        do {
            return try await executeProcessQuery(
                imagePath: imagePath,
                targetElementPrompt: targetElementPrompt,
                codexHome: codexHome
            )
        } catch VisionServiceError.executionFailed(let err) where codexHome != nil && (err.contains("401") || err.contains("token") || err.contains("refresh")) {
            self.isVisionServiceHealthy = false
            self.lastInfrastructureError = err
            ClickyLogger.error("[CODEX_VISION]", "Infrastructure incident: Luna session token invalid: \(err)")
            return try await executeProcessQuery(
                imagePath: imagePath,
                targetElementPrompt: targetElementPrompt,
                codexHome: nil
            )
        } catch {
            let errStr = error.localizedDescription
            if errStr.contains("401") || errStr.contains("token") || errStr.contains("refresh") {
                self.isVisionServiceHealthy = false
                self.lastInfrastructureError = errStr
                ClickyLogger.error("[CODEX_VISION]", "Infrastructure incident: Luna session token invalid. Fast-path failover active.")
            }
            throw error
        }
    }
    /// Queries Luna Truth Vision (gpt-6-luna) for holistic window state, error/alert popout, and form fields
    public func queryScreenState(
        imagePath: String,
        appName: String,
        codexHome: String? = nil
    ) async throws -> VisualScreenState {
        do {
            return try await executeScreenStateQuery(
                imagePath: imagePath,
                appName: appName,
                codexHome: codexHome
            )
        } catch VisionServiceError.executionFailed(let err) where codexHome != nil && (err.contains("401") || err.contains("token") || err.contains("refresh")) {
            self.isVisionServiceHealthy = false
            self.lastInfrastructureError = err
            ClickyLogger.error("[CODEX_VISION]", "Infrastructure incident on screen state: \(err)")
            return try await executeScreenStateQuery(
                imagePath: imagePath,
                appName: appName,
                codexHome: nil
            )
        } catch {
            let errStr = error.localizedDescription
            if errStr.contains("401") || errStr.contains("token") || errStr.contains("refresh") {
                self.isVisionServiceHealthy = false
                self.lastInfrastructureError = errStr
                ClickyLogger.error("[CODEX_VISION]", "Infrastructure incident on screen state. Fast-path failover active.")
            }
            throw error
        }
    }

    private func executeScreenStateQuery(
        imagePath: String,
        appName: String,
        codexHome: String? = nil
    ) async throws -> VisualScreenState {
        guard let resolvedPath = Self.resolveCodexBinaryPath() else {
            throw VisionServiceError.binaryNotFound(Self.codexBinaryPath)
        }
        guard FileManager.default.fileExists(atPath: imagePath) else {
            throw VisionServiceError.outputNotFound("Input image not found at: \(imagePath)")
        }
        
        let stdinPrompt = """
        You are Luna, the Truth Vision perception engine for an autonomous computer agent in \(appName).
        Analyze the provided screen snapshot image and determine the holistic window and interface state.

        Respond with ONLY a single raw JSON object (no markdown quotes, no backticks, no explanatory text):
        {
          "windowTitle": "<title of the frontmost window or draft>",
          "windowType": "<draft_composer | error_alert | dialog | collection_list | document_editor | other>",
          "hasModalOrError": <true if an error popup, alert sheet, or confirmation dialog is present, else false>,
          "errorOrAlertMessage": <"<text of error/alert>" or null>,
          "formFields": {
            "<fieldName>": "<current visible content or empty>"
          },
          "visualSummary": "<concise 1-2 sentence description of what is visually on screen>"
        }
        """
        
        let tempOutputDir = NSTemporaryDirectory()
        let tempOutputFile = (tempOutputDir as NSString).appendingPathComponent("codex_truth_\(UUID().uuidString).json")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: resolvedPath)
                process.arguments = [
                    "exec",
                    "--ephemeral",
                    "--skip-git-repo-check",
                    "-s", "read-only",
                    "-m", Self.defaultModel,
                    "-c", "reasoning_effort=medium",
                    "-i", imagePath,
                    "-o", tempOutputFile,
                    "-"
                ]
                
                var env = ProcessInfo.processInfo.environment
                if let codexHome = codexHome, !codexHome.isEmpty {
                    env["CODEX_HOME"] = codexHome
                }
                process.environment = env
                
                let stdinPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardInput = stdinPipe
                process.standardError = stderrPipe
                
                let timeoutItem = DispatchWorkItem {
                    if process.isRunning { process.terminate() }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 15.0, execute: timeoutItem)
                
                do {
                    try process.run()
                    if let promptData = stdinPrompt.data(using: .utf8) {
                        stdinPipe.fileHandleForWriting.write(promptData)
                    }
                    try? stdinPipe.fileHandleForWriting.close()
                    
                    process.waitUntilExit()
                    timeoutItem.cancel()
                    
                    let exitCode = process.terminationStatus
                    if exitCode != 0 {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errString = String(data: errData, encoding: .utf8) ?? "Exit code \(exitCode)"
                        continuation.resume(throwing: VisionServiceError.executionFailed(errString))
                        return
                    }
                    
                    guard FileManager.default.fileExists(atPath: tempOutputFile),
                          let outputData = try? Data(contentsOf: URL(fileURLWithPath: tempOutputFile)),
                          let outputString = String(data: outputData, encoding: .utf8) else {
                        continuation.resume(throwing: VisionServiceError.outputNotFound(tempOutputFile))
                        return
                    }
                    
                    try? FileManager.default.removeItem(atPath: tempOutputFile)
                    
                    let sanitizedJson = Self.extractJsonPayload(from: outputString)
                    guard let sanitizedData = sanitizedJson.data(using: .utf8),
                          let parsed = try? JSONDecoder().decode(VisualScreenState.self, from: sanitizedData) else {
                        continuation.resume(throwing: VisionServiceError.parsingFailed(outputString))
                        return
                    }
                    
                    continuation.resume(returning: parsed)
                } catch {
                    timeoutItem.cancel()
                    try? FileManager.default.removeItem(atPath: tempOutputFile)
                    continuation.resume(throwing: VisionServiceError.executionFailed(error.localizedDescription))
                }
            }
        }
    }

    private func executeProcessQuery(
        imagePath: String,
        targetElementPrompt: String,
        codexHome: String? = nil
    ) async throws -> VisionCoordinateResult {
        guard let resolvedPath = Self.resolveCodexBinaryPath() else {
            throw VisionServiceError.binaryNotFound(Self.codexBinaryPath)
        }
        guard FileManager.default.fileExists(atPath: imagePath) else {
            throw VisionServiceError.outputNotFound("Input image not found at: \(imagePath)")
        }
        
        isProcessing = true
        lastQueryTarget = targetElementPrompt
        let startTime = Date()
        
        defer {
            isProcessing = false
            lastExecutionDuration = Date().timeIntervalSince(startTime)
        }
        
        // Structured prompt requesting strict JSON coordinate output
        let stdinPrompt = """
        You are a high-precision computer vision locator for macOS UI elements.
        Locate the exact center coordinates of the requested target element in the provided image.
        Target element: "\(targetElementPrompt)"
        
        Respond with ONLY a single raw JSON object (no markdown quotes, no backticks, no explanatory text):
        {"target":"\(targetElementPrompt)","x":<integer_x>,"y":<integer_y>,"confidence":<0.0_to_1.0>}
        """
        
        let tempOutputDir = NSTemporaryDirectory()
        let tempOutputFile = (tempOutputDir as NSString).appendingPathComponent("codex_vision_\(UUID().uuidString).json")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: resolvedPath)
                
                // Headless non-interactive execution arguments
                process.arguments = [
                    "exec",
                    "--ephemeral",
                    "--skip-git-repo-check",
                    "-s", "read-only",
                    "-m", Self.defaultModel,
                    "-c", "reasoning_effort=medium",
                    "-i", imagePath,
                    "-o", tempOutputFile,
                    "-"
                ]
                
                // Inject custom CODEX_HOME if specified for multi-account pool routing
                var env = ProcessInfo.processInfo.environment
                if let codexHome = codexHome, !codexHome.isEmpty {
                    env["CODEX_HOME"] = codexHome
                }
                process.environment = env
                
                let stdinPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardInput = stdinPipe
                process.standardError = stderrPipe
                
                // Timeout watchdog timer
                let timeoutItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 15.0, execute: timeoutItem)
                
                do {
                    try process.run()
                    
                    if let promptData = stdinPrompt.data(using: .utf8) {
                        stdinPipe.fileHandleForWriting.write(promptData)
                    }
                    try? stdinPipe.fileHandleForWriting.close()
                    
                    process.waitUntilExit()
                    timeoutItem.cancel()
                    
                    let exitCode = process.terminationStatus
                    if exitCode != 0 {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errString = String(data: errData, encoding: .utf8) ?? "Exit code \(exitCode)"
                        continuation.resume(throwing: VisionServiceError.executionFailed(errString))
                        return
                    }
                    
                    guard FileManager.default.fileExists(atPath: tempOutputFile),
                          let outputData = try? Data(contentsOf: URL(fileURLWithPath: tempOutputFile)),
                          let outputString = String(data: outputData, encoding: .utf8) else {
                        continuation.resume(throwing: VisionServiceError.outputNotFound(tempOutputFile))
                        return
                    }
                    
                    // Clean up temp file
                    try? FileManager.default.removeItem(atPath: tempOutputFile)
                    
                    // Parse JSON output (sanitize markdown code blocks if any)
                    let sanitizedJson = Self.extractJsonPayload(from: outputString)
                    guard let sanitizedData = sanitizedJson.data(using: .utf8),
                          let parsed = try? JSONDecoder().decode(VisionCoordinateResult.self, from: sanitizedData) else {
                        continuation.resume(throwing: VisionServiceError.parsingFailed(outputString))
                        return
                    }
                    
                    Task { @MainActor in
                        Self.shared.lastResult = parsed
                    }
                    continuation.resume(returning: parsed)
                    
                } catch {
                    timeoutItem.cancel()
                    try? FileManager.default.removeItem(atPath: tempOutputFile)
                    continuation.resume(throwing: VisionServiceError.executionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// Sanitizes model responses that may contain wrapping backticks or whitespace.
    public static func extractJsonPayload(from rawString: String) -> String {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: "\n")
            let filtered = lines.filter { !$0.hasPrefix("```") }
            return filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let startIndex = trimmed.firstIndex(of: "{"),
           let endIndex = trimmed.lastIndex(of: "}") {
            return String(trimmed[startIndex...endIndex])
        }
        return trimmed
    }
}
