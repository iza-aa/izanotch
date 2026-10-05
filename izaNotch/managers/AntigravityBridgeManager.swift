//
//  AntigravityBridgeManager.swift
//  izaNotch
//
//  Created by Antigravity on 15/09/2026.
//

import SwiftUI
import Combine
import Defaults
import AppKit

@MainActor
public final class AntigravityBridgeManager: ObservableObject {
    public static let shared = AntigravityBridgeManager()
    
    @Published public var isRunning: Bool = false
    @Published public var isStarting: Bool = false
    @Published public var port: Int = Defaults[.antigravityBridgePort]
    @Published public var lastHealthStatus: String = "Offline"
    @Published public var statusMessage: String? = nil
    @Published public var autoStartEnabled: Bool {
        didSet {
            Defaults[.autoStartAntigravityBridge] = autoStartEnabled
        }
    }
    
    public var baseURLString: String {
        "http://127.0.0.1:\(port)/v1"
    }
    
    private var bridgeProcess: Process?
    private var healthCheckTimer: Timer?
    private var statusResetTask: Task<Void, Never>?
    private let fileManager = FileManager.default
    
    private var bridgeDirectoryURL: URL {
        let username = NSUserName()
        let realHome = URL(fileURLWithPath: "/Users/\(username)")
        return realHome.appendingPathComponent(".gemini/bridge")
    }
    
    private var bridgeServerScriptURL: URL {
        bridgeDirectoryURL.appendingPathComponent("src/server.js")
    }
    
    private var bridgeLogFileURL: URL {
        bridgeDirectoryURL.appendingPathComponent("bridge.log")
    }
    
    private init() {
        self.autoStartEnabled = Defaults[.autoStartAntigravityBridge]
        
        setupLifecycleObservers()
        startHealthPolling()
        
        if autoStartEnabled {
            Task {
                await self.startBridge()
            }
        } else {
            Task {
                await self.checkHealth()
            }
        }
    }
    
    deinit {
        healthCheckTimer?.invalidate()
    }
    
