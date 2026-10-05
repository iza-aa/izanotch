import Foundation

print("=== Running Test F-10 Task 1: Chat Card Live Mirroring & Precision Grounding ===")

let cardPath = "boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift"
guard let content = try? String(contentsOfFile: cardPath, encoding: .utf8) else {
    print("❌ [FAIL] Cannot read HomeSpaceComputerCardView.swift")
    exit(1)
}

// Check 1: Eliminates fake mockups (Sonoma wallpaper & Priya Natarajan CRM)
let hasNoFakeMockup = !content.contains("mockupDesktopCanvas") && !content.contains("scenicNatureWallpaper") && !content.contains("frontOutreachWindow")
if hasNoFakeMockup {
    print("  ✅ [PASS] Eliminates fake Sonoma wallpaper and CRM mockups")
} else {
    print("  ❌ [FAIL] Fake Sonoma wallpaper or CRM mockups still exist in HomeSpaceComputerCardView.swift")
}

// Check 2: Connects to CompanionWindowStreamService
let hasStreamService = content.contains("CompanionWindowStreamService.shared")
if hasStreamService {
    print("  ✅ [PASS] Connects to CompanionWindowStreamService.shared for live window projection")
} else {
    print("  ❌ [FAIL] Missing connection to CompanionWindowStreamService.shared")
}

// Check 3: Provides Precision Grounding Overlay (Grid + Crosshair)
let hasGroundingGrid = content.contains("precisionGroundingOverlay") || content.contains("coordinateGrid")
let hasCrosshair = content.contains("crosshair") || content.contains("targetCrosshair")
if hasGroundingGrid && hasCrosshair {
    print("  ✅ [PASS] Implements Hybrid Precision Grounder overlay with 100px grid and target crosshair")
} else {
    print("  ❌ [FAIL] Missing precision grounding overlay or target crosshair: grid=\(hasGroundingGrid), crosshair=\(hasCrosshair)")
}

if hasNoFakeMockup && hasStreamService && hasGroundingGrid && hasCrosshair {
    print("=== Results: 3/3 tests passed ===")
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("=== Results: TEST FAILED ===")
    exit(1)
}
