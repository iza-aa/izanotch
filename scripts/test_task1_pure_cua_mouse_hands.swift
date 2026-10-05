import Foundation
import CoreGraphics
import AppKit

// MARK: - TDD Test: Task 1 - Pure Physical CUA Mouse Hands & Persistent Reticle
print("[TDD_TEST] Starting Task 1 verification: Pure CUA Mouse Hands & Zero Mail AppleScript...")

let projectDir = "/Users/heizaaa/Desktop/cdev/iza-3"
let serviceFilePath = "\(projectDir)/boringNotch/Clicky/Tools/MascotVirtualDesktopService.swift"

guard let serviceSource = try? String(contentsOfFile: serviceFilePath, encoding: .utf8) else {
    print("[FAIL] Cannot read MascotVirtualDesktopService.swift at \(serviceFilePath)")
    exit(1)
}

var allPassed = true

// 1. Verify NO Mail snap-to-top AppleScript remains
if serviceSource.contains("snapToTopScript") || serviceSource.contains("date \"Friday, 1 January 1970") {
    print("[FAIL] MascotVirtualDesktopService still contains hardcoded Mail snap-to-top AppleScript!")
    allPassed = false
} else {
    print("[PASS] Cleaned: No Mail snap-to-top AppleScript found.")
}

// 2. Verify virtualReticle is non-optional (always stay & ready)
if serviceSource.contains("@Published public var virtualReticle: CGPoint = CGPoint(x: 0.5, y: 0.5)") {
    print("[PASS] virtualReticle is non-optional CGPoint defaulting to (0.5, 0.5).")
} else {
    print("[FAIL] virtualReticle is not configured as non-optional persistent CGPoint defaulting to (0.5, 0.5).")
    allPassed = false
}

// 3. Verify presence of performCuaRightClick
if serviceSource.contains("func performCuaRightClick") {
    print("[PASS] performCuaRightClick exists.")
} else {
    print("[FAIL] performCuaRightClick is missing.")
    allPassed = false
}

// 4. Verify presence of performCuaScroll
if serviceSource.contains("func performCuaScroll") {
    print("[PASS] performCuaScroll exists.")
} else {
    print("[FAIL] performCuaScroll is missing.")
    allPassed = false
}

// 5. Verify presence of performCuaPressAndHold
if serviceSource.contains("func performCuaPressAndHold") {
    print("[PASS] performCuaPressAndHold exists.")
} else {
    print("[FAIL] performCuaPressAndHold is missing.")
    allPassed = false
}

// 6. Verify presence of performCuaDrag
if serviceSource.contains("func performCuaDrag") {
    print("[PASS] performCuaDrag exists.")
} else {
    print("[FAIL] performCuaDrag is missing.")
    allPassed = false
}

// 7. Verify presence of performCuaMove
if serviceSource.contains("func performCuaMove") {
    print("[PASS] performCuaMove exists.")
} else {
    print("[FAIL] performCuaMove is missing.")
    allPassed = false
}

// 8. Test CGEvent scroll wheel generation (runtime event capability)
let scrollEvent = CGEvent(
    scrollWheelEvent2Source: nil,
    units: .pixel,
    wheelCount: 2,
    wheel1: 120, // scroll up
    wheel2: 0,
    wheel3: 0
)
if scrollEvent != nil {
    print("[PASS] CoreGraphics CGEvent scroll wheel creation verified.")
} else {
    print("[FAIL] Failed to create CGEvent scroll wheel.")
    allPassed = false
}

// 9. Test CGEvent right mouse click generation
let rightDown = CGEvent(
    mouseEventSource: nil,
    mouseType: .rightMouseDown,
    mouseCursorPosition: CGPoint(x: 100, y: 100),
    mouseButton: .right
)
if rightDown != nil {
    print("[PASS] CoreGraphics CGEvent right mouse event creation verified.")
} else {
    print("[FAIL] Failed to create CGEvent right mouse event.")
    allPassed = false
}

if allPassed {
    print("[SUCCESS] ALL TASK 1 TESTS PASSED!")
    exit(0)
} else {
    print("[TDD_RED] Task 1 requirements NOT yet fulfilled. Ready for implementation.")
    exit(2)
}
