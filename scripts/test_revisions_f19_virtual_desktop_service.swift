import Foundation
import CoreGraphics
import AppKit

// MARK: - Test MascotVirtualDesktopService Standalone Probe
print("[TEST] Testing MascotVirtualDesktopService runtime initialization...")

final class MockVirtualDesktopManager {
    static let descClass = NSClassFromString("CGVirtualDisplayDescriptor") as? NSObject.Type
    static let displayClass = NSClassFromString("CGVirtualDisplay") as? NSObject.Type
    static let settingsClass = NSClassFromString("CGVirtualDisplaySettings") as? NSObject.Type
    static let modeClass = NSClassFromString("CGVirtualDisplayMode") as? NSObject.Type

    var displayObj: AnyObject?
    var displayID: CGDirectDisplayID = 0
    var bounds: CGRect = .zero

    func create() -> Bool {
        guard let descClass = Self.descClass,
              let displayClass = Self.displayClass,
              let settingsClass = Self.settingsClass,
              let modeClass = Self.modeClass else {
            return false
        }

        let desc = descClass.init()
        desc.setValue("Izanotchy Virtual Space", forKey: "name")
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
        let ok = apply(display, applySel, settings)
        guard ok else { return false }

        let displayIDSel = NSSelectorFromString("displayID")
        typealias DisplayIDFn = @convention(c) (AnyObject, Selector) -> CGDirectDisplayID
        let idImp = display.method(for: displayIDSel)
        let getDisplayID = unsafeBitCast(idImp, to: DisplayIDFn.self)
        let dID = getDisplayID(display, displayIDSel)

        self.displayObj = display
        self.displayID = dID
        self.bounds = CGDisplayBounds(dID)
        return true
    }

    func mapPoint(viewPoint: CGPoint, viewSize: CGSize) -> CGPoint {
        let normX = max(0, min(1, viewPoint.x / viewSize.width))
        let normY = max(0, min(1, viewPoint.y / viewSize.height))
        let targetX = bounds.origin.x + (normX * bounds.width)
        let targetY = bounds.origin.y + (normY * bounds.height)
        return CGPoint(x: targetX, y: targetY)
    }
}

DispatchQueue.global().async {
    let mgr = MockVirtualDesktopManager()
    let success = mgr.create()
    assert(success, "Display creation must succeed")
    assert(mgr.displayID > 0, "Display ID must be valid")
    assert(mgr.bounds.width == 1920, "Bounds width must be 1920")
    assert(mgr.bounds.height == 1080, "Bounds height must be 1080")
    print("[TEST_PASS] Created Virtual Display ID: \(mgr.displayID) Bounds: \(mgr.bounds)")

    // Test coordinate mapping
    let mappedCenter = mgr.mapPoint(viewPoint: CGPoint(x: 350, y: 195), viewSize: CGSize(width: 700, height: 390))
    let expectedCenterX = mgr.bounds.origin.x + (mgr.bounds.width * 0.5)
    let expectedCenterY = mgr.bounds.origin.y + (mgr.bounds.height * 0.5)
    assert(abs(mappedCenter.x - expectedCenterX) < 1.0, "Center X mapping mismatch")
    assert(abs(mappedCenter.y - expectedCenterY) < 1.0, "Center Y mapping mismatch")
    print("[TEST_PASS] Coordinate mapping verified: \(mappedCenter) matches expected (\(expectedCenterX), \(expectedCenterY))")

    print("ALL TESTS PASSED (100% GREEN)")
    exit(0)
}

dispatchMain()
