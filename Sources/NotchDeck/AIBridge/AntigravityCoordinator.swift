import Foundation

public struct AntigravityCoordinator: Sendable {
    public static func observeRecentTranscript(brainDir: URL) -> String? {
        let logFile = brainDir.appendingPathComponent("transcript.jsonl")
        guard FileManager.default.fileExists(atPath: logFile.path),
              let content = try? String(contentsOf: logFile, encoding: .utf8) else {
            return nil
        }
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.last
    }

    public static func runCLICommand(arguments: [String]) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
