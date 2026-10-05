import ClickyPlatform
import ClickyFoundation
//
//  CUATypeActionTool.swift
//  boringNotch (Izanotchy)
//
//  Physical Keyboard Type Tool: Focuses target field via physical left click and executes virtual keystrokes.
//

import AppKit
import Foundation

public final class CUATypeActionTool: CUAPhysicalActionTool, @unchecked Sendable {
    public static let shared = CUATypeActionTool()

    public var supportedActionTypes: [String] {
        ["type", "write", "input"]
    }

    @MainActor
    public func execute(actionType: String, context: CUAPhysicalActionContext) async -> CUAPhysicalActionResult {
        // Step 1: Click target input field to focus
        MascotVirtualDesktopService.shared.performCuaLeftClick(normalizedPoint: context.normalizedPoint)

        // Step 2: Type provided text payload
        if let text = context.textToType, !text.isEmpty {
            try? await Task.sleep(nanoseconds: 200_000_000)
            MascotVirtualDesktopService.shared.performCuaType(text: text)
            return CUAPhysicalActionResult(observationResult: "Typed text into '\(context.targetElement)'")
        }

        return CUAPhysicalActionResult(observationResult: "Focused input field '\(context.targetElement)' (no text to type)")
    }
}
