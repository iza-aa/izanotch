// scripts/test_revisions_f10_live_headless_vision.swift
import Foundation

// Test live import of account and headless vision execution
let codexAuthPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json").path
guard FileManager.default.fileExists(atPath: codexAuthPath) else {
    print("❌ ~/.codex/auth.json not found")
    exit(1)
}

let poolDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".izanotchy/credentials/gpt_accounts")
try? FileManager.default.createDirectory(at: poolDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

let account1Dir = poolDir.appendingPathComponent("account_primary")
try? FileManager.default.createDirectory(at: account1Dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

let targetAuth = account1Dir.appendingPathComponent("auth.json")
try? FileManager.default.copyItem(atPath: codexAuthPath, toPath: targetAuth.path)

print("✅ Created isolated CODEX_HOME at: \(account1Dir.path)")

// Prepare a test snapshot image
let sampleImage = "/tmp/f10_vision_test_frame.png"
if !FileManager.default.fileExists(atPath: sampleImage) {
    // Generate a quick sample image with a red dot at 500, 300
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = ["-x", "-t", "png", sampleImage]
    try? process.run()
    process.waitUntilExit()
}

// Call Codex CLI headless with gpt-6-luna and reasoning_effort=medium
let codexBin = "/Applications/ChatGPT.app/Contents/Resources/codex"
let tempOutputFile = "/tmp/f10_vision_output.json"

let process = Process()
process.executableURL = URL(fileURLWithPath: codexBin)
process.arguments = [
    "exec",
    "--ephemeral",
    "--skip-git-repo-check",
    "-s", "read-only",
    "-m", "gpt-6-luna",
    "-c", "reasoning_effort=medium",
    "-i", sampleImage,
    "-o", tempOutputFile,
    "-"
]

var env = ProcessInfo.processInfo.environment
env["CODEX_HOME"] = account1Dir.path
process.environment = env

let stdinPipe = Pipe()
let stderrPipe = Pipe()
process.standardInput = stdinPipe
process.standardError = stderrPipe

let prompt = """
Locate the center coordinates of the Apple menu icon () or top menu bar in the provided screen snapshot.
Respond with ONLY raw JSON: {"target":"Apple menu","x":<integer>,"y":<integer>,"confidence":<0.0_to_1.0>}
"""

do {
    print("🚀 Invoking 6 Luna Medium headless via isolated CODEX_HOME...")
    let startTime = Date()
    try process.run()
    
    stdinPipe.fileHandleForWriting.write(prompt.data(using: .utf8)!)
    try? stdinPipe.fileHandleForWriting.close()
    
    process.waitUntilExit()
    let duration = Date().timeIntervalSince(startTime)
    
    let exitCode = process.terminationStatus
    print("⏱️ Completed in \(String(format: "%.2f", duration))s (exit code \(exitCode))")
    
    if exitCode == 0, FileManager.default.fileExists(atPath: tempOutputFile) {
        let outputData = try Data(contentsOf: URL(fileURLWithPath: tempOutputFile))
        let outputStr = String(data: outputData, encoding: .utf8) ?? ""
        print("📄 Raw Output:")
        print(outputStr)
        
        struct Res: Codable {
            let target: String
            let x: Int
            let y: Int
            let confidence: Double?
        }
        
        // Clean JSON
        var cleaned = outputStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if let s = cleaned.firstIndex(of: "{"), let e = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[s...e])
        }
        
        if let parsed = try? JSONDecoder().decode(Res.self, from: cleaned.data(using: .utf8)!) {
            print("🎯 Successfully parsed VisionCoordinateResult:")
            print("   - Target: \(parsed.target)")
            print("   - Coordinates: X=\(parsed.x), Y=\(parsed.y)")
            print("   - Confidence: \(parsed.confidence ?? 1.0)")
            print("✅ 6 LUNA MEDIUM HEADLESS VISION TEST PASSED!")
            exit(0)
        } else {
            print("⚠️ Output was not standard JSON: \(outputStr)")
            exit(1)
        }
    } else {
        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        print("❌ Codex failed: \(String(data: errData, encoding: .utf8) ?? "")")
        exit(1)
    }
} catch {
    print("❌ Process error: \(error)")
    exit(1)
}
