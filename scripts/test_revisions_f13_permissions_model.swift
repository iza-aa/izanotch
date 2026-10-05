import Foundation

print("=== Running Test F-13 Checkpoint 1: Permissions Model & Persistence ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let enumsPath = "\(rootPath)/boringNotch/Clicky/ClickyEnums.swift"
let profilePath = "\(rootPath)/boringNotch/Clicky/Roster/CompanionProfile.swift"
let rosterPath = "\(rootPath)/boringNotch/Clicky/Roster/CompanionRosterStore.swift"

var passed = 0
var total = 0

// Test 1: BuddySession defines allowedSafariDomains and safariTabAccessMode
total += 1
if let content = try? String(contentsOfFile: enumsPath, encoding: .utf8) {
    if content.contains("allowedSafariDomains: [String]") && content.contains("safariTabAccessMode: String") {
        print("  ✅ [PASS] BuddySession defines allowedSafariDomains and safariTabAccessMode")
        passed += 1
    } else {
        print("  ❌ [FAIL] BuddySession does not define allowedSafariDomains or safariTabAccessMode")
    }
} else {
    print("  ❌ [FAIL] Cannot read ClickyEnums.swift")
}

// Test 2: CompanionProfile defines Codable fields for workflowAppNames, allowedSafariDomains, and safariTabAccessMode
total += 1
if let content = try? String(contentsOfFile: profilePath, encoding: .utf8) {
    let hasApps = content.contains("workflowAppNames: [String]")
    let hasDomains = content.contains("allowedSafariDomains: [String]")
    let hasMode = content.contains("safariTabAccessMode: String")
    let hasCodingKeys = content.contains("case workflowAppNames, allowedSafariDomains, safariTabAccessMode")
    
    if hasApps && hasDomains && hasMode && hasCodingKeys {
        print("  ✅ [PASS] CompanionProfile includes Codable support for apps, safari domains, and tab mode")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionProfile missing permissions fields or CodingKeys")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionProfile.swift")
}

// Test 3: CompanionRosterStore supports updateCompanion with app and safari permissions
total += 1
if let content = try? String(contentsOfFile: rosterPath, encoding: .utf8) {
    if content.contains("workflowAppNames: [String]?") &&
       content.contains("allowedSafariDomains: [String]?") &&
       content.contains("safariTabAccessMode: String?") {
        print("  ✅ [PASS] CompanionRosterStore supports updateCompanion with app and safari permissions")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionRosterStore.updateCompanion does not accept permission arguments")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionRosterStore.swift")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    exit(1)
}