    // MARK: - Lifecycle Notifications
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopBridge()
        }
    }
    
    // MARK: - Health Polling
    private func startHealthPolling() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let isHealthy = await self.checkHealth()
                if !isHealthy && self.autoStartEnabled && !self.isStarting {
                    await self.startBridge()
                }
            }
        }
    }
    
    // MARK: - Dynamic Node.js Binary Detector
    private func findNodeBinaryPath() -> String? {
        let username = NSUserName()
        let candidatePaths = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
            "/Users/\(username)/.nvm/current/bin/node"
        ]
        
        for p in candidatePaths {
            if fileManager.isExecutableFile(atPath: p) {
                return p
            }
        }
        
        // Scan NVM versions directory
        let nvmVersionsPath = "/Users/\(username)/.nvm/versions/node"
        if let versions = try? fileManager.contentsOfDirectory(atPath: nvmVersionsPath) {
            let sortedVersions = versions.sorted().reversed()
            for v in sortedVersions {
                let nodePath = "\(nvmVersionsPath)/\(v)/bin/node"
                if fileManager.isExecutableFile(atPath: nodePath) {
                    return nodePath
                }
            }
        }
        
        // Dynamic PATH lookup fallback
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which node"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !out.isEmpty && fileManager.isExecutableFile(atPath: out) {
            return out
        }
        
        return nil
    }
    
    // MARK: - Health Check
    @discardableResult
    public func checkHealth() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else {
            self.isRunning = false
            self.lastHealthStatus = "Offline"
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String, status == "ok" {
                self.isRunning = true
                self.lastHealthStatus = "Online"
                return true
            }
        } catch {
            // Not responding
        }
        
        self.isRunning = false
        self.lastHealthStatus = "Offline"
        return false
    }
    
    // MARK: - Start Bridge Process
    public func startBridge() async {
        guard !isStarting else { return }
        
        // Check if already running (e.g. from previous run or external start)
        if await checkHealth() {
            self.isRunning = true
            self.lastHealthStatus = "Online"
            return
        }
        
        isStarting = true
        showStatus("Menyalakan AI Bridge...")
        
        guard let nodePath = findNodeBinaryPath() else {
            isStarting = false
            showStatus("Gagal: Node.js tidak ditemukan di sistem")
            return
        }
        
        guard fileManager.fileExists(atPath: bridgeServerScriptURL.path) else {
            isStarting = false
            showStatus("Gagal: Script bridge tidak ditemukan di ~/.gemini/bridge")
            return
        }
        
        // Kill any existing stale process on our port before spawning
        killProcessOnPort(port)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.currentDirectoryURL = bridgeDirectoryURL
        process.arguments = [bridgeServerScriptURL.path]
        
        var env = ProcessInfo.processInfo.environment
        env["PORT"] = "\(port)"
        process.environment = env
        
        // Redirect stdout/stderr to bridge.log
        if !fileManager.fileExists(atPath: bridgeLogFileURL.path) {
            fileManager.createFile(atPath: bridgeLogFileURL.path, contents: nil)
        }
        if let logHandle = try? FileHandle(forWritingTo: bridgeLogFileURL) {
            logHandle.seekToEndOfFile()
            process.standardOutput = logHandle
            process.standardError = logHandle
        }
        
        self.bridgeProcess = process
        
        do {
            try process.run()
            
            // Wait up to 3 seconds for port to open
            for _ in 0..<15 {
                try? await Task.sleep(for: .milliseconds(200))
                if await checkHealth() {
                    self.isRunning = true
                    self.isStarting = false
                    self.lastHealthStatus = "Online"
                    showStatus("AI Bridge aktif di port \(port)")
                    return
                }
            }
        } catch {
            showStatus("Gagal menjalankan Bridge: \(error.localizedDescription)")
        }
        
        self.isStarting = false
        await checkHealth()
    }
    
    // MARK: - Stop Bridge Process
    public func stopBridge() {
        if let process = bridgeProcess, process.isRunning {
            process.terminate()
        }
        bridgeProcess = nil
        
        killProcessOnPort(port)
        
        self.isRunning = false
        self.lastHealthStatus = "Offline"
        showStatus("AI Bridge dimatikan")
    }
    
    // MARK: - Restart Bridge
    public func restartBridge() async {
        stopBridge()
        try? await Task.sleep(for: .milliseconds(500))
        await startBridge()
    }
    
    // MARK: - Port Helper
    private func killProcessOnPort(_ targetPort: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-ti", ":\(targetPort)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        
        let pidsOut = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        for pidStr in pidsOut.components(separatedBy: .newlines) {
            let pid = pidStr.trimmingCharacters(in: .whitespaces)
            if !pid.isEmpty && pid != "\(ProcessInfo.processInfo.processIdentifier)" {
                let killProc = Process()
                killProc.executableURL = URL(fileURLWithPath: "/bin/kill")
                killProc.arguments = ["-9", pid]
                try? killProc.run()
                killProc.waitUntilExit()
            }
        }
    }
    
    // MARK: - Utility Actions
    public func copyBaseURLToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(baseURLString, forType: .string)
        showStatus("Disalin: \(baseURLString)")
    }
    
    public func copySampleConfigToClipboard() {
        let sample = """
        {
          "baseURL": "\(baseURLString)",
          "apiKey": "antigravity",
          "model": "gemini-3.8-flash"
        }
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sample, forType: .string)
        showStatus("Config OpenAI disalin!")
    }
    
    public func openLogFile() {
        if fileManager.fileExists(atPath: bridgeLogFileURL.path) {
            NSWorkspace.shared.open(bridgeLogFileURL)
        } else {
            NSWorkspace.shared.open(bridgeDirectoryURL)
        }
    }
    
    private func showStatus(_ msg: String) {
        statusResetTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            self.statusMessage = msg
        }
        statusResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeInOut(duration: 0.3)) {
                self.statusMessage = nil
            }
        }
    }
}
