//
//  TaskIngressGateway.swift
//  izaNotch (Izanotchy)
//
//  Ingress Gateway: Normalizes natural language instructions into Canonical English JSON Task Contracts.
//  Zero Linguistic Prompt Injections — Multilingual Semantic Principles & Abstract Schemas.
//

import AppKit
import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

public final class TaskIngressGateway: @unchecked Sendable {
    public static let shared = TaskIngressGateway()

    private init() {}

    /// Deconstructs and normalizes a user prompt into a Canonical English JSON Task Contract
    public func deconstructTaskGoal(
        userPrompt: String,
        companionSlug: String,
        connectedApps: [String] = []
    ) async -> AFMTaskDecomposition {
        let trimmed = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let emptyPlan = AFMTaskDecomposition(
                userIntent: userPrompt,
                targetAppName: "None",
                actionScope: "conversational",
                plannedSubGoals: [],
                requiresCUA: false,
                intentType: "conversational",
                targetEntity: "user",
                targetIndex: nil,
                searchQuery: nil,
                normalizedGoal: "Respond to user conversationally",
                userLanguage: Self.resolveLanguage(prompt: userPrompt)
            )
            return finalizeDecompositionWithRouting(emptyPlan, connectedApps: connectedApps)
        }

        let connectedAppsStr: String = {
            if !connectedApps.isEmpty {
                return connectedApps.joined(separator: ", ")
            }
            let running = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap { $0.localizedName }
            if !running.isEmpty {
                return running.joined(separator: ", ")
            }
            return "Finder, System"
        }()

        let instructions = IngressPolicy.systemInstructions
        let prompt = IngressPolicy.formatPrompt(
            userPrompt: userPrompt,
            companionSlug: companionSlug,
            connectedAppsStr: connectedAppsStr
        )

