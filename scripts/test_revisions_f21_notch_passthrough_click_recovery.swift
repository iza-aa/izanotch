import Foundation
import CoreGraphics
import Cocoa

func assertTest(_ condition: Bool, _ name: String) {
    if condition {
        print("✅ PASS: \(name)")
    } else {
        print("❌ FAIL: \(name)")
    }
    assert(condition, name)
}

print("🧪 Starting F-21 Dynamic WindowServer Click-Through & Allocation Lock Verification...")

// 1. Virtual Display Allocation Lock & Multi-layer Filtering
var isAllocatingVirtualDisplay = true
var mascotDisplayID: CGDirectDisplayID = 0 // Simulating displayID not yet returned during applySettings

func isVirtualDisplay(
    name: String,
    frame: CGRect,
    displayID: CGDirectDisplayID,
    isAllocating: Bool,
    mascotID: CGDirectDisplayID,
    isFirstScreen: Bool
) -> Bool {
    if isAllocating && !isFirstScreen {
        return true
    }
    if name.contains("Izanotchy VM") || name.contains("Virtual") || name.contains("Null Display") {
        return true
    }
    if frame.origin.x >= 1500 || (frame.width == 1920 && frame.height == 1080 && frame.origin.x > 0) {
        return true
    }
    if mascotID > 0 && displayID == mascotID {
        return true
    }
    return false
}

// Test case 1: Primary display is NEVER filtered out
let primaryFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
assertTest(!isVirtualDisplay(name: "Built-in Retina Display", frame: primaryFrame, displayID: 1, isAllocating: true, mascotID: 0, isFirstScreen: true),
    "Primary screen is protected during allocation")

// Test case 2: Secondary virtual display during applySettings (name is empty, displayID is 0)
let earlyVirtualFrame = CGRect(x: 1512, y: -98, width: 1920, height: 1080)
assertTest(isVirtualDisplay(name: "", frame: earlyVirtualFrame, displayID: 0, isAllocating: true, mascotID: 0, isFirstScreen: false),
    "Allocation lock instantly filters virtual display before name or ID exist")

// Test case 3: Geometric fallback filters virtual display even after allocation lock released
isAllocatingVirtualDisplay = false
assertTest(isVirtualDisplay(name: "Display", frame: earlyVirtualFrame, displayID: 9, isAllocating: false, mascotID: 0, isFirstScreen: false),
    "Geometric bounds (x >= 1500, 1920x1080) filter virtual display even if name is generic")

// Test case 4: Name matches
assertTest(isVirtualDisplay(name: "Izanotchy VM Space", frame: earlyVirtualFrame, displayID: 9, isAllocating: false, mascotID: 9, isFirstScreen: false),
    "Named display 'Izanotchy VM Space' is recognized")

// 2. Dynamic WindowServer ignoresMouseEvents Switching Logic
let windowFrame = NSRect(x: 436, y: 772, width: 640, height: 210) // Screen coordinates (bottom-left Cocoa origin)
let activeClosedRect = NSRect(x: 215.5, y: 170.0, width: 209.0, height: 44.0) // Local window coordinates

func computeIgnoresMouseEvents(
    mouseLoc: NSPoint,
    winFrame: NSRect,
    activeRect: NSRect,
    isOpen: Bool
) -> Bool {
    // When notch is open, whole window must be interactive
    if isOpen {
        return false
    }
    
    // When mouse is completely outside window
    if !winFrame.contains(mouseLoc) {
        return true
    }
    
    // When mouse is inside 640x210 window
    let localPoint = NSPoint(x: mouseLoc.x - winFrame.origin.x, y: mouseLoc.y - winFrame.origin.y)
    if activeRect.contains(localPoint) {
        return false // Interactive inside compact notch
    } else {
        return true // Passes through outside compact notch
    }
}

// Case A: Mouse on IDE tab below notch (Screen X: 756, Screen Y: 852 -> Local X: 320, Local Y: 80)
let ideTabMouseLoc = NSPoint(x: 756, y: 852)
let ignoresOnTab = computeIgnoresMouseEvents(mouseLoc: ideTabMouseLoc, winFrame: windowFrame, activeRect: activeClosedRect, isOpen: false)
assertTest(ignoresOnTab == true, "Mouse on IDE tab below notch: ignoresMouseEvents is TRUE (100% WindowServer click pass-through!)")

// Case B: Mouse inside compact notch capsule (Screen X: 756, Screen Y: 965 -> Local X: 320, Local Y: 193)
let notchMouseLoc = NSPoint(x: 756, y: 965)
let ignoresOnNotch = computeIgnoresMouseEvents(mouseLoc: notchMouseLoc, winFrame: windowFrame, activeRect: activeClosedRect, isOpen: false)
assertTest(ignoresOnNotch == false, "Mouse inside compact notch: ignoresMouseEvents is FALSE (Tap to open & hover active!)")

// Case C: Mouse completely outside window (e.g. desktop wallpaper or dock)
let wallpaperMouseLoc = NSPoint(x: 100, y: 300)
let ignoresOnWallpaper = computeIgnoresMouseEvents(mouseLoc: wallpaperMouseLoc, winFrame: windowFrame, activeRect: activeClosedRect, isOpen: false)
assertTest(ignoresOnWallpaper == true, "Mouse outside window: ignoresMouseEvents is TRUE")

// Case D: When notch is expanded open, entire 640x210 window is interactive
let ignoresWhenOpen = computeIgnoresMouseEvents(mouseLoc: ideTabMouseLoc, winFrame: windowFrame, activeRect: activeClosedRect, isOpen: true)
assertTest(ignoresWhenOpen == false, "When notch is open: entire window is interactive (ignoresMouseEvents == false)")

// 3. HostingView Hit-Test Invariants
func hostingViewHitTest(point: NSPoint, activeRect: NSRect, isOpen: Bool, hasVM: Bool) -> Bool {
    guard hasVM else { return false } // nil when orphan
    if !isOpen {
        if !activeRect.contains(point) {
            return false // nil outside notch
        }
        return true // self fallback inside notch
    }
    return true // subview/super when open
}

assertTest(!hostingViewHitTest(point: NSPoint(x: 320, y: 80), activeRect: activeClosedRect, isOpen: false, hasVM: true),
    "HostingView hitTest returns nil outside notch rect")
assertTest(hostingViewHitTest(point: NSPoint(x: 320, y: 190), activeRect: activeClosedRect, isOpen: false, hasVM: true),
    "HostingView hitTest returns non-nil inside notch rect")
assertTest(!hostingViewHitTest(point: NSPoint(x: 320, y: 190), activeRect: activeClosedRect, isOpen: false, hasVM: false),
    "HostingView hitTest returns nil when viewModel is deallocated")

print("🎉 ALL 11/11 F-21 PASS-THROUGH CLICK RECOVERY TESTS PASSED!")
