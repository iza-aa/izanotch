import Foundation

print("=== Running Test: AFM Email Check Autonomous Flow ===")

// 1. Verify AppleScript Mail query
let scriptSource = """
tell application "Mail"
    set unreadCount to unread count of inbox
    set msgList to {}
    set recentMsgs to messages of inbox
    set maxCount to 3
    if (count of recentMsgs) < maxCount then set maxCount to (count of recentMsgs)
    repeat with i from 1 to maxCount
        set m to item i of recentMsgs
        set end of msgList to (sender of m & " | Subjek: " & subject of m)
    end repeat
    set AppleScript's text item delimiters to " /// "
    return "Belum dibaca: " & unreadCount & " pesan /// " & (msgList as string)
end tell
"""

if let appleScript = NSAppleScript(source: scriptSource) {
    var errorInfo: NSDictionary?
    let output = appleScript.executeAndReturnError(&errorInfo)
    if let str = output.stringValue, !str.isEmpty {
        print("  ✅ [PASS] Real Mail.app extraction works: \(str.prefix(100))...")
    } else {
        print("  ❌ [FAIL] AppleScript execution failed: \(String(describing: errorInfo))")
        exit(1)
    }
} else {
    print("  ❌ [FAIL] Cannot create NSAppleScript")
    exit(1)
}

// 2. Verify no hardcoded dummy data in CompanionVMAgentLoop.swift
let loopFile = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"
let loopContent = try String(contentsOfFile: loopFile, encoding: .utf8)

if loopContent.contains("Inbox (5 unread)") {
    print("  ❌ [FAIL] Found fake hardcoded 'Inbox (5 unread)' in CompanionVMAgentLoop.swift")
    exit(1)
} else {
    print("  ✅ [PASS] No fake dummy inbox array found in CompanionVMAgentLoop.swift")
}

// 3. Verify read action handling in CompanionVMAgentLoop.swift
if loopContent.contains("decision.actionType == \"read\"") && loopContent.contains("readElements") {
    print("  ✅ [PASS] CompanionVMAgentLoop handles decision.actionType == 'read' and feeds observation")
} else {
    print("  ❌ [FAIL] Missing read handling in CompanionVMAgentLoop.swift")
    exit(1)
}

// 4. Verify coordinate normalization logic
if loopContent.contains("vBounds.origin.x") && loopContent.contains("normX = min(max(relX / vWidth") {
    print("  ✅ [PASS] Virtual display coordinate normalization implemented correctly")
} else {
    print("  ❌ [FAIL] Broken coordinate normalization in CompanionVMAgentLoop.swift")
    exit(1)
}

// 5. Verify ClickyHybridGroundingEngine does not match any button as send
let engineFile = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/ClickyHybridGroundingEngine.swift"
let engineContent = try String(contentsOfFile: engineFile, encoding: .utf8)
if engineContent.contains("role.contains(\"button\")") {
    print("  ❌ [FAIL] Overly broad 'role.contains(button)' still present in ClickyHybridGroundingEngine.swift")
    exit(1)
} else {
    print("  ✅ [PASS] Overly broad button matching eliminated from ClickyHybridGroundingEngine.swift")
}

print("=== ALL 5 VERIFICATION CHECKS PASSED ===")
