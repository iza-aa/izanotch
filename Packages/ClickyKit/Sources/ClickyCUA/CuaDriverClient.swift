import ClickyPlatform
import ClickyFoundation
//
//  CuaDriverClient.swift
//  boringNotch (Izanotchy)
//
//  Universal macOS Desktop Automation Client (Pillar 2)
//  Backed by Cua Driver (https://github.com/trycua/cua)
//  Inspects AX UI trees, extracts element_tokens, clicks, types, and sends hotkeys
//  with delivery_mode: "background" (zero focus-stealing, background-safe).
//

import AppKit
import CoreGraphics
import Foundation

public struct CuaApp: Identifiable {
    public var id: String { "\(pid)_\(bundleId ?? name)" }
    public let name: String
    public let pid: Int32
    public let bundleId: String?
    public let isActive: Bool
    public let isRunning: Bool
}

public struct CuaWindow: Identifiable {
    public var id: Int64 { windowId }
    public let windowId: Int64
    public let pid: Int32
    public let appName: String
    public let title: String
    public let bounds: CGRect
    public let isOnScreen: Bool
    public let onCurrentSpace: Bool
    public let zIndex: Int
}

public struct CuaElement: Identifiable {
    public var id: String { elementToken }
    public let elementToken: String
    public let role: String
    public let label: String
    public let value: String?
    public let frame: CGRect
}

public struct CuaWindowState {
    public let elements: [CuaElement]
    public let treeMarkdown: String
    public let screenshotPath: String?
}

// MARK: - Dedicated Cua Driver Daemon & Persistent Transport (ExampleAgentHarness.swift)

public final class CuaDriverTransport: @unchecked Sendable {
    public static let defaultSession = "__cua_runtime_session"
    public let driverPath: String
    private var daemonProcess: Process?
    private var proxyProcess: Process?
    private var currentSocketPath: String?
    private var toProxyPipe: Pipe?
    private var fromProxyPipe: Pipe?
    private var incomingBuffer = Data()
    private var requestCounter = 1
    private let transportLock = NSRecursiveLock()

    public init(driverPath: String) {
        self.driverPath = driverPath
    }

    public var isRunning: Bool {
        transportLock.lock()
        defer { transportLock.unlock() }
        return (proxyProcess?.isRunning ?? false) && (daemonProcess?.isRunning ?? false)
    }

    public var socketPath: String? {
        transportLock.lock()
        defer { transportLock.unlock() }
        return currentSocketPath
    }

    deinit {
        stop()
    }

    public static func terminateAllOrphanInstances() {
        let killProc = Process()
        killProc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killProc.arguments = ["-9", "-f", "cua-driver"]
        try? killProc.run()
        killProc.waitUntilExit()

        if let tmpFiles = try? FileManager.default.contentsOfDirectory(atPath: "/tmp") {
            for file in tmpFiles where file.hasPrefix("cua-izanotchy-") && file.hasSuffix(".sock") {
                try? FileManager.default.removeItem(atPath: "/tmp/" + file)
            }
        }
    }

    public func ensureRunning() throws {
        transportLock.lock()
        defer { transportLock.unlock() }
        try ensureRunningLocked()
    }

