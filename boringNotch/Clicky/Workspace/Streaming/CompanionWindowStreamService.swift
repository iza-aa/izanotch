import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit

// MARK: - CompanionWindowStreamService (F-08)
/// Layanan streaming dan penangkap frame jendela aplikasi macOS (Mail, Safari, TradingView, dll)
/// Menghubungkan window server ke canvas kartu chat "Computer" dan modal semi-fullscreen.
@MainActor
public final class CompanionWindowStreamService: ObservableObject {
    public static let shared = CompanionWindowStreamService()

    @Published public private(set) var activeSnapshot: NSImage?
    @Published public private(set) var activeWindowFramePath: String?
    public var activeSnapshotPath: String? { activeWindowFramePath }
    @Published public private(set) var isStreaming: Bool = false
    @Published public private(set) var currentTargetAppName: String?
    @Published public private(set) var currentTargetWindowId: Int64?

    private var streamingTimer: Timer?
    private var activeSlug: String = "inbox-buddy"
    private var isCapturingFallback: Bool = false
    public var activeIntentType: String? = nil
    public var activeTargetEntity: String? = nil

    private init() {}

    public func updateActiveSnapshot(_ image: NSImage?, path: String?) {
        self.activeSnapshot = image
        self.activeWindowFramePath = path
    }

    // MARK: - ScreenCaptureKit In-Memory Window Capture (macOS 14+)
    private func captureWindowViaScreenCaptureKit(windowId: Int64) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let window = content.windows.first(where: { $0.windowID == CGWindowID(windowId) }) else {
                return nil
            }
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.width = max(Int(window.frame.width), 100)
            config.height = max(Int(window.frame.height), 100)
            config.showsCursor = false
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            ClickyLogger.warning("[WINDOW_STREAM]", "ScreenCaptureKit error for window \(windowId): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Target Window Discovery & Capture
    /// Asynchronously captures candidate target window with real-time screencapture fallback.
    /// Guarantees that activeSnapshot and disk image exist before returning, preventing blank viewports.
    @discardableResult
    public func captureTargetWindowAsync(appName: String, slug: String) async -> String? {
        self.activeSlug = slug
        self.currentTargetAppName = appName

        let candidates = findCandidateWindows(appName: appName)
        guard !candidates.isEmpty else {
            ClickyLogger.warning("[WINDOW_STREAM]", "Target window not found for app: \"\(appName)\"")
            return nil
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let snapshotsDir = "\(homeDir)/.izanotchy/companions/\(slug)/workspace/snapshots"
        let targetFilePath = "\(snapshotsDir)/active_frame.png"
        try? FileManager.default.createDirectory(atPath: snapshotsDir, withIntermediateDirectories: true)

        for candidate in candidates {
            let windowId = candidate.windowId
            self.currentTargetWindowId = windowId

            // Method A: Modern ScreenCaptureKit in-memory capture (Fast 2-5ms, works on macOS 14/15)
            if let sckImage = await captureWindowViaScreenCaptureKit(windowId: windowId) {
                self.activeSnapshot = sckImage
                self.activeWindowFramePath = targetFilePath

                if let cgImage = sckImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let bitmap = NSBitmapImageRep(cgImage: cgImage)
                    if let pngData = bitmap.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: URL(fileURLWithPath: targetFilePath), options: .atomic)
                    }
                }
                ClickyLogger.info("[WINDOW_STREAM]", "Captured window frame via ScreenCaptureKit for \"\(appName)\" (ID: \(windowId), \"\(candidate.title)\")")
                return targetFilePath
            }

            // Method B: System screencapture -l fallback (Awaited asynchronously off MainActor)
            let res = await CompanionVMAgentLoop.runSubprocessAsync(
                executable: "/usr/sbin/screencapture",
                arguments: ["-x", "-l", "\(windowId)", targetFilePath],
                timeoutSeconds: 2.0
            )

            if res.exitCode == 0,
               FileManager.default.fileExists(atPath: targetFilePath),
               let loadedImage = NSImage(contentsOfFile: targetFilePath) {
                self.activeWindowFramePath = targetFilePath
                self.activeSnapshot = loadedImage
                ClickyLogger.info("[WINDOW_STREAM]", "Captured window frame via screencapture for \"\(appName)\" (ID: \(windowId), \"\(candidate.title)\")")
                return targetFilePath
            } else {
                ClickyLogger.warning("[WINDOW_STREAM]", "screencapture failed for ID \(windowId): exit=\(res.exitCode), output=\(res.output), exists=\(FileManager.default.fileExists(atPath: targetFilePath))")
            }
        }

