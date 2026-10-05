import ClickyPlatform
import ClickyFoundation
//
//  CUAPhysicalActionDispatcher.swift
//  izaNotch (Izanotchy)
//
//  Modular CUA Physical Action Dispatcher: Routes atomic sub-goal decisions from the Planner
//  to specialized physical cursor tools (Click, Scroll, Type, Read) without monolothic inline if-else chains.
//

import AppKit
import Foundation

public final class CUAPhysicalActionDispatcher: @unchecked Sendable {
    public static let shared = CUAPhysicalActionDispatcher()

    private let tools: [CUAPhysicalActionTool]

    private init() {
        self.tools = [
            CUAReadActionTool.shared,
            CUAClickActionTool.shared,
            CUAScrollActionTool.shared,
            CUATypeActionTool.shared
        ]
    }

    /// Dispatches an atomic AFM decision to the appropriate physical action tool.
    @MainActor
    public func dispatchAction(
        decision: AFMStepDecision,
        normalizedPoint: CGPoint,
        appName: String,
        targetPID: pid_t?,
        snapshotPath: String?
    ) async -> CUAPhysicalActionResult {
        let actionType = decision.actionType.lowercased()
        let context = CUAPhysicalActionContext(
            normalizedPoint: normalizedPoint,
            appName: appName,
            targetPID: targetPID,
            snapshotPath: snapshotPath,
            subGoal: decision.subGoal,
            targetElement: decision.targetElement,
            textToType: decision.textToType
        )

        for tool in tools {
            if tool.supportedActionTypes.contains(actionType) {
                return await tool.execute(actionType: actionType, context: context)
            }
        }

        // Fallback: Default to left click if action type is unrecognized
        ClickyLogger.warning("[CUA_DISPATCHER]", "Unrecognized actionType '\(decision.actionType)', falling back to ClickActionTool")
        return await CUAClickActionTool.shared.execute(actionType: "click", context: context)
    }
}
