import Foundation

print("=== Running Task 9 Test: Zero Literal '?? \"Mail\"' Fallbacks ===")

let filesToCheck = [
    "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift",
    "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/HomeSpace/CompanionVMViewportView.swift",
    "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift"
]

var failedFiles: [String] = []

for file in filesToCheck {
    guard let content = try? String(contentsOfFile: file) else {
        print("❌ Could not read file: \(file)")
        exit(1)
    }
    if content.contains("?? \"Mail\"") {
        print("❌ Found literal '?? \"Mail\"' fallback in: \(file)")
        failedFiles.append(file)
    }
}

if !failedFiles.isEmpty {
    print("❌ FAIL: Residual hardcoded '?? \"Mail\"' fallbacks found in \(failedFiles.count) files.")
    exit(1)
}

print("✅ PASS: All residual literal '?? \"Mail\"' fallbacks successfully eliminated.")
exit(0)
