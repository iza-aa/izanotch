import Foundation

// MARK: - TDD Test: Option 1 Clean & Minimalist Sandboxing Verification
print("=== Running TDD Test: Option 1 Clean Sandboxing ===")

var testsPassed = 0
var totalTests = 0

func assertTest(_ condition: Bool, _ name: String) {
    totalTests += 1
    if condition {
        testsPassed += 1
        print("  ✅ [PASS] \(name)")
    } else {
        print("  ❌ [FAIL] \(name)")
    }
}

let rootDir = "/Users/heizaaa/Desktop/cdev/iza-3"
let workspaceManagerPath = "\(rootDir)/boringNotch/Clicky/Onboarding/CompanionWorkspaceManager.swift"
let rosterStorePath = "\(rootDir)/boringNotch/Clicky/Roster/CompanionRosterStore.swift"

guard let wsContent = try? String(contentsOfFile: workspaceManagerPath, encoding: .utf8),
      let rosterContent = try? String(contentsOfFile: rosterStorePath, encoding: .utf8) else {
    print("❌ Failed to read source files")
    exit(1)
}

// Test 1: CompanionWorkspaceManager has pruneOrphanWorkspaces
let hasPrune = wsContent.contains("func pruneOrphanWorkspaces(activeSlugs:")
assertTest(hasPrune, "CompanionWorkspaceManager implements pruneOrphanWorkspaces(activeSlugs:)")

// Test 2: CompanionWorkspaceManager cleans up legacy <slug>.md and legacy output/ folder
let cleansLegacyMd = wsContent.contains("removeItem(at: legacySpec)") || wsContent.contains("removeItem(at: legacyOutputDir)")
assertTest(cleansLegacyMd, "CompanionWorkspaceManager removes legacy <slug>.md and legacy output/ directory")

// Test 3: generateCompanionSpec writes only to persona.md, no longer writing to legacySpec
let writesLegacySpec = wsContent.contains("let legacySpec = paths.baseSlugDirectory.appendingPathComponent(\"\\(profile.slug).md\")\n        try? content.write(to: legacySpec")
assertTest(!writesLegacySpec, "generateCompanionSpec does not write redundant legacy <slug>.md")

// Test 4: CompanionRosterStore calls pruneOrphanWorkspaces and deleteCompanionWorkspace
let rosterPrunes = rosterContent.contains("pruneOrphanWorkspaces")
let rosterDeletes = rosterContent.contains("deleteCompanionWorkspace")
assertTest(rosterPrunes && rosterDeletes, "CompanionRosterStore integrates pruneOrphanWorkspaces and deleteCompanionWorkspace")

// Test 5: Verify on-disk cleanup of futures-scout (no futures-scout.md, no output/)
let homeDir = FileManager.default.homeDirectoryForCurrentUser
let futuresDir = homeDir.appendingPathComponent(".izanotchy/companions/futures-scout")
let hasLegacyFuturesMd = FileManager.default.fileExists(atPath: futuresDir.appendingPathComponent("futures-scout.md").path)
let hasLegacyOutput = FileManager.default.fileExists(atPath: futuresDir.appendingPathComponent("output").path)
let hasPersonaMd = FileManager.default.fileExists(atPath: futuresDir.appendingPathComponent("persona.md").path)
let hasWorkspaceDir = FileManager.default.fileExists(atPath: futuresDir.appendingPathComponent("workspace").path)
let hasBrowserDataDir = FileManager.default.fileExists(atPath: futuresDir.appendingPathComponent("browser_data").path)

print("  Diagnostic disk state: legacyMd=\(hasLegacyFuturesMd), output=\(hasLegacyOutput), persona=\(hasPersonaMd), ws=\(hasWorkspaceDir), browser=\(hasBrowserDataDir)")
assertTest(!hasLegacyFuturesMd && !hasLegacyOutput && hasPersonaMd && hasWorkspaceDir && hasBrowserDataDir,
           "Disk verification: futures-scout contains only valid sandbox files (zero duplicates, zero legacy output)")

print("=== Results: \(testsPassed)/\(totalTests) tests passed ===")
if testsPassed == totalTests {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED (Expected before full implementation)")
    exit(1)
}
