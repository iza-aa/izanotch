import Foundation

print("=== RUNNING REVISION TEST: F-14 NOTCH HOVER RECOVERY & LIFECYCLE ===")

let projectDir = FileManager.default.currentDirectoryPath
let appSwiftPath = "\(projectDir)/boringNotch/boringNotchApp.swift"
let windowManagerPath = "\(projectDir)/boringNotch/Clicky/HomeSpace/HomeSpaceWindowManager.swift"
let headerSwiftPath = "\(projectDir)/boringNotch/components/Notch/BoringHeader.swift"

guard FileManager.default.fileExists(atPath: appSwiftPath) else {
    print("❌ FAIL: boringNotchApp.swift not found")
    exit(1)
}

guard FileManager.default.fileExists(atPath: windowManagerPath) else {
    print("❌ FAIL: HomeSpaceWindowManager.swift not found")
    exit(1)
}

guard FileManager.default.fileExists(atPath: headerSwiftPath) else {
    print("❌ FAIL: BoringHeader.swift not found")
    exit(1)
}

let appContent = try String(contentsOfFile: appSwiftPath)
let wmContent = try String(contentsOfFile: windowManagerPath)
let headerContent = try String(contentsOfFile: headerSwiftPath)

var passed = 0
var total = 0

func assertTest(_ condition: Bool, _ name: String) {
    total += 1
    if condition {
        passed += 1
        print("✅ [\(passed)/\(total)] PASS: \(name)")
    } else {
        print("❌ [\(passed)/\(total)] FAIL: \(name)")
    }
}

// 1. Check HomeSpacePanel key bindings (Escape and Cmd+W)
assertTest(wmContent.contains("override func cancelOperation(_ sender: Any?)"), "HomeSpacePanel implements cancelOperation for Escape key")
assertTest(wmContent.contains("HomeSpaceWindowManager.shared.hide()"), "cancelOperation calls HomeSpaceWindowManager.shared.hide()")
assertTest(wmContent.contains("override func performKeyEquivalent(with event: NSEvent) -> Bool"), "HomeSpacePanel implements performKeyEquivalent")
assertTest(wmContent.contains("charactersIgnoringModifiers == \"w\""), "HomeSpacePanel supports Cmd+W to close")

// 2. Check HomeSpaceWindowManager hide completion notification
assertTest(wmContent.contains("ClickyLogger.info(\"[HOMESPACE]\", \"Home Space window closed\")"), "HomeSpaceWindowManager logs closure event")
assertTest(wmContent.contains("NotificationCenter.default.post(name: Notification.Name(\"HomeSpaceVisibilityDidChange\"), object: false)"), "HomeSpaceWindowManager dispatches HomeSpaceVisibilityDidChange false")

// 3. Check boringNotchApp observer restores vm.close(), alphaValue, orderFrontRegardless, and ignoresMouseEvents
assertTest(appContent.contains("self?.vm.close()"), "boringNotchApp calls self?.vm.close() on visibility change")
assertTest(appContent.contains("window.orderFrontRegardless()"), "boringNotchApp calls orderFrontRegardless() to re-arm WindowServer hover tracking")
assertTest(appContent.contains("window.ignoresMouseEvents = false"), "boringNotchApp explicitly ensures ignoresMouseEvents is false")
assertTest(appContent.contains("singleWindow = self?.window"), "boringNotchApp includes single window in allWindows collection")

// 4. Check BoringHeader studio expansion closes notch
assertTest(headerContent.contains("vm.close()"), "BoringHeader calls vm.close() when transitioning to HomeSpace studio")

// 5. Check Spotlight/Raycast Native Auto-Dismiss on HomeSpaceWindowManager
assertTest(wmContent.contains("addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])"), "HomeSpaceWindowManager registers global click-outside monitor")
assertTest(wmContent.contains("addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])"), "HomeSpaceWindowManager registers local click-outside monitor")
assertTest(wmContent.contains("NSWindow.didResignKeyNotification"), "HomeSpaceWindowManager observes didResignKey for auto-dismiss")

// 6. Check HomeSpaceRootView top notch hit target
let rootViewPath = "\(projectDir)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
let rootContent = (try? String(contentsOfFile: rootViewPath)) ?? ""
assertTest(rootContent.contains("Top Notch Tab Tap Target"), "HomeSpaceRootView provides top notch tab tap target")
assertTest(rootContent.contains("onTapGesture"), "Top notch tab has tap gesture to close back to notch")

print("\n--- RESULTS: \(passed)/\(total) TESTS PASSED ---")
if passed == total {
    print("🎉 ALL TESTS PASSED! Ready for clean compilation and live verification.")
    exit(0)
} else {
    print("💥 SOME TESTS FAILED.")
    exit(1)
}
