//
//  CUATypeActionTool.swift
//  izaNotch (Izanotchy)
//
//  Physical Keyboard Type Tool: Focuses target field via physical left click and executes virtual keystrokes.
//

import AppKit
import Foundation

public final class CUATypeActionTool: CUAPhysicalActionTool, @unchecked Sendable {
    public static let shared = CUATypeActionTool()

    public var supportedActionTypes: [String] {
        ["type", "write", "input", "clear", "delete"]
    }

    @MainActor
    public func execute(actionType: String, context: CUAPhysicalActionContext) async -> CUAPhysicalActionResult {
        // Step 1: Click target input field and focus via Accessibility IPC
        if let pid = context.targetPID {
            _ = MascotVirtualDesktopService.shared.resolveEffectivePid(explicitPid: pid)
        }
        MascotVirtualDesktopService.shared.performCuaLeftClick(normalizedPoint: context.normalizedPoint, pid: context.targetPID)

        var isTokenField = false
        var focusedRole = ""
        if let pid = context.targetPID ?? MascotVirtualDesktopService.shared.currentAppPid {
            let screenPoint = MascotVirtualDesktopService.shared.targetDisplayCoordinate(for: context.normalizedPoint)
            let focusResult = await CUAClickActionTool.executeBackgroundAccessibilityFocus(pid: pid, screenPoint: screenPoint)
            isTokenField = focusResult.isTokenField
            focusedRole = focusResult.focusedRole
        }

        // Post-Click Focus Verification (P2 Mandate, run in background queue with 0.20s timeout)
        if let pid = context.targetPID ?? MascotVirtualDesktopService.shared.currentAppPid {
            let isEditableFocused = await Task.detached(priority: .userInitiated) { () -> Bool in
                let appRef = AXUIElementCreateApplication(pid)
                AXUIElementSetMessagingTimeout(appRef, 0.20)
                var focusedRef: CFTypeRef?
                let focusStatus = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedRef)
                if focusStatus == .success, let focusedElem = focusedRef {
                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(focusedElem as! AXUIElement, kAXRoleAttribute as CFString, &roleRef)
                    let fRole = ((roleRef as? String) ?? "").lowercased()
                    let editableRoles: Set<String> = ["axtextfield", "axtextarea", "axsearchfield", "axcombobox", "axwebarea"]
                    return editableRoles.contains(fRole)
                }
                return false
            }.value

            if !isEditableFocused {
                ClickyLogger.warning("[CUA_TYPE_TOOL]", "Post-Click Focus Verification: element on PID \(pid) is not yet editable. Advancing focus via Tab.")
                MascotVirtualDesktopService.shared.performCuaKey(keyCode: 0x30, pid: context.targetPID)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        // Handle explicit clear/delete action
        if actionType == "clear" || actionType == "delete" {
            try? await Task.sleep(nanoseconds: 100_000_000)
            MascotVirtualDesktopService.shared.performCuaSelectAll(clearAfter: true)
            return CUAPhysicalActionResult(observationResult: "Cleared text in '\(context.targetElement)'")
        }

        // Step 1b: Caret activation based strictly on role affordance (AXWebArea / WebKit container)
        if focusedRole == "axwebarea" {
            try? await Task.sleep(nanoseconds: 60_000_000)
            MascotVirtualDesktopService.shared.performCuaLeftClick(normalizedPoint: context.normalizedPoint, pid: context.targetPID)
        }

        // Step 2: Select all existing text in field so new text cleanly overwrites any dirty text
        try? await Task.sleep(nanoseconds: 100_000_000)
        MascotVirtualDesktopService.shared.performCuaSelectAll(clearAfter: false)
        // Step 3: Type provided text payload
        var payloadText = context.textToType
        if (payloadText == nil || payloadText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) && actionType != "clear" && actionType != "delete" {
            let target = context.targetElement.lowercased()
            if target.contains("body") || target.contains("isi") || target.contains("message") {
                payloadText = Self.extractPayloadFromPrompt(context.subGoal)
            }
        }

        if let text = payloadText, !text.isEmpty {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MascotVirtualDesktopService.shared.performCuaType(text: text, pid: context.targetPID)

            // Step 4: If target is a token field (subrole AXTokenField / recipient list), commit token chip via Return
            if isTokenField && !text.contains("\n") {
                try? await Task.sleep(nanoseconds: 100_000_000)
                MascotVirtualDesktopService.shared.commitTokenField(pid: context.targetPID)
                ClickyLogger.info("[CUA_TYPE_TOOL]", "Committed token field chip for '\(context.targetElement)'")
            }

            return CUAPhysicalActionResult(observationResult: "Typed text into '\(context.targetElement)'\(isTokenField ? " [token committed]" : "")")
        }
        return CUAPhysicalActionResult(observationResult: "Focused input field '\(context.targetElement)' (no text to type)")
    }

    public static func extractPayloadFromPrompt(_ prompt: String) -> String {
        let lower = prompt.lowercased()
        let markers = ["bahwa ", "isinya ", "isi: ", "isi ", "dengan pesan ", "dengan isi ", "message: ", "message ", "content: ", "content "]
        for marker in markers {
            if let range = lower.range(of: marker) {
                let candidate = String(prompt[range.upperBound...]).trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
                if !candidate.isEmpty {
                    return candidate
                }
            }
        }
        return ""
    }
}