    private func ensureRunningLocked() throws {
        if let proxy = proxyProcess, proxy.isRunning,
           let daemon = daemonProcess, daemon.isRunning,
           let sock = currentSocketPath, FileManager.default.fileExists(atPath: sock) {
            return
        }

        stopLocked()
        Self.terminateAllOrphanInstances()

        let pid = ProcessInfo.processInfo.processIdentifier
        let sockPath = "/tmp/cua-izanotchy-\(pid).sock"
        try? FileManager.default.removeItem(atPath: sockPath)

        var env = ProcessInfo.processInfo.environment
        env["CUA_DRIVER_EMBEDDED"] = "1"
        env["CUA_DRIVER_HOST_BUNDLE_ID"] = Bundle.main.bundleIdentifier ?? "com.boringnotch.boringNotch"
        env["CUA_DRIVER_PERMISSION_MODE"] = "unrestricted"
        env["CUA_DRIVER_DANGEROUSLY_BYPASS_APPROVALS"] = "1"

        let logURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/Izanotchy/cua_daemon.log")
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        let logHandle = FileHandle(forWritingAtPath: logURL.path)

        // 1. Launch daemon
        let daemon = Process()
        daemon.executableURL = URL(fileURLWithPath: driverPath)
        daemon.arguments = [
            "serve",
            "--embedded",
            "--socket", sockPath,
            "--permission-mode", "unrestricted",
            "--dangerously-bypass-approvals"
        ]
        daemon.environment = env
        if let handle = logHandle {
            daemon.standardOutput = handle
            daemon.standardError = handle
        }
        try daemon.run()
        self.daemonProcess = daemon

        // 2. Poll for socket creation
        let deadline = Date().addingTimeInterval(6.0)
        while !FileManager.default.fileExists(atPath: sockPath) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        guard FileManager.default.fileExists(atPath: sockPath) else {
            daemon.terminate()
            self.daemonProcess = nil
            throw NSError(domain: "CuaDriver", code: 500, userInfo: [NSLocalizedDescriptionKey: "Embedded daemon failed to create socket at \(sockPath)"])
        }
        self.currentSocketPath = sockPath

        // 3. Launch persistent MCP proxy
        let proxy = Process()
        proxy.executableURL = URL(fileURLWithPath: driverPath)
        proxy.arguments = ["mcp", "--embedded", "--socket", sockPath]
        proxy.environment = env

        let toProxy = Pipe()
        let fromProxy = Pipe()
        proxy.standardInput = toProxy
        proxy.standardOutput = fromProxy
        try proxy.run()

        self.proxyProcess = proxy
        self.toProxyPipe = toProxy
        self.fromProxyPipe = fromProxy
        self.incomingBuffer = Data()

        // 4. Initialize Handshake
        let initId = nextRequestIdLocked()
        let initPayload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": initId,
            "method": "initialize",
            "params": [
                "protocolVersion": "2024-11-05",
                "capabilities": [String: Any](),
                "clientInfo": ["name": "Izanotchy", "version": "1.0"]
            ]
        ]
        _ = try sendSyncMessageLocked(initPayload, expectedId: initId)

