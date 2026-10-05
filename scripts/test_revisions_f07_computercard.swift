import Foundation

// MARK: - Test Suite for Fitur F-07: Kartu Chat Interaktif "Computer" (1:1 Foto 1)

var testsPassed = 0
var totalTests = 0

func assertTest(_ condition: Bool, _ message: String) {
    totalTests += 1
    if condition {
        print("  ✅ [PASS] \(message)")
        testsPassed += 1
    } else {
        print("  ❌ [FAIL] \(message)")
    }
}

print("=== Running Test Interactive Computer Card (F-07) ===")

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath

// Test 1: Check ClickyEnums.swift contains ComputerCardStatus and ComputerCardPayload
let clickyEnumsPath = "\(currentDir)/boringNotch/Clicky/ClickyEnums.swift"
if let enumsContent = try? String(contentsOfFile: clickyEnumsPath, encoding: .utf8) {
    let hasStatusEnum = enumsContent.contains("enum ComputerCardStatus") &&
                          enumsContent.contains("case working = \"Working\"") &&
                          enumsContent.contains("case done = \"Done\"")
    let hasPayloadStruct = enumsContent.contains("struct ComputerCardPayload") &&
                           enumsContent.contains("var instructionText: String") &&
                           enumsContent.contains("var snapshotImagePath: String?")
    let hasMessageIntegration = enumsContent.contains("var computerPayload: ComputerCardPayload?")
    
    assertTest(hasStatusEnum && hasPayloadStruct && hasMessageIntegration, "ClickyEnums defines ComputerCardStatus, ComputerCardPayload, and integrates into HomeSpaceChatMessage")
} else {
    assertTest(false, "Failed to read ClickyEnums.swift")
}

// Test 2: Check HomeSpaceComputerCardView.swift exists and implements 1:1 Foto 1 elements
let cardViewPath = "\(currentDir)/boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift"
if let cardContent = try? String(contentsOfFile: cardViewPath, encoding: .utf8) {
    let hasHeader = cardContent.contains("Text(payload.cardTitle)") || cardContent.contains("Text(\"Computer\")")
    let hasStatusPill = cardContent.contains("statusPill") || cardContent.contains("payload.status")
    let hasInstruction = cardContent.contains("instructionText")
    let hasCanvas = cardContent.contains("canvasFrame") || cardContent.contains("mockupDesktopCanvas")
    let hasTakeoverButton = cardContent.contains("takeoverNeeded") || cardContent.contains("Take Over Screen")

    assertTest(hasHeader && hasStatusPill && hasInstruction && hasCanvas && hasTakeoverButton, "HomeSpaceComputerCardView implements header, status pill, instruction text, and visual canvas")
} else {
    assertTest(false, "HomeSpaceComputerCardView.swift exists and defines required visual components")
}

// Test 3: Check HomeSpaceComputerCardView has fallback mockup desktop canvas or F-10 live workspace grounding canvas
if let cardContent = try? String(contentsOfFile: cardViewPath, encoding: .utf8) {
    let hasLiveOrMockup = cardContent.contains("workspaceConnectionPlaceholder") || cardContent.contains("precisionGroundingOverlay") || cardContent.contains("mockupDesktopCanvas")
    assertTest(hasLiveOrMockup, "HomeSpaceComputerCardView canvas provides live workspace projection or precision grounding canvas")
} else {
    assertTest(false, "HomeSpaceComputerCardView renders live workspace projection canvas")
}

// Test 4: Check HomeSpaceRootView integrates HomeSpaceComputerCardView
let rootViewPath = "\(currentDir)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
if let rootContent = try? String(contentsOfFile: rootViewPath, encoding: .utf8) {
    let hasCardInvocation = rootContent.contains("HomeSpaceComputerCardView(payload:")
    assertTest(hasCardInvocation, "HomeSpaceRootView embeds HomeSpaceComputerCardView in the assistant message loop")
} else {
    assertTest(false, "Failed to read HomeSpaceRootView.swift")
}

// Test 5: Check project.pbxproj registers HomeSpaceComputerCardView.swift
let pbxPath = "\(currentDir)/boringNotch.xcodeproj/project.pbxproj"
if let pbxContent = try? String(contentsOfFile: pbxPath, encoding: .utf8) {
    let isRegistered = pbxContent.contains("HomeSpaceComputerCardView.swift in Sources")
    assertTest(isRegistered, "boringNotch.xcodeproj registers HomeSpaceComputerCardView.swift in Sources build phase")
} else {
    assertTest(false, "Failed to read project.pbxproj")
}

print("=== Results: \(testsPassed)/\(totalTests) tests passed ===")
if testsPassed == totalTests {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("TESTS FAILED")
    exit(1)
}
