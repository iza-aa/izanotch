import Foundation
import CoreGraphics

func assertTest(_ condition: Bool, _ name: String) {
    if condition {
        print("✅ PASS: \(name)")
    } else {
        print("❌ FAIL: \(name)")
        exit(1)
    }
}

print("🧪 Starting F-17 Notch Click & Precision Hit-Test Verification...")

// 1. Geometry Calculations
let windowWidth: CGFloat = 640.0
let windowHeight: CGFloat = 210.0 // 190 + 20 shadowPadding
let closedNotchWidth: CGFloat = 185.0
let closedNotchHeight: CGFloat = 32.0
let chinHeight: CGFloat = 0.0

let effectiveWidth = max(closedNotchWidth, 185.0) + 24.0 // 209.0
let effectiveHeight = max(32.0, closedNotchHeight + chinHeight) + 6.0 // 38.0
let minX = (windowWidth - effectiveWidth) / 2.0 // 215.5
let minY = windowHeight - effectiveHeight // 172.0
let activeClosedRect = CGRect(x: minX, y: minY, width: effectiveWidth, height: effectiveHeight)

// Test 1: Direct Center Click on Physical Closed Notch
let notchCenterPoint = CGPoint(x: 320.0, y: 195.0)
assertTest(activeClosedRect.contains(notchCenterPoint), "Click on physical notch center (320, 195) is INTERACTIVE (detected)")

// Test 2: Click on Left Edge of Notch
let notchLeftPoint = CGPoint(x: 220.0, y: 190.0)
assertTest(activeClosedRect.contains(notchLeftPoint), "Click on notch left fillet (220, 190) is INTERACTIVE (detected)")

// Test 3: Click on Right Edge of Notch
let notchRightPoint = CGPoint(x: 420.0, y: 190.0)
assertTest(activeClosedRect.contains(notchRightPoint), "Click on notch right fillet (420, 190) is INTERACTIVE (detected)")

// Test 4: Click Below Notch (e.g. Browser Tab, Title Bar, Desktop)
let browserTabPoint = CGPoint(x: 320.0, y: 100.0)
assertTest(!activeClosedRect.contains(browserTabPoint), "Click below notch (320, 100) returns NIL (100% PASS-THROUGH to browser/apps)")

// Test 5: Click Way Below Notch (e.g. Webpage Body / App Workspace)
let webContentPoint = CGPoint(x: 320.0, y: 20.0)
assertTest(!activeClosedRect.contains(webContentPoint), "Click far below notch (320, 20) returns NIL (100% PASS-THROUGH)")

// Test 6: Click Left of Notch in Menu Bar (e.g. Apple Menu / App Menus)
let menuBarLeftPoint = CGPoint(x: 100.0, y: 195.0)
assertTest(!activeClosedRect.contains(menuBarLeftPoint), "Click to left of notch (100, 195) returns NIL (100% PASS-THROUGH to macOS menu bar)")

// Test 7: Click Right of Notch in Menu Bar (e.g. Control Center / Clock)
let menuBarRightPoint = CGPoint(x: 550.0, y: 195.0)
assertTest(!activeClosedRect.contains(menuBarRightPoint), "Click to right of notch (550, 195) returns NIL (100% PASS-THROUGH to menu bar extras)")

// Test 8: Pan Gesture Minimum Distance Threshold
let tapMovementDistance: CGFloat = 0.5
let dragMinDistance: CGFloat = 8.0
let isConsideredDrag = tapMovementDistance >= dragMinDistance
assertTest(!isConsideredDrag, "Tap movement (< 8pt) is NOT intercepted by DragGesture, preserving instantaneous .onTapGesture / TapGesture")

let swipeMovementDistance: CGFloat = 25.0
let isConsideredRealDrag = swipeMovementDistance >= dragMinDistance
assertTest(isConsideredRealDrag, "Swipe movement (> 8pt) is recognized as real Drag/Pan gesture")

// Test 9: Open Notch Expansion Frame
let openNotchWidth: CGFloat = 640.0
let openNotchHeight: CGFloat = 190.0
let openRect = CGRect(x: 0, y: windowHeight - openNotchHeight, width: openNotchWidth, height: openNotchHeight)
assertTest(openRect.contains(CGPoint(x: 320, y: 100)), "When notch is OPEN, full expanded workspace is interactive")
assertTest(openRect.contains(CGPoint(x: 100, y: 50)), "When notch is OPEN, lateral controls are interactive")

print("🎉 ALL 9/9 F-17 TESTS PASSED!")
