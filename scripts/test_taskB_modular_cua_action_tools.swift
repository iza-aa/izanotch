import Foundation

print("=== Running Task B Test: Modular CUA Physical Action Tools ===")

let actionFiles = [
    "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/Actions/CUAPhysicalActionTool.swift",
    "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/Actions/CUAClickActionTool.swift",
    "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/Actions/CUAScrollActionTool.swift",
    "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/Actions/CUATypeActionTool.swift",
    "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/Actions/CUAReadActionTool.swift",
    "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/Actions/CUAPhysicalActionDispatcher.swift"
]

for filePath in actionFiles {
    if !FileManager.default.fileExists(atPath: filePath) {
        print("❌ FAIL: Missing required modular action tool file: \(filePath)")
        exit(1)
    }
}

let loopPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"
guard let loopContent = try? String(contentsOf: URL(fileURLWithPath: loopPath), encoding: .utf8) else {
    print("❌ Failed to read CompanionVMAgentLoop.swift")
    exit(1)
}

if !loopContent.contains("CUAPhysicalActionDispatcher.shared.dispatchAction") {
    print("❌ FAIL: CompanionVMAgentLoop does not delegate to CUAPhysicalActionDispatcher")
    exit(1)
}

print("✅ PASS: Modular CUA Action Tools & Dispatcher verified successfully.")
exit(0)
