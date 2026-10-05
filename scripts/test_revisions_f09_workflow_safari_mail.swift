import Foundation

// MARK: - TDD Test Suite: F-09 Workflow Suite (Safari + Mail) & Live Projection & Takeover

func runTests() {
    print("=== Running Test Workflow Suite (Safari + Mail) & Takeover (F-09) ===")
    var passCount = 0
    let totalTests = 5

    let basePath = "/Users/heizaaa/Desktop/cdev/iza-3"

    // 1. Test ClickyEnums: workflowAppNames & ComputerCardPayload additions
    let enumsPath = "\(basePath)/boringNotch/Clicky/ClickyEnums.swift"
    guard let enumsContent = try? String(contentsOfFile: enumsPath, encoding: .utf8) else {
        print("❌ [FAIL] Cannot read ClickyEnums.swift")
        exit(1)
    }

    if enumsContent.contains("workflowAppNames") &&
       enumsContent.contains("activeWorkflowApp") &&
       enumsContent.contains("takeoverReason") {
        print("  ✅ [PASS] ClickyEnums provides workflowAppNames and ComputerCardPayload activeWorkflowApp/takeoverReason")
        passCount += 1
    } else {
        print("  ❌ [FAIL] ClickyEnums missing workflowAppNames, activeWorkflowApp, or takeoverReason")
    }

    // 2. Test CompanionWindowStreamService: multi-app switching
    let streamServicePath = "\(basePath)/boringNotch/Clicky/Tools/CompanionWindowStreamService.swift"
    guard let streamContent = try? String(contentsOfFile: streamServicePath, encoding: .utf8) else {
        print("❌ [FAIL] Cannot read CompanionWindowStreamService.swift")
        exit(1)
    }

    if streamContent.contains("switchTargetApp") &&
       streamContent.contains("resolveRunningAppWindows") {
        print("  ✅ [PASS] CompanionWindowStreamService provides multi-app switching and window resolution")
        passCount += 1
    } else {
        print("  ❌ [FAIL] CompanionWindowStreamService missing switchTargetApp or resolveRunningAppWindows")
    }

    // 3. Test Function Calling Tools: MailWorkflowOperationTool
    let toolsPath = "\(basePath)/boringNotch/Clicky/Tools/ClickyFunctionTool.swift"
    let registryPath = "\(basePath)/boringNotch/Clicky/Tools/ClickyFunctionToolRegistry.swift"
    guard let toolsContent = try? String(contentsOfFile: toolsPath, encoding: .utf8),
          let registryContent = try? String(contentsOfFile: registryPath, encoding: .utf8) else {
        print("❌ [FAIL] Cannot read ClickyFunctionTool or ClickyFunctionToolRegistry")
        exit(1)
    }

    if toolsContent.contains("MailWorkflowOperationTool") &&
       registryContent.contains("mail_workflow_operation") {
        print("  ✅ [PASS] MailWorkflowOperationTool implemented and registered in ClickyFunctionToolRegistry")
        passCount += 1
    } else {
        print("  ❌ [FAIL] MailWorkflowOperationTool missing or not registered")
    }

    // 4. Test HomeSpaceInteractiveComputerModalView: live window projection & elimination of fake Sonoma wallpaper
    let modalPath = "\(basePath)/boringNotch/Clicky/HomeSpace/HomeSpaceInteractiveComputerModalView.swift"
    guard let modalContent = try? String(contentsOfFile: modalPath, encoding: .utf8) else {
        print("❌ [FAIL] Cannot read HomeSpaceInteractiveComputerModalView.swift")
        exit(1)
    }

    if modalContent.contains("liveWindowProjectionCanvas") &&
       !modalContent.contains("scenicNatureWallpaper") &&
       modalContent.contains("selectedDockApp") {
        print("  ✅ [PASS] HomeSpaceInteractiveComputerModalView uses liveWindowProjectionCanvas, eliminates fake Sonoma wallpaper, and provides interactive dock switching")
        passCount += 1
    } else {
        print("  ❌ [FAIL] Modal does not use liveWindowProjectionCanvas or still uses scenicNatureWallpaper")
    }

    // 5. Test Human Takeover Protocol UI
    if modalContent.contains("Take Over Screen") &&
       modalContent.contains("takeoverReason") &&
       (modalContent.contains("Resume") || modalContent.contains("Kembalikan Kontrol")) {
        print("  ✅ [PASS] Modal implements Human Takeover Protocol (Take Over Screen / Resume)")
        passCount += 1
    } else {
        print("  ❌ [FAIL] Modal missing Human Takeover Protocol UI elements")
    }

    print("=== Results: \(passCount)/\(totalTests) tests passed ===")
    if passCount == totalTests {
        print("ALL TESTS PASSED")
        exit(0)
    } else {
        print("SOME TESTS FAILED (TDD RED PHASE)")
        exit(1)
    }
}

runTests()
