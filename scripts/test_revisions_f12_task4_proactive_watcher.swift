import Foundation

print("=== Running Test F-12 Task 4: Proactive Background VM Watcher (1:1 Grok Bot) ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let watcherPath = "\(rootPath)/boringNotch/Clicky/Tools/CompanionVMBackgroundWatcher.swift"
let appPath = "\(rootPath)/boringNotch/boringNotchApp.swift"

var passed = 0
var total = 0

// Test 1: CompanionVMBackgroundWatcher exists and defines singleton actor/class
total += 1
if let content = try? String(contentsOfFile: watcherPath, encoding: .utf8) {
    if content.contains("class CompanionVMBackgroundWatcher") || content.contains("actor CompanionVMBackgroundWatcher") {
        print("  ✅ [PASS] CompanionVMBackgroundWatcher exists and defines background service")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionVMBackgroundWatcher declaration missing")
    }
} else {
    print("  ❌ [FAIL] File \(watcherPath) does not exist")
}

// Test 2: Implements lifecycle start/stop and polling loop
total += 1
if let content = try? String(contentsOfFile: watcherPath, encoding: .utf8) {
    if content.contains("func start()") && content.contains("func stop()") && content.contains("pollCycle") {
        print("  ✅ [PASS] Implements start(), stop(), and pollCycle() methods")
        passed += 1
    } else {
        print("  ❌ [FAIL] Lifecycle methods missing in CompanionVMBackgroundWatcher")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionVMBackgroundWatcher.swift")
}

// Test 3: Detects important/urgent items and posts proactive message to CompanionRosterStore
total += 1
if let content = try? String(contentsOfFile: watcherPath, encoding: .utf8) {
    if content.contains("CompanionRosterStore.shared.appendMessage") && content.contains("presentCompanionOnRail") {
        print("  ✅ [PASS] Dispatches proactive messages and presents companion on floating rail")
        passed += 1
    } else {
        print("  ❌ [FAIL] Proactive message dispatch or rail presentation missing")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionVMBackgroundWatcher.swift")
}

// Test 4: Integrated into application startup lifecycle in boringNotchApp.swift
total += 1
if let appContent = try? String(contentsOfFile: appPath, encoding: .utf8) {
    if appContent.contains("CompanionVMBackgroundWatcher.shared.start()") {
        print("  ✅ [PASS] CompanionVMBackgroundWatcher starts on application launch")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionVMBackgroundWatcher not started in boringNotchApp.swift")
    }
} else {
    print("  ❌ [FAIL] Cannot read boringNotchApp.swift")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED (EXPECTED BEFORE IMPLEMENTATION)")
    exit(1)
}
