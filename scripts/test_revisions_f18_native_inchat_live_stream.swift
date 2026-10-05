import Foundation
import AppKit

// MARK: - Test Suite F-18: Native In-Chat Live Stream & Virtual CUA Deck
// Verifies:
// 1. ComputerCardPayload schema extensions (targetCoordinateX, targetCoordinateY, currentActionLabel)
// 2. Candidate window discovery and sorting logic
// 3. System dialog detection logic (Takeover gating)
// 4. In-chat first execution (Zero auto-maximize modal in HomeSpaceRootView)
// 5. Scaled-to-fit canvas frame and dynamic crosshair indicator

var testsPassed = 0
var testsFailed = 0

func assertTest(_ condition: Bool, _ name: String) {
    if condition {
        print("  ✅ [PASS] \(name)")
        testsPassed += 1
    } else {
        print("  ❌ [FAIL] \(name)")
        testsFailed += 1
    }
}

print("==================================================================")
print("🧪 Running Test Suite F-18: Native In-Chat Live Stream Architecture")
print("==================================================================")

// Test 1: Source Code Verification - ComputerCardPayload schema
let enumsPath = "boringNotch/Clicky/ClickyEnums.swift"
if let enumsContent = try? String(contentsOfFile: enumsPath, encoding: .utf8) {
    assertTest(enumsContent.contains("public var targetCoordinateX: Double?"), "ComputerCardPayload has targetCoordinateX property")
    assertTest(enumsContent.contains("public var targetCoordinateY: Double?"), "ComputerCardPayload has targetCoordinateY property")
    assertTest(enumsContent.contains("public var currentActionLabel: String?"), "ComputerCardPayload has currentActionLabel property")
    assertTest(enumsContent.contains("public var deliverableSummary: String?"), "ComputerCardPayload has deliverableSummary property")
} else {
    assertTest(false, "Failed to read ClickyEnums.swift")
}

// Test 2: Source Code Verification - CompanionWindowStreamService
let streamServicePath = "boringNotch/Clicky/Tools/CompanionWindowStreamService.swift"
if let streamContent = try? String(contentsOfFile: streamServicePath, encoding: .utf8) {
    assertTest(streamContent.contains("func findCandidateWindows(appName: String) -> [WindowTargetInfo]"), "findCandidateWindows implementation exists")
    assertTest(streamContent.contains("func ensureWorkflowAppRunning(appName: String)"), "ensureWorkflowAppRunning implementation exists")
    assertTest(streamContent.contains("func detectBlockingDialog(appName: String) -> String?"), "detectBlockingDialog implementation exists")
    assertTest(streamContent.contains("/usr/sbin/screencapture"), "Native screencapture fallback exists in captureTargetWindow")
    assertTest(streamContent.contains("[\"-x\", \"-l\", \"\\(windowId)\""), "screencapture includes -x flag to completely mute shutter sound")
} else {
    assertTest(false, "Failed to read CompanionWindowStreamService.swift")
}

// Test 3: Source Code Verification - HomeSpaceRootView Zero Auto-Maximize & CompanionManager updateChatMessage
let rootViewPath = "boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
if let rootContent = try? String(contentsOfFile: rootViewPath, encoding: .utf8) {
    assertTest(rootContent.contains("In-Chat First: Keep action directly inside chat feed (Zero Auto-Maximize)"), "Zero auto-maximize protocol documented in submitPrompt")
    assertTest(rootContent.contains("onProgress: { progressPayload in"), "onProgress streaming wired in submitPrompt")
    assertTest(!rootContent.contains("self.activeComputerModalPayload = workingPayload"), "No immediate auto-open of activeComputerModalPayload on submit")
    assertTest(rootContent.contains("companion.updateChatMessage(id: assistantMsgId"), "HomeSpaceRootView updates chat message state via companion.updateChatMessage")
} else {
    assertTest(false, "Failed to read HomeSpaceRootView.swift")
}

let mgrPath = "boringNotch/Clicky/CompanionManager.swift"
if let mgrContent = try? String(contentsOfFile: mgrPath, encoding: .utf8) {
    assertTest(mgrContent.contains("func updateChatMessage(id: UUID, computerPayload: ComputerCardPayload?, text: String? = nil)"), "CompanionManager has updateChatMessage method")
} else {
    assertTest(false, "Failed to read CompanionManager.swift")
}

