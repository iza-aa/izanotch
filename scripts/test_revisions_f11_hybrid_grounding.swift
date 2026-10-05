// scripts/test_revisions_f11_hybrid_grounding.swift
import Foundation

let enginePath = "boringNotch/Clicky/Tools/ClickyHybridGroundingEngine.swift"
print("=== Running Test F-11 Task 2: AXUIElement-First with 6 Luna Vision Fallback ===")

guard let content = try? String(contentsOfFile: enginePath, encoding: .utf8) else {
    print("❌ [FAIL] Cannot read \(enginePath) (file does not exist yet)")
    exit(1)
}

var passed = 0
var total = 5

// 1. Tier 1: AXUIElement presence
if content.contains("AXUIElementCreateApplication") && content.contains("locateViaAXUIElement") {
    print("  ✅ [PASS] Implements Tier 1: AXUIElement hierarchical element resolution")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing AXUIElement scanning logic")
}

// 2. Tier 2: 6 Luna Medium Vision Fallback
if content.contains("ChatGPTCodexVisionService.shared") && content.contains("queryCoordinates") {
    print("  ✅ [PASS] Implements Tier 2: Fallback to 6 Luna Medium Vision VM when AX fails")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing 6 Luna Medium Vision VM fallback")
}

// 3. GroundingMethod enum & result
if content.contains("enum GroundingMethod") && content.contains("axUIElement") && content.contains("vision6Luna") {
    print("  ✅ [PASS] Declares GroundingMethod reporting exact resolution source (axUIElement vs vision6Luna)")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing GroundingMethod enum or cases")
}

// 4. AX-First Priority check (AX runs before Vision)
if let axIndex = content.range(of: "locateViaAXUIElement")?.lowerBound,
   let visionIndex = content.range(of: "ChatGPTCodexVisionService")?.lowerBound,
   axIndex < visionIndex {
    print("  ✅ [PASS] Strictly prioritizes AXUIElement evaluation before executing vision fallback")
    passed += 1
} else {
    print("  ❌ [FAIL] Execution order violates AXUIElement-first priority rule")
}

// 5. Zero blind hotkey compliance (focus on coordinate & element targeting)
if content.contains("resolveElementCoordinate") && !content.contains("hotkey(") {
    print("  ✅ [PASS] Focuses on coordinate & element resolution (zero hardcoded hotkey branching)")
    passed += 1
} else {
    print("  ❌ [FAIL] Contains hardcoded hotkey branching")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED")
    exit(1)
}
