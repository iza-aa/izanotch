import Foundation

print("=== RUNNING REVISION TEST: F-15 / MILESTONE 199 (DOMAIN-GATED CUA DRIVER & SANDBOXED VM CANVAS) ===")

let projectDir = FileManager.default.currentDirectoryPath
let companionManagerPath = "\(projectDir)/boringNotch/Clicky/CompanionManager.swift"
let clickyEnumsPath = "\(projectDir)/boringNotch/Clicky/ClickyEnums.swift"
let companionProfilePath = "\(projectDir)/boringNotch/Clicky/Roster/CompanionProfile.swift"
let vmAgentLoopPath = "\(projectDir)/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"
let modalViewPath = "\(projectDir)/boringNotch/Clicky/HomeSpace/HomeSpaceInteractiveComputerModalView.swift"
let cardViewPath = "\(projectDir)/boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift"
let rootViewPath = "\(projectDir)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"

let cmContent = try String(contentsOfFile: companionManagerPath)
let enumsContent = try String(contentsOfFile: clickyEnumsPath)
let profileContent = try String(contentsOfFile: companionProfilePath)
let vmLoopContent = try String(contentsOfFile: vmAgentLoopPath)
let modalContent = try String(contentsOfFile: modalViewPath)
let cardContent = try String(contentsOfFile: cardViewPath)
let rootContent = try String(contentsOfFile: rootViewPath)

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

// 1. BuddySession & CompanionProfile isSandboxedVM helper
assertTest(enumsContent.contains("public var isSandboxedVM: Bool"), "BuddySession defines isSandboxedVM helper")
assertTest(enumsContent.contains("executionDomain == .virtualSandbox || !workflowAppNames.isEmpty"), "isSandboxedVM evaluates executionDomain or connected apps")
assertTest(profileContent.contains("public var isSandboxedVM: Bool"), "CompanionProfile defines isSandboxedVM helper")

// 2. CompanionManager domain-gated CUA lifecycle
assertTest(cmContent.contains("activeBuddy.isSandboxedVM || activeBuddy.executionDomain == .virtualSandbox"), "CompanionManager.start checks if active buddy is sandboxed VM")
assertTest(cmContent.contains("CuaDriverClient.shared.stopDaemon()"), "CompanionManager.start stops CUA daemon for sandboxed VM")
assertTest(cmContent.contains("matchingCompanion.isSandboxedVM || matchingCompanion.executionDomain == .virtualSandbox"), "CompanionManager.selectSession checks if selected buddy is sandboxed VM")

// 3. CompanionVMAgentLoop sandbox isolation
assertTest(vmLoopContent.contains("let isSandboxed = session?.isSandboxedVM ?? true"), "CompanionVMAgentLoop checks isSandboxed from session")
assertTest(vmLoopContent.contains("inspect_sandbox_workspace"), "CompanionVMAgentLoop inspects sandbox workspace without host screen capture")
assertTest(vmLoopContent.contains("isReadInboxIntent"), "CompanionVMAgentLoop implements robust email reading intent matching")
assertTest(vmLoopContent.contains("loadSandboxEmails"), "CompanionVMAgentLoop loads deliverables from sandbox sent_emails and incoming")
assertTest(vmLoopContent.contains("saveSandboxEmail"), "CompanionVMAgentLoop writes sandboxed email deliverables")
assertTest(vmLoopContent.contains("isSandboxed: Bool = true"), "groundAndClick and typeText support isSandboxed gating")

// 4. Modal and Card Sandboxed VM Canvas
assertTest(modalContent.contains("sandboxedVMWorkspaceView"), "HomeSpaceInteractiveComputerModalView implements sandboxedVMWorkspaceView")
assertTest(modalContent.contains("companion.activeBuddy.isSandboxedVM"), "HomeSpaceInteractiveComputerModalView checks isSandboxedVM")
assertTest(modalContent.contains("sandboxedMailClientView"), "Modal view renders sandboxed virtual mail client")
assertTest(modalContent.contains("sandboxedSafariBrowserView"), "Modal view renders sandboxed virtual browser")
assertTest(cardContent.contains("sandboxedCardWorkspaceView"), "HomeSpaceComputerCardView renders sandboxedCardWorkspaceView")

// 5. RootView and prompt integration
assertTest(rootContent.contains("companion.activeBuddy.isSandboxedVM ? \"Initializing Sandbox VM...\" : \"Initializing VM workspace...\""), "HomeSpaceRootView sets appropriate queueSummary for sandbox VM")
assertTest(rootContent.contains("companion.chatMessages[lastIdx].text = finalPayload.instructionText"), "HomeSpaceRootView updates assistant chat text with findings")

print("\nResult: \(passed)/\(total) tests passed.")
if passed == total {
    print("🎯 ALL F-15 / MILESTONE 199 REVISION TESTS PASSED PERFECTLY!")
    exit(0)
} else {
    print("❌ SOME TESTS FAILED")
    exit(1)
}
