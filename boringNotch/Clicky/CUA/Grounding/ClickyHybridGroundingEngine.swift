//
//  ClickyHybridGroundingEngine.swift
//  boringNotch
//
//  Hybrid Grounding Engine:
//  - Tier 1: AXUIElement (macOS Accessibility API) -> Zero-token, deterministic, high-speed resolution
//  - Tier 2: 6 Luna Medium Headless Vision VM -> Intelligent visual fallback when AX tree is inaccessible
//

import AppKit
import ApplicationServices
import Foundation

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
        snapshotPath: String? = nil
    ) async -> GroundedTargetResult? {
        // TIER 1: Evaluate AXUIElement First (Asynchronous background scan with 1.5s strict timeout)
        if let pid = pid, pid > 0 {
            if let axPoint = await locateViaAXUIElementAsync(pid: pid, targetQuery: targetPrompt, windowBounds: windowBounds, timeoutSeconds: 1.5) {
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
                
                let query = targetQuery.lowercased()
                var visitedNodes = 0
                var foundPoint: CGPoint? = nil
                
                for window in windows {
                    lock.lock()
                    let alreadyResumed = hasResumed
                    lock.unlock()
                    if alreadyResumed { break }
                    
                    if let pt = Self.scanElementHierarchySafe(element: window, query: query, depth: 0, visitedNodes: &visitedNodes, maxNodes: 80) {
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
    public func locateViaAXUIElement(pid: pid_t, targetQuery: String, windowBounds: CGRect?) -> CGPoint? {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.1)
        var windowListRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListRef) == .success,
              let windows = windowListRef as? [AXUIElement], !windows.isEmpty else {
            return nil
        }
        var visited = 0
        for window in windows {
            if let found = Self.scanElementHierarchySafe(element: window, query: targetQuery.lowercased(), depth: 0, visitedNodes: &visited, maxNodes: 40) {
                return found
            }
        }
        return nil
    }
    
    private static func scanElementHierarchySafe(
        element: AXUIElement,
        query: String,
        depth: Int,
        visitedNodes: inout Int,
        maxNodes: Int
    ) -> CGPoint? {
        if depth > 4 || visitedNodes >= maxNodes { return nil }
        visitedNodes += 1
        
        var titleRef: CFTypeRef?
        var descRef: CFTypeRef?
        var valRef: CFTypeRef?
        var roleRef: CFTypeRef?
        var idRef: CFTypeRef?
        
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valRef)
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &idRef)
        
        let title = (titleRef as? String)?.lowercased() ?? ""
        let desc = (descRef as? String)?.lowercased() ?? ""
        let val = (valRef as? String)?.lowercased() ?? ""
        let role = (roleRef as? String)?.lowercased() ?? ""
        let ident = (idRef as? String)?.lowercased() ?? ""
        
        let tokens = query.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 }
        let directMatch = title.contains(query) || desc.contains(query) || val.contains(query) || ident.contains(query)
        let tokenMatch = !tokens.isEmpty && tokens.allSatisfy { token in
            title.contains(token) || desc.contains(token) || val.contains(token) || ident.contains(token)
        }
        let isMatch = directMatch || tokenMatch
        
        if isMatch {
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
                        return CGPoint(x: pos.x + size.width / 2.0, y: pos.y + size.height / 2.0)
                    }
                }
            }
        }
        
        // Skip descending into massive web areas or large text areas to preserve performance
        if role == "axwebarea" || role == "axtextarea" {
            return nil
        }
        
        // Traverse children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children.prefix(25) {
                if let pt = scanElementHierarchySafe(element: child, query: query, depth: depth + 1, visitedNodes: &visitedNodes, maxNodes: maxNodes) {
                    return pt
                }
                if visitedNodes >= maxNodes { break }
            }
        }
        
        return nil
    }
}
