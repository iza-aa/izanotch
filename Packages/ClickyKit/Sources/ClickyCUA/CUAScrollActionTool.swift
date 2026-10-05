import ClickyPlatform
import ClickyFoundation
//
//  CUAScrollActionTool.swift
//  izaNotch (Izanotchy)
//
//  Physical Mouse Scroll Tool: Dispatches 2-finger swipe / wheel scroll events to target application coordinates.
//

import AppKit
import Foundation

public final class CUAScrollActionTool: CUAPhysicalActionTool, @unchecked Sendable {
    public static let shared = CUAScrollActionTool()

    public var supportedActionTypes: [String] {
        ["scroll", "scroll_up", "scroll_down"]
    }

    @MainActor
    public func execute(actionType: String, context: CUAPhysicalActionContext) async -> CUAPhysicalActionResult {
        let act = actionType.lowercased()
        let isUp = act == "scroll_up" || (act == "scroll" && context.subGoal.lowercased().contains("up"))

        let subGoalLower = context.subGoal.lowercased()
        let isPageScroll = subGoalLower.contains("page") || subGoalLower.contains("browse") || subGoalLower.contains("fast") || subGoalLower.contains("halaman")

        // Physical wheel pixel delta:
        // Micro-scroll: ~140px (reveals next ~2 rows while maintaining visible anchor)
        // Page-scroll: ~380px (full page navigation)
        let pixelDelta: Int32 = isPageScroll ? (isUp ? 380 : -380) : (isUp ? 140 : -140)

        // Ensure scroll coordinate lands safely inside the scrollable container body (clamping Y between 30% and 70%)
        let targetX = context.normalizedPoint.x > 0.05 ? context.normalizedPoint.x : 0.35
        let targetY = min(max(context.normalizedPoint.y, 0.30), 0.70)
        let safePoint = CGPoint(x: targetX, y: targetY)

        MascotVirtualDesktopService.shared.performCuaScroll(normalizedPoint: safePoint, deltaY: pixelDelta)

        // Dual-Layer Background Scroll via Accessibility IPC with Adaptive Calculation
        var axSuccess = false
        if let pid = context.targetPID, pid > 0 {
            let screenPoint = MascotVirtualDesktopService.shared.targetDisplayCoordinate(for: safePoint)
            axSuccess = Self.executeBackgroundAccessibilityScroll(
                pid: pid,
                screenPoint: screenPoint,
                isUp: isUp,
                isPageScroll: isPageScroll
            )
        }

        let modeLabel = isPageScroll ? "page" : "adaptive"
        let directionLabel = isUp ? "up" : "down"
        return CUAPhysicalActionResult(observationResult: "Executed \(modeLabel) scroll_\(directionLabel) on '\(context.targetElement)' (AX: \(axSuccess ? "ok" : "wheel-only"))")
    }

