//
//  TaskEgressValidator.swift
//  boringNotch (Izanotchy)
//
//  Egress Gateway: Validates task completion from visual/AX observations and synthesizes responses.
//  Zero Linguistic Prompt Injections — Abstract Reasoning & Strict Factual Extraction.
//

import AppKit
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public final class TaskEgressValidator: @unchecked Sendable {
    public static let shared = TaskEgressValidator()

    private init() {}

    /// Modular State Evaluation Result
    public struct TaskStateEvaluation: Sendable {
        public let isDone: Bool
        public let requiresTakeover: Bool
        public let systemState: String
        public let extractedData: String

        public init(isDone: Bool, requiresTakeover: Bool, systemState: String, extractedData: String) {
            self.isDone = isDone
            self.requiresTakeover = requiresTakeover
            self.systemState = systemState
            self.extractedData = extractedData
        }
    }

    /// Step 1: Technical & Factual State Validation (Single Responsibility)
    public func evaluateTaskState(
        userGoal: String,
        appName: String,
        performedSteps: [String],
        latestObservation: String,
        taskContract: AFMTaskDecomposition? = nil
    ) async -> TaskStateEvaluation {
        let goalText = taskContract?.normalizedGoal.isEmpty == false ? taskContract!.normalizedGoal : userGoal
        let targetEntity = taskContract?.targetEntity ?? "main_window"
        let intentType = taskContract?.intentType ?? "inspect"
        let searchQuery = taskContract?.searchQuery ?? "none"
        let effectiveTargetIndex = taskContract?.targetIndex ?? ((intentType == "inspect" || intentType == "read") && searchQuery == "none" ? 1 : nil)
        let targetIndexStr = effectiveTargetIndex != nil ? "\(effectiveTargetIndex!)" : "unspecified"
        // Deterministic Preparatory Guard:
        // If the most recent action was scrolling, the agent is merely preparing the viewport.
        // It has NOT clicked or inspected the target item yet.
        if let lastStep = performedSteps.last?.lowercased(),
           lastStep.contains("scroll_down") || lastStep.contains("scroll_up") || lastStep.contains("scroll") {
            ClickyLogger.info("[TASK_VALIDATOR]", "Deterministic short-circuit: last step was scroll preparatory action. isDone=false.")
            return TaskStateEvaluation(
                isDone: false,
                requiresTakeover: false,
                systemState: "Navigating list viewport",
                extractedData: ""
            )
        }

        let policy = ValidationPolicyRegistry.policy(for: intentType)
        let instructions = policy.buildInstructions(
            appName: appName,
            targetIndexStr: targetIndexStr
        )



        let cleanObs = latestObservation.count > 1000 ? String(latestObservation.prefix(1000)) + "... [truncated]" : latestObservation

        let prompt = """
        Goal: "\(goalText)" (target: \(targetEntity), index: \(targetIndexStr))
        Steps: [\(performedSteps.joined(separator: "; "))]
        Observation: "\(cleanObs)"
        Evaluate state and extract factual findings.
        """

        // Tier 1: Apple Foundation Models on-device session (NPU Neural Engine)
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                let rawText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsed = parseStateEvaluationJSON(from: rawText) {
                    ClickyLogger.info("[TASK_VALIDATOR]", "AFM evaluated state: isDone=\(parsed.isDone), takeover=\(parsed.requiresTakeover), state='\(parsed.systemState)'")
                    return parsed
                }
            } catch {
                ClickyLogger.warning("[TASK_VALIDATOR]", "AFM state evaluation error: \(error.localizedDescription)")
            }
        }
        #endif

        // Tier 2: Apple Foundation Models daemon via SiriAIEngine (port 1976)
        if SiriAIEngine.shared.isDaemonRunning {
            do {
                let turnRes = try await SiriAIEngine.shared.analyzeMessagesWithToolsStreaming(
                    messages: [["role": "user", "content": prompt]],
                    systemPrompt: instructions,
                    onTextChunk: { _ in }
                )
                if let parsed = parseStateEvaluationJSON(from: turnRes.text) {
                    ClickyLogger.info("[TASK_VALIDATOR]", "AFM (SiriAIEngine) evaluated state: isDone=\(parsed.isDone), takeover=\(parsed.requiresTakeover), state='\(parsed.systemState)'")
                    return parsed
                }
            } catch {
                ClickyLogger.warning("[TASK_VALIDATOR]", "SiriAIEngine state evaluation error: \(error.localizedDescription)")
            }
        }

        // Tier 3: Model reasoning fallback via GeminiBridgeClient
        do {
            let client = GeminiBridgeClient()
            let turnRes = try await client.analyzeMessagesWithToolsStreaming(
                messages: [["role": "user", "content": prompt]],
                systemPrompt: instructions,
                tools: [],
                maxTokens: 512,
                onTextChunk: { _ in }
            )
            if let parsed = parseStateEvaluationJSON(from: turnRes.text) {
                ClickyLogger.info("[TASK_VALIDATOR]", "Gemini evaluated state: isDone=\(parsed.isDone), takeover=\(parsed.requiresTakeover), state='\(parsed.systemState)'")
                return parsed
            }
        } catch {
            ClickyLogger.warning("[TASK_VALIDATOR]", "Gemini state evaluation error: \(error.localizedDescription)")
        }

        return TaskStateEvaluation(
            isDone: false,
            requiresTakeover: false,
            systemState: "Awaiting AFM state validation",
            extractedData: ""
        )
    }

    /// Step 2: Natural Language Response Synthesis (Single Responsibility)
    public func synthesizeUserResponse(
        goalText: String,
        appName: String,
        systemState: String,
        extractedData: String,
        userLanguage: String
    ) async -> String {
        let langName = Locale(identifier: "en").localizedString(forLanguageCode: userLanguage) ?? userLanguage
        let instructions = """
        You are an on-device Assistant Response Synthesizer for \(appName).
        Formulate a direct, polite answer strictly in \(langName) (code: \(userLanguage)) addressing the user with the factual findings or action status.
        Under NO circumstances should response be in English if \(langName) is not English.
        NEVER output generic process status like 'proses inspeksi selesai' or internal self-evaluations like 'tujuan belum tercapai'.
        If target item or data was found, summarize the factual findings directly (e.g. sender name, subject, date/time, or content).
        Output ONLY plain text in \(langName) with no JSON, quotes, or markdown.
        """

        let prompt = """
        Goal: "\(goalText)"
        State: "\(systemState)"
        Findings: "\(extractedData)"
        Synthesize direct, factual response in \(langName):
        """

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if let session = try? LanguageModelSession(instructions: instructions),
               let resp = try? await session.respond(to: prompt) {
                let txt = resp.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !txt.isEmpty { return txt }
            }
        }
        #endif

        if SiriAIEngine.shared.isDaemonRunning {
            if let turnRes = try? await SiriAIEngine.shared.analyzeMessagesWithToolsStreaming(
                messages: [["role": "user", "content": prompt]],
                systemPrompt: instructions,
                onTextChunk: { _ in }
            ) {
                let txt = turnRes.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !txt.isEmpty { return txt }
            }
        }

        // Tier 3: Model reasoning fallback via GeminiBridgeClient
        do {
            let client = GeminiBridgeClient()
            let turnRes = try await client.analyzeMessagesWithToolsStreaming(
                messages: [["role": "user", "content": prompt]],
                systemPrompt: instructions,
                tools: [],
                maxTokens: 256,
                onTextChunk: { _ in }
            )
            let txt = turnRes.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !txt.isEmpty { return txt }
        } catch {}

        return extractedData.isEmpty ? systemState : extractedData
    }

    /// Requests AFM on-device or cloud fallback to validate whether the state transition or final goal is reached
    public func validate(
        userGoal: String,
        appName: String,
        performedSteps: [String],
        latestObservation: String,
        taskContract: AFMTaskDecomposition? = nil
    ) async -> AFMValidationResult {
        let lang = TaskIngressGateway.resolveLanguage(prompt: userGoal, modelDetected: taskContract?.userLanguage ?? "id")
        let goalText = taskContract?.normalizedGoal.isEmpty == false ? taskContract!.normalizedGoal : userGoal

        // 1. Evaluate State Transition & Extract Facts (Technical Logic)
        let state = await evaluateTaskState(
            userGoal: goalText,
            appName: appName,
            performedSteps: performedSteps,
            latestObservation: latestObservation,
            taskContract: taskContract
        )

        // 2. Synthesize Natural Language Response in user's language (Presentation Logic)
        var responseToUser = ""
        let hasFactualData = !state.extractedData.isEmpty && state.extractedData.lowercased() != "none"
        if state.isDone || hasFactualData || state.requiresTakeover {
            responseToUser = await synthesizeUserResponse(
                goalText: goalText,
                appName: appName,
                systemState: state.systemState,
                extractedData: state.extractedData,
                userLanguage: lang
            )
        }

        return postProcessValidation(
            isDone: state.isDone,
            requiresTakeover: state.requiresTakeover,
            systemState: state.systemState,
            extractedData: state.extractedData,
            rawResponseToUser: responseToUser,
            appName: appName,
            taskContract: taskContract,
            lang: lang
        )
    }

    /// Synthesizes an alert or explanation notice to the user strictly in userLanguage via AI model tiers
    public func synthesizeNotice(
        noticeSummary: String,
        appName: String,
        userGoal: String,
        userLanguage: String
    ) async -> String {
        let langName = Locale(identifier: "en").localizedString(forLanguageCode: userLanguage) ?? userLanguage
        let instructions = """
        You are an on-device Assistant Voice and Response Synthesizer for \(appName).
        Formulate a clear, direct, polite 1-sentence notification strictly in \(langName) (code: \(userLanguage)) informing the user about this situation.
        Notice: "\(noticeSummary)"
        Original Request: "\(userGoal)"
        Output ONLY the plain text message in \(langName) with no quotes, tags, or markdown.
        """
        let prompt = "Synthesize 1-sentence notification in \(langName)."

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if let session = try? LanguageModelSession(instructions: instructions),
               let resp = try? await session.respond(to: prompt) {
                let txt = resp.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !txt.isEmpty { return txt }
            }
        }
        #endif

        if SiriAIEngine.shared.isDaemonRunning {
            if let turnRes = try? await SiriAIEngine.shared.analyzeMessagesWithToolsStreaming(
                messages: [["role": "user", "content": prompt]],
                systemPrompt: instructions,
                onTextChunk: { _ in }
            ) {
                let txt = turnRes.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !txt.isEmpty { return txt }
            }
        }

        // Tier 3: Model reasoning fallback via GeminiBridgeClient
        do {
            let client = GeminiBridgeClient()
            let turnRes = try await client.analyzeMessagesWithToolsStreaming(
                messages: [["role": "user", "content": prompt]],
                systemPrompt: instructions,
                tools: [],
                maxTokens: 128,
                onTextChunk: { _ in }
            )
            let txt = turnRes.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !txt.isEmpty { return txt }
        } catch {}

        // Graceful universal fallback
        return noticeSummary
    }

    private func parseStateEvaluationJSON(from rawText: String) -> TaskStateEvaluation? {
        guard let data = extractJSONData(from: rawText),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let isDone = (dict["isDone"] as? Bool) ?? (dict["is_done"] as? Bool) ?? (dict["done"] as? Bool) else {
            return nil
        }
        let systemState = (dict["systemState"] as? String)
            ?? (dict["system_state"] as? String)
            ?? (dict["summary"] as? String)
            ?? (dict["state"] as? String)
            ?? (isDone ? "Task accomplished" : "In progress")

        let extractedData = (dict["extractedData"] as? String)
            ?? (dict["extracted_data"] as? String)
            ?? (dict["data"] as? String)
            ?? ""

        let requiresTakeover = (dict["requiresTakeover"] as? Bool)
            ?? (dict["requires_takeover"] as? Bool)
            ?? false

        return TaskStateEvaluation(
            isDone: isDone,
            requiresTakeover: requiresTakeover,
            systemState: systemState,
            extractedData: extractedData
        )
    }

    private func postProcessValidation(
        isDone: Bool,
        requiresTakeover: Bool,
        systemState: String,
        extractedData: String,
        rawResponseToUser: String,
        appName: String,
        taskContract: AFMTaskDecomposition? = nil,
        lang: String
    ) -> AFMValidationResult {
        var responseToUser = rawResponseToUser

        // 1. Strip literal prompt artifacts like <answer in Bahasa Indonesia> or any bracketed placeholders
        responseToUser = responseToUser.replacingOccurrences(of: #"^<[^>]+>\s*"#, with: "", options: .regularExpression)
        responseToUser = responseToUser.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)

        // 1b. Absolute Non-Empty Response Fallback:
        // If model output empty responseToUser but provided a rich systemState or extractedData, use it!
        if responseToUser.isEmpty {
            if !systemState.isEmpty && systemState != "Task accomplished" && systemState != "In progress" {
                responseToUser = systemState
            } else if !extractedData.isEmpty && extractedData.lowercased() != "none" {
                responseToUser = extractedData
            }
        }

        // 1c. Factual Content Delivery:
        // If responseToUser is merely a terse meta-label/status header (e.g. "hasil analisis email pertama")
        // while extractedData contains rich factual findings (e.g. sender, subject, date, body),
        // ensure the user receives the actual extracted content in the response!
        let hasRichExtraction = !extractedData.isEmpty && extractedData.lowercased() != "none" && extractedData.count > 25
        let isMetaLabelOnly = responseToUser.count <= 45 && (
            responseToUser.lowercased().contains("analisis") ||
            responseToUser.lowercased().contains("pemeriksaan") ||
            responseToUser.lowercased().contains("inspeksi") ||
            responseToUser.lowercased().contains("selesai") ||
            responseToUser.lowercased().contains("status")
        )
        if hasRichExtraction {
            if isMetaLabelOnly {
                responseToUser = "\(responseToUser): \(extractedData)"
            } else if !responseToUser.lowercased().contains(extractedData.prefix(15).lowercased()) && !responseToUser.contains(":") {
                responseToUser = "\(responseToUser)\n\n\(extractedData)"
            }
        }

        // 2. Anti-hallucination guard: ensure responseToUser provides factual status rather than generic commands
        if responseToUser.lowercased().hasPrefix("silakan") || responseToUser.lowercased().hasPrefix("lakukan") {
            if !extractedData.isEmpty && extractedData.lowercased() != "none" {
                responseToUser = extractedData
            }
        }

        // 3. Tone Guard: If responseToUser contains internal negative self-critique but factual data exists
        let negativeCritiquePhrases = ["belum tercapai", "tidak tercapai", "belum ada indikasi", "belum dibaca sepenuhnya", "tidak ada indikasi"]
        let hasNegativeCritique = negativeCritiquePhrases.contains { responseToUser.lowercased().contains($0) }
        let hasFactualData = !extractedData.isEmpty && extractedData.lowercased() != "none" && !extractedData.lowercased().contains("tidak ada")

        if hasNegativeCritique && hasFactualData {
            responseToUser = extractedData
        }

        // 4. Send / Submission Goal Invariant: If goal requires human confirmation on completion
        let isSendGoal = (taskContract?.requiresTakeoverOnCompletion == true)
        let effectiveRequiresTakeover = requiresTakeover || (isSendGoal && isDone)

        // 5. Language Consistency Guard: If user prompt is not English, ensure response does not leak English
        if lang != "en" {
            let lowerResp = responseToUser.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let isEnglishStart = lowerResp.hasPrefix("the ") || lowerResp.hasPrefix("here is") || lowerResp.hasPrefix("we have") || lowerResp.hasPrefix("in your")
            if isEnglishStart {
                if !extractedData.isEmpty && extractedData.lowercased() != "none" {
                    responseToUser = extractedData
                } else if let targetIdx = taskContract?.targetIndex {
                    responseToUser = "Item #\(targetIdx) (\(appName))"
                } else {
                    responseToUser = systemState
                }
            }
        }

        var effectiveIsDone = isDone
        if effectiveRequiresTakeover {
            effectiveIsDone = false
        } else if hasFactualData && !hasNegativeCritique {
            effectiveIsDone = true
        }

        return AFMValidationResult(
            isDone: effectiveIsDone,
            systemState: systemState,
            extractedData: extractedData,
            responseToUser: responseToUser,
            requiresTakeover: effectiveRequiresTakeover
        )
    }


    private func extractJSONData(from text: String) -> Data? {
        var str = text
        if let start = str.range(of: "{"), let end = str.range(of: "}", options: .backwards), start.lowerBound <= end.lowerBound {
            str = String(str[start.lowerBound...end.lowerBound])
        }
        return str.data(using: .utf8)
    }
}
