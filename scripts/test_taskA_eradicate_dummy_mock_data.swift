import Foundation

print("=== Running Task A Test: Eradicate Dummy Mock Data ===")

let loopPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"
guard let loopContent = try? String(contentsOf: URL(fileURLWithPath: loopPath), encoding: .utf8) else {
    print("❌ Failed to read CompanionVMAgentLoop.swift")
    exit(1)
}

let bannedLoopTokens = [
    "SandboxedEmailRecord",
    "loadSandboxEmails",
    "saveSandboxEmail",
    "rezkyhaikal2@gmail.com",
    "welcome-sync",
    "sandbox.local"
]

var foundInLoop: [String] = []
for token in bannedLoopTokens {
    if loopContent.contains(token) {
        foundInLoop.append(token)
    }
}

if !foundInLoop.isEmpty {
    print("❌ FAIL: CompanionVMAgentLoop still contains banned dummy tokens: \(foundInLoop)")
    exit(1)
}

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
guard let rootContent = try? String(contentsOf: URL(fileURLWithPath: rootPath), encoding: .utf8) else {
    print("❌ Failed to read HomeSpaceRootView.swift")
    exit(1)
}

if rootContent.contains("rezkyhaikal10@gmail.com") {
    print("❌ FAIL: HomeSpaceRootView still contains hardcoded dummy email 'rezkyhaikal10@gmail.com'")
    exit(1)
}

print("✅ PASS: All dummy mock data completely eradicated.")
exit(0)