    /// Background Accessibility IPC Scroll with Adaptive Row-Proportional Resolution
    public static func executeBackgroundAccessibilityScroll(
        pid: pid_t,
        screenPoint: CGPoint,
        isUp: Bool,
        isPageScroll: Bool = false
    ) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.25)

        var elementAtPos: AXUIElement?
        _ = AXUIElementCopyElementAtPosition(appElement, Float(screenPoint.x), Float(screenPoint.y), &elementAtPos)

        var targetScrollArea: AXUIElement?
        var targetScrollBar: AXUIElement?

        // 1. Traverse parent chain up to find AXScrollArea or AXScrollBar
        var current: AXUIElement? = elementAtPos
        for _ in 0..<7 {
            guard let cur = current else { break }
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(cur, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""

            if role == "AXScrollBar" {
                targetScrollBar = cur
                break
            } else if role == "AXScrollArea" {
                targetScrollArea = cur
                break
            }

            var parentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(cur, kAXParentAttribute as CFString, &parentRef) == .success,
               let p = parentRef {
                current = (p as! AXUIElement)
            } else {
                break
            }
        }

        // 2. Fallback: Search window hierarchy for scroll area if not found under cursor
        if targetScrollArea == nil && targetScrollBar == nil {
            var windowListRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListRef) == .success,
               let windows = windowListRef as? [AXUIElement] {
                for win in windows {
                    if let found = findFirstScrollArea(in: win, depth: 0, maxDepth: 4) {
                        targetScrollArea = found
                        break
                    }
                }
            }
        }

        // 3. Resolve vertical scroll bar from scroll area
        if targetScrollBar == nil, let sa = targetScrollArea {
            var vBarRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(sa, "AXVerticalScrollBar" as CFString, &vBarRef) == .success,
               let vb = vBarRef {
                targetScrollBar = (vb as! AXUIElement)
            }
        }

        // 4. Resolve scroll area from scroll bar if scroll area is missing
        if targetScrollArea == nil, let bar = targetScrollBar {
            var parentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(bar, kAXParentAttribute as CFString, &parentRef) == .success,
               let p = parentRef {
                targetScrollArea = (p as! AXUIElement)
            }
        }

        // 5. Inspect target scroll area for table / outline total rows & visible rows
        var totalRows: Int?
        var visibleRowsCount: Int?
        if let sa = targetScrollArea, let table = findFirstTableOrOutline(in: sa, depth: 0, maxDepth: 3) {
            var rowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(table, kAXRowsAttribute as CFString, &rowsRef) == .success,
               let rows = rowsRef as? [AXUIElement] {
                totalRows = rows.count
            }
            var visRowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(table, "AXVisibleRows" as CFString, &visRowsRef) == .success,
               let visRows = visRowsRef as? [AXUIElement] {
                visibleRowsCount = visRows.count
            }
        }

        // 6. Execute scroll on scroll bar with Adaptive Row-Proportional Calculation
        if let bar = targetScrollBar {
            let action = isUp ? "AXDecrement" : "AXIncrement"
            let actRes = AXUIElementPerformAction(bar, action as CFString)

            var valRef: CFTypeRef?
            var valueSetSuccess = false
            if AXUIElementCopyAttributeValue(bar, kAXValueAttribute as CFString, &valRef) == .success,
               let num = valRef as? NSNumber {
                let curVal = num.floatValue

                // Calculate adaptive step based on table dimensions or scroll bar metadata
                let step = calculateAdaptiveStep(
                    bar: bar,
                    totalRows: totalRows,
                    visibleRowsCount: visibleRowsCount,
                    isPageScroll: isPageScroll
                )

                let targetVal = isUp ? max(curVal - step, 0.0) : min(curVal + step, 1.0)
                var n = targetVal
                if let cfN = CFNumberCreate(nil, .floatType, &n) {
                    let setRes = AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, cfN)
                    valueSetSuccess = (setRes == .success)
                    ClickyLogger.info(
                        "[CUA_SCROLL_TOOL]",
                        "Adaptive scroll PID \(pid): totalRows=\(totalRows ?? -1), visRows=\(visibleRowsCount ?? -1), isPage=\(isPageScroll), step=\(step), set AXValue from \(curVal) to \(targetVal) [res: \(setRes.rawValue), act: \(actRes.rawValue)]"
                    )
                }
            }

            if valueSetSuccess || actRes == .success {
                return true
            }
        }

        return false
    }

    /// Dynamically calculates row-proportional or view-adaptive scroll step (0.0 ... 1.0)
    public static func calculateAdaptiveStep(
        bar: AXUIElement,
        totalRows: Int?,
        visibleRowsCount: Int?,
        isPageScroll: Bool
    ) -> Float {
        // Priority 1: Table or Outline with known total row count
        if let rows = totalRows, rows > 0 {
            if isPageScroll {
                let vis = visibleRowsCount ?? 6
                let rowsToScroll = max(Float(vis - 1), 4.0)
                return min(rowsToScroll / Float(rows), 0.50)
            } else {
                // Micro-scroll for target item reveal: scroll ~2.0 to 2.5 rows
                let rowsToScroll: Float = 2.5
                return min(rowsToScroll / Float(rows), 0.25)
            }
        }

        // Priority 2: Native scroll bar line or page scroll attributes
        var lineStepRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(bar, "AXLineScrollAmount" as CFString, &lineStepRef) == .success,
           let num = lineStepRef as? NSNumber, num.floatValue > 0.000001 {
            let line = num.floatValue
            return isPageScroll ? min(line * 6.0, 0.40) : min(line * 2.5, 0.15)
        }

        var pageStepRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(bar, "AXPageScrollAmount" as CFString, &pageStepRef) == .success,
           let num = pageStepRef as? NSNumber, num.floatValue > 0.000001 {
            let page = num.floatValue
            return isPageScroll ? min(page * 0.75, 0.40) : min(page * 0.25, 0.10)
        }

        // Priority 3: Safe, non-intrusive heuristic for generic non-table views
        // Replaces coarse 20% jump with gentle 1.5% micro-step or 8% page step
        return isPageScroll ? 0.08 : 0.015
    }

    private static func findFirstTableOrOutline(in element: AXUIElement, depth: Int, maxDepth: Int) -> AXUIElement? {
        guard depth <= maxDepth else { return nil }
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? ""
        if role == "AXTable" || role == "AXOutline" {
            return element
        }
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children.prefix(10) {
                if let found = findFirstTableOrOutline(in: child, depth: depth + 1, maxDepth: maxDepth) {
                    return found
                }
            }
        }
        return nil
    }

    private static func findFirstScrollArea(in element: AXUIElement, depth: Int, maxDepth: Int) -> AXUIElement? {
        guard depth <= maxDepth else { return nil }
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? ""
        if role == "AXScrollArea" {
            return element
        }
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children.prefix(15) {
                if let found = findFirstScrollArea(in: child, depth: depth + 1, maxDepth: maxDepth) {
                    return found
                }
            }
        }
        return nil
    }

    /// Resets scroll bar to top (0.0) to ensure a clean workspace anchor for new inspection tasks
    public static func resetScrollToTop(pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.25)
        var windowListRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListRef) == .success,
              let windows = windowListRef as? [AXUIElement] else { return }
        for win in windows {
            if let sa = findFirstScrollArea(in: win, depth: 0, maxDepth: 4) {
                var vBarRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(sa, "AXVerticalScrollBar" as CFString, &vBarRef) == .success,
                   let vb = vBarRef {
                    var zero: Float = 0.0
                    if let cfZero = CFNumberCreate(nil, .floatType, &zero) {
                        let res = AXUIElementSetAttributeValue((vb as! AXUIElement), kAXValueAttribute as CFString, cfZero)
                        ClickyLogger.info("[CUA_SCROLL_TOOL]", "Reset scroll to top (0.0) on PID \(pid) [res: \(res.rawValue)]")
                    }
                }
            }
        }
    }
}
