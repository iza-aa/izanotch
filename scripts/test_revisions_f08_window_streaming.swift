import Foundation

// MARK: - Test Suite for Fitur F-08: Live Window Streaming & Interactive Modal (1:1 Foto Baru)

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

print("=== Running Test Live Window Streaming & Interactive Modal (F-08) ===")

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath

// Test 1: Check CompanionWindowStreamService.swift exists and defines window capture functions
let streamServicePath = "\(currentDir)/boringNotch/Clicky/Tools/CompanionWindowStreamService.swift"
if let serviceContent = try? String(contentsOfFile: streamServicePath, encoding: .utf8) {
    let hasClass = serviceContent.contains("class CompanionWindowStreamService") || serviceContent.contains("actor CompanionWindowStreamService")
    let hasCaptureMethod = serviceContent.contains("captureTargetWindow") || serviceContent.contains("captureWindow")
    let hasSnapshotPath = serviceContent.contains("active_frame.png") || serviceContent.contains("snapshots")
    
    assertTest(hasClass && hasCaptureMethod && hasSnapshotPath, "CompanionWindowStreamService provides target window detection and frame snapshot caching")
} else {
    assertTest(false, "CompanionWindowStreamService.swift exists and provides window capture logic")
}

// Test 2: Check HomeSpaceInteractiveComputerModalView.swift exists and matches 1:1 Foto Baru
let modalViewPath = "\(currentDir)/boringNotch/Clicky/HomeSpace/HomeSpaceInteractiveComputerModalView.swift"
if let modalContent = try? String(contentsOfFile: modalViewPath, encoding: .utf8) {
    let hasCloseButton = modalContent.contains("xmark") || modalContent.contains("onDismiss")
    let hasYouCursor = modalContent.contains("Text(\"You\")") || modalContent.contains("youCursorBadge")
    let hasMiniDock = modalContent.contains("miniDock") || (modalContent.contains("safari") && modalContent.contains("mail"))
    let hasEnlargedCanvas = modalContent.contains("canvas") || modalContent.contains("mockupDesktopCanvas")
    
    assertTest(hasCloseButton && hasYouCursor && hasMiniDock && hasEnlargedCanvas, "HomeSpaceInteractiveComputerModalView implements 1:1 Foto Baru elements (close button [✕], 'You' cursor pill, floating mini dock with Safari & Mail, and enlarged canvas)")
} else {
    assertTest(false, "HomeSpaceInteractiveComputerModalView.swift exists and defines interactive semi-fullscreen modal")
}

// Test 3: Check HomeSpaceComputerCardView supports click interaction to open modal
let cardViewPath = "\(currentDir)/boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift"
if let cardContent = try? String(contentsOfFile: cardViewPath, encoding: .utf8) {
    let hasTapAction = cardContent.contains("onCardTapped") || cardContent.contains("onOpenModal") || cardContent.contains(".onTapGesture")
    assertTest(hasTapAction, "HomeSpaceComputerCardView provides click/tap interaction to open the interactive modal")
} else {
    assertTest(false, "Failed to read HomeSpaceComputerCardView.swift")
}

// Test 4: Check HomeSpaceRootView manages and presents HomeSpaceInteractiveComputerModalView
let rootViewPath = "\(currentDir)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
if let rootContent = try? String(contentsOfFile: rootViewPath, encoding: .utf8) {
    let hasModalPresentation = rootContent.contains("HomeSpaceInteractiveComputerModalView")
    let hasModalState = rootContent.contains("activeComputerModalPayload") || rootContent.contains("selectedComputerPayload")
    assertTest(hasModalPresentation && hasModalState, "HomeSpaceRootView manages state and presents HomeSpaceInteractiveComputerModalView with smooth overlay")
} else {
    assertTest(false, "Failed to read HomeSpaceRootView.swift")
}

// Test 5: Check project.pbxproj registers both new files
let pbxPath = "\(currentDir)/boringNotch.xcodeproj/project.pbxproj"
if let pbxContent = try? String(contentsOfFile: pbxPath, encoding: .utf8) {
    let hasService = pbxContent.contains("CompanionWindowStreamService.swift in Sources")
    let hasModal = pbxContent.contains("HomeSpaceInteractiveComputerModalView.swift in Sources")
    assertTest(hasService && hasModal, "boringNotch.xcodeproj registers CompanionWindowStreamService and HomeSpaceInteractiveComputerModalView in Sources build phase")
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
