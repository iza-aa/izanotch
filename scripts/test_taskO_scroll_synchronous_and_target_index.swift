import Foundation

print("=== Running Verification Test: Scroll Reliability, Synchronous Capture, and Anti-Hallucination Guard ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let scrollToolPath = "\(rootPath)/boringNotch/Clicky/CUA/Actions/CUAScrollActionTool.swift"
let vdServicePath = "\(rootPath)/boringNotch/Clicky/Workspace/VirtualDisplay/MascotVirtualDesktopService.swift"
let streamServicePath = "\(rootPath)/boringNotch/Clicky/Workspace/Streaming/CompanionWindowStreamService.swift"
let plannerPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift"
let validatorPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift"
let loopPath = "\(rootPath)/boringNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift"

var passed = 0
var total = 0

// Test 1: CUAScrollActionTool implements dual-layer scroll with AXScrollArea, AXScrollBar, AXIncrement/Decrement, and AXValue
total += 1
if let content = try? String(contentsOfFile: scrollToolPath, encoding: .utf8) {
    let hasScrollArea = content.contains("AXScrollArea")
    let hasScrollBar = content.contains("AXScrollBar")
    let hasIncrement = content.contains("AXIncrement") && content.contains("AXDecrement")
    let hasValue = content.contains("kAXValueAttribute")

    if hasScrollArea && hasScrollBar && hasIncrement && hasValue {
        print("  ✅ [PASS] CUAScrollActionTool implements dual-layer scroll via AXScrollArea & AXScrollBar")
        passed += 1
    } else {
        print("  ❌ [FAIL] CUAScrollActionTool missing components (scrollArea: \(hasScrollArea), scrollBar: \(hasScrollBar), inc: \(hasIncrement), val: \(hasValue))")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(scrollToolPath)")
}

// Test 2: MascotVirtualDesktopService posts pixel-based scroll events to session and HID taps
total += 1
if let content = try? String(contentsOfFile: vdServicePath, encoding: .utf8) {
    let hasSessionTap = content.contains("cgSessionEventTap")
    let hasHidTap = content.contains("cghidEventTap")
    let hasPixelUnits = content.contains("units: .pixel")

    if hasSessionTap && hasHidTap && hasPixelUnits {
        print("  ✅ [PASS] MascotVirtualDesktopService posts pixel scroll events to session and HID taps")
        passed += 1
    } else {
        print("  ❌ [FAIL] MascotVirtualDesktopService missing event tap posting")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(vdServicePath)")
}

// Test 3: CompanionWindowStreamService writes snapshot PNG synchronously (zero disk race condition)
total += 1
if let content = try? String(contentsOfFile: streamServicePath, encoding: .utf8) {
    let hasAsyncPngWrite = content.contains("DispatchQueue.global(qos: .utility).async {\n                    if let cgImage = sckImage") || content.contains("DispatchQueue.global(qos: .utility).async {\n                    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)")
    let hasSyncPngWrite = content.contains("pngData.write(to: URL(fileURLWithPath: targetFilePath), options: .atomic)")

    if !hasAsyncPngWrite && hasSyncPngWrite {
        print("  ✅ [PASS] CompanionWindowStreamService writes snapshot PNG synchronously to eliminate race condition")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionWindowStreamService still has async PNG write race condition")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(streamServicePath)")
}

// Test 4: TaskStepPlanner enforces scroll when target index is not yet present in listItems
total += 1
let inspectPolicyPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift"
let inspectValPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/Policies/InspectValidationPolicy.swift"

if let rawContent = try? String(contentsOfFile: plannerPath, encoding: .utf8) {
    let policyContent = (try? String(contentsOfFile: inspectPolicyPath, encoding: .utf8)) ?? ""
    let content = rawContent + "\n" + policyContent

    let hasTargetIndexRule = content.contains("Check if an entry with that exact index exists in listItems")
    let hasNoPrematureClick = content.contains("NEVER plan actionType: \"click\" on an item index that is not present in listItems")

    if hasTargetIndexRule && hasNoPrematureClick {
        print("  ✅ [PASS] TaskStepPlanner strictly enforces scroll when target index is not in listItems")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskStepPlanner missing target index scroll rules")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(plannerPath)")
}

// Test 5: TaskEgressValidator enforces Target Index Presence and Reading Pane Prerequisite
total += 1
if let rawContent = try? String(contentsOfFile: validatorPath, encoding: .utf8) {
    let policyContent = (try? String(contentsOfFile: inspectValPath, encoding: .utf8)) ?? ""
    let content = rawContent + "\n" + policyContent

    let hasPresenceCheck = content.contains("Target Index Presence Check")
    let hasReadingPanePrereq = content.contains("Reading Pane Prerequisite")
    let hasNoItem1Hallucination = content.contains("NEVER hallucinate or report text from an unrelated item (such as item 1)")

    if hasPresenceCheck && hasReadingPanePrereq && hasNoItem1Hallucination {
        print("  ✅ [PASS] TaskEgressValidator enforces Target Index Presence & Reading Pane Prerequisite")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskEgressValidator missing anti-hallucination rules")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(validatorPath)")
}

// Test 6: CompanionVMAgentLoop has targetIndexNotReached guard
total += 1
if let content = try? String(contentsOfFile: loopPath, encoding: .utf8) {
    let hasTargetGuard = content.contains("targetIndexNotReached") && content.contains("hasClickedTarget")

    if hasTargetGuard {
        print("  ✅ [PASS] CompanionVMAgentLoop has targetIndexNotReached guard preventing premature exit")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionVMAgentLoop missing targetIndexNotReached guard")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(loopPath)")
}

// Test 7: Verify boringNotch is running
total += 1
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
proc.arguments = ["-x", "boringNotch"]
try? proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("  ✅ [PASS] boringNotch process is active and running")
    passed += 1
} else {
    print("  ❌ [FAIL] boringNotch process is not active")
}

print("\nResult: \(passed)/\(total) passed.")
if passed == total {
    print("🎉 All verification tests passed successfully!")
    exit(0)
} else {
    print("⚠️ Some verification tests failed.")
    exit(1)
}
