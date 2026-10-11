//
//  CUAClickActionTool.swift
//  izaNotch (Izanotchy)
//
//  Physical Mouse Click Tool: Handles left click, right click (2-finger tap on macOS), press and hold, and drag.
//

import AppKit
import ApplicationServices
import Foundation

public final class CUAClickActionTool: CUAPhysicalActionTool, @unchecked Sendable {
    public static let shared = CUAClickActionTool()

    public var supportedActionTypes: [String] {
        ["click", "left_click", "right_click", "press_and_hold", "drag"]
    }

    @MainActor
    public func execute(actionType: String, context: CUAPhysicalActionContext) async -> CUAPhysicalActionResult {
        let act = actionType.lowercased()

        if act == "right_click" {
            MascotVirtualDesktopService.shared.performCuaRightClick(normalizedPoint: context.normalizedPoint)
            return CUAPhysicalActionResult(observationResult: "Executed right_click on '\(context.targetElement)'")
        } else if act == "press_and_hold" {
            MascotVirtualDesktopService.shared.performCuaPressAndHold(normalizedPoint: context.normalizedPoint, durationMs: 500)
            return CUAPhysicalActionResult(observationResult: "Executed press_and_hold on '\(context.targetElement)'")
        } else if act == "drag" {
            MascotVirtualDesktopService.shared.performCuaDrag(from: MascotVirtualDesktopService.shared.virtualReticle, to: context.normalizedPoint)
            return CUAPhysicalActionResult(observationResult: "Executed drag to '\(context.targetElement)'")
        } else {
            // Default left click: trigger physical cursor ripple on virtual canvas
            MascotVirtualDesktopService.shared.performCuaLeftClick(normalizedPoint: context.normalizedPoint, pid: context.targetPID)
            // Execute deterministic background element selection/press via Accessibility IPC
            if let pid = context.targetPID ?? MascotVirtualDesktopService.shared.currentAppPid {
                let screenPoint = MascotVirtualDesktopService.shared.targetDisplayCoordinate(for: context.normalizedPoint)
                await Self.executeBackgroundAccessibilityClick(pid: pid, screenPoint: screenPoint, targetHint: context.targetElement)
            }

            return CUAPhysicalActionResult(observationResult: "Executed click on '\(context.targetElement)'")
        }
    }

