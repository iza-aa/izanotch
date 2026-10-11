//
//  ClickyHybridGroundingEngine.swift
//  izaNotch
//
//  Hybrid Grounding Engine:
//  - Tier 1: AXUIElement (macOS Accessibility API) -> Zero-token, deterministic, high-speed resolution
//  - Tier 2: 6 Luna Medium Headless Vision VM -> Intelligent visual fallback when AX tree is inaccessible
//

import AppKit
import ApplicationServices
import Foundation

// MARK: - Constants for Web & Electron Accessibility Inspection
private let kAXDOMIdentifierAttr = "AXDOMIdentifier"
private let kAXDOMClassListAttr = "AXDOMClassList"

public struct GroundedTargetResult: Equatable {
    public enum GroundingMethod: String, Codable {
        case axUIElement = "AXUIElement"
        case vision6Luna = "6 Luna Medium Vision"
    }
    
    public let target: String
    public let coordinate: CGPoint
    public let method: GroundingMethod
    public let confidence: Double
    
    public init(target: String, coordinate: CGPoint, method: GroundingMethod, confidence: Double = 1.0) {
        self.target = target
        self.coordinate = coordinate
        self.method = method
        self.confidence = confidence
    }
}

@MainActor
public final class ClickyHybridGroundingEngine: ObservableObject {
    public static let shared = ClickyHybridGroundingEngine()
    
    @Published public private(set) var lastResolvedResult: GroundedTargetResult?
    @Published public private(set) var lastGroundingMethod: GroundedTargetResult.GroundingMethod?
    
    private init() {}
    
    /// Resolves target UI element coordinate using AXUIElement first, falling back to 6 Luna Medium Vision if unavailable.
    public func resolveElementCoordinate(
        targetPrompt: String,
        pid: pid_t?,
        windowBounds: CGRect? = nil,
        snapshotPath: String? = nil,
        actionType: String? = nil
    ) async -> GroundedTargetResult? {
        // TIER 1: Evaluate AXUIElement First (Asynchronous background scan with 1.5s strict timeout)
        if let pid = pid, pid > 0 {
            if let axPoint = await locateViaAXUIElementAsync(pid: pid, targetQuery: targetPrompt, windowBounds: windowBounds, actionType: actionType, timeoutSeconds: 1.5) {
                let result = GroundedTargetResult(
                    target: targetPrompt,
                    coordinate: axPoint,
                    method: .axUIElement,
                    confidence: 1.0
                )
                self.lastResolvedResult = result
                self.lastGroundingMethod = .axUIElement
                ClickyLogger.info("[HYBRID_GROUNDER]", "Resolved \"\(targetPrompt)\" via AXUIElement at (\(Int(axPoint.x)), \(Int(axPoint.y)))")
                return result
            }
        }
        
        // TIER 2: Fallback to 6 Luna Medium Headless Vision VM
        if let snapshotPath = snapshotPath, FileManager.default.fileExists(atPath: snapshotPath) {
            do {
                ClickyLogger.info("[HYBRID_GROUNDER]", "AXUIElement not available for \"\(targetPrompt)\". Falling back to 6 Luna Medium Vision...")
                let codexHome = ChatGPTAccountPoolManager.shared.getActiveCodexHome()
                let visionResult = try await ChatGPTCodexVisionService.shared.queryCoordinates(
                    imagePath: snapshotPath,
                    targetElementPrompt: targetPrompt,
                    codexHome: codexHome
                )
                let point = CGPoint(x: visionResult.x, y: visionResult.y)
                let result = GroundedTargetResult(
                    target: targetPrompt,
                    coordinate: point,
                    method: .vision6Luna,
                    confidence: visionResult.confidence
                )
                self.lastResolvedResult = result
                self.lastGroundingMethod = .vision6Luna
                ClickyLogger.info("[HYBRID_GROUNDER]", "Resolved \"\(targetPrompt)\" via 6 Luna Medium Vision at (\(visionResult.x), \(visionResult.y)) [confidence: \(visionResult.confidence)]")
                return result
            } catch {
                ClickyLogger.warning("[HYBRID_GROUNDER]", "Vision fallback failed: \(error.localizedDescription)")
            }
        }
        
        return nil
    }
    
