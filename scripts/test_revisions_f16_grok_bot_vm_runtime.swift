import Foundation

print("=== RUNNING REVISION TEST: F-16 / MILESTONE 200 (GROK-BOT RUNTIME VM & ZERO-MOCKUP DUAL-MODE) ===")

let projectDir = FileManager.default.currentDirectoryPath
let agentsPath = "\(projectDir)/AGENTS.md"
let companionManagerPath = "\(projectDir)/boringNotch/Clicky/CompanionManager.swift"
let clickyEnumsPath = "\(projectDir)/boringNotch/Clicky/ClickyEnums.swift"
let vmViewportControllerPath = "\(projectDir)/boringNotch/Clicky/Tools/CompanionVMViewportController.swift"
let vmViewportViewPath = "\(projectDir)/boringNotch/Clicky/HomeSpace/CompanionVMViewportView.swift"
let modalViewPath = "\(projectDir)/boringNotch/Clicky/HomeSpace/HomeSpaceInteractiveComputerModalView.swift"
let cardViewPath = "\(projectDir)/boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift"
let vmLoopPath = "\(projectDir)/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"

var passed = 0
var total = 0

func assertTest(_ condition: Bool, _ name: String) {
    total += 1
    if condition {
        passed += 1
        print("✅ [\(passed)/\(total)] PASS: \(name)")
    } else {
        print("❌ [\(passed)/\(total)] FAIL: \(name)")
    }
}

// 1. AGENTS.md Core Principle 6
let agentsContent = (try? String(contentsOfFile: agentsPath)) ?? ""
assertTest(agentsContent.contains("Protokol Klarifikasi & Pengarahan Visi"), "AGENTS.md defines Principle 6: Proactive Clarification & Vision Direction")
assertTest(agentsContent.contains("Mode 1 (Host Mac / Tanpa Connected Apps)"), "AGENTS.md defines Mode 1 Host Mac")
assertTest(agentsContent.contains("Mode 2 (VM Sandbox / Ada Connected Apps)"), "AGENTS.md defines Mode 2 VM Sandbox")
assertTest(agentsContent.contains("Larangan Mutlak Mockup Palsu"), "AGENTS.md strictly forbids fake mockups")

// 2. CompanionVMViewportController
let ctrlExists = FileManager.default.fileExists(atPath: vmViewportControllerPath)
assertTest(ctrlExists, "CompanionVMViewportController.swift exists")
let ctrlContent = (try? String(contentsOfFile: vmViewportControllerPath)) ?? ""
assertTest(ctrlContent.contains("class CompanionVMViewportController"), "CompanionVMViewportController is defined")
assertTest(ctrlContent.contains("WKWebView"), "Controller manages real WebKit WKWebView")
assertTest(ctrlContent.contains("captureSnapshot"), "Controller supports snapshot capture for Vision")
assertTest(ctrlContent.contains("simulateVMClick"), "Controller supports virtual VM click dispatch")
assertTest(ctrlContent.contains("simulateVMType"), "Controller supports virtual VM type dispatch")
assertTest(ctrlContent.contains("requiresLoginTakeover"), "Controller tracks login takeover state")

// 3. CompanionVMViewportView
let viewExists = FileManager.default.fileExists(atPath: vmViewportViewPath)
assertTest(viewExists, "CompanionVMViewportView.swift exists")
let viewContent = (try? String(contentsOfFile: vmViewportViewPath)) ?? ""
assertTest(viewContent.contains("struct CompanionVMViewportView"), "CompanionVMViewportView is defined")
assertTest(viewContent.contains("NSViewRepresentable"), "View embeds native NSViewRepresentable WebKit")
assertTest(viewContent.contains("vmCursorPosition"), "View renders virtual agent cursor overlay")
assertTest(viewContent.contains("takeoverNotificationBanner"), "View renders takeover notification banner")

// 4. Modal and Card Mockup Elimination
let modalContent = (try? String(contentsOfFile: modalViewPath)) ?? ""
assertTest(!modalContent.contains("sandboxedMailClientView"), "HomeSpaceInteractiveComputerModalView has deleted fake sandboxedMailClientView")
assertTest(!modalContent.contains("virtualFolderRow"), "HomeSpaceInteractiveComputerModalView has deleted fake virtualFolderRow")
assertTest(modalContent.contains("displaySnapshot") || modalContent.contains("streamService"), "Modal view renders real Mac application window stream")

let cardContent = (try? String(contentsOfFile: cardViewPath)) ?? ""
assertTest(!cardContent.contains("sandboxedCardWorkspaceView"), "HomeSpaceComputerCardView has deleted fake sandboxedCardWorkspaceView")

// 5. Dual-Mode CUA in CompanionManager
let cmContent = (try? String(contentsOfFile: companionManagerPath)) ?? ""
assertTest(cmContent.contains("CuaDriverClient.shared.stopDaemon()"), "CompanionManager stops host CUA when in sandboxed VM mode")

// 6. CompanionVMAgentLoop real VM execution
let loopContent = (try? String(contentsOfFile: vmLoopPath)) ?? ""
assertTest(loopContent.contains("CompanionVMViewportController"), "CompanionVMAgentLoop uses CompanionVMViewportController")

print("\nResult: \(passed)/\(total) tests passed.")
if passed == total {
    print("🎯 ALL F-16 / MILESTONE 200 REVISION TESTS PASSED PERFECTLY!")
    exit(0)
} else {
    print("❌ SOME TESTS FAILED (Expected during Red phase of TDD)")
    exit(1)
}
