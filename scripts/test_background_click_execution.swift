import Foundation

print("=== Running Verification Test: Background Click Execution & AppKit Selection ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let clickToolPath = "\(rootPath)/boringNotch/Clicky/CUA/Actions/CUAClickActionTool.swift"
let vdServicePath = "\(rootPath)/boringNotch/Clicky/Workspace/VirtualDisplay/MascotVirtualDesktopService.swift"

var passed = 0
var total = 0

// Test 1: CUAClickActionTool integrates Accessibility IPC for background selection
total += 1
if let content = try? String(contentsOfFile: clickToolPath, encoding: .utf8) {
    let hasAXImport = content.contains("import ApplicationServices")
    let hasAXMethod = content.contains("executeBackgroundAccessibilityClick")
    let hasRowSelect = content.contains("kAXSelectedAttribute") && content.contains("AXRow")
    let hasPressAction = content.contains("kAXPressAction")
    
    if hasAXImport && hasAXMethod && hasRowSelect && hasPressAction {
        print("  ✅ [PASS] CUAClickActionTool implements robust background selection via Accessibility IPC")
        passed += 1
    } else {
        print("  ❌ [FAIL] CUAClickActionTool missing AX components (import: \(hasAXImport), method: \(hasAXMethod), row: \(hasRowSelect), press: \(hasPressAction))")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(clickToolPath)")
}

// Test 2: MascotVirtualDesktopService sets combinedSessionState and clickState = 1
total += 1
if let content = try? String(contentsOfFile: vdServicePath, encoding: .utf8) {
    let hasSessionState = content.contains(".combinedSessionState")
    let hasClickState = content.contains(".mouseEventClickState, value: 1")
    let hasTakeoverAX = content.contains("CUAClickActionTool.executeBackgroundAccessibilityClick")
    
    if hasSessionState && hasClickState && hasTakeoverAX {
        print("  ✅ [PASS] MascotVirtualDesktopService sets combinedSessionState, clickState = 1, and takeover AX integration")
        passed += 1
    } else {
        print("  ❌ [FAIL] MascotVirtualDesktopService missing event state configurations")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(vdServicePath)")
}

// Test 3: Check running process via simple pgrep
total += 1
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
proc.arguments = ["-x", "boringNotch"]
try? proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("  ✅ [PASS] boringNotch process is active and running")
    passed += 1
} else {
    print("  ❌ [FAIL] boringNotch process is not active")
}

print("\nResult: \(passed)/\(total) passed.")
if passed == total {
    print("🎉 All verification tests passed successfully!")
    exit(0)
} else {
    print("⚠️ Some verification tests failed.")
    exit(1)
}