    // MARK: - Asynchronous Bounded AXUIElement Locator
    /// Scans the accessibility tree of the application asynchronously in background with strict timeout
    public func locateViaAXUIElementAsync(
        pid: pid_t,
        targetQuery: String,
        windowBounds: CGRect? = nil,
        actionType: String? = nil,
        timeoutSeconds: TimeInterval = 1.5
    ) async -> CGPoint? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appElement = AXUIElementCreateApplication(pid)
                // Set AX timeout to 200ms per IPC message to prevent blocking
                AXUIElementSetMessagingTimeout(appElement, 0.2)
                
                var hasResumed = false
                let lock = NSLock()
                
                let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
                timer.schedule(deadline: .now() + timeoutSeconds)
                timer.setEventHandler {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: nil)
                    }
                }
                timer.resume()
                
                var windowListRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListRef) == .success,
                      let windows = windowListRef as? [AXUIElement], !windows.isEmpty else {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        timer.cancel()
                        continuation.resume(returning: nil)
                    }
                    return
                }
                
                var sortedWindows = windows
                var focusedWinRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWinRef) == .success,
                   let focusedWin = focusedWinRef,
                   CFGetTypeID(focusedWin) == AXUIElementGetTypeID() {
                    let axWin = focusedWin as! AXUIElement
                    sortedWindows.removeAll { CFEqual($0, axWin) }
                    sortedWindows.insert(axWin, at: 0)
                }
                
                let query = targetQuery.lowercased()
                let targetOrdinal = Self.extractListOrdinal(from: query)
                let isType = Self.isTypeAction(actionType)
                let isFieldQuery = isType || Self.isInputFieldQuery(query)
                if isFieldQuery {
                    if let editorWin = sortedWindows.first(where: {
                        Self.findFirstAXElement(parent: $0, role: "AXWebArea", maxDepth: 6) != nil ||
                        Self.findFirstAXElement(parent: $0, role: "AXTextArea", maxDepth: 6) != nil
                    }) {
                        sortedWindows.removeAll { CFEqual($0, editorWin) }
                        sortedWindows.insert(editorWin, at: 0)
                    }
                }
                var foundPoint: CGPoint? = nil
                
                for window in sortedWindows {
                    lock.lock()
                    let alreadyResumed = hasResumed
                    lock.unlock()
                    if alreadyResumed { break }
                    
                    var windowVisited = 0
                    
                    // Priority 1: Direct AXToolbar scan (< 5ms) for controls / toolbar actions (bypassed for type actions and field queries)
                    if !isFieldQuery, let tb = Self.findFirstAXElement(parent: window, role: "AXToolbar") {
                        var tbVisited = 0
                        if let pt = Self.scanElementHierarchySafe(element: tb, query: query, depth: 0, visitedNodes: &tbVisited, maxNodes: 80, isTypeAction: isType) {
                            foundPoint = pt
                            break
                        }
                    }

                    if let ordinal = targetOrdinal {
                        var listVisited = 0
                        if let pt = Self.locateListRowByOrdinal(element: window, targetOrdinal: ordinal, visitedNodes: &listVisited, maxNodes: 150) {
                            foundPoint = pt
                            break
                        }
                    }
                    
                    if let pt = Self.scanElementHierarchySafe(element: window, query: query, depth: 0, visitedNodes: &windowVisited, maxNodes: 200, isTypeAction: isType) {
                        foundPoint = pt
                        break
                    }
                }
                
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    timer.cancel()
                    continuation.resume(returning: foundPoint)
                }
            }
        }
    }
    
    /// Synchronous convenience helper with strict node and timeout bounds
    public func locateViaAXUIElement(
        pid: pid_t,
        targetQuery: String,
        windowBounds: CGRect?,
        actionType: String? = nil
    ) -> CGPoint? {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.1)
        var windowListRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListRef) == .success,
              let windows = windowListRef as? [AXUIElement], !windows.isEmpty else {
            return nil
        }
        var sortedWindows = windows
        var focusedWinRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWinRef) == .success,
           let focusedWin = focusedWinRef,
           CFGetTypeID(focusedWin) == AXUIElementGetTypeID() {
            let axWin = focusedWin as! AXUIElement
            sortedWindows.removeAll { CFEqual($0, axWin) }
            sortedWindows.insert(axWin, at: 0)
        }
        let query = targetQuery.lowercased()
        let targetOrdinal = Self.extractListOrdinal(from: query)
        let isType = Self.isTypeAction(actionType)
        let isFieldQuery = isType || Self.isInputFieldQuery(query)
        if isFieldQuery {
            if let editorWin = sortedWindows.first(where: {
                Self.findFirstAXElement(parent: $0, role: "AXWebArea", maxDepth: 6) != nil ||
                Self.findFirstAXElement(parent: $0, role: "AXTextArea", maxDepth: 6) != nil
            }) {
                sortedWindows.removeAll { CFEqual($0, editorWin) }
                sortedWindows.insert(editorWin, at: 0)
            }
        }
        for window in sortedWindows {
            // Priority 1: Direct AXToolbar scan (< 5ms, bypassed for type actions and field queries)
            if !isFieldQuery, let tb = Self.findFirstAXElement(parent: window, role: "AXToolbar") {
                var tbVisited = 0
                if let found = Self.scanElementHierarchySafe(element: tb, query: query, depth: 0, visitedNodes: &tbVisited, maxNodes: 80, isTypeAction: isType) {
                    return found
                }
            }
            if let ordinal = targetOrdinal {
                var listVisited = 0
                if let found = Self.locateListRowByOrdinal(element: window, targetOrdinal: ordinal, visitedNodes: &listVisited, maxNodes: 120) {
                    return found
                }
            }
            var windowVisited = 0
            if let found = Self.scanElementHierarchySafe(element: window, query: query, depth: 0, visitedNodes: &windowVisited, maxNodes: 150, isTypeAction: isType) {
                return found
            }
        }
        return nil
    }
    
    nonisolated private static func findFirstAXElement(parent: AXUIElement, role: String, depth: Int = 0, maxDepth: Int = 3) -> AXUIElement? {
        guard depth <= maxDepth else { return nil }
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &roleRef) == .success,
           let r = roleRef as? String, r == role {
            return parent
        }
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findFirstAXElement(parent: child, role: role, depth: depth + 1, maxDepth: maxDepth) {
                    return found
                }
            }
        }
        return nil
    }

    // MARK: - App-Agnostic List Ordinal Resolvers
    nonisolated private static func extractListOrdinal(from query: String) -> Int? {
        let q = query.lowercased()
        if let match = q.range(of: #"(?:item|row|index|baris|ke-?)\s*(\d+)"#, options: .regularExpression) {
            let sub = String(q[match])
            let digits = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let num = Int(digits), num >= 1 {
                return num - 1 // 0-based
            }
        }
        return nil
    }

    nonisolated public static func isTypeAction(_ actionType: String?) -> Bool {
        guard let a = actionType?.lowercased() else { return false }
        return a == "type" || a == "write" || a == "input"
    }

    nonisolated public static func isInputFieldQuery(_ query: String) -> Bool {
        let q = query.lowercased()
        let fieldKeywords = ["field", "area", "input", "line", "body", "editor", "message", "pesan"]
        return fieldKeywords.contains { q.contains($0) }
    }

    nonisolated private static func locateListRowByOrdinal(
        element: AXUIElement,
        targetOrdinal: Int,
        visitedNodes: inout Int,
        maxNodes: Int
    ) -> CGPoint? {
        if visitedNodes >= maxNodes { return nil }
        visitedNodes += 1
        
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            if role == "AXTable" || role == "AXList" {
                var rowsRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXRowsAttribute as CFString, &rowsRef) == .success ||
                   AXUIElementCopyAttributeValue(element, kAXVisibleRowsAttribute as CFString, &rowsRef) == .success,
                   let rows = rowsRef as? [AXUIElement], !rows.isEmpty {
                    let targetIdx = min(max(targetOrdinal, 0), rows.count - 1)
                    let targetRow = rows[targetIdx]
                    
                    var posRef: CFTypeRef?
                    var sizeRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(targetRow, kAXPositionAttribute as CFString, &posRef) == .success,
                       AXUIElementCopyAttributeValue(targetRow, kAXSizeAttribute as CFString, &sizeRef) == .success,
                       let posVal = posRef, let sizeVal = sizeRef,
                       CFGetTypeID(posVal) == AXValueGetTypeID(),
                       CFGetTypeID(sizeVal) == AXValueGetTypeID() {
                        var pos = CGPoint.zero
                        var size = CGSize.zero
                        if AXValueGetValue(posVal as! AXValue, .cgPoint, &pos),
                           AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) {
                            if size.width > 4 && size.height > 4 {
                                return CGPoint(x: pos.x + size.width / 2.0, y: pos.y + size.height / 2.0)
                            }
                        }
                    }
                }
            }
        }
        
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children.prefix(30) {
                if let pt = locateListRowByOrdinal(element: child, targetOrdinal: targetOrdinal, visitedNodes: &visitedNodes, maxNodes: maxNodes) {
                    return pt
                }
                if visitedNodes >= maxNodes { break }
            }
        }
        return nil
    }
    
    nonisolated private static func findAdjacentInputField(for element: AXUIElement) -> CGPoint? {
        var parentRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef) == .success,
              let parent = parentRef, CFGetTypeID(parent) == AXUIElementGetTypeID() else {
            return nil
        }
        let parentElement = parent as! AXUIElement
        var siblingsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parentElement, kAXChildrenAttribute as CFString, &siblingsRef) == .success,
              let siblings = siblingsRef as? [AXUIElement] else {
            return nil
        }

        var elemPos = CGPoint.zero
        var ePosRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &ePosRef) == .success,
           let ep = ePosRef, CFGetTypeID(ep) == AXValueGetTypeID() {
            AXValueGetValue(ep as! AXValue, .cgPoint, &elemPos)
        }

        var bestSiblingPt: CGPoint? = nil
        var minDistance: CGFloat = .infinity

        for sibling in siblings {
            if CFEqual(sibling, element) { continue }
            var sRoleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(sibling, kAXRoleAttribute as CFString, &sRoleRef) == .success,
               let sRole = (sRoleRef as? String)?.lowercased(),
               (sRole == "axtextfield" || sRole == "axtextarea" || sRole == "axsearchfield" || sRole == "axcombobox" || sRole == "axwebarea") {
                var posRef: CFTypeRef?
                var sizeRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(sibling, kAXPositionAttribute as CFString, &posRef) == .success,
                   AXUIElementCopyAttributeValue(sibling, kAXSizeAttribute as CFString, &sizeRef) == .success,
                   let posVal = posRef, let sizeVal = sizeRef,
                   CFGetTypeID(posVal) == AXValueGetTypeID(),
                   CFGetTypeID(sizeVal) == AXValueGetTypeID() {
                    var sPos = CGPoint.zero
                    var sSize = CGSize.zero
                    if AXValueGetValue(posVal as! AXValue, .cgPoint, &sPos) &&
                       AXValueGetValue(sizeVal as! AXValue, .cgSize, &sSize),
                       sSize.width > 4 && sSize.height > 4 {
                        let yDist = abs(sPos.y - elemPos.y)
                        let xDist = sPos.x - elemPos.x
                        if yDist < 30 && xDist >= -15 {
                            let totalDist = yDist * 2.0 + max(xDist, 0)
                            if totalDist < minDistance {
                                minDistance = totalDist
                                bestSiblingPt = CGPoint(x: sPos.x + sSize.width / 2.0, y: sPos.y + sSize.height / 2.0)
                            }
                        }
                    }
                }
            }
        }
        return bestSiblingPt
    }

    nonisolated private static func scanElementHierarchySafe(
        element: AXUIElement,
        query: String,
        depth: Int,
        visitedNodes: inout Int,
        maxNodes: Int,
        isTypeAction: Bool = false
    ) -> CGPoint? {
        if depth > 8 || visitedNodes >= maxNodes { return nil }
        visitedNodes += 1
        
        var titleRef: CFTypeRef?
        var descRef: CFTypeRef?
        var valRef: CFTypeRef?
        var roleRef: CFTypeRef?
        var idRef: CFTypeRef?
        var subroleRef: CFTypeRef?
        var helpRef: CFTypeRef?
        var domIdRef: CFTypeRef?
        var domClassRef: CFTypeRef?
        
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valRef)
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &idRef)
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
        AXUIElementCopyAttributeValue(element, kAXHelpAttribute as CFString, &helpRef)
        AXUIElementCopyAttributeValue(element, kAXDOMIdentifierAttr as CFString, &domIdRef)
        AXUIElementCopyAttributeValue(element, kAXDOMClassListAttr as CFString, &domClassRef)
        
        let title = (titleRef as? String)?.lowercased() ?? ""
        let desc = (descRef as? String)?.lowercased() ?? ""
        let val = (valRef as? String)?.lowercased() ?? ""
        let role = (roleRef as? String)?.lowercased() ?? ""
        let ident = (idRef as? String)?.lowercased() ?? ""
        let subrole = (subroleRef as? String)?.lowercased() ?? ""
        let help = (helpRef as? String)?.lowercased() ?? ""
        let domId = (domIdRef as? String)?.lowercased() ?? ""
        
        var domClasses: [String] = []
        if let classArr = domClassRef as? [String] {
            domClasses = classArr.map { $0.lowercased() }
        } else if let classStr = domClassRef as? String {
            domClasses = [classStr.lowercased()]
        }
        
        let cleanTitle = title.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
        let cleanDesc = desc.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
        let tokens = query.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 }
        let isFieldQuery = isTypeAction || Self.isInputFieldQuery(query)
        let isButtonControl = role == "axbutton" || role == "axmenubutton" || role == "axpopupbutton"
        if isFieldQuery && isButtonControl && !role.contains("text") {
            return nil
        }
        
        let matchVal = !isFieldQuery && val.contains(query)
        let isCreateAction = query.contains("compose") || query.contains("create")
        let matchesNewAction = isCreateAction && (cleanTitle.contains("new") || cleanDesc.contains("new"))
        let isBodyQuery = query.contains("body") || query.contains("message") || query.contains("isi") || query.contains("content") || query.contains("editor")
        let isBodyMatch = isBodyQuery && (role == "axtextarea" || role == "axwebarea")
        let directMatch = (cleanTitle.count >= 2 && (cleanTitle.contains(query) || query.contains(cleanTitle))) ||
                          (cleanDesc.count >= 2 && (cleanDesc.contains(query) || query.contains(cleanDesc))) ||
                          matchesNewAction ||
                          isBodyMatch ||
                          matchVal ||
                          ident.contains(query) ||
                          help.contains(query) ||
                          domId.contains(query) ||
                          domClasses.contains { $0.contains(query) }
        let genericRoleWords: Set<String> = ["field", "button", "control", "item", "element", "text", "view", "area", "menu", "input"]
        let matchingTokens = tokens.filter { token in
            title.contains(token) ||
            desc.contains(token) ||
            (!genericRoleWords.contains(token) && role.contains(token)) ||
            (!isFieldQuery && val.contains(token)) ||
            ident.contains(token) ||
            domId.contains(token) ||
            domClasses.contains { $0.contains(token) } ||
            (isCreateAction && token == "compose" && (title.contains("new") || desc.contains("new")))
        }
        let tokenMatch: Bool
        if tokens.count == 2 && isFieldQuery {
            tokenMatch = matchingTokens.count == tokens.count || directMatch
        } else {
            tokenMatch = !tokens.isEmpty && (
                (tokens.count == 1 && !matchingTokens.isEmpty) ||
                (tokens.count >= 2 && Double(matchingTokens.count) / Double(tokens.count) >= 0.5)
            )
        }
        
        let isMatch = directMatch || tokenMatch
        let isExcludedContainer = (role == "axrow" || role == "axtable" || role == "axoutline") && Self.extractListOrdinal(from: query) == nil
        
        if isMatch && !isExcludedContainer {
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
               AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
               let posVal = posRef, let sizeVal = sizeRef,
               CFGetTypeID(posVal) == AXValueGetTypeID(),
               CFGetTypeID(sizeVal) == AXValueGetTypeID() {
                var pos = CGPoint.zero
                var size = CGSize.zero
                if AXValueGetValue(posVal as! AXValue, .cgPoint, &pos) &&
                   AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) {
                    if size.width > 4 && size.height > 4 {
                        let isLabel = role == "axstatictext" || title.hasSuffix(":") || desc.hasSuffix(":")
                        if isFieldQuery && isLabel {
                            // Find adjacent native input field in the same container/parent
                            if let neighborPt = findAdjacentInputField(for: element) {
                                return neighborPt
                            }
                            // Do not click static label when field input is requested
                            return nil
                        }
                        return CGPoint(x: pos.x + size.width / 2.0, y: pos.y + size.height / 2.0)
                    }
                }
            }
        }
        
        // Traverse children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children.prefix(30) {
                if let pt = scanElementHierarchySafe(element: child, query: query, depth: depth + 1, visitedNodes: &visitedNodes, maxNodes: maxNodes, isTypeAction: isTypeAction) {
                    return pt
                }
                if visitedNodes >= maxNodes { break }
            }
        }
        
        return nil
    }
}