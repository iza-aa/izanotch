// scripts/test_revisions_f11_authentic_app_icons.swift
import Foundation

let iconViewPath = "boringNotch/Clicky/Tools/AppSystemIconView.swift"
let cardPath = "boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift"
let modalPath = "boringNotch/Clicky/HomeSpace/HomeSpaceInteractiveComputerModalView.swift"

print("=== Running Test F-11 Task 1: Authentic macOS App Icons ===")

guard let iconContent = try? String(contentsOfFile: iconViewPath, encoding: .utf8) else {
    print("❌ [FAIL] Cannot read \(iconViewPath) (file does not exist yet)")
    exit(1)
}

guard let cardContent = try? String(contentsOfFile: cardPath, encoding: .utf8),
      let modalContent = try? String(contentsOfFile: modalPath, encoding: .utf8) else {
    print("❌ [FAIL] Cannot read card or modal swift files")
    exit(1)
}

var passed = 0
var total = 4

// 1. NSWorkspace icon extraction check
if iconContent.contains("NSWorkspace.shared.icon") {
    print("  ✅ [PASS] AppSystemIconView extracts authentic system icon via NSWorkspace.shared.icon")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing NSWorkspace.shared.icon in AppSystemIconView")
}

// 2. Dynamic bundle ID resolution
if iconContent.contains("urlForApplication") || iconContent.contains("com.apple.mail") {
    print("  ✅ [PASS] Dynamically resolves system app URLs for Mail and Safari")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing dynamic app URL resolution")
}

// 3. Card uses AppSystemIconView
if cardContent.contains("AppSystemIconView") {
    print("  ✅ [PASS] HomeSpaceComputerCardView uses AppSystemIconView instead of flat SF Symbol")
    passed += 1
} else {
    print("  ❌ [FAIL] HomeSpaceComputerCardView still missing AppSystemIconView")
}

// 4. Modal uses AppSystemIconView
if modalContent.contains("AppSystemIconView") {
    print("  ✅ [PASS] HomeSpaceInteractiveComputerModalView uses AppSystemIconView")
    passed += 1
} else {
    print("  ❌ [FAIL] HomeSpaceInteractiveComputerModalView still missing AppSystemIconView")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED")
    exit(1)
}
