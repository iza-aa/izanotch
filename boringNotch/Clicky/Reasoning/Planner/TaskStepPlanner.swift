//
//  TaskStepPlanner.swift
//  boringNotch (Izanotchy)
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
        let searchQuery = taskContract?.searchQuery ?? "none"
        let effectiveTargetIndex = taskContract?.targetIndex ?? ((intentType == "inspect" || intentType == "read") && searchQuery == "none" ? 1 : nil)
        let targetIndexStr = effectiveTargetIndex != nil ? "\(effectiveTargetIndex!)" : "unspecified"

        let policy = StepPolicyRegistry.policy(for: intentType)
        let instructions = policy.buildInstructions(
            appName: appName,
            targetIndexStr: targetIndexStr
        )



        let cleanObs: String
        if let obs = lastObservation, !obs.isEmpty {
            cleanObs = obs.count > 1000 ? String(obs.prefix(1000)) + "... [truncated]" : obs
        } else {
            cleanObs = "App is open in workspace"
        }

        let prompt = """
        Goal: "\(goalText)" (intent: \(intentType), target: \(targetEntity), index: \(targetIndexStr))
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

        // Tier 3: Model reasoning fallback via GeminiBridgeClient
        do {
            let turnRes = try await CompanionManager.shared.geminiClient.analyzeMessagesWithToolsStreaming(
                messages: [["role": "user", "content": prompt]],
                systemPrompt: instructions,
                tools: [],
                maxTokens: 512,
                onTextChunk: { _ in }
            )
            if let parsed = parseDecisionJSON(from: turnRes.text) {
                ClickyLogger.info("[TASK_PLANNER]", "Gemini planned step \(currentStep): [\(parsed.actionType)] \(parsed.subGoal)")
                return parsed
            }
        } catch {
            ClickyLogger.warning("[TASK_PLANNER]", "Gemini planning error: \(error.localizedDescription)")
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

    private func parseDecisionJSON(from text: String) -> AFMStepDecision? {

        guard let data = extractJSONData(from: text) else { return nil }
        if let direct = try? JSONDecoder().decode(AFMStepDecision.self, from: data) {
            return direct
        }
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let thought = dict["thought"] as? String ?? ""
            let subGoal = dict["subGoal"] as? String ?? dict["sub_goal"] as? String ?? ""
            let targetElement = dict["targetElement"] as? String ?? dict["target_element"] as? String ?? ""
            let actionType = dict["actionType"] as? String ?? dict["action_type"] as? String ?? "click"
            let textToType = dict["textToType"] as? String ?? dict["text_to_type"] as? String
            let isFinished = dict["isFinished"] as? Bool ?? dict["is_finished"] as? Bool ?? false

            if !subGoal.isEmpty || !targetElement.isEmpty {
                return AFMStepDecision(
                    thought: thought,
                    subGoal: subGoal.isEmpty ? targetElement : subGoal,
                    targetElement: targetElement.isEmpty ? subGoal : targetElement,
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
