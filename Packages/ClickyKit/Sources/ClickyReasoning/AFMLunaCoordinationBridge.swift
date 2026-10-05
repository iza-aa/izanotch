import ClickyFoundation
//
//  AFMLunaCoordinationBridge.swift
//  boringNotch (Izanotchy)
//
//  Unified Coordination Facade:
//  - TaskIngressGateway: Ingress Language Normalization & Canonical Contract Decomposition
//  - TaskStepPlanner: AFM Dynamic Step Reasoner
//  - TaskEgressValidator: Factual Validation & User Response Synthesis
//  - Luna Vision: High-Resolution Visual Perception & Element Grounder
//

import AppKit
import ClickyAIProviders
import ClickyCUA
import ClickyFoundation
import Foundation

public final class AFMLunaCoordinationBridge: @unchecked Sendable {
    public static let shared = AFMLunaCoordinationBridge()
    
    private init() {}
    
    /// Deconstructs a high-level user goal into an explicit task definition: intent, target application, action scope, and step-by-step sub-goals.
    /// 100% reasoned dynamically by model without hardcoded switch-cases or dictionary injections.
    public func deconstructTaskGoalWithAFM(
        userPrompt: String,
        companionSlug: String,
        connectedApps: [String] = []
    ) async -> AFMTaskDecomposition {
        await TaskIngressGateway.shared.deconstructTaskGoal(
            userPrompt: userPrompt,
            companionSlug: companionSlug,
            connectedApps: connectedApps
        )
    }
    
    /// Requests AFM on-device to plan the next atomic sub-goal given the user's objective and past step records
    public func planNextStepWithAFM(
        userGoal: String,
        currentStep: Int,
        appName: String,
        lastObservation: String?,
        historySummary: [String],
        taskContract: AFMTaskDecomposition? = nil
    ) async -> AFMStepDecision {
        await TaskStepPlanner.shared.planNextStep(
            userGoal: userGoal,
            currentStep: currentStep,
            appName: appName,
            lastObservation: lastObservation,
            historySummary: historySummary,
            taskContract: taskContract
        )
    }
    
    /// Requests Luna (6 Luna Medium Vision) to visually locate the target element in the isolated workspace screenshot
    public func perceiveElementWithLuna(
        snapshotPath: String,
        targetElement: String,
        subGoal: String,
        pid: pid_t?
    ) async -> LunaPerceptionResult? {
        // Fast-path: Quick bounded AXUIElement check (1.2s timeout)
        if let pid = pid, pid > 0 {
            if let axPoint = await ClickyHybridGroundingEngine.shared.locateViaAXUIElementAsync(pid: pid, targetQuery: targetElement, timeoutSeconds: 1.2) {
                ClickyLogger.info("[LUNA_PERCEPTION]", "Resolved '\(targetElement)' via Fast-Path AX at (\(Int(axPoint.x)), \(Int(axPoint.y)))")
                return LunaPerceptionResult(targetElement: targetElement, coordinate: axPoint, confidence: 1.0, sourceMethod: "AXUIElement")
            }
        }
        
        // Primary Vision: 6 Luna Medium Headless Vision VM
        if FileManager.default.fileExists(atPath: snapshotPath) {
            do {
                ClickyLogger.info("[LUNA_PERCEPTION]", "Consulting 6 Luna Medium Vision for: '\(targetElement)' (Sub-goal: \(subGoal))...")
                let codexHome = await ChatGPTAccountPoolManager.shared.getActiveCodexHome()
                let visionRes = try await ChatGPTCodexVisionService.shared.queryCoordinates(
                    imagePath: snapshotPath,
                    targetElementPrompt: targetElement,
                    codexHome: codexHome
                )
                let point = CGPoint(x: CGFloat(visionRes.x), y: CGFloat(visionRes.y))
                ClickyLogger.info("[LUNA_PERCEPTION]", "Luna localized '\(targetElement)' at (\(visionRes.x), \(visionRes.y)) [conf: \(visionRes.confidence)]")
                return LunaPerceptionResult(targetElement: targetElement, coordinate: point, confidence: visionRes.confidence, sourceMethod: "6 Luna Medium Vision")
            } catch {
                ClickyLogger.warning("[LUNA_PERCEPTION]", "Luna vision perception failed: \(error.localizedDescription)")
            }
        }
        
        return nil
    }

    /// Requests AFM to validate whether the state transition or final goal is reached
    public func validateWithAFM(
        userGoal: String,
        appName: String,
        performedSteps: [String],
        latestObservation: String,
        taskContract: AFMTaskDecomposition? = nil
    ) async -> AFMValidationResult {
        await TaskEgressValidator.shared.validate(
            userGoal: userGoal,
            appName: appName,
            performedSteps: performedSteps,
            latestObservation: latestObservation,
            taskContract: taskContract
        )
    }
}
