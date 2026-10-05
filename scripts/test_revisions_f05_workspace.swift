import Foundation

// MARK: - Test Revisions F-05: Per-Companion Workspace & Storage Isolation
print("=== Running Test Revisions F-05 (Workspace Isolation) ===")

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
let enumsPath = "\(rootDir)/boringNotch/Clicky/ClickyEnums.swift"
let rootViewPath = "\(rootDir)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"

guard let wsContent = try? String(contentsOfFile: workspaceManagerPath, encoding: .utf8),
      let enumsContent = try? String(contentsOfFile: enumsPath, encoding: .utf8),
      let rootContent = try? String(contentsOfFile: rootViewPath, encoding: .utf8) else {
    print("❌ Failed to read source files")
    exit(1)
}

// Test 1: CompanionWorkspacePaths struct defines complete sandbox hierarchy
let hasPathsStruct = wsContent.contains("struct CompanionWorkspacePaths")
let hasWorkspaceDir = wsContent.contains("workspaceDirectory")
let hasBrowserDataDir = wsContent.contains("browserDataDirectory")
let hasMemoryFile = wsContent.contains("memoryFile")
assertTest(hasPathsStruct && hasWorkspaceDir && hasBrowserDataDir && hasMemoryFile, 
           "CompanionWorkspacePaths defines complete isolated workspace hierarchy")

// Test 2: ensureWorkspaceHierarchy generates workspace, browser_data, memory.json, and shared_workspace
let hasEnsureMethod = wsContent.contains("func ensureWorkspaceHierarchy(for slug: String)")
let hasSharedWorkspace = wsContent.contains("sharedWorkspaceDirectory")
let hasDeliverables = wsContent.contains("deliverables")
let hasSnapshots = wsContent.contains("snapshots")
assertTest(hasEnsureMethod && hasSharedWorkspace && hasDeliverables && hasSnapshots,
           "ensureWorkspaceHierarchy creates workspace/ (deliverables, snapshots), browser_data/ and shared_workspace")

// Test 3: openWorkspaceInFinder exists and invokes NSWorkspace
let hasFinderMethod = wsContent.contains("func openWorkspaceInFinder(for slug: String)")
let hasNSWorkspace = wsContent.contains("NSWorkspace.shared.open")
assertTest(hasFinderMethod && hasNSWorkspace,
           "openWorkspaceInFinder is implemented and opens directory via NSWorkspace")

// Test 4: BuddySession has computed slug property
let hasSlugProperty = enumsContent.contains("public var slug: String")
assertTest(hasSlugProperty, "BuddySession provides computed slug property")

// Test 5: HomeSpaceRootView has 'Open Workspace in Finder' button in Edit Studio and sidebar context menu
let hasEditStudioWorkspace = rootContent.contains("Open Workspace in Finder") || rootContent.contains("WORKSPACE & SANDBOX")
let hasSidebarContextWorkspace = rootContent.contains("openWorkspaceInFinder")
assertTest(hasEditStudioWorkspace && hasSidebarContextWorkspace,
           "HomeSpaceRootView provides UI access to open companion workspace in Finder")

print("=== Results: \(testsPassed)/\(totalTests) tests passed ===")
if testsPassed == totalTests {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED (Expected before implementation)")
    exit(1)
}