        var notifData = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "method": "notifications/initialized"])
        notifData.append(0x0A)
        toProxy.fileHandleForWriting.write(notifData)

        // 5. Start default session and enable agent cursor overlay
        let startSessionId = nextRequestIdLocked()
        _ = try? sendSyncMessageLocked([
            "jsonrpc": "2.0",
            "id": startSessionId,
            "method": "tools/call",
            "params": [
                "name": "start_session",
                "arguments": ["session": Self.defaultSession]
            ]
        ], expectedId: startSessionId)

        let enableCursorId = nextRequestIdLocked()
        _ = try? sendSyncMessageLocked([
            "jsonrpc": "2.0",
            "id": enableCursorId,
            "method": "tools/call",
            "params": [
                "name": "set_agent_cursor_enabled",
                "arguments": ["session": Self.defaultSession, "enabled": true]
            ]
        ], expectedId: enableCursorId)

        ClickyLogger.success("[CUA_DRIVER]", "Embedded daemon and MCP proxy initialized successfully (socket: \(sockPath))")
    }

    private func nextRequestIdLocked() -> Int {
        requestCounter += 1
        return requestCounter
    }

    private func sendSyncMessageLocked(_ dict: [String: Any], expectedId: Int) throws -> [String: Any] {
        guard let toPipe = toProxyPipe, let fromPipe = fromProxyPipe else {
            throw NSError(domain: "CuaDriver", code: 500, userInfo: [NSLocalizedDescriptionKey: "Proxy pipes not available"])
        }

        var data = try JSONSerialization.data(withJSONObject: dict)
        data.append(0x0A)
        toPipe.fileHandleForWriting.write(data)

        let readHandle = fromPipe.fileHandleForReading
        let deadline = Date().addingTimeInterval(20.0)

        while Date() < deadline {
            while let nl = incomingBuffer.firstIndex(of: 0x0A) {
                let lineData = incomingBuffer.subdata(in: incomingBuffer.startIndex..<nl)
                incomingBuffer.removeSubrange(incomingBuffer.startIndex...nl)
                if lineData.isEmpty { continue }
                if let jsonObj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                   let msgId = jsonObj["id"] as? Int, msgId == expectedId {
                    if let err = jsonObj["error"] as? [String: Any] {
                        let errMsg = err["message"] as? String ?? "RPC error"
                        throw NSError(domain: "CuaDriver", code: 500, userInfo: [NSLocalizedDescriptionKey: errMsg])
                    }
                    return jsonObj["result"] as? [String: Any] ?? [:]
                }
            }

            let chunk = readHandle.availableData
            if chunk.isEmpty {
                throw NSError(domain: "CuaDriver", code: 500, userInfo: [NSLocalizedDescriptionKey: "Proxy process exited unexpectedly"])
            }
            incomingBuffer.append(chunk)
        }

        throw NSError(domain: "CuaDriver", code: 408, userInfo: [NSLocalizedDescriptionKey: "Cua Driver RPC timed out waiting for response"])
    }

    private func isSessionEndedResponse(_ res: [String: Any]) -> Bool {
        let isErr = (res["isError"] as? Bool == true) || ((res["isError"] as? NSNumber)?.intValue == 1)
        if !isErr { return false }
        if let content = res["content"] as? [[String: Any]] {
            for item in content {
                if let text = item["text"] as? String,
                   text.contains("has ended") || text.contains("start_session") {
                    return true
                }
            }
        }
        return false
    }

    private func reviveSessionLocked() {
        let startSessionId = nextRequestIdLocked()
        _ = try? sendSyncMessageLocked([
            "jsonrpc": "2.0",
            "id": startSessionId,
            "method": "tools/call",
            "params": [
                "name": "start_session",
                "arguments": ["session": Self.defaultSession]
            ]
        ], expectedId: startSessionId)

        let enableCursorId = nextRequestIdLocked()
        _ = try? sendSyncMessageLocked([
            "jsonrpc": "2.0",
            "id": enableCursorId,
            "method": "tools/call",
            "params": [
                "name": "set_agent_cursor_enabled",
                "arguments": ["session": Self.defaultSession, "enabled": true]
            ]
        ], expectedId: enableCursorId)
        ClickyLogger.info("[CUA_DRIVER]", "Session revived successfully: \(Self.defaultSession)")
    }

    public func ensureSessionActive() {
        transportLock.lock()
        defer { transportLock.unlock() }
        try? ensureRunningLocked()
        reviveSessionLocked()
    }

    public func executeTool(name: String, arguments: [String: Any]) throws -> [String: Any] {
        transportLock.lock()
        defer { transportLock.unlock() }

        try ensureRunningLocked()

        let reqId = nextRequestIdLocked()
        let reqPayload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": reqId,
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ]
        let res = try sendSyncMessageLocked(reqPayload, expectedId: reqId)

        // Auto-heal once-retry: If session has ended, revive it and retry once
        if name != "start_session" && isSessionEndedResponse(res) {
            ClickyLogger.warning("[CUA_DRIVER]", "Session ended. Auto-healing: calling start_session and retrying '\(name)' once...")
            reviveSessionLocked()

            let retryId = nextRequestIdLocked()
            let retryPayload: [String: Any] = [
                "jsonrpc": "2.0",
                "id": retryId,
                "method": "tools/call",
                "params": [
                    "name": name,
                    "arguments": arguments
                ]
            ]
            return try sendSyncMessageLocked(retryPayload, expectedId: retryId)
        }

        return res
    }

    public func listToolsRaw() throws -> [[String: Any]] {
        transportLock.lock()
        defer { transportLock.unlock() }

        try ensureRunningLocked()

        let reqId = nextRequestIdLocked()
        let reqPayload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": reqId,
            "method": "tools/list",
            "params": [String: Any]()
        ]
        let res = try sendSyncMessageLocked(reqPayload, expectedId: reqId)
        return res["tools"] as? [[String: Any]] ?? []
    }

    public func stop() {
        transportLock.lock()
        defer { transportLock.unlock() }
        stopLocked()
    }

    private func stopLocked() {
        if let proxy = proxyProcess {
            if proxy.isRunning {
                proxy.terminate()
                kill(proxy.processIdentifier, SIGKILL)
            }
            proxyProcess = nil
        }
        if let daemon = daemonProcess {
            if daemon.isRunning {
                daemon.terminate()
                kill(daemon.processIdentifier, SIGKILL)
            }
            daemonProcess = nil
        }
        if let sock = currentSocketPath {
            try? FileManager.default.removeItem(atPath: sock)
            currentSocketPath = nil
        }
        toProxyPipe = nil
        fromProxyPipe = nil
        incomingBuffer.removeAll()
    }
}

