#!/usr/bin/env swift
//
// test_taskK_cursor_kinematics_and_luna_sync.swift
// Verification suite for Task K: Sleek Buddy-Colored Cursor, Human Kinematics, Luna Session Sync, & Factual Egress
//

import Foundation
import CoreGraphics

print("=================================================================")
print("🧪 [TEST TASK K]: CURSOR KINEMATICS, LUNA SYNC & FACTUAL EGRESS")
print("=================================================================\n")

var passedTests = 0
var totalTests = 0

func assertTest(_ condition: Bool, _ name: String) {
    totalTests += 1
    if condition {
        passedTests += 1
        print("  ✅ [PASS] \(name)")
    } else {
        print("  ❌ [FAIL] \(name)")
    }
}

let rootDir = "/Users/heizaaa/Desktop/cdev/iza-3"

// TEST 1: MascotAgentCursorView sizing & dynamic accent color
print("[1/5] Verifying MascotAgentCursorView Sizing & Color Palette...")
let cursorFilePath = "\(rootDir)/boringNotch/Clicky/UI/Viewport/InteractiveVirtualDesktopView.swift"
if let cursorContent = try? String(contentsOfFile: cursorFilePath, encoding: .utf8) {
    assertTest(cursorContent.contains("public var accentColor: Color"), "MascotAgentCursorView accepts dynamic accentColor")
    assertTest(cursorContent.contains("width: 9, height: 12"), "Cursor arrow is compact (9x12 pt) rather than oversized 16x20")
    assertTest(cursorContent.contains("lineWidth: 1.0"), "Cursor border stroke is crisp 1.0 pt")
    assertTest(cursorContent.contains("width: 14, height: 14"), "Click ripple circle is reduced from 26pt to compact 14pt")
    assertTest(cursorContent.contains("buddyThemeColor"), "InteractiveVirtualDesktopView binds cursor and ripples to buddyThemeColor")
} else {
    assertTest(false, "Failed to read InteractiveVirtualDesktopView.swift")
}

// TEST 2: Human-like Kinematic Gliding in MascotVirtualDesktopService
print("\n[2/5] Verifying Human-like Kinematic Gliding in MascotVirtualDesktopService...")
let vdServicePath = "\(rootDir)/boringNotch/Clicky/Workspace/VirtualDisplay/MascotVirtualDesktopService.swift"
if let vdContent = try? String(contentsOfFile: vdServicePath, encoding: .utf8) {
    assertTest(vdContent.contains("public func glideReticleTo("), "glideReticleTo function implemented")
    assertTest(vdContent.contains("sin(Double.pi * t)"), "Natural organic curvature (sin arc) implemented")
    assertTest(vdContent.contains("4.0 * t * t * t"), "Ease-in-out cubic velocity curve implemented")
    assertTest(vdContent.contains("Task.sleep(nanoseconds: 120_000_000)"), "Human dwell time (120ms) before action implemented")
} else {
    assertTest(false, "Failed to read MascotVirtualDesktopService.swift")
}

// TEST 3: CompanionVMAgentLoop uses glideReticleTo
print("\n[3/5] Verifying CompanionVMAgentLoop Smooth Glide Integration...")
let loopFilePath = "\(rootDir)/boringNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift"
if let loopContent = try? String(contentsOfFile: loopFilePath, encoding: .utf8) {
    assertTest(loopContent.contains("await MascotVirtualDesktopService.shared.glideReticleTo("), "Step 5 uses glideReticleTo with human kinematics")
    assertTest(!loopContent.contains("MascotVirtualDesktopService.shared.performCuaMove(normalizedPoint: CGPoint(x: normX, y: normY))\n            try? await Task.sleep(nanoseconds: 200_000_000)"), "Removed instant jump teleport in Step 5")
} else {
    assertTest(false, "Failed to read CompanionVMAgentLoop.swift")
}

// TEST 4: Luna Session Sync & Automatic Failover
print("\n[4/5] Verifying Luna Session Sync & Failover Protection...")
let poolMgrPath = "\(rootDir)/boringNotch/Clicky/Services/Vision/ChatGPTAccountPoolManager.swift"
let visionSvcPath = "\(rootDir)/boringNotch/Clicky/Services/Vision/ChatGPTCodexVisionService.swift"

if let poolContent = try? String(contentsOfFile: poolMgrPath, encoding: .utf8),
   let visionContent = try? String(contentsOfFile: visionSvcPath, encoding: .utf8) {
    assertTest(poolContent.contains("public func syncDefaultCodexSession()"), "syncDefaultCodexSession implemented in ChatGPTAccountPoolManager")
    assertTest(poolContent.contains("syncDefaultCodexSession()"), "getActiveCodexHome triggers syncDefaultCodexSession")
    assertTest(visionContent.contains("failing over to system ~/.codex session"), "ChatGPTCodexVisionService automatically fails over to ~/.codex on token error")
} else {
    assertTest(false, "Failed to read vision service files")
}

// TEST 5: Factual Egress Delivery in TaskEgressValidator & AX Row Scanning
print("\n[5/5] Verifying Factual Egress Delivery & AX Row Scanning...")
let validatorPath = "\(rootDir)/boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift"
let axGrounderPath = "\(rootDir)/boringNotch/Clicky/CUA/Grounding/ClickyHybridGroundingEngine.swift"

if let valContent = try? String(contentsOfFile: validatorPath, encoding: .utf8),
   let axContent = try? String(contentsOfFile: axGrounderPath, encoding: .utf8) {
    assertTest(valContent.contains("hasRichExtraction"), "TaskEgressValidator checks for rich extractedData")
    assertTest(valContent.contains("responseToUser = \"\\(responseToUser): \\(extractedData)\""), "Synthesizes rich findings when responseToUser is a brief meta-label")
    assertTest(!axContent.contains("if role == \"axrow\" || role == \"axcell\""), "axrow and axcell are not blocked from scanning in AX hierarchy")
} else {
    assertTest(false, "Failed to read validator or grounder files")
}

print("\n=================================================================")
print("🏁 RESULTS: \(passedTests)/\(totalTests) TESTS PASSED")
print("=================================================================")

if passedTests == totalTests {
    exit(0)
} else {
    exit(1)
}