    /// Executes background element action (press, selection) via Accessibility IPC without stealing host focus
    public static func executeBackgroundAccessibilityClick(pid: pid_t, screenPoint: CGPoint, targetHint: String) async {
        await Task.detached(priority: .userInitiated) {
            let appRef = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appRef, 0.25)

            var elementRef: AXUIElement?
            let copyStatus = AXUIElementCopyElementAtPosition(appRef, Float(screenPoint.x), Float(screenPoint.y), &elementRef)

            if copyStatus == .success, let el = elementRef {
                if triggerActionOrSelection(on: el, pid: pid, screenPoint: screenPoint) {
                    return
                }
            }

            // Fallback: If copyElementAtPosition didn't hit actionable element, search window hierarchy
            if !targetHint.isEmpty {
                var windowListRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowListRef) == .success,
                   let windows = windowListRef as? [AXUIElement] {
                    let query = targetHint.lowercased()
                    for window in windows {
                        var visited = 0
                        if findAndTriggerElement(in: window, query: query, depth: 0, visited: &visited, maxNodes: 50, pid: pid) {
                            return
                        }
                    }
                }
            }
        }.value
    }

    /// Focuses an input field at coordinates via Accessibility IPC and detects if it has subrole AXTokenField
    public static func executeBackgroundAccessibilityFocus(pid: pid_t, screenPoint: CGPoint) async -> (focused: Bool, isTokenField: Bool, focusedRole: String) {
        await Task.detached(priority: .userInitiated) {
            let appRef = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appRef, 0.25)

            var elementRef: AXUIElement?
            let copyStatus = AXUIElementCopyElementAtPosition(appRef, Float(screenPoint.x), Float(screenPoint.y), &elementRef)

            var isToken = false
            var focused = false
            var matchedRole = ""
            if copyStatus == .success, let el = elementRef {
                var current: AXUIElement? = el
                for _ in 0..<5 {
                    guard let curr = current else { break }

                    var subroleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(curr, kAXSubroleAttribute as CFString, &subroleRef) == .success,
                       let subrole = subroleRef as? String,
                       subrole.lowercased().contains("token") {
                        isToken = true
                    }

                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(curr, kAXRoleAttribute as CFString, &roleRef)
                    let role = ((roleRef as? String) ?? "").lowercased()

                    if role == "axtextfield" || role == "axtextarea" || role == "axsearchfield" || role == "axcombobox" {
                        let status = AXUIElementSetAttributeValue(curr, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                        if status == .success {
                            focused = true
                            matchedRole = role
                            ClickyLogger.info("[CUA_CLICK_TOOL]", "Explicitly focused '\(role)' on PID \(pid) at (\(Int(screenPoint.x)), \(Int(screenPoint.y))) [token: \(isToken)]")
                            break
                        }
                    } else if role == "axwebarea" {
                        var editableChild: AXUIElement? = nil
                        var childrenRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(curr, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                           let kids = childrenRef as? [AXUIElement] {
                            for kid in kids.prefix(15) {
                                var kRoleRef: CFTypeRef?
                                AXUIElementCopyAttributeValue(kid, kAXRoleAttribute as CFString, &kRoleRef)
                                let kRole = ((kRoleRef as? String) ?? "").lowercased()
                                if kRole == "axtextarea" || kRole == "axtextfield" || kRole.contains("text") {
                                    editableChild = kid
                                    break
                                }
                            }
                        }
                        if let child = editableChild {
                            let status = AXUIElementSetAttributeValue(child, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                            if status == .success {
                                focused = true
                                matchedRole = "axwebarea_editable"
                                ClickyLogger.info("[CUA_CLICK_TOOL]", "Explicitly focused editable child of axwebarea on PID \(pid)")
                                break
                            }
                        }
                        matchedRole = "axwebarea"
                        focused = true
                        break
                    }

                    var parentRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(curr, kAXParentAttribute as CFString, &parentRef) == .success,
                       let parent = parentRef {
                        current = (parent as! AXUIElement)
                    } else {
                        break
                    }
                }
            }
            return (focused, isToken, matchedRole)
        }.value
    }
    private static func triggerActionOrSelection(on element: AXUIElement, pid: pid_t, screenPoint: CGPoint) -> Bool {
        var current: AXUIElement? = element
        for _ in 0..<5 {
            guard let curr = current else { break }

            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(curr, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""
            let lowerRole = role.lowercased()

            // 1. Table row selection (AppKit NSTableView / NSOutlineView)
            if role == "AXRow" || role == (kAXRowRole as String) {
                let selStatus = AXUIElementSetAttributeValue(curr, kAXSelectedAttribute as CFString, kCFBooleanTrue)
                var parentRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(curr, kAXParentAttribute as CFString, &parentRef) == .success,
                   let parent = parentRef, CFGetTypeID(parent) == AXUIElementGetTypeID() {
                    let parentTable = parent as! AXUIElement
                    let rowsArray = [curr] as CFArray
                    let tableSelStatus = AXUIElementSetAttributeValue(parentTable, "AXSelectedRows" as CFString, rowsArray)
                    ClickyLogger.info("[CUA_CLICK_TOOL]", "Triggered AXSelectedRows on parent table on PID \(pid) [status: \(tableSelStatus.rawValue)]")
                }
                ClickyLogger.info("[CUA_CLICK_TOOL]", "Triggered AXRow selection on PID \(pid) at (\(Int(screenPoint.x)), \(Int(screenPoint.y))) [selected: \(selStatus.rawValue)]")
                return true
            }

            // 2. Standard press or pick action (Button, Tab, MenuItem, Checkbox, Link)
            // Skip raw static text or image labels so action triggers on the enclosing parent button!
            let isLabelOnly = lowerRole == "axstatictext" || lowerRole == "aximage"
            if !isLabelOnly {
                var actionsRef: CFArray?
                if AXUIElementCopyActionNames(curr, &actionsRef) == .success, let actions = actionsRef as? [String] {
                    if actions.contains(kAXPressAction as String) {
                        let actStatus = AXUIElementPerformAction(curr, kAXPressAction as CFString)
                        ClickyLogger.info("[CUA_CLICK_TOOL]", "Triggered kAXPressAction on role '\(role)' on PID \(pid) [status: \(actStatus.rawValue)]")
                        return true
                    }
                    if actions.contains(kAXPickAction as String) {
                        let actStatus = AXUIElementPerformAction(curr, kAXPickAction as CFString)
                        ClickyLogger.info("[CUA_CLICK_TOOL]", "Triggered kAXPickAction on role '\(role)' on PID \(pid) [status: \(actStatus.rawValue)]")
                        return true
                    }
                }
            }
            // 3. Input field keyboard focus (AppKit NSTextField / NSTextView / NSSearchField / NSComboBox)
            // DILARANG set fokus pada axwebarea container karena akan meng-blur caret!
            if lowerRole == "axtextfield" || lowerRole == "axtextarea" || lowerRole == "axsearchfield" || lowerRole == "axcombobox" {
                let focusStatus = AXUIElementSetAttributeValue(curr, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                ClickyLogger.info("[CUA_CLICK_TOOL]", "Set kAXFocusedAttribute on role '\(role)' on PID \(pid) at (\(Int(screenPoint.x)), \(Int(screenPoint.y))) [status: \(focusStatus.rawValue)]")
                return true
            }

            // 4. Parent traversal
            var parentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(curr, kAXParentAttribute as CFString, &parentRef) == .success,
               let parent = parentRef {
                current = (parent as! AXUIElement)
            } else {
                break
            }
        }
        return false
    }

    private static func findAndTriggerElement(
        in element: AXUIElement,
        query: String,
        depth: Int,
        visited: inout Int,
        maxNodes: Int,
        pid: pid_t
    ) -> Bool {
        if depth > 4 || visited >= maxNodes { return false }
        visited += 1

        var titleRef: CFTypeRef?
        var descRef: CFTypeRef?
        var valRef: CFTypeRef?
        var roleRef: CFTypeRef?

        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valRef)
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)

        let title = (titleRef as? String)?.lowercased() ?? ""
        let desc = (descRef as? String)?.lowercased() ?? ""
        let val = (valRef as? String)?.lowercased() ?? ""
        let role = (roleRef as? String) ?? ""

        let combined = "\(title) \(desc) \(val)"
        if !query.isEmpty && (combined.contains(query) || (query.contains("first") && role == "AXRow")) {
            return triggerActionOrSelection(on: element, pid: pid, screenPoint: .zero)
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if findAndTriggerElement(in: child, query: query, depth: depth + 1, visited: &visited, maxNodes: maxNodes, pid: pid) {
                    return true
                }
            }
        }
        return false
    }
}
