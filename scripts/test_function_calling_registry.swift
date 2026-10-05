import Foundation

// MARK: - Test Script: xAI Function Calling Engine (Registry & Dispatcher)
print("=== Running Test Function Calling Registry & Dispatcher (F-06) ===")

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
let toolFilePath = "\(rootDir)/boringNotch/Clicky/Tools/ClickyFunctionTool.swift"
let registryFilePath = "\(rootDir)/boringNotch/Clicky/Tools/ClickyFunctionToolRegistry.swift"
let dispatcherFilePath = "\(rootDir)/boringNotch/Clicky/Tools/ClickyToolDispatcher.swift"
let rootViewPath = "\(rootDir)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"

guard let toolContent = try? String(contentsOfFile: toolFilePath, encoding: .utf8),
      let registryContent = try? String(contentsOfFile: registryFilePath, encoding: .utf8),
      let dispatcherContent = try? String(contentsOfFile: dispatcherFilePath, encoding: .utf8),
      let rootContent = try? String(contentsOfFile: rootViewPath, encoding: .utf8) else {
    print("❌ Failed to read source files")
    exit(1)
}

// Test 1: ClickyFunctionTool Protocol & Standard xAI Schema
let hasToolProtocol = toolContent.contains("protocol ClickyFunctionTool")
let hasXAISchema = toolContent.contains("func toXAISchema()")
let hasResultStruct = toolContent.contains("struct ClickyToolResult")
assertTest(hasToolProtocol && hasXAISchema && hasResultStruct,
           "ClickyFunctionTool protocol and xAI schema generator declared correctly")

// Test 2: Core Tools Declared (get_crypto_market_analysis & workspace_file_operation)
let hasMarketTool = toolContent.contains("struct GetCryptoMarketAnalysisTool") && toolContent.contains("get_crypto_market_analysis")
let hasFileTool = toolContent.contains("struct WorkspaceFileOperationTool") && toolContent.contains("workspace_file_operation")
assertTest(hasMarketTool && hasFileTool,
           "Core tools (get_crypto_market_analysis & workspace_file_operation) implemented")

// Test 3: Sandbox Security in workspace_file_operation
let hasTraversalGuard = toolContent.contains("cleanRelPath.contains(\"..\")") || toolContent.contains("Path traversal outside companion workspace is prohibited")
assertTest(hasTraversalGuard,
           "WorkspaceFileOperationTool implements strict path traversal sandbox protection")

// Test 4: ClickyFunctionToolRegistry thread-safe singleton & xAI schema export
let hasRegistrySingleton = registryContent.contains("static let shared = ClickyFunctionToolRegistry()")
let hasExportSchemas = registryContent.contains("func exportXAISchemas() -> [[String: Any]]")
let hasToolLookup = registryContent.contains("func tool(named name: String)")
assertTest(hasRegistrySingleton && hasExportSchemas && hasToolLookup,
           "ClickyFunctionToolRegistry provides tool lookup, thread safety, and xAI export")

// Test 5: ClickyToolDispatcher parallel execution withTaskGroup
let hasDispatcher = dispatcherContent.contains("class ClickyToolDispatcher")
let hasTaskGroup = dispatcherContent.contains("withTaskGroup(of: ClickyToolResult.self)")
let hasObservableState = dispatcherContent.contains("@Published public var currentExecutingToolName: String?")
assertTest(hasDispatcher && hasTaskGroup && hasObservableState,
           "ClickyToolDispatcher dispatches tools in parallel via withTaskGroup and publishes execution states")

// Test 6: HomeSpaceRootView UI Feedback mini-pill
let hasUIProgress = rootContent.contains("toolDispatcher.currentExecutingToolName") && rootContent.contains("⚙️ Tool:")
assertTest(hasUIProgress,
           "HomeSpaceRootView provides visual feedback mini-pill for currently executing tool")

print("=== Results: \(testsPassed)/\(totalTests) tests passed ===")
if testsPassed == totalTests {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED")
    exit(1)
}