        // Tier 1: Apple Foundation Models on-device session (NPU Neural Engine)
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                let rawText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsed = parseTaskDecompositionJSON(from: rawText, userPrompt: userPrompt) {
                    ClickyLogger.info("[TASK_INGRESS]", "Decomposed task plan via FoundationModels: targetApp=\(parsed.targetAppName), targetIndex=\(String(describing: parsed.targetIndex)), requiresCUA=\(parsed.requiresCUA)")
                    return finalizeDecompositionWithRouting(parsed, connectedApps: connectedApps)
                }
            } catch {
                ClickyLogger.warning("[TASK_INGRESS]", "FoundationModels decomposition error: \(error.localizedDescription)")
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
                    maxTokens: 256,
                    onTextChunk: { _ in }
                )
                if let parsed = parseTaskDecompositionJSON(from: turnRes.text, userPrompt: userPrompt) {
                    ClickyLogger.info("[TASK_INGRESS]", "Decomposed task plan via SiriAIEngine: targetApp=\(parsed.targetAppName), targetIndex=\(String(describing: parsed.targetIndex))")
                    return finalizeDecompositionWithRouting(parsed, connectedApps: connectedApps)
                }
            } catch {
                ClickyLogger.warning("[TASK_INGRESS]", "SiriAIEngine decomposition error: \(error.localizedDescription)")
            }
        }


        // Safe graceful heuristic fallback
        let lower = userPrompt.lowercased()
        let matchedApp = connectedApps.first { lower.contains($0.lowercased()) }
        let requiresCUA = (matchedApp != nil)
        let candidateApp = matchedApp ?? "None"
        let resolvedLang = Self.resolveLanguage(prompt: userPrompt)

        let fallbackPlan = AFMTaskDecomposition(
            userIntent: userPrompt,
            targetAppName: candidateApp,
            actionScope: requiresCUA ? "Interact with active \(candidateApp) window" : "conversational",
            plannedSubGoals: requiresCUA ? ["Interact with \(candidateApp) interface to fulfill user request"] : [],
            requiresCUA: requiresCUA,
            intentType: requiresCUA ? "interact" : "conversational",
            targetEntity: requiresCUA ? "main_window" : "user",
            targetIndex: nil,
            searchQuery: nil,
            normalizedGoal: userPrompt,
            userLanguage: resolvedLang,
            requiresTakeoverOnCompletion: false
        )
        return finalizeDecompositionWithRouting(fallbackPlan, connectedApps: connectedApps)
    }

    /// Enforces the unified Routing Gate (TASK-046) and emits telemetry.
    private func finalizeDecompositionWithRouting(
        _ rawPlan: AFMTaskDecomposition,
        connectedApps: [String]
    ) -> AFMTaskDecomposition {
        let (tier, reason) = ExecutionRoutingGate.shared.resolveExecutionTier(
            targetAppName: rawPlan.targetAppName,
            intentType: rawPlan.intentType,
            connectedApps: connectedApps,
            isConversational: rawPlan.isConversational
        )

        ClickyLogger.info(
            "[ROUTING]",
            "Task '\(rawPlan.normalizedGoal)' -> tier=\(tier), reason='\(reason)' [targetApp=\(rawPlan.targetAppName), intentType=\(rawPlan.intentType), connectedApps=[\(connectedApps.joined(separator: ", "))]]"
        )

        return AFMTaskDecomposition(
            userIntent: rawPlan.userIntent,
            targetAppName: rawPlan.targetAppName,
            actionScope: rawPlan.actionScope,
            plannedSubGoals: rawPlan.plannedSubGoals,
            requiresCUA: rawPlan.requiresCUA,
            intentType: rawPlan.intentType,
            targetEntity: rawPlan.targetEntity,
            targetContainer: rawPlan.targetContainer,
            targetSection: rawPlan.targetSection,
            targetIndex: rawPlan.targetIndex,
            searchQuery: rawPlan.searchQuery,
            normalizedGoal: rawPlan.normalizedGoal,
            userLanguage: rawPlan.userLanguage,
            requiresTakeoverOnCompletion: rawPlan.requiresTakeoverOnCompletion,
            executionTier: tier,
            routingReason: reason
        )
    }

    /// Dynamically resolves user language using Apple's on-device NaturalLanguage framework
    public static func resolveLanguage(prompt: String, modelDetected: String? = nil) -> String {
        if let detected = modelDetected?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !detected.isEmpty, detected != "unspecified" {
            return detected
        }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Locale.current.language.languageCode?.identifier ?? "id"
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        if let dominant = recognizer.dominantLanguage?.rawValue, !dominant.isEmpty {
            return dominant
        }
        return "id"
    }

    /// Reconciles model-extracted targetIndex with explicit digits and ordinal words in user instruction.
    public static func reconcileTargetIndex(extractedIndex: Int?, userPrompt: String) -> Int? {
        let lower = userPrompt.lowercased()
        let ordinals: [(word: String, value: Int)] = [
            ("pertama", 1), ("first", 1), ("ke-1", 1), ("ke 1", 1),
            ("kedua", 2), ("second", 2), ("ke-2", 2), ("ke 2", 2),
            ("ketiga", 3), ("third", 3), ("ke-3", 3), ("ke 3", 3),
            ("keempat", 4), ("fourth", 4), ("ke-4", 4), ("ke 4", 4),
            ("kelima", 5), ("fifth", 5), ("ke-5", 5), ("ke 5", 5),
            ("keenam", 6), ("sixth", 6), ("ke-6", 6), ("ke 6", 6),
            ("ketujuh", 7), ("seventh", 7), ("ke-7", 7), ("ke 7", 7),
            ("kedelapan", 8), ("eighth", 8), ("ke-8", 8), ("ke 8", 8),
            ("kesembilan", 9), ("ninth", 9), ("ke-9", 9), ("ke 9", 9),
            ("kesepuluh", 10), ("tenth", 10), ("ke-10", 10), ("ke 10", 10)
        ]
        for entry in ordinals {
            if lower.contains(entry.word) {
                return entry.value
            }
        }

        let pattern = #"\b\d+\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return extractedIndex }
        let matches = regex.matches(in: userPrompt, range: NSRange(userPrompt.startIndex..., in: userPrompt))
        let promptNumbers: [Int] = matches.compactMap { match in
            guard let range = Range(match.range, in: userPrompt) else { return nil }
            return Int(userPrompt[range])
        }
        if let extracted = extractedIndex {
            if !promptNumbers.contains(extracted), let exactNumber = promptNumbers.first(where: { abs($0 - extracted) <= 1 && $0 > 0 }) {
                return exactNumber
            }
            return extracted
        }
        return promptNumbers.first
    }

    private func parseTaskDecompositionJSON(from text: String, userPrompt: String = "") -> AFMTaskDecomposition? {
        guard let data = extractJSONData(from: text) else { return nil }

        if var direct = try? JSONDecoder().decode(AFMTaskDecomposition.self, from: data) {
            let finalLang = Self.resolveLanguage(prompt: userPrompt, modelDetected: direct.userLanguage)
            let isConversational = direct.intentType.lowercased() == "conversational" || direct.targetAppName.lowercased() == "none"
            let requiresCUA = isConversational ? false : (direct.targetAppName.lowercased() == "none" ? false : true)
            let isInspect = direct.intentType.lowercased() == "inspect" || direct.intentType.lowercased() == "read"
            let isComposeOrSend = direct.intentType.lowercased() == "compose" ||
                                  direct.intentType.lowercased() == "send" ||
                                  direct.intentType.lowercased() == "create"
            let rawContainer = isConversational ? nil : direct.targetContainer
            let targetContainer: String?
            if let c = rawContainer {
                let lowerPrompt = userPrompt.lowercased()
                let knownFolders = ["inbox", "kotak masuk", "sent", "terkirim", "draft", "draf", "trash", "sampah", "junk", "spam", "archive", "arsip", "flagged", "ditandai", "all inboxes", "semua kotak masuk"]
                let promptMentionsFolder = knownFolders.contains { lowerPrompt.contains($0) }
                targetContainer = promptMentionsFolder ? c : nil
            } else {
                targetContainer = nil
            }
            let targetSection = isConversational ? nil : direct.targetSection
            let rawQuery = isConversational ? nil : direct.searchQuery
            let resolvedQuery: String?
            if let q = rawQuery?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
               q == "saya" || q == "me" || q == "my email" || q == "email saya" || q == "emailku" || q == "aku" || q == "user" {
                resolvedQuery = nil
            } else if isInspect && userPrompt.lowercased().contains("email saya") && (rawQuery?.lowercased() == "saya" || rawQuery?.lowercased().contains("saya") == true) {
                resolvedQuery = nil
            } else {
                resolvedQuery = rawQuery
            }

            var finalGoal = direct.normalizedGoal
            if resolvedQuery == nil && isInspect {
                let gLower = finalGoal.lowercased()
                if gLower.contains("related to saya") || gLower.contains("from saya") || gLower.contains("addressed to 'saya'") || gLower.contains("labeled 'saya'") || gLower.contains("email from 'saya'") {
                    finalGoal = "Inspect and read the latest email from the user's inbox."
                }
            }

            let resolvedIndex: Int?
            if isConversational || isComposeOrSend {
                resolvedIndex = nil
            } else if let rawIdx = direct.targetIndex {
                resolvedIndex = Self.reconcileTargetIndex(extractedIndex: rawIdx, userPrompt: userPrompt)
            } else if let recIdx = Self.reconcileTargetIndex(extractedIndex: nil, userPrompt: userPrompt) {
                resolvedIndex = recIdx
            } else if isInspect && resolvedQuery == nil && targetContainer == nil {
                resolvedIndex = 1
            } else {
                resolvedIndex = nil
            }
            let requiresTakeover: Bool
            if isConversational || isInspect {
                requiresTakeover = false
            } else if direct.intentType.lowercased() == "send" {
                requiresTakeover = true
            } else {
                requiresTakeover = direct.requiresTakeoverOnCompletion
            }

            return AFMTaskDecomposition(
                userIntent: direct.userIntent,
                targetAppName: isConversational ? "None" : direct.targetAppName,
                actionScope: isConversational ? "conversational" : direct.actionScope,
                plannedSubGoals: isConversational ? [] : direct.plannedSubGoals,
                requiresCUA: requiresCUA,
                intentType: isConversational ? "conversational" : direct.intentType,
                targetEntity: isConversational ? "user" : direct.targetEntity,
                targetContainer: targetContainer,
                targetSection: targetSection,
                targetIndex: resolvedIndex,
                searchQuery: resolvedQuery,
                normalizedGoal: finalGoal,
                userLanguage: finalLang,
                requiresTakeoverOnCompletion: requiresTakeover
            )
        }
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let intent = dict["userIntent"] as? String ?? dict["user_intent"] as? String ?? ""
            let app = dict["targetAppName"] as? String ?? dict["target_app_name"] as? String ?? "None"
            let scope = dict["actionScope"] as? String ?? dict["action_scope"] as? String ?? ""
            let subGoals = dict["plannedSubGoals"] as? [String] ?? dict["planned_sub_goals"] as? [String] ?? []
            let intentType = dict["intentType"] as? String ?? dict["intent_type"] as? String ?? (app == "None" ? "conversational" : "inspect")
            let isConversational = intentType.lowercased() == "conversational" || app.lowercased() == "none"
            let requiresCUA = isConversational ? false : (app.lowercased() == "none" ? false : true)
            let targetEntity = isConversational ? "user" : (dict["targetEntity"] as? String ?? dict["target_entity"] as? String ?? "main_window")
            let targetContainer = isConversational ? nil : (dict["targetContainer"] as? String ?? dict["target_container"] as? String)
            let targetSection = isConversational ? nil : (dict["targetSection"] as? String ?? dict["target_section"] as? String)
            let rawIndex = dict["targetIndex"] as? Int ?? dict["target_index"] as? Int
            let rawQuery = dict["searchQuery"] as? String ?? dict["search_query"] as? String
            let resolvedQuery: String?
            if isConversational {
                resolvedQuery = nil
            } else if let q = rawQuery?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
               q == "saya" || q == "me" || q == "my email" || q == "email saya" || q == "emailku" || q == "aku" || q == "user" {
                resolvedQuery = nil
            } else if (dict["intentType"] as? String ?? "").lowercased() == "inspect" && userPrompt.lowercased().contains("email saya") && (rawQuery?.lowercased() == "saya" || rawQuery?.lowercased().contains("saya") == true) {
                resolvedQuery = nil
            } else {
                resolvedQuery = rawQuery
            }

            let isInspect = intentType.lowercased() == "inspect" || intentType.lowercased() == "read"
            let isComposeOrSend = intentType.lowercased() == "compose" || intentType.lowercased() == "send" || intentType.lowercased() == "create"
            let resolvedIndex: Int?
            if isConversational || isComposeOrSend {
                resolvedIndex = nil
            } else if let rawIdx = rawIndex {
                resolvedIndex = Self.reconcileTargetIndex(extractedIndex: rawIdx, userPrompt: userPrompt)
            } else if isInspect && resolvedQuery == nil && targetContainer == nil {
                resolvedIndex = 1
            } else {
                resolvedIndex = nil
            }

            var normalizedGoal = dict["normalizedGoal"] as? String ?? dict["normalized_goal"] as? String ?? intent
            if resolvedQuery == nil && isInspect {
                let gLower = normalizedGoal.lowercased()
                if gLower.contains("related to saya") || gLower.contains("from saya") || gLower.contains("addressed to 'saya'") || gLower.contains("labeled 'saya'") || gLower.contains("email from 'saya'") {
                    normalizedGoal = "Inspect and read the latest email from the user's inbox."
                }
            }

            let rawLang = dict["userLanguage"] as? String ?? dict["user_language"] as? String
            let userLanguage = Self.resolveLanguage(prompt: userPrompt, modelDetected: rawLang)
            let rawTakeover = (dict["requiresTakeoverOnCompletion"] as? Bool ?? dict["requires_takeover_on_completion"] as? Bool ?? false)
            let requiresTakeover: Bool
            if isConversational || isInspect {
                requiresTakeover = false
            } else {
                requiresTakeover = rawTakeover
            }

            if !intent.isEmpty || !subGoals.isEmpty || requiresCUA || !normalizedGoal.isEmpty {
                return AFMTaskDecomposition(
                    userIntent: intent.isEmpty ? "Execute user request" : intent,
                    targetAppName: isConversational ? "None" : app,
                    actionScope: isConversational ? "conversational" : scope,
                    plannedSubGoals: isConversational ? [] : subGoals,
                    requiresCUA: requiresCUA,
                    intentType: isConversational ? "conversational" : intentType,
                    targetEntity: targetEntity,
                    targetContainer: targetContainer,
                    targetSection: targetSection,
                    targetIndex: resolvedIndex,
                    searchQuery: resolvedQuery,
                    normalizedGoal: normalizedGoal.isEmpty ? intent : normalizedGoal,
                    userLanguage: userLanguage,
                    requiresTakeoverOnCompletion: requiresTakeover
                )
            }
        }
        return nil
    }

    private func extractJSONData(from text: String) -> Data? {
        var str = text
        if let start = str.range(of: "{"), let end = str.range(of: "}", options: .backwards), start.lowerBound <= end.lowerBound {
            str = String(str[start.lowerBound...end.lowerBound])
        }
        return str.data(using: .utf8)
    }
}
