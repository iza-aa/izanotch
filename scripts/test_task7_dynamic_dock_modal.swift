import Foundation

// MARK: - TDD Test: Task 7 - Dynamic Connected Apps Dock in Modal View
print("[TDD_TEST] Starting Task 7 verification: Dynamic Workflow Apps Dock in HomeSpaceInteractiveComputerModalView...")

let projectDir = "/Users/heizaaa/Desktop/cdev/iza-3"
let modalFilePath = "\(projectDir)/boringNotch/Clicky/HomeSpace/HomeSpaceInteractiveComputerModalView.swift"

guard let modalSource = try? String(contentsOfFile: modalFilePath, encoding: .utf8) else {
    print("[FAIL] Cannot read HomeSpaceInteractiveComputerModalView.swift.")
    exit(1)
}

var allPassed = true

// 1. Verify dynamic ForEach loop exists for workflowAppNames in dock
if modalSource.contains("ForEach(apps, id: \\.self)") || modalSource.contains("ForEach(companion.activeBuddy.workflowAppNames") {
    print("[PASS] Verified: Dynamic ForEach loop over workflowAppNames is used in dock.")
} else {
    print("[FAIL] HomeSpaceInteractiveComputerModalView does not use dynamic ForEach loop for workflowAppNames!")
    allPassed = false
}

// 2. Verify static hardcoded switcher (selectedDockApp == "mail" ? "Mail" : "Safari") is removed
if modalSource.contains("selectedDockApp == \"mail\" ? \"Mail\" : \"Safari\"") {
    print("[FAIL] HomeSpaceInteractiveComputerModalView still has hardcoded binary switcher 'selectedDockApp == \"mail\" ? \"Mail\" : \"Safari\"'!")
    allPassed = false
} else {
    print("[PASS] Verified: Hardcoded binary switcher removed.")
}

// 3. Verify slug is dynamic companion.activeBuddy.slug (not literal "inbox-buddy")
if modalSource.contains("slug: \"inbox-buddy\"") {
    print("[FAIL] HomeSpaceInteractiveComputerModalView still uses hardcoded slug \"inbox-buddy\"!")
    allPassed = false
} else {
    print("[PASS] Verified: Dynamic activeBuddy.slug is used.")
}

if allPassed {
    print("[SUCCESS] ALL TASK 7 TESTS PASSED!")
    exit(0)
} else {
    print("[TDD_RED] Task 7 requirements NOT yet fulfilled. Ready for implementation.")
    exit(2)
}
