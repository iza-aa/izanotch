import Foundation

// MARK: - TDD Test: Task 4 & 5 - Universal Dynamic App Discovery & Window Matching
print("[TDD_TEST] Starting Task 4 & 5 verification: Zero Hardcoded Paths and Process Names...")

let projectDir = "/Users/heizaaa/Desktop/cdev/iza-3"
let streamServicePath = "\(projectDir)/boringNotch/Clicky/Tools/CompanionWindowStreamService.swift"
let vdServicePath = "\(projectDir)/boringNotch/Clicky/Tools/MascotVirtualDesktopService.swift"

guard let streamSource = try? String(contentsOfFile: streamServicePath, encoding: .utf8),
      let vdSource = try? String(contentsOfFile: vdServicePath, encoding: .utf8) else {
    print("[FAIL] Cannot read source files.")
    exit(1)
}

var allPassed = true

// 1. Verify NO hardcoded path branch "if clean.lowercased() == \"mail\"" in CompanionWindowStreamService
if streamSource.contains("if clean.lowercased() == \"mail\"") {
    print("[FAIL] CompanionWindowStreamService still contains hardcoded path check 'if clean.lowercased() == \"mail\"'!")
    allPassed = false
} else {
    print("[PASS] Verified: Hardcoded 'if clean.lowercased() == \"mail\"' path branch removed.")
}

// 2. Verify NO hardcoded path branch "else if clean.lowercased() == \"safari\""
if streamSource.contains("clean.lowercased() == \"safari\"") {
    print("[FAIL] CompanionWindowStreamService still contains hardcoded path check 'clean.lowercased() == \"safari\"'!")
    allPassed = false
} else {
    print("[PASS] Verified: Hardcoded 'clean.lowercased() == \"safari\"' path branch removed.")
}

// 3. Verify NO hardcoded process match "(cleanTarget == \"mail\" && ownerName.contains(\"mail\"))"
if streamSource.contains("cleanTarget == \"mail\" && ownerName.contains(\"mail\")") {
    print("[FAIL] CompanionWindowStreamService still contains hardcoded process matching '(cleanTarget == \"mail\" && ownerName.contains(\"mail\"))'!")
    allPassed = false
} else {
    print("[PASS] Verified: Hardcoded process matching for mail removed.")
}

// 4. Verify NO hardcoded hide check "(clean == \"mail\" && name.contains(\"mail\"))" in MascotVirtualDesktopService
if vdSource.contains("(clean == \"mail\" && name.contains(\"mail\"))") {
    print("[FAIL] MascotVirtualDesktopService still contains hardcoded hide check '(clean == \"mail\" && name.contains(\"mail\"))'!")
    allPassed = false
} else {
    print("[PASS] Verified: MascotVirtualDesktopService hide matching is clean.")
}

// 5. Verify universal discovery is used
if streamSource.contains("InstalledAppsDiscoveryService.shared.findAppURL") {
    print("[PASS] Verified: Universal dynamic discovery via InstalledAppsDiscoveryService is integrated.")
} else {
    print("[FAIL] InstalledAppsDiscoveryService.shared.findAppURL is not integrated in app path resolution.")
    allPassed = false
}

if allPassed {
    print("[SUCCESS] ALL TASK 4 & 5 TESTS PASSED!")
    exit(0)
} else {
    print("[TDD_RED] Task 4 & 5 requirements NOT yet fulfilled. Ready for implementation.")
    exit(2)
}
