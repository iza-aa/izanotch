//
//  TaskStepPlanner.swift
//  izaNotch (Izanotchy)
//
//  Task Step Planner: Plans the next atomic CUA action based on the Canonical Task Contract.
//  Zero Linguistic Prompt Injections — Dynamic Ordinal Targeting & Abstract Schemas.
//

import AppKit
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public final class TaskStepPlanner: @unchecked Sendable {
    public static let shared = TaskStepPlanner()

    private init() {}

    /// Requests AFM on-device or cloud fallback to plan the single next atomic sub-goal
    public func planNextStep(
        userGoal: String,
        currentStep: Int,
        appName: String,
        lastObservation: String?,
        historySummary: [String],
        taskContract: AFMTaskDecomposition? = nil
    ) async -> AFMStepDecision {
        let goalText = taskContract?.normalizedGoal.isEmpty == false ? taskContract!.normalizedGoal : userGoal
        let intentType = taskContract?.intentType ?? "inspect"
        let targetEntity = taskContract?.targetEntity ?? "main_window"
        let targetContainer = taskContract?.targetContainer ?? "unspecified"
        let searchQuery = taskContract?.searchQuery ?? "none"
        let effectiveTargetIndex = taskContract?.targetIndex ?? ((intentType == "inspect" || intentType == "read") && searchQuery == "none" && targetContainer == "unspecified" ? 1 : nil)
        let targetIndexStr = effectiveTargetIndex != nil ? "\(effectiveTargetIndex!)" : "unspecified"

        let policy = StepPolicyRegistry.policy(for: intentType)
        let instructions = policy.buildInstructions(
            appName: appName,
            targetIndexStr: targetIndexStr,
            targetContainer: targetContainer
        )



        let cleanObs: String
        if let obs = lastObservation, !obs.isEmpty {
            cleanObs = obs.count > 1000 ? String(obs.prefix(1000)) + "... [truncated]" : obs
        } else {
            cleanObs = "App is open in workspace"
        }

        let sectionStr = taskContract?.targetSection ?? "unspecified"
        let prompt = """
        Goal: "\(goalText)" (intent: \(intentType), section: \(sectionStr), container: \(targetContainer), target: \(targetEntity), index: \(targetIndexStr))
        App: \(appName) | Step: \(currentStep)
        Previous: [\(historySummary.joined(separator: ", "))]
        Observation: "\(cleanObs)"
        Determine the next atomic UI sub-goal.
        """

        // Tier 1: Apple Foundation Models on-device session (NPU Neural Engine)
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                let rawText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

                if let parsed = parseDecisionJSON(from: rawText) {
                    ClickyLogger.info("[TASK_PLANNER]", "AFM planned step \(currentStep): [\(parsed.actionType)] \(parsed.subGoal) -> Target: '\(parsed.targetElement)'")
                    return parsed
                }
            } catch {
                ClickyLogger.warning("[TASK_PLANNER]", "AFM on-device planning error: \(error.localizedDescription)")
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
                    maxTokens: 160,
                    onTextChunk: { _ in }
                )
                if let parsed = parseDecisionJSON(from: turnRes.text) {
                    ClickyLogger.info("[TASK_PLANNER]", "AFM (SiriAIEngine) planned step \(currentStep): [\(parsed.actionType)] \(parsed.subGoal)")
                    return parsed
                }
            } catch {
                ClickyLogger.warning("[TASK_PLANNER]", "SiriAIEngine planning error: \(error.localizedDescription)")
            }
        }


        // Safe graceful heuristic fallback
        let targetLabel = taskContract?.targetIndex != nil ? "item \(taskContract!.targetIndex!)" : targetEntity
        if currentStep == 1 {
            return AFMStepDecision(
                thought: "Inspect target window to locate \(targetLabel)",
                subGoal: "Inspect \(appName) and observe \(targetLabel)",
                targetElement: "\(appName) main window",
                actionType: "read",
                isFinished: false
            )
        } else {
            return AFMStepDecision(
                thought: "Target information observed in workspace",
                subGoal: "Conclude task and synthesize results",
                targetElement: "\(appName) interface",
                actionType: "done",
                isFinished: true
            )
        }
    }

    private func sanitizeTargetElement(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 1. Deterministic noise stripper: remove parenthetical descriptions (e.g. "(typically a paperclip...)")
        str = str.replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression)
        // 2. Deterministic anti-JSON-path guard: strip and extract leaf if internal path/array syntax is leaked
        if str.contains("$") || str.contains("[") || str.hasPrefix(".") {
            str = str.components(separatedBy: CharacterSet(charactersIn: "$.[]")).filter { !$0.isEmpty }.last ?? str
        }
        // 3. Clean quotes or punctuation noise
        str = str.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`.,:; "))
        return str
    }

    public static var jsonRepairCount: Int = 0
    private static let plannerKeys = ["thought", "subGoal", "targetElement", "actionType", "textToType", "isFinished"]

    private func repairMissingKeyQuotes(_ raw: String) -> String {
        var out = raw
        for key in Self.plannerKeys {
            for p in [",\\s*\(key)\"\\s*:", ",\\s*\(key)\\s*:", "\\{\\s*\(key)\\s*:"] {
                guard let rx = try? NSRegularExpression(pattern: p) else { continue }
                out = rx.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: ",\"\(key)\":")
            }
        }
        return out
    }

    private func extractFieldsFallback(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        for key in Self.plannerKeys {
            let p = "\"?\\b\(key)\\b\"?\\s*:\\s*(\"(?:[^\"\\\\]|\\\\.)*\"|true|false|null|[0-9]+)"
            guard let rx = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) else { continue }
            let matches = rx.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
            if let m = matches.last, m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: raw) {
                var val = String(raw[r])
                if val.hasPrefix("\"") && val.hasSuffix("\"") && val.count >= 2 {
                    val = String(val.dropFirst().dropLast())
                }
                result[key] = val
            }
        }
        return result
    }

    private func parseDecisionJSON(from text: String) -> AFMStepDecision? {
        // Tier 1: Direct JSON parsing
        if let data = extractJSONData(from: text) {
            if let direct = try? JSONDecoder().decode(AFMStepDecision.self, from: data) {
                let sanitized = sanitizeTargetElement(direct.targetElement)
                return AFMStepDecision(
                    thought: direct.thought,
                    subGoal: direct.subGoal,
                    targetElement: sanitized.isEmpty ? direct.subGoal : sanitized,
                    actionType: direct.actionType,
                    textToType: direct.textToType,
                    isFinished: direct.isFinished
                )
            }
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let thought = dict["thought"] as? String ?? ""
                let subGoal = dict["subGoal"] as? String ?? dict["sub_goal"] as? String ?? ""
                let rawTarget = dict["targetElement"] as? String ?? dict["target_element"] as? String ?? ""
                let sanitizedTarget = sanitizeTargetElement(rawTarget)
                let actionType = dict["actionType"] as? String ?? dict["action_type"] as? String ?? "click"
                let textToType = dict["textToType"] as? String ?? dict["text_to_type"] as? String
                let isFinished = dict["isFinished"] as? Bool ?? dict["is_finished"] as? Bool ?? false

                if !subGoal.isEmpty || !sanitizedTarget.isEmpty {
                    return AFMStepDecision(
                        thought: thought,
                        subGoal: subGoal.isEmpty ? sanitizedTarget : subGoal,
                        targetElement: sanitizedTarget.isEmpty ? subGoal : sanitizedTarget,
                        actionType: actionType,
                        textToType: textToType,
                        isFinished: isFinished
                    )
                }
            }
        }

        // Tier 2: Syntax quote repair
        let repaired = repairMissingKeyQuotes(text)
        if let data = extractJSONData(from: repaired),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            Self.jsonRepairCount += 1
            ClickyLogger.info("[TASK_PLANNER]", "Repaired malformed JSON syntax via key-quote recovery (telemetry count: \(Self.jsonRepairCount))")
            let thought = dict["thought"] as? String ?? ""
            let subGoal = dict["subGoal"] as? String ?? dict["sub_goal"] as? String ?? ""
            let rawTarget = dict["targetElement"] as? String ?? dict["target_element"] as? String ?? ""
            let sanitizedTarget = sanitizeTargetElement(rawTarget)
            let actionType = dict["actionType"] as? String ?? dict["action_type"] as? String ?? "click"
            let textToType = dict["textToType"] as? String ?? dict["text_to_type"] as? String
            let isFinished = dict["isFinished"] as? Bool ?? dict["is_finished"] as? Bool ?? false

            return AFMStepDecision(
                thought: thought,
                subGoal: subGoal.isEmpty ? sanitizedTarget : subGoal,
                targetElement: sanitizedTarget.isEmpty ? subGoal : sanitizedTarget,
                actionType: actionType,
                textToType: textToType,
                isFinished: isFinished
            )
        }

        // Tier 3: Regex field extraction fallback
        let fields = extractFieldsFallback(text)
        if !fields.isEmpty {
            Self.jsonRepairCount += 1
            ClickyLogger.info("[TASK_PLANNER]", "Recovered decision via regex field extraction fallback (telemetry count: \(Self.jsonRepairCount))")
            let thought = fields["thought"] ?? ""
            let subGoal = fields["subGoal"] ?? fields["sub_goal"] ?? ""
            let rawTarget = fields["targetElement"] ?? fields["target_element"] ?? ""
            let sanitizedTarget = sanitizeTargetElement(rawTarget)
            let actionType = fields["actionType"] ?? fields["action_type"] ?? "click"
            let textToType = fields["textToType"] ?? fields["text_to_type"]
            let isFinished = fields["isFinished"]?.lowercased() == "true"

            if !subGoal.isEmpty || !sanitizedTarget.isEmpty {
                return AFMStepDecision(
                    thought: thought,
                    subGoal: subGoal.isEmpty ? sanitizedTarget : subGoal,
                    targetElement: sanitizedTarget.isEmpty ? subGoal : sanitizedTarget,
                    actionType: actionType,
                    textToType: textToType,
                    isFinished: isFinished
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