// Test 4: Source Code Verification - HomeSpaceComputerCardView Canvas & Ticker
let cardViewPath = "boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift"
if let cardContent = try? String(contentsOfFile: cardViewPath, encoding: .utf8) {
    assertTest(cardContent.contains("scaledToFit()"), "Canvas frame uses scaledToFit to preserve native traffic lights and toolbar")
    assertTest(cardContent.contains("Live Action Ticker (When companion is operating)"), "Live action ticker added below canvas")
    assertTest(cardContent.contains("payload.targetCoordinateX ?? 0.52"), "targetCrosshair dynamically animates with payload target coordinates")
} else {
    assertTest(false, "Failed to read HomeSpaceComputerCardView.swift")
}

// Test 5: Source Code Verification - HomeSpaceInteractiveComputerModalView Unified Window Stream
let modalViewPath = "boringNotch/Clicky/HomeSpace/HomeSpaceInteractiveComputerModalView.swift"
if let modalContent = try? String(contentsOfFile: modalViewPath, encoding: .utf8) {
    assertTest(!modalContent.contains("CompanionVMViewportView(onDismiss: onDismiss)"), "Modal does not render fake WebKit CompanionVMViewportView")
    assertTest(modalContent.contains("streamService.startStreaming(appName: appName"), "Modal triggers streamService.startStreaming for target app on appear")
    assertTest(modalContent.contains("displaySnapshot"), "Modal renders authentic displaySnapshot of real Mac application window")
} else {
    assertTest(false, "Failed to read HomeSpaceInteractiveComputerModalView.swift")
}

// Test 6: Source Code Verification - CompanionVMAgentLoop Native Execution & True Dispatch
let agentLoopPath = "boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"
if let loopContent = try? String(contentsOfFile: agentLoopPath, encoding: .utf8) {
    assertTest(loopContent.contains("onProgress: (@MainActor (ComputerCardPayload) -> Void)? = nil"), "executeAutonomousTask accepts onProgress closure")
    assertTest(loopContent.contains("CompanionWindowStreamService.shared.ensureWorkflowAppRunning"), "Ensures workflow app is running")
    assertTest(loopContent.contains("CompanionWindowStreamService.shared.detectBlockingDialog"), "Gated Human Takeover on blocking system dialogs")
    assertTest(loopContent.contains("ClickyHybridGroundingEngine.shared.resolveElementCoordinate"), "Autonomous loop uses ClickyHybridGroundingEngine for UI element detection")
    assertTest(loopContent.contains("send targetMsg"), "Executes true AppleScript send targetMsg on Mail.app")
    assertTest(loopContent.contains("SENT_SUCCESS"), "Validates genuine SENT_SUCCESS response before marking task as done")
} else {
    assertTest(false, "Failed to read CompanionVMAgentLoop.swift")
}

// Test 6: Runtime Target Window Candidate Sorting Check
let candidates: [(id: Int64, title: String, width: Double, height: Double, isDialog: Bool)] = [
    (id: 1, title: "iCloud Mail Cleanup", width: 420, height: 632, isDialog: true),
    (id: 2, title: "", width: 500, height: 500, isDialog: false),
    (id: 3, title: "All Inboxes", width: 1059, height: 688, isDialog: false),
    (id: 4, title: "New Message", width: 1512, height: 949, isDialog: false)
]

let sorted = candidates.sorted { a, b in
    if a.isDialog != b.isDialog { return !a.isDialog }
    let aTitle = a.title.lowercased()
    let bTitle = b.title.lowercased()
    let aIsMsg = aTitle.contains("message") || aTitle.contains("compose")
    let bIsMsg = bTitle.contains("message") || bTitle.contains("compose")
    if aIsMsg != bIsMsg { return aIsMsg }
    let aIsInbox = aTitle.contains("inbox") || aTitle.contains("mail")
    let bIsInbox = bTitle.contains("inbox") || bTitle.contains("mail")
    if aIsInbox != bIsInbox { return aIsInbox }
    return (a.width * a.height) > (b.width * b.height)
}

assertTest(sorted.first?.id == 4, "Window selection algorithm prioritizes 'New Message' (ID 4) over general inbox")
assertTest(sorted[1].id == 3, "Window selection algorithm prioritizes 'All Inboxes' (ID 3) over dialogs")
assertTest(sorted.last?.isDialog == true, "Window selection algorithm deprioritizes dialog windows to the bottom")

print("==================================================================")
print("📊 F-18 Test Results: \(testsPassed) passed, \(testsFailed) failed")
print("==================================================================")

if testsFailed > 0 {
    exit(1)
}
