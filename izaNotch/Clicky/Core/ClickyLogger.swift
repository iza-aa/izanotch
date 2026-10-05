//
//  ClickyLogger.swift
//  izaNotch
//
//  Unified diagnostic and telemetry logger for Clicky Cursor Assistant.
//  Writes live logs to ~/Library/Logs/Izanotchy/clicky.log and publishes
//  entries for real-time inspection in Settings UI.
//

import AppKit
import Foundation

final class ClickyLogger: ObservableObject {
    static let shared = ClickyLogger()

    @Published private(set) var recentLogs: [String] = []

    private let logFileURL: URL
    private let fileHandle: FileHandle?
    private let dateFormatter: DateFormatter
    private let lock = NSLock()

    private init() {
        let fileManager = FileManager.default
        let logsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Izanotchy", isDirectory: true)

        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let logFile = logsDirectory.appendingPathComponent("clicky.log")
        self.logFileURL = logFile

        if !fileManager.fileExists(atPath: logFile.path) {
            fileManager.createFile(atPath: logFile.path, contents: nil)
        }

        self.fileHandle = try? FileHandle(forWritingTo: logFile)
        self.fileHandle?.seekToEndOfFile()

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        log("[LOGGER]", "ClickyLogger initialized. Writing to: \(logFile.path)")
    }

    func log(_ category: String, _ message: String, level: String = "INFO") {
        let timestamp: String
        lock.lock()
        timestamp = dateFormatter.string(from: Date())
        let formattedLine = "[\(timestamp)] [\(level)] \(category) \(message)"

        // 1. Console print
        print(formattedLine)

        // 2. Append to disk file
        if let data = (formattedLine + "\n").data(using: .utf8), let handle = fileHandle {
            try? handle.write(contentsOf: data)
        }
        lock.unlock()

        // 3. Keep in memory for Settings UI (last 150 lines) on MainActor
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recentLogs.append(formattedLine)
            if self.recentLogs.count > 150 {
                self.recentLogs.removeFirst(self.recentLogs.count - 150)
            }
        }
    }

    func clearLogs() {
        lock.lock()
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        self.fileHandle?.seekToEndOfFile()
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.recentLogs.removeAll()
        }

        log("[LOGGER]", "Logs cleared by user")
    }

    func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }

    // Convenience static helpers — nonisolated and thread-safe
    static func info(_ category: String, _ message: String) {
        shared.log(category, message, level: "INFO")
    }

    static func success(_ category: String, _ message: String) {
        shared.log(category, message, level: "SUCCESS")
    }

    static func warning(_ category: String, _ message: String) {
        shared.log(category, message, level: "WARNING")
    }

    static func error(_ category: String, _ message: String) {
        shared.log(category, message, level: "ERROR")
    }
}
