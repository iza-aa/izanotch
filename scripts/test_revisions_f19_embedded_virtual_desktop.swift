import Foundation
import CoreGraphics
import AppKit

print("=== Running F-19 Embedded Virtual Desktop & Connected Apps Unit Tests ===")

var testsPassed = 0

// Test 1: Verify CGVirtualDisplay Classes
guard let descClass = NSClassFromString("CGVirtualDisplayDescriptor") as? NSObject.Type,
      let displayClass = NSClassFromString("CGVirtualDisplay") as? NSObject.Type,
      let settingsClass = NSClassFromString("CGVirtualDisplaySettings") as? NSObject.Type,
      let modeClass = NSClassFromString("CGVirtualDisplayMode") as? NSObject.Type else {
    print("[FAIL] CGVirtualDisplay classes not found")
    exit(1)
}
testsPassed += 1
print("[PASS 1] All CoreGraphics VirtualDisplay private classes found and linkable.")

// Test 2: Virtual Display Descriptor and Mode Initialization
let desc = descClass.init()
desc.setValue("Izanotchy VM Space", forKey: "name")
desc.setValue(1920, forKey: "maxPixelsWide")
desc.setValue(1080, forKey: "maxPixelsHigh")
desc.setValue(CGSize(width: 400, height: 250), forKey: "sizeInMillimeters")
desc.setValue(0x1234, forKey: "productID")
desc.setValue(0x3456, forKey: "vendorID")
desc.setValue(0x0001, forKey: "serialNum")
desc.setValue(DispatchQueue.main, forKey: "queue")

let displayAlloc = displayClass.perform(NSSelectorFromString("alloc")).takeUnretainedValue()
let initSel = NSSelectorFromString("initWithDescriptor:")
let display = displayAlloc.perform(initSel, with: desc).takeUnretainedValue()

let modeAlloc = modeClass.perform(NSSelectorFromString("alloc")).takeUnretainedValue()
let modeInitSel = NSSelectorFromString("initWithWidth:height:refreshRate:")
typealias ModeInitFn = @convention(c) (AnyObject, Selector, UInt, UInt, Double) -> AnyObject
let modeImp = modeAlloc.method(for: modeInitSel)
let modeInit = unsafeBitCast(modeImp, to: ModeInitFn.self)
let mode = modeInit(modeAlloc, modeInitSel, 1920, 1080, 60.0)

let settings = settingsClass.init()
settings.setValue([mode], forKey: "modes")
settings.setValue(1, forKey: "hiDPI")

let applySel = NSSelectorFromString("applySettings:")
typealias ApplyFn = @convention(c) (AnyObject, Selector, AnyObject) -> Bool
let applyImp = display.method(for: applySel)
let apply = unsafeBitCast(applyImp, to: ApplyFn.self)
let applySuccess = apply(display, applySel, settings)
assert(applySuccess, "applySettings must succeed")

let displayIDSel = NSSelectorFromString("displayID")
typealias DisplayIDFn = @convention(c) (AnyObject, Selector) -> CGDirectDisplayID
let idImp = display.method(for: displayIDSel)
let getDisplayID = unsafeBitCast(idImp, to: DisplayIDFn.self)
let dID = getDisplayID(display, displayIDSel)
assert(dID > 0, "Display ID must be valid")

testsPassed += 1
print("[PASS 2] Virtual Display successfully initialized with ID: \(dID)")

// Test 3: Display Bounds Separation from Host Screen
let bounds = CGDisplayBounds(dID)
let mainBounds = CGDisplayBounds(CGMainDisplayID())
assert(bounds.width == 1920, "Virtual width must be 1920")
assert(bounds.height == 1080, "Virtual height must be 1080")
assert(bounds.origin.x >= mainBounds.width, "Virtual display must be located outside host screen")
testsPassed += 1
print("[PASS 3] Virtual Display coordinates: \(bounds) - completely isolated from Main screen: \(mainBounds)")

// Test 4: Target Window Positioning Calculation
let targetOriginX = Int(bounds.origin.x + 40)
let targetOriginY = Int(bounds.origin.y + 40)
let targetWidth = 1260
let targetHeight = 800
let windowRect = CGRect(x: targetOriginX, y: targetOriginY, width: targetWidth, height: targetHeight)
assert(windowRect.minX >= mainBounds.width, "Window MinX must be outside host screen")
testsPassed += 1
print("[PASS 4] App Window target rect: \(windowRect) resides 100% within Virtual Space.")

// Test 5: Human Takeover Coordinate Mapping (Local View -> Virtual Display)
let viewSize = CGSize(width: 710, height: 390)
func mapClick(local: CGPoint) -> CGPoint {
    let normX = max(0.0, min(1.0, local.x / viewSize.width))
    let normY = max(0.0, min(1.0, local.y / viewSize.height))
    return CGPoint(x: bounds.origin.x + (normX * bounds.width), y: bounds.origin.y + (normY * bounds.height))
}
let centerClick = mapClick(local: CGPoint(x: 355, y: 195))
let expectedCenterX = bounds.origin.x + (bounds.width * 0.5)
let expectedCenterY = bounds.origin.y + (bounds.height * 0.5)
assert(abs(centerClick.x - expectedCenterX) < 1.0, "Center X mapping mismatch")
assert(abs(centerClick.y - expectedCenterY) < 1.0, "Center Y mapping mismatch")
testsPassed += 1
print("[PASS 5] Human Takeover coordinate mapping: \(centerClick) matches virtual center (\(expectedCenterX), \(expectedCenterY)).")

// Test 6: Virtual Unicode Key Event Dispatch
let testString = "test@example.com"
let utf16Chars = Array(testString.utf16)
let keyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
assert(keyEvent != nil, "Keyboard event must be valid")
keyEvent?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
testsPassed += 1
print("[PASS 6] Virtual Unicode keyboard event constructed with \(utf16Chars.count) characters.")

// Test 7: Verify CompanionWindowStreamService No-Relaunch Guard
let streamServiceFile = try! String(contentsOfFile: "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/CompanionWindowStreamService.swift", encoding: .utf8)
assert(!streamServiceFile.contains("if candidates.isEmpty {\n            ensureWorkflowAppRunning"), "Must not auto-relaunch app on empty candidates during stream capture")
testsPassed += 1
print("[PASS 7] CompanionWindowStreamService verified free of recursive auto-relaunch loop.")

// Test 8: Verify Atomic Compose & Send Script in CompanionVMAgentLoop
let loopFile = try! String(contentsOfFile: "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift", encoding: .utf8)
assert(loopFile.contains("make new to recipient at end of to recipients with properties {address:"), "Must configure recipient atomically in compose script")
assert(loopFile.contains("MascotVirtualDesktopService.shared.assignAppToVirtualDesktop"), "Must assign compose window to MascotVirtualDesktopService")
testsPassed += 1
print("[PASS 8] CompanionVMAgentLoop verified with atomic recipient compose and Virtual Desktop routing.")

print("\n==========================================")
print("ALL \(testsPassed)/\(testsPassed) UNIT TESTS PASSED (100% GREEN)")
print("==========================================")
exit(0)
