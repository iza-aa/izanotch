//
//  TaskEgressValidator.swift
//  izaNotch (Izanotchy)
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

        // Deterministic Failure Guard:
        // 1. If the most recent action failed to execute or could not be grounded, the task cannot be complete.
        if let lastStep = performedSteps.last?.lowercased(),
           lastStep.contains("failed to execute") || lastStep.contains("not visible") || lastStep.contains("ungrounded") {
            ClickyLogger.info("[TASK_VALIDATOR]", "Deterministic short-circuit: last step was ungrounded/failed. isDone=false.")
            return TaskStateEvaluation(
                isDone: false,
                requiresTakeover: false,
                systemState: "Target element not visible or ungrounded",
                extractedData: ""
            )
        }

        // 2. If any step failed and no subsequent step succeeded, the task cannot be complete.
        if let lastFailureIdx = performedSteps.lastIndex(where: {
            let s = $0.lowercased()
            return s.contains("failed to execute") || s.contains("not visible") || s.contains("ungrounded")
        }) {
            let subsequentSuccess = performedSteps[(lastFailureIdx + 1)...].contains(where: {
                let s = $0.lowercased()
                return !s.contains("failed") && (
                    s.contains("done") ||
                    s.contains("typed") ||
                    s.contains("type") ||
                    s.contains("clicked") ||
                    s.contains("click") ||
                    s.contains("scroll") ||
                    s.contains("executed")
                )
            })
            if !subsequentSuccess {
                ClickyLogger.info("[TASK_VALIDATOR]", "Deterministic short-circuit: unrecovered failure in performed steps. isDone=false.")
                return TaskStateEvaluation(
                    isDone: false,
                    requiresTakeover: false,
                    systemState: "Unrecovered failure during execution",
                    extractedData: ""
                )
            }
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
                    tools: [],
                    maxTokens: 180,
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
        Do NOT filter by personal pronouns like 'saya' or 'my'. Deliver the extracted findings directly.
        Output ONLY plain text in \(langName) with no JSON, quotes, or markdown.
        """

        let prompt: String
        let hasFindings = !extractedData.isEmpty && extractedData.lowercased() != "none"
        if hasFindings {
            prompt = """
            Context: The requested item was successfully opened and retrieved from the user's \(appName).
            Extracted Content:
            "\(extractedData)"

            Directly summarize the above extracted content for the user in \(langName):
            """
        } else {
            prompt = """
            Goal: "\(goalText)"
            State: "\(systemState)"
            Synthesize direct, factual response in \(langName):
            """
        }

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
            lang: lang,
            latestObservation: latestObservation
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


        // Graceful universal fallback
        return noticeSummary
    }

    private func parseStateEvaluationJSON(from rawText: String) -> TaskStateEvaluation? {
        if let data = extractJSONData(from: rawText),
           let dict = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] {
            let isDoneBool = (dict["isDone"] as? Bool) ?? (dict["is_done"] as? Bool) ?? (dict["done"] as? Bool)
            let isDoneStr = (dict["isDone"] as? String) ?? (dict["is_done"] as? String) ?? (dict["done"] as? String)
            let isDone = isDoneBool ?? (isDoneStr?.lowercased() == "true") ?? false

            let systemState = (dict["systemState"] as? String)
                ?? (dict["system_state"] as? String)
                ?? (dict["summary"] as? String)
                ?? (dict["state"] as? String)
                ?? (isDone ? "Task accomplished" : "In progress")

            let extractedData = (dict["extractedData"] as? String)
                ?? (dict["extracted_data"] as? String)
                ?? (dict["data"] as? String)
                ?? ""

            let requiresTakeoverBool = (dict["requiresTakeover"] as? Bool) ?? (dict["requires_takeover"] as? Bool)
            let requiresTakeoverStr = (dict["requiresTakeover"] as? String) ?? (dict["requires_takeover"] as? String)
            let requiresTakeover = requiresTakeoverBool ?? (requiresTakeoverStr?.lowercased() == "true") ?? false

            return TaskStateEvaluation(
                isDone: isDone,
                requiresTakeover: requiresTakeover,
                systemState: systemState,
                extractedData: extractedData
            )
        }

        let lower = rawText.lowercased()
        if lower.contains("\"isdone\": true") || lower.contains("\"is_done\": true") || lower.contains("\"isdone\":\"true\"") || lower.contains("\"isdone\":true") {
            let takeover = lower.contains("\"requirestakeover\": true") || lower.contains("\"requires_takeover\": true")
            return TaskStateEvaluation(
                isDone: true,
                requiresTakeover: takeover,
                systemState: "Form composition completed",
                extractedData: ""
            )
        }

        return nil
    }
    private func postProcessValidation(
        isDone: Bool,
        requiresTakeover: Bool,
        systemState: String,
        extractedData: String,
        rawResponseToUser: String,
        appName: String,
        taskContract: AFMTaskDecomposition? = nil,
        lang: String,
        latestObservation: String = ""
    ) -> AFMValidationResult {
        var responseToUser = rawResponseToUser

        // 0. Anti-Parroting Post-Check (Mandate 1):
        let templateGarbage = [
            "brief state summary", "factual data extracted", "<factual_state_summary>",
            "<extracted_content_summary>", "brief state", "state summary", "brief summary", "brief state summary."
        ]
        var cleanSystemState = systemState
        let isParroted = templateGarbage.contains { cleanSystemState.localizedCaseInsensitiveContains($0) }
        var effectiveIsDone = isDone

        if isParroted || cleanSystemState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ClickyLogger.warning("[TASK_VALIDATOR]", "Anti-Parroting Guard: Rejected parroted template text in systemState: '\(cleanSystemState)'. Synthesizing factual state from observation.")
            if !latestObservation.isEmpty && latestObservation != "{}" {
                cleanSystemState = Self.synthesizeFactualStateFromObservation(latestObservation)
            } else {
                cleanSystemState = "Awaiting factual screen verification"
                effectiveIsDone = false
            }
        }

        // 1. Strip literal prompt artifacts like bracketed placeholders
        responseToUser = responseToUser.replacingOccurrences(of: #"^<[^>]+>\s*"#, with: "", options: .regularExpression)
        responseToUser = responseToUser.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. Structural Non-Empty Response Fallback:
        if responseToUser.isEmpty {
            if !extractedData.isEmpty && extractedData.lowercased() != "none" {
                responseToUser = extractedData
            } else if !cleanSystemState.isEmpty && cleanSystemState != "Task accomplished" && cleanSystemState != "In progress" {
                responseToUser = cleanSystemState
            }
        }

        // 3. Factual Content Delivery:
        // If response is extremely brief while rich extracted findings exist, attach findings
        let hasRichExtraction = !extractedData.isEmpty && extractedData.lowercased() != "none" && extractedData.count > 20
        if hasRichExtraction && responseToUser.count < 30 && !responseToUser.contains(extractedData.prefix(15)) {
            responseToUser = "\(responseToUser): \(extractedData)"
        }

        // 4. Send / Submission Goal Invariant: Only actual external mutations enforce takeover
        let isSendGoal = (taskContract?.requiresTakeoverOnCompletion == true)
        let effectiveRequiresTakeover = requiresTakeover || (isSendGoal && isDone)

        effectiveIsDone = isDone
        if effectiveRequiresTakeover {
            effectiveIsDone = false
        } else if hasRichExtraction {
            // Check intent type: ONLY inspect / read goals can be deemed done merely due to rich extraction.
            // Action, composition, and send goals (compose, send, interact, create)
            // MUST faithfully respect isDone evaluated by the model, NEVER fake-completed by reading pane text.
            let isActionGoal = isSendGoal || ["compose", "send", "interact", "create", "write"].contains(taskContract?.intentType.lowercased() ?? "")
            if !isActionGoal {
                effectiveIsDone = true
            }
        }

        // Factual Reading Verification for Inspect/Read Intents (Zero Fake Completion):
        let isInspectOrRead = ["inspect", "read"].contains(taskContract?.intentType.lowercased() ?? "")
        if isInspectOrRead {
            // An inspect/reading task can ONLY be done if latestObservation actually contains
            // substantive content in previewPane, reading pane summary, general content, or rich extracted data.
            let hasValidReadingContent: Bool = {
                // 1. JSON observation with previewPane
                if latestObservation.contains("\"previewPane\":"),
                   let data = latestObservation.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let previewItems = json["previewPane"] as? [String] {
                    let combined = previewItems.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !previewItems.isEmpty && combined.count > 5 { return true }
                }

                // 2. Targeted observation string with Reading Pane summary
                if latestObservation.contains("Reading Pane: '") {
                    let parts = latestObservation.components(separatedBy: "Reading Pane: '")
                    if let textPart = parts.dropFirst().first {
                        let content = textPart.prefix(while: { $0 != "'" }).trimmingCharacters(in: .whitespacesAndNewlines)
                        if content.count > 5 { return true }
                    }
                }

                // 3. JSON observation with general content (single-pane apps like Notes, Safari, Terminal)
                if latestObservation.contains("\"content\":"),
                   let data = latestObservation.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let contentItems = json["content"] as? [String] {
                    let combined = contentItems.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !contentItems.isEmpty && combined.count > 5 { return true }
                }

                // 4. Substantive factual extraction per ERR-030 (e.g. list row details or document content)
                let isModalSheetText = extractedData.lowercased().contains("save this message") ||
                                       extractedData.lowercased().contains("unsaved changes") ||
                                       extractedData.lowercased().contains("don't save")
                if hasRichExtraction && !isModalSheetText { return true }
                return false
            }()

            if !hasValidReadingContent {
                effectiveIsDone = false
            }
        }

        // 5. Anti-Hallucination Integrity Guard:
        // If task is not completed (effectiveIsDone == false), responseToUser must NEVER falsely claim success or delivery
        if !effectiveIsDone {
            let forbiddenSuccessPhrases = [
                "email was sent", "email has been sent", "email telah dikirim", "email sudah dikirim",
                "message was sent", "message has been sent", "pesan telah dikirim", "pesan sudah dikirim",
                "successfully sent", "berhasil dikirim", "has been created and sent", "telah dibuat dan dikirim",
                "email terbaru adalah", "email terbaru dari", "pesan terbaru adalah", "pesan terbaru dari",
                "the latest email is", "the newest email is", "the latest message is"
            ]
            let lower = responseToUser.lowercased()
            if forbiddenSuccessPhrases.contains(where: { lower.contains($0) }) {
                let fallbackNotice: String
                if isInspectOrRead {
                    fallbackNotice = lang == "id"
                        ? "Daftar atau konten item belum berhasil dibuka di panel pratinjau."
                        : "The item or content has not been opened in the preview pane yet."
                } else {
                    fallbackNotice = lang == "id"
                        ? "Tindakan belum selesai. Formulir atau bidang input belum sepenuhnya terisi atau dikirimkan."
                        : "The action was not completed. Input fields were not fully submitted."
                }
                responseToUser = fallbackNotice
            }
        }

        // Zero Hardcoded Linguistic Checks:
        // If the model response is empty despite rich factual extraction, deliver the factual findings directly.
        let hasFactualData = !extractedData.isEmpty && extractedData.lowercased() != "none"
        if hasFactualData && responseToUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            responseToUser = extractedData
        }

        return AFMValidationResult(
            isDone: effectiveIsDone,
            systemState: cleanSystemState,
            extractedData: extractedData,
            responseToUser: responseToUser,
            requiresTakeover: effectiveRequiresTakeover
        )
    }

    private static func synthesizeFactualStateFromObservation(_ obs: String) -> String {
        guard let data = obs.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "Screen content verified"
        }
        var parts: [String] = []
        if let fields = dict["formFields"] as? [String: String], !fields.isEmpty {
            let filled = fields.filter { $0.value != "[empty]" && !$0.value.isEmpty }
            if !filled.isEmpty {
                let desc = filled.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                parts.append("Form fields populated: \(desc)")
            }
        }
        if let items = dict["listItems"] as? [[String: Any]], let first = items.first {
            let title = first["headline"] as? String ?? first["content"] as? String ?? ""
            if !title.isEmpty {
                parts.append("List item: \(title)")
            }
        }
        if let preview = dict["previewPane"] as? String, !preview.isEmpty {
            parts.append("Reading pane: \(preview.prefix(80))")
        }
        return parts.isEmpty ? "Factual screen content verified" : parts.joined(separator: "; ")
    }

    private func extractJSONData(from text: String) -> Data? {
        var str = text
        if let start = str.range(of: "{"), let end = str.range(of: "}", options: .backwards), start.lowerBound <= end.lowerBound {
            str = String(str[start.lowerBound...end.lowerBound])
        }
        return str.data(using: .utf8)
    }
}