@MainActor
public final class CuaDriverClient {
    public static let shared = CuaDriverClient()
    public static let defaultSession = "__cua_runtime_session"

    private let primaryBinaryPath = "/Users/heizaaa/Desktop/cdev/iza-3/bin/cua-driver"
    private let fallbackBinaryPath = NSString(string: "~/.cua-driver/bin/cua-driver").expandingTildeInPath

    private var transport: CuaDriverTransport?

    private init() {
        // Immediate clean sweep of any orphan daemons left over from previous runs
        CuaDriverTransport.terminateAllOrphanInstances()

        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopDaemon()
            }
        }
    }

    deinit {
        transport?.stop()
        CuaDriverTransport.terminateAllOrphanInstances()
    }

    private func getTransport() throws -> CuaDriverTransport {
        if let t = transport { return t }
        guard let bin = binaryPath else {
            throw NSError(domain: "CuaDriver", code: 404, userInfo: [NSLocalizedDescriptionKey: "cua-driver binary not found"])
        }
        let t = CuaDriverTransport(driverPath: bin)
        self.transport = t
        return t
    }

    public func stopDaemon() {
        transport?.stop()
        transport = nil
        CuaDriverTransport.terminateAllOrphanInstances()
    }

    public var isDaemonRunning: Bool {
        return transport?.isRunning ?? false
    }

    public var activeSocketPath: String? {
        return transport?.socketPath
    }

    /// Eagerly starts the embedded daemon and MCP proxy in background so that
    /// the agent cursor overlay and native socket are pre-warmed for immediate action.
    public func warmUp() {
        guard let t = try? getTransport() else { return }
        Task.detached(priority: .utility) {
            do {
                try t.ensureRunning()
            } catch {
                ClickyLogger.warning("[CUA_DRIVER]", "Background warmUp failed: \(error)")
            }
        }
    }

    /// Ensures that the CUA runtime session is active and the cursor overlay is enabled.
    /// Idempotent (<1ms). Revives ended sessions without restarting the daemon.
    public func ensureSessionActive() async {
        do {
            let t = try getTransport()
            await Task.detached(priority: .userInitiated) {
                t.ensureSessionActive()
            }.value
        } catch {
            ClickyLogger.warning("[CUA_DRIVER]", "ensureSessionActive failed: \(error)")
        }
    }

    /// Visually glides the native Cua Driver agent cursor overlay to the target point
    public func glideAgentCursor(to point: CGPoint) async {
        do {
            _ = try await executeTool(name: "move_cursor", arguments: ["x": point.x, "y": point.y])
            ClickyLogger.info("[CUA_DRIVER]", "Glided agent cursor to (\(Int(point.x)), \(Int(point.y)))")
        } catch {
            ClickyLogger.warning("[CUA_DRIVER]", "Failed to glide agent cursor: \(error)")
        }
    }

    // MARK: - Binary Resolution

    public var binaryPath: String? {
        // 1. Primary workspace embedded binary
        if FileManager.default.isExecutableFile(atPath: primaryBinaryPath) {
            return primaryBinaryPath
        }

        // 2. App Bundle Helpers
        if let bundleHelper = Bundle.main.url(forResource: "cua-driver", withExtension: nil)?.path,
           FileManager.default.isExecutableFile(atPath: bundleHelper) {
            return bundleHelper
        }

        // 3. Embedded Reference Path
        if FileManager.default.isExecutableFile(atPath: fallbackBinaryPath) {
            return fallbackBinaryPath
        }

        // 4. User local install
        let userLocal = NSString(string: "~/.cua-driver/bin/cua-driver").expandingTildeInPath
        if FileManager.default.isExecutableFile(atPath: userLocal) {
            return userLocal
        }

        // 5. System paths
        for path in ["/usr/local/bin/cua-driver", "/opt/homebrew/bin/cua-driver"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    public var isAvailable: Bool {
        return binaryPath != nil
    }

    private var cachedAnthropicTools: [[String: Any]]? = nil

    private var diskCacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let izanotchyDir = appSupport.appendingPathComponent("Izanotchy", isDirectory: true)
        if !FileManager.default.fileExists(atPath: izanotchyDir.path) {
            try? FileManager.default.createDirectory(at: izanotchyDir, withIntermediateDirectories: true)
        }
        return izanotchyDir.appendingPathComponent("cua_tools_cache_v021.json")
    }

    // MARK: - OpenAPI Schema Sanitizer

    /// Sanitizes tool input schemas so they are strictly valid OpenAPI 3.0 schemas
    /// compatible with both Anthropic and Google Gemini Function Declarations.
    /// Handles union types like `type: ["boolean", "null"]` by extracting the primary type
    /// and setting `nullable: true`, strips `enum` from boolean schemas (which Gemini rejects),
    /// and ensures string schemas have valid string enums.
    public nonisolated static func sanitizeSchema(_ schema: [String: Any]) -> [String: Any] {
        var clean = schema

        // 1. Sanitize union types (e.g. ["boolean", "null"], ["string", "null"])
        if let typeArray = clean["type"] as? [String] {
            let primaryType = typeArray.first(where: { $0 != "null" }) ?? "string"
            clean["type"] = primaryType
            clean["nullable"] = true
        }

        // 2. Strip enum from boolean schemas (Gemini rejects enum on booleans)
        if let typeStr = clean["type"] as? String, typeStr.lowercased() == "boolean" {
            clean.removeValue(forKey: "enum")
        }

        // 3. Stringify all enum items if enum is present
        if let enumArray = clean["enum"] as? [Any] {
            clean["enum"] = enumArray.map { String(describing: $0) }
        }

        // 4. Recursively sanitize properties
        if let properties = clean["properties"] as? [String: Any] {
            var sanitizedProps: [String: Any] = [:]
            for (key, val) in properties {
                if let propSchema = val as? [String: Any] {
                    sanitizedProps[key] = sanitizeSchema(propSchema)
                } else {
                    sanitizedProps[key] = val
                }
            }
            clean["properties"] = sanitizedProps
        }

        // 5. Recursively sanitize items (for arrays)
        if let items = clean["items"] as? [String: Any] {
            clean["items"] = sanitizeSchema(items)
        }

        return clean
    }

    // MARK: - Low-Level JSON-RPC stdio Executor

    /// Queries the live cua-driver MCP server for its full list of available tools (56 native tools)
    /// and formats them into Anthropic-compatible tool definitions (using `input_schema`).
    /// Caches permanently in RAM and on Disk (~/Library/Application Support/Izanotchy/cua_tools_cache_v021.json).
    /// Attaches `cache_control: {"type": "ephemeral"}` to the final tool to trigger server-side KV-caching.
    public func listTools(withPromptCache: Bool = true) async throws -> [[String: Any]] {
        // 1. RAM Cache Hit (Instant <0.001ms)
        if let cached = cachedAnthropicTools, !cached.isEmpty {
            return applyPromptCache(to: cached, enabled: withPromptCache)
        }

        // 2. Disk Cache Hit (Fast <1ms)
        let cacheFile = diskCacheURL
        if let diskData = try? Data(contentsOf: cacheFile),
           let diskTools = try? JSONSerialization.jsonObject(with: diskData) as? [[String: Any]],
           !diskTools.isEmpty {
            let sanitizedTools = diskTools.map { tool -> [String: Any] in
                var cleaned = tool
                if let schema = tool["input_schema"] as? [String: Any] {
                    cleaned["input_schema"] = Self.sanitizeSchema(schema)
                }
                return cleaned
            }
            self.cachedAnthropicTools = sanitizedTools
            // Re-save sanitized version if modified
            if let dataToSave = try? JSONSerialization.data(withJSONObject: sanitizedTools, options: [.prettyPrinted]) {
                try? dataToSave.write(to: cacheFile)
            }
            ClickyLogger.info("[CUA_DRIVER]", "Loaded \(sanitizedTools.count) sanitized native tools from disk cache (\(cacheFile.lastPathComponent))")
            return applyPromptCache(to: sanitizedTools, enabled: withPromptCache)
        }

        // 3. One-Time Binary Probe
        // 3. Query persistent daemon transport
        let transport = try getTransport()
        let tools = try await Task.detached(priority: .userInitiated) { () -> [[String: Any]] in
            let rawTools = try transport.listToolsRaw()
            var resultTools: [[String: Any]] = []
            for t in rawTools {
                guard let name = t["name"] as? String else { continue }
                let desc = t["description"] as? String ?? ""
                let schema = t["inputSchema"] as? [String: Any] ?? t["input_schema"] as? [String: Any] ?? ["type": "object", "properties": [:]]
                let sanitizedSchema = Self.sanitizeSchema(schema)
                resultTools.append([
                    "name": name,
                    "description": desc,
                    "input_schema": sanitizedSchema
                ])
            }
            return resultTools
        }.value

        self.cachedAnthropicTools = tools
        // Save to disk cache permanently
        if let dataToSave = try? JSONSerialization.data(withJSONObject: tools, options: [.prettyPrinted]) {
            try? dataToSave.write(to: cacheFile)
            ClickyLogger.success("[CUA_DRIVER]", "Saved \(tools.count) native tools to persistent disk cache: \(cacheFile.path)")
        }

        return applyPromptCache(to: tools, enabled: withPromptCache)
    }

    private func applyPromptCache(to tools: [[String: Any]], enabled: Bool) -> [[String: Any]] {
        guard enabled, !tools.isEmpty else { return tools }
        var result = tools
        var lastTool = result.removeLast()
        lastTool["cache_control"] = ["type": "ephemeral"]
        result.append(lastTool)
        return result
    }

    /// Returns the full suite of 56 native tools ready for Claude/Gemini API calls with KV-prompt cache.
    public func getAllNativeTools() async -> [[String: Any]] {
        do {
            return try await listTools(withPromptCache: true)
        } catch {
            ClickyLogger.warning("[CUA_DRIVER]", "Failed to retrieve native tools: \(error)")
            return []
        }
    }



    public func executeTool(name: String, arguments: [String: Any]) async throws -> [String: Any] {
        var args = arguments
        if let sess = args["session"] as? String {
            if !sess.starts(with: "__cua_runtime_") {
                args["session"] = Self.defaultSession
            }
        } else {
            args["session"] = Self.defaultSession
        }
        let transport = try getTransport()
        return try await Task.detached(priority: .userInitiated) {
            return try transport.executeTool(name: name, arguments: args)
        }.value
    }

    // MARK: - High-Level API Primitives

    public func checkPermissions() async -> (accessibility: Bool, screenRecording: Bool) {
        do {
            let res = try await executeTool(name: "check_permissions", arguments: [:])
            if let sc = res["structuredContent"] as? [String: Any] {
                let ax = sc["accessibility"] as? Bool ?? false
                let sr = sc["screen_recording"] as? Bool ?? false
                return (ax, sr)
            }
        } catch {
            ClickyLogger.warning("[CUA_DRIVER]", "checkPermissions failed: \(error)")
        }
        return (false, false)
    }

    public func listApps() async throws -> [CuaApp] {
        let res = try await executeTool(name: "list_apps", arguments: [:])
        guard let sc = res["structuredContent"] as? [String: Any],
              let apps = sc["apps"] as? [[String: Any]] else {
            return []
        }

        return apps.compactMap { dict in
            guard let name = dict["name"] as? String else { return nil }
            let pid = (dict["pid"] as? NSNumber)?.int32Value ?? 0
            let bundleId = dict["bundle_id"] as? String
            let active = dict["active"] as? Bool ?? false
            let running = dict["running"] as? Bool ?? false
            return CuaApp(name: name, pid: pid, bundleId: bundleId, isActive: active, isRunning: running)
        }
    }

    public func listWindows(pid: Int32? = nil) async throws -> [CuaWindow] {
        var args: [String: Any] = [:]
        if let p = pid { args["pid"] = p }
        let res = try await executeTool(name: "list_windows", arguments: args)
        guard let sc = res["structuredContent"] as? [String: Any],
              let wins = sc["windows"] as? [[String: Any]] else {
            return []
        }

        return wins.compactMap { dict in
            guard let wid = (dict["window_id"] as? NSNumber)?.int64Value,
                  let wpid = (dict["pid"] as? NSNumber)?.int32Value else { return nil }
            let title = dict["title"] as? String ?? ""
            let appName = dict["app_name"] as? String ?? ""
            let onScreen = dict["is_on_screen"] as? Bool ?? false
            let currentSpace = dict["on_current_space"] as? Bool ?? false
            let z = (dict["z_index"] as? NSNumber)?.intValue ?? 0

            var rect = CGRect.zero
            if let b = dict["bounds"] as? [String: Any] {
                let x = (b["x"] as? NSNumber)?.doubleValue ?? 0
                let y = (b["y"] as? NSNumber)?.doubleValue ?? 0
                let w = (b["width"] as? NSNumber)?.doubleValue ?? 0
                let h = (b["height"] as? NSNumber)?.doubleValue ?? 0
                rect = CGRect(x: x, y: y, width: w, height: h)
            }

            return CuaWindow(
                windowId: wid,
                pid: wpid,
                appName: appName,
                title: title,
                bounds: rect,
                isOnScreen: onScreen,
                onCurrentSpace: currentSpace,
                zIndex: z
            )
        }
    }

    public func getWindowState(pid: Int32, windowId: Int64) async throws -> CuaWindowState {
        let args: [String: Any] = [
            "pid": pid,
            "window_id": windowId,
            "session": Self.defaultSession
        ]
        let res = try await executeTool(name: "get_window_state", arguments: args)

        var elements: [CuaElement] = []
        if let sc = res["structuredContent"] as? [String: Any],
           let rawElems = sc["elements"] as? [[String: Any]] {
            for el in rawElems {
                guard let token = el["element_token"] as? String,
                      let role = el["role"] as? String else { continue }
                let label = el["label"] as? String ?? ""
                let val = el["value"] as? String

                var frame = CGRect.zero
                if let f = el["frame"] as? [String: Any] {
                    let x = (f["x"] as? NSNumber)?.doubleValue ?? 0
                    let y = (f["y"] as? NSNumber)?.doubleValue ?? 0
                    let w = (f["width"] as? NSNumber)?.doubleValue ?? 0
                    let h = (f["height"] as? NSNumber)?.doubleValue ?? 0
                    frame = CGRect(x: x, y: y, width: w, height: h)
                }
                elements.append(CuaElement(elementToken: token, role: role, label: label, value: val, frame: frame))
            }
        }

        let treeMd = res["tree_markdown"] as? String ?? ""
        let shotPath = res["screenshot_file_path"] as? String
        return CuaWindowState(elements: elements, treeMarkdown: treeMd, screenshotPath: shotPath)
    }

    public func click(pid: Int32, elementToken: String? = nil, coordinate: CGPoint? = nil) async throws -> Bool {
        var args: [String: Any] = [
            "pid": pid,
            "delivery_mode": "background",
            "session": Self.defaultSession
        ]
        if let token = elementToken, !token.isEmpty {
            args["element_token"] = token
        } else if let pt = coordinate {
            args["x"] = pt.x
            args["y"] = pt.y
        }

        let res = try await executeTool(name: "click", arguments: args)
        ClickyLogger.info("[CUA_DRIVER]", "Click dispatched for pid \(pid): \(res)")
        return true
    }

    public func typeText(pid: Int32, text: String, elementToken: String? = nil) async throws -> Bool {
        var args: [String: Any] = [
            "pid": pid,
            "text": text,
            "delivery_mode": "background",
            "session": Self.defaultSession
        ]
        if let token = elementToken, !token.isEmpty {
            args["element_token"] = token
        }

        let res = try await executeTool(name: "type_text", arguments: args)
        ClickyLogger.info("[CUA_DRIVER]", "TypeText dispatched for pid \(pid): \(res)")
        return true
    }

    public func hotkey(pid: Int32, windowId: Int64? = nil, keys: [String]) async throws -> Bool {
        var args: [String: Any] = [
            "pid": pid,
            "keys": keys,
            "delivery_mode": "background",
            "session": Self.defaultSession
        ]
        if let wid = windowId {
            args["window_id"] = wid
        }
        let res = try await executeTool(name: "hotkey", arguments: args)
        ClickyLogger.info("[CUA_DRIVER]", "Hotkey \(keys) dispatched for pid \(pid) (winId: \(String(describing: windowId))): \(res)")
        return true
    }

    public func launchApp(bundleId: String? = nil, name: String? = nil) async throws -> Int32? {
        var args: [String: Any] = [:]
        if let bid = bundleId { args["bundle_id"] = bid }
        if let n = name { args["name"] = n }

        let res = try await executeTool(name: "launch_app", arguments: args)
        if let p = (res["pid"] as? NSNumber)?.int32Value {
            ClickyLogger.success("[CUA_DRIVER]", "Launched app \(name ?? bundleId ?? "") -> PID \(p)")
            return p
        }
        return nil
    }

    public func killApp(pid: Int32) async throws -> Bool {
        let args: [String: Any] = [
            "pid": pid,
            "session": Self.defaultSession
        ]
        let res = try await executeTool(name: "kill_app", arguments: args)
        ClickyLogger.info("[CUA_DRIVER]", "kill_app dispatched for pid \(pid): \(res)")
        return true
    }

    public func moveCursor(pid: Int32? = nil, windowId: Int64? = nil, x: Double, y: Double) async throws -> Bool {
        var args: [String: Any] = [
            "x": x,
            "y": y,
            "session": Self.defaultSession
        ]
        if let p = pid, let wid = windowId {
            args["target"] = [
                "kind": "window",
                "pid": p,
                "window_id": wid
            ]
        }
        let res = try await executeTool(name: "move_cursor", arguments: args)
        ClickyLogger.info("[CUA_DRIVER]", "move_cursor dispatched to (\(x), \(y)): \(res)")
        return true
    }

    public func pressKey(pid: Int32, key: String) async throws -> Bool {
        let args: [String: Any] = [
            "pid": pid,
            "key": key,
            "delivery_mode": "background",
            "session": Self.defaultSession
        ]
        let res = try await executeTool(name: "press_key", arguments: args)
        ClickyLogger.info("[CUA_DRIVER]", "press_key '\(key)' dispatched for pid \(pid): \(res)")
        return true
    }

    public func captureWindowSnapshot(pid: Int32, windowId: Int64, outPath: String) async throws -> (width: CGFloat, height: CGFloat, scale: CGFloat, bounds: CGRect) {
        let args: [String: Any] = [
            "pid": pid,
            "window_id": windowId,
            "screenshot_out_file": outPath,
            "session": Self.defaultSession
        ]
        let res = try await executeTool(name: "get_window_state", arguments: args)
        guard let sc = res["structuredContent"] as? [String: Any] else {
            throw NSError(domain: "CuaDriver", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get window state structured content"])
        }
        let w = (sc["screenshot_width"] as? NSNumber)?.doubleValue ?? 1024
        let h = (sc["screenshot_height"] as? NSNumber)?.doubleValue ?? 768
        let scale = (sc["screenshot_scale"] as? NSNumber)?.doubleValue ?? 2
        var bounds = CGRect.zero
        if let b = sc["window_bounds"] as? [String: Any] {
            let bx = (b["x"] as? NSNumber)?.doubleValue ?? 0
            let by = (b["y"] as? NSNumber)?.doubleValue ?? 0
            let bw = (b["width"] as? NSNumber)?.doubleValue ?? 0
            let bh = (b["height"] as? NSNumber)?.doubleValue ?? 0
            bounds = CGRect(x: bx, y: by, width: bw, height: bh)
        }
        return (CGFloat(w), CGFloat(h), CGFloat(scale), bounds)
    }

    public func clickPixel(pid: Int32, windowId: Int64, x: Double, y: Double) async throws -> Bool {
        let args: [String: Any] = [
            "pid": pid,
            "window_id": windowId,
            "x": x,
            "y": y,
            "delivery_mode": "foreground",
            "session": Self.defaultSession
        ]
        let res = try await executeTool(name: "click", arguments: args)
        ClickyLogger.info("[CUA_DRIVER]", "clickPixel dispatched to (\(x), \(y)): \(res)")
        return true
    }
}
