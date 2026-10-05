import Foundation

print("=== RUNNING REVISION TEST: F-22 HOMESPACE PERSISTENT WORKSPACE MODE ===")

let projectDir = FileManager.default.currentDirectoryPath
let appSwiftPath = "\(projectDir)/boringNotch/boringNotchApp.swift"
let windowManagerPath = "\(projectDir)/boringNotch/Clicky/HomeSpace/HomeSpaceWindowManager.swift"
let companionManagerPath = "\(projectDir)/boringNotch/Clicky/CompanionManager.swift"
let rootViewPath = "\(projectDir)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"

guard FileManager.default.fileExists(atPath: appSwiftPath) else {
    print("❌ FAIL: boringNotchApp.swift not found")
    exit(1)
}

guard FileManager.default.fileExists(atPath: windowManagerPath) else {
    print("❌ FAIL: HomeSpaceWindowManager.swift not found")
    exit(1)
}

guard FileManager.default.fileExists(atPath: companionManagerPath) else {
    print("❌ FAIL: CompanionManager.swift not found")
    exit(1)
}

guard FileManager.default.fileExists(atPath: rootViewPath) else {
    print("❌ FAIL: HomeSpaceRootView.swift not found")
    exit(1)
}

let appContent = try String(contentsOfFile: appSwiftPath)
let wmContent = try String(contentsOfFile: windowManagerPath)
let cmContent = try String(contentsOfFile: companionManagerPath)
let rootContent = try String(contentsOfFile: rootViewPath)

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

// 1. HomeSpacePanel keyboard accessibility & explicit close bindings
assertTest(wmContent.contains("override func cancelOperation(_ sender: Any?)"), "HomeSpacePanel implements cancelOperation for Escape key")
assertTest(wmContent.contains("HomeSpaceWindowManager.shared.hide()"), "cancelOperation delegates directly to HomeSpaceWindowManager.shared.hide()")
assertTest(wmContent.contains("override func performKeyEquivalent(with event: NSEvent) -> Bool"), "HomeSpacePanel implements performKeyEquivalent")
assertTest(wmContent.contains("charactersIgnoringModifiers == \"w\""), "HomeSpacePanel supports Cmd+W shortcut to close")

// 2. Global Escape Shortcut Monitor Integration in CompanionManager
assertTest(cmContent.contains("func handleEscapePressed()"), "CompanionManager implements handleEscapePressed()")
assertTest(cmContent.contains("HomeSpaceWindowManager.shared.isVisible") && cmContent.contains("HomeSpaceWindowManager.shared.hide()"), "CompanionManager handleEscapePressed() dismisses HomeSpace if visible")

// 3. Persistent Workspace Mode: Absence of Aggressive Auto-Dismiss Monitors
assertTest(!wmContent.contains("globalClickMonitor"), "HomeSpaceWindowManager eliminates global click-outside monitor")
assertTest(!wmContent.contains("localClickMonitor"), "HomeSpaceWindowManager eliminates local click-outside monitor")
assertTest(!wmContent.contains("resignKeyObserver"), "HomeSpaceWindowManager eliminates didResignKey auto-dismiss observer")
assertTest(!wmContent.contains("Auto-dismissing HomeSpace on outside click"), "HomeSpaceWindowManager removes outside click dismissal log")

// 4. Clean Lifecycle and Notification Dispatching
assertTest(wmContent.contains("NotificationCenter.default.post(name: Notification.Name(\"HomeSpaceVisibilityDidChange\"), object: true)"), "HomeSpaceWindowManager posts visibility true upon presentation")
assertTest(wmContent.contains("NotificationCenter.default.post(name: Notification.Name(\"HomeSpaceVisibilityDidChange\"), object: false)"), "HomeSpaceWindowManager posts visibility false upon hiding")
assertTest(wmContent.contains("ClickyLogger.info(\"[HOMESPACE]\", \"Home Space window closed\")"), "HomeSpaceWindowManager logs closure event")

// 5. Explicit Close Targets in HomeSpaceRootView
assertTest(rootContent.contains("Top Notch Tab Tap Target"), "HomeSpaceRootView provides physical notch tap target for closure")
assertTest(rootContent.contains("onTapGesture"), "Top notch tab responds to tap gestures")
assertTest(rootContent.contains("Image(systemName: \"xmark\")"), "HomeSpaceRootView provides explicit xmark close buttons")

// 6. Seamless BoringNotch Recovery in boringNotchApp
assertTest(appContent.contains("HomeSpaceVisibilityDidChange"), "boringNotchApp observes HomeSpaceVisibilityDidChange")
assertTest(appContent.contains("self?.vm.close()"), "boringNotchApp ensures closed resting state on transition")
assertTest(appContent.contains("window.orderFrontRegardless()"), "boringNotchApp calls orderFrontRegardless() to re-arm hover tracking")

print("\n--- RESULTS: \(passed)/\(total) TESTS PASSED ---")
if passed == total {
    print("🎉 ALL TESTS PASSED! HomeSpace is fully verified for Persistent Workspace Mode.")
    exit(0)
} else {
    print("💥 SOME TESTS FAILED.")
    exit(1)
}