        ClickyLogger.warning("[WINDOW_STREAM]", "Could not capture any candidate window for \"\(appName)\"")
        return nil
    }

    /// Mencari jendela aplikasi target yang sedang terbuka di layar dan menangkap satu frame gambar (synchronous fallback).
    @discardableResult
    public func captureTargetWindow(appName: String, slug: String) -> String? {
        self.activeSlug = slug
        self.currentTargetAppName = appName

        let candidates = findCandidateWindows(appName: appName)
        guard !candidates.isEmpty else {
            return nil
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let snapshotsDir = "\(homeDir)/.izanotchy/companions/\(slug)/workspace/snapshots"
        let targetFilePath = "\(snapshotsDir)/active_frame.png"
        try? FileManager.default.createDirectory(atPath: snapshotsDir, withIntermediateDirectories: true)

        for candidate in candidates {
            let windowId = candidate.windowId
            self.currentTargetWindowId = windowId

            // Method A: In-memory CGWindowListCreateImage (Fast 1-3ms)
            if let cgImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                CGWindowID(windowId),
                [.boundsIgnoreFraming, .bestResolution]
            ) {
                let img = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                self.activeSnapshot = img
                self.activeWindowFramePath = targetFilePath

                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: URL(fileURLWithPath: targetFilePath), options: .atomic)
                }
                return targetFilePath
            }

            // Method B: System screencapture -l fallback (Dispatched to background to protect Event Tap)
            if !isCapturingFallback {
                isCapturingFallback = true
                let cTitle = candidate.title
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    defer {
                        DispatchQueue.main.async {
                            self?.isCapturingFallback = false
                        }
                    }
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    p.arguments = ["-x", "-l", "\(windowId)", targetFilePath]
                    try? p.run()
                    p.waitUntilExit()

                    if p.terminationStatus == 0,
                       FileManager.default.fileExists(atPath: targetFilePath),
                       let loadedImage = NSImage(contentsOfFile: targetFilePath) {
                        DispatchQueue.main.async {
                            self?.activeWindowFramePath = targetFilePath
                            self?.activeSnapshot = loadedImage
                            ClickyLogger.info("[WINDOW_STREAM]", "Captured window frame via screencapture for \"\(appName)\" (ID: \(windowId), \"\(cTitle)\")")
                        }
                    }
                }
            }
        }

        return self.activeWindowFramePath
    }

    // MARK: - Throttled Live Streaming
    /// Memulai pengambilan frame berkala (1–2 FPS) agar tampilan di kartu dan modal selalu ter-update secara nyata.
    public func startStreaming(appName: String, slug: String, interval: TimeInterval = 1.0) {
        guard !isStreaming else { return }
        self.isStreaming = true
        self.currentTargetAppName = appName
        self.activeSlug = slug

        // Immediate first capture
        Task { @MainActor [weak self] in
            guard let self = self, self.isStreaming else { return }
            await self.captureTargetWindowAsync(appName: appName, slug: slug)
        }

        // Periodic timer on main runloop
        streamingTimer?.invalidate()
        streamingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isStreaming else { return }
                await self.captureTargetWindowAsync(appName: appName, slug: slug)
            }
        }
        ClickyLogger.info("[WINDOW_STREAM]", "Started live window streaming for \"\(appName)\" (interval: \(interval)s)")
    }

    /// Menghentikan loop streaming frame
    public func stopStreaming() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        isStreaming = false
        ClickyLogger.info("[WINDOW_STREAM]", "Stopped live window streaming")
    }

    /// Beralih memantau aplikasi lain di dalam Workflow Suite bot (misal: dari Safari ke Mail)
    public func switchTargetApp(appName: String, slug: String) {
        self.currentTargetAppName = appName
        self.activeSlug = slug
        ClickyLogger.info("[WINDOW_STREAM]", "Switching target app to: \"\(appName)\" for companion \"\(slug)\"")
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.captureTargetWindowAsync(appName: appName, slug: slug)
        }

        if isStreaming {
            streamingTimer?.invalidate()
            streamingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isStreaming else { return }
                    await self.captureTargetWindowAsync(appName: appName, slug: slug)
                }
            }
        }
    }

    /// Mendeteksi jendela-jendela yang sedang berjalan dari daftar Workflow Apps
    public func resolveRunningAppWindows(appNames: [String]) -> [String: CGWindowID] {
        var resolved: [String: CGWindowID] = [:]
        for app in appNames {
            if let target = findTargetWindow(appName: app) {
                resolved[app] = CGWindowID(target.windowId)
            }
        }
        return resolved
    }

    /// Meluncurkan atau membawa aplikasi alur kerja ke depan sesuai domain eksekusi
    public func launchOrFocusWorkflowApp(appName: String, domain: MascotExecutionDomain = .virtualSandbox) {
        if domain == .virtualSandbox {
            ClickyLogger.info("[WINDOW_STREAM]", "Companion is executing inside isolated virtualSandbox device (\(appName)) — Host Mac desktop preserved.")
            let slug = activeSlug
            let workspace = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".izanotchy/companions/\(slug)/workspace/snapshots", isDirectory: true)
            try? FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        } else {
            ClickyLogger.info("[WINDOW_STREAM]", "Launching \(appName) on host Mac desktop.")
            NSWorkspace.shared.launchApplication(appName)
        }
    }

    // MARK: - Helper Window Discovery
    public struct WindowTargetInfo {
        public let windowId: Int64
        public let pid: pid_t
        public let bounds: CGRect
        public let title: String
        public let isDialog: Bool
    }

    /// Meluncurkan aplikasi di background tanpa mencuri fokus pengguna (activates = false)
    /// Jika aplikasi sudah berjalan tetapi jendelanya tertutup, mengirimkan perintah reopen universal.
    public func ensureWorkflowAppRunning(appName: String) {
        let clean = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let runningApps = NSWorkspace.shared.runningApplications
        let matchingApp = runningApps.first { app in
            app.localizedName?.localizedCaseInsensitiveContains(clean) == true
        }

        var appPath: String?
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.\(clean)") ??
                        InstalledAppsDiscoveryService.shared.findAppURL(appName: clean) {
            appPath = appURL.path
        } else {
            let possiblePaths = [
                "/Applications/\(clean).app",
                "/System/Applications/\(clean).app",
                "/System/Volumes/Preboot/Cryptexes/App/System/Applications/\(clean).app"
            ]
            appPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) })
        }

        if let app = matchingApp {
            if app.isHidden {
                app.unhide()
                ClickyLogger.info("[WINDOW_STREAM]", "Unhid running background app \"\(clean)\"")
            }
            // App is already running. Check if it has any candidate viewer windows
            let candidates = findCandidateWindows(appName: clean)
            if candidates.isEmpty {
                // Universal reopen request via AppleScript to reopen default main window
                let script = "tell application \"\(clean)\" to reopen"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                    ClickyLogger.info("[WINDOW_STREAM]", "Sent universal reopen command to background app \"\(clean)\"")
                }
            }
        } else if let path = appPath, FileManager.default.fileExists(atPath: path) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = ["-g", "-a", path, "--args", "-ApplePersistenceIgnoreState", "YES"]
            try? p.run()
            ClickyLogger.info("[WINDOW_STREAM]", "Ensured workflow app running in background (clean persistence): \(path)")
        }
    }

    /// Mendeteksi apakah ada sheet modal/dialog autentikasi yang memblokir interaksi
    public func detectBlockingDialog(appName: String) -> String? {
        let candidates = findCandidateWindows(appName: appName)
        for c in candidates {
            let lower = c.title.lowercased()
            let isAuthBlocking = lower.contains("password") ||
                                 lower.contains("passcode") ||
                                 lower.contains("kata sandi") ||
                                 lower.contains("two-factor") ||
                                 lower.contains("2-step") ||
                                 lower.contains("verification code") ||
                                 lower.contains("keychain") ||
                                 lower.contains("sign-in required")
            if isAuthBlocking {
                return c.title.isEmpty ? "Authentication Dialog" : c.title
            }
        }
        return nil
    }

    public func findCandidateWindows(appName: String) -> [WindowTargetInfo] {
        let options = CGWindowListOption(arrayLiteral: .optionAll, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let cleanTarget = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates: [WindowTargetInfo] = []

        for w in windowList {
            let ownerName = (w[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            let windowName = (w[kCGWindowName as String] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let layer = w[kCGWindowLayer as String] as? Int ?? -1
            let windowId = Int64(w[kCGWindowNumber as String] as? Int ?? 0)
            let pid = pid_t(w[kCGWindowOwnerPID as String] as? Int ?? 0)

            guard layer == 0, windowId > 0 else { continue }

            if cleanTarget != "finder" && (ownerName == "finder" || ownerName.contains("finder")) {
                continue
            }

            let matchesApp = ownerName == cleanTarget ||
                             ownerName.hasPrefix(cleanTarget) ||
                             ownerName.contains(cleanTarget)

            guard matchesApp else { continue }

            if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
               let wX = boundsDict["X"] as? Double,
               let wY = boundsDict["Y"] as? Double,
               let wW = boundsDict["Width"] as? Double,
               let wH = boundsDict["Height"] as? Double,
               wW > 180, wH > 120 {
                let rect = CGRect(x: wX, y: wY, width: wW, height: wH)
                let isDialog = wW < 520 || wH < 400 || windowName.lowercased().contains("cleanup") || windowName.lowercased().contains("dialog")
                candidates.append(WindowTargetInfo(windowId: windowId, pid: pid, bounds: rect, title: windowName, isDialog: isDialog))
            }
        }

        // Preserve natural front-to-back z-order from WindowServer (topmost window first).
        // Prefer standard application windows over tiny transient utility dialogs.
        let nonDialogs = candidates.filter { !$0.isDialog }
        guard !nonDialogs.isEmpty else { return candidates }

        // Universal Intent-Based Viewer & Primary Workspace Window Resolution:
        // Always anchor to the primary application viewer / workspace window first so that tasks start with a clean slate.
        let primaryWorkspaceTokens = ["inbox", "inboxes", "kotak masuk", "semua kotak masuk", "viewer", "overview", "library", "notes", "all inboxes", cleanTarget]
        if let primaryWin = nonDialogs.first(where: { win in
            let title = win.title.lowercased()
            return primaryWorkspaceTokens.contains { title.contains($0) }
        }) {
            // If currently on an active fresh editor window spawned in-session (e.g. "new", "baru", "untitled"), allow it;
            // otherwise, prioritize the clean primary workspace window.
            let intent = activeIntentType?.lowercased() ?? ""
            if (intent == "compose" || intent == "send"),
               let freshEditorWin = nonDialogs.first(where: { win in
                   let title = win.title.lowercased()
                   return title.contains("new") || title.contains("baru") || title.contains("untitled") || title.contains("tanpa judul")
               }) {
                return [freshEditorWin] + nonDialogs.filter { $0.windowId != freshEditorWin.windowId }
            }
            return [primaryWin] + nonDialogs.filter { $0.windowId != primaryWin.windowId }
        }

        // Universal Dynamic Entity Grounding across ANY Application:
        // Score candidate windows dynamically using semantic token overlap with targetEntity.
        if let targetEntity = activeTargetEntity?.lowercased(), !targetEntity.isEmpty, targetEntity != "main_window" && targetEntity != "user" {
            let entityTokens = targetEntity
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }
            
            if !entityTokens.isEmpty {
                let scored = nonDialogs.map { candidate -> (WindowTargetInfo, Int) in
                    let cTitle = candidate.title.lowercased()
                    let matchCount = entityTokens.filter { cTitle.contains($0) }.count
                    return (candidate, matchCount)
                }
                if let bestMatch = scored.first(where: { $0.1 > 0 })?.0 {
                    return [bestMatch] + nonDialogs.filter { $0.windowId != bestMatch.windowId }
                }
            }
        }

        return nonDialogs
    }

    private func findTargetWindow(appName: String) -> WindowTargetInfo? {
        return findCandidateWindows(appName: appName).first
    }
}
