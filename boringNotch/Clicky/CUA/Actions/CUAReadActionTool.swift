//
//  CUAReadActionTool.swift
//  boringNotch (Izanotchy)
//
//  Perceptual Observation Tool: Reads structured UI hierarchy and visual content from the target application window.
//

import AppKit
import Foundation

public final class CUAReadActionTool: CUAPhysicalActionTool, @unchecked Sendable {
    public static let shared = CUAReadActionTool()

    public var supportedActionTypes: [String] {
        ["read", "inspect", "observe"]
    }

    @MainActor
    public func execute(actionType: String, context: CUAPhysicalActionContext) async -> CUAPhysicalActionResult {
        let obsJSON = await CompanionVMAgentLoop.shared.readStructuredObservation(
            appName: context.appName,
            pid: context.targetPID,
            snapshotPath: context.snapshotPath
        )
        let result = "Observed \(context.targetElement):\n" + obsJSON
        ClickyLogger.info("[CUA_READ_TOOL]", "Read observation for '\(context.targetElement)': \(obsJSON.prefix(120))...")
        return CUAPhysicalActionResult(observationResult: result)
    }
}
