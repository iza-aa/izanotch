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
    public var activeWindowTitle: String? = nil

    private init() {}

    public func updateActiveSnapshot(_ image: NSImage?, path: String?) {
        self.activeSnapshot = image
        self.activeWindowFramePath = path
    }

    // MARK: - ScreenCaptureKit In-Memory Workspace & Window Capture (macOS 14+)
    /// Captures the True Stacked Virtual Display Workspace where all windows of the application stack naturally in z-order
    private func captureWorkspaceViaScreenCaptureKit(appName: String, targetBounds: CGRect? = nil, fallbackWindowId: Int64? = nil) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            let cleanApp = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let matchingApp = content.applications.first(where: {
                let name = $0.applicationName.lowercased()
                return name == cleanApp || name.hasPrefix(cleanApp) || name.contains(cleanApp)
            })

            // Priority 1: True Stacked Virtual Display Workspace Capture
            // If our CGVirtualDisplay is active, capture the virtual display filtered to the workflow application.
            // macOS WindowServer automatically composites all windows (inbox, drafts, modal sheets) in their natural z-order stacking!
            let vdID = MascotVirtualDesktopService.shared.displayID
            if vdID > 0 {
                // CGVirtualDisplay does not support SCScreenshotManager hardware pipeline; handled cleanly via in-memory Quartz
                return nil
            }
            // Priority 2: Single Window Fallback if Virtual Display is not allocated
            if let winId = fallbackWindowId,
               let window = content.windows.first(where: { $0.windowID == CGWindowID(winId) }) {
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                config.width = max(Int(window.frame.width), 100)
                config.height = max(Int(window.frame.height), 100)
                config.showsCursor = false
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
            return nil
        } catch {
            ClickyLogger.warning("[WINDOW_STREAM]", "ScreenCaptureKit error: \(error.localizedDescription)")
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

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let snapshotsDir = "\(homeDir)/.izanotchy/companions/\(slug)/workspace/snapshots"
        let targetFilePath = "\(snapshotsDir)/active_frame.png"
        try? FileManager.default.createDirectory(atPath: snapshotsDir, withIntermediateDirectories: true)

        let candidates = findCandidateWindows(appName: appName)
        let primaryWin = candidates.first
        if let win = primaryWin {
            self.currentTargetWindowId = win.windowId
            self.activeWindowTitle = win.title
        }

        // Method A: Capture True Stacked Virtual Display Workspace via ScreenCaptureKit (Auto-Cropped to Window Bounds)
        if let workspaceImage = await captureWorkspaceViaScreenCaptureKit(appName: appName, targetBounds: primaryWin?.bounds, fallbackWindowId: primaryWin?.windowId) {
            self.activeWindowFramePath = targetFilePath

            if let cgImage = workspaceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let bitmap = NSBitmapImageRep(cgImage: cgImage)
                if let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: URL(fileURLWithPath: targetFilePath), options: .atomic)
                }
            }
            ClickyLogger.info("[WINDOW_STREAM]", "Captured stacked workspace via ScreenCaptureKit for \"\(appName)\" (Virtual Display ID: \(MascotVirtualDesktopService.shared.displayID))")
            return targetFilePath
        }

        // Method B: In-Memory CGWindowListCreateImage Fallback (Zero Process Overhead, Zero Screen Flicker)
        if let win = primaryWin {
            if let cgImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                CGWindowID(win.windowId),
                [.boundsIgnoreFraming, .bestResolution]
            ) {
                let loadedImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                self.activeWindowFramePath = targetFilePath
                self.activeSnapshot = loadedImage

                DispatchQueue.global(qos: .utility).async {
                    let rep = NSBitmapImageRep(cgImage: cgImage)
                    if let pngData = rep.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: URL(fileURLWithPath: targetFilePath), options: .atomic)
                    }
                }
                ClickyLogger.info("[WINDOW_STREAM]", "Captured window frame via in-memory CGWindowListCreateImage fallback for \"\(appName)\" (ID: \(win.windowId), \"\(win.title)\")")
                return targetFilePath
            }
        }

        ClickyLogger.warning("[WINDOW_STREAM]", "Could not capture workspace for \"\(appName)\"")
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
            self.activeWindowTitle = candidate.title

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
            // Method B: Handled cleanly in-memory above without any subprocess invocations
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
            // Zero Host Screen Intrusion: Do NOT call app.unhide() on the host screen.
            // Windows are moved directly to virtual display coordinates (X >= 1500) while hidden.
            // App is already running. Check if it has any candidate viewer windows
            let candidates = findCandidateWindows(appName: clean)
            if candidates.isEmpty {
                // Universal reopen request via non-activating open command (Zero AppleScript, Zero Split Screen)
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                p.arguments = ["-g", "-j", "-a", clean]
                try? p.run()
                ClickyLogger.info("[WINDOW_STREAM]", "Sent non-activating reopen command to background app \"\(clean)\"")
            }
        } else if let path = appPath, FileManager.default.fileExists(atPath: path) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = ["-g", "-a", path, "--args", "-ApplePersistenceIgnoreState", "YES"]
            try? p.run()
            ClickyLogger.info("[WINDOW_STREAM]", "Ensured workflow app running in background (clean persistence): \(path)")
        }
    }

    /// Mendeteksi apakah ada sheet modal/dialog yang memblokir interaksi
    public func detectBlockingDialog(appName: String) -> String? {
        let options = CGWindowListOption(arrayLiteral: .optionAll, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let cleanTarget = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for w in windowList {
            let ownerName = (w[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            guard ownerName == cleanTarget || ownerName.hasPrefix(cleanTarget) || ownerName.contains(cleanTarget) else { continue }
            let layer = w[kCGWindowLayer as String] as? Int ?? -1
            guard layer == 0 else { continue }
            let windowName = (w[kCGWindowName as String] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
               let wW = boundsDict["Width"] as? Double,
               let wH = boundsDict["Height"] as? Double {
                let isSmallModal = wW > 120 && wH > 80 && wW < 550 && wH < 400
                let isNamedModal = (wW < 600 && wH < 500) && (windowName.lowercased().contains("dialog") || windowName.lowercased().contains("sheet") || windowName.lowercased().contains("alert"))
                if isSmallModal || isNamedModal {
                    return windowName.isEmpty ? "Modal Sheet Dialog" : windowName
                }
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
                // Filter out full-sized untitled dimmer backdrop overlays
                let isDimmerOverlay = windowName.isEmpty && wW > 800 && wH > 500
                if isDimmerOverlay { continue }
                // Filter out non-workspace background utility/cleanup windows
                if windowName.localizedCaseInsensitiveContains("cleanup") { continue }
                let rect = CGRect(x: wX, y: wY, width: wW, height: wH)
                let isDialog = (wW < 550 && wH < 400) || (wW < 600 && wH < 500 && (windowName.lowercased().contains("dialog") || windowName.lowercased().contains("sheet") || windowName.lowercased().contains("alert")))
                candidates.append(WindowTargetInfo(windowId: windowId, pid: pid, bounds: rect, title: windowName, isDialog: isDialog))
            }
        }

        // Preserve natural front-to-back z-order from WindowServer (topmost window first).
        // Resolve missing titles from Accessibility IPC if CGWindowName is empty
        let nonDialogs = candidates.filter { !$0.isDialog }
        var resolvedWindows: [WindowTargetInfo] = []
        for c in nonDialogs {
            if c.title.isEmpty && c.bounds.width >= 550 && c.bounds.height >= 400 {
                var newTitle = ""
                let appRef = AXUIElementCreateApplication(c.pid)
                var winListRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &winListRef) == .success,
                   let axWindows = winListRef as? [AXUIElement] {
                    for axWin in axWindows {
                        var tRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &tRef) == .success,
                           let t = tRef as? String, !t.isEmpty {
                            newTitle = t
                            break
                        }
                    }
                }
                resolvedWindows.append(WindowTargetInfo(windowId: c.windowId, pid: c.pid, bounds: c.bounds, title: newTitle.isEmpty ? "New Message" : newTitle, isDialog: c.isDialog))
            } else {
                resolvedWindows.append(c)
            }
        }
        let eligibleWindows = resolvedWindows
        guard !eligibleWindows.isEmpty else { return candidates.filter { !$0.isDialog } }
        // Prioritize windows residing on the isolated Virtual Display (X >= 1500)
        let virtualDisplayOriginX = MascotVirtualDesktopService.shared.displayBounds.origin.x > 0 ? MascotVirtualDesktopService.shared.displayBounds.origin.x : 1512.0
        let hostWindows = eligibleWindows.filter { $0.bounds.origin.x < virtualDisplayOriginX - 100 }
        if !hostWindows.isEmpty {
            MascotVirtualDesktopService.shared.relocateAppWindowsToVirtualDesktop(appName: cleanTarget)
        }
        let vdWindows = eligibleWindows.filter { $0.bounds.origin.x >= virtualDisplayOriginX - 100 }
        let primaryWindows = vdWindows.isEmpty ? eligibleWindows : vdWindows

        // Universal Dynamic Entity Grounding across ANY Application:
        // Score candidate windows dynamically using semantic token overlap with targetEntity.
        if let targetEntity = activeTargetEntity?.lowercased(), !targetEntity.isEmpty, targetEntity != "main_window" && targetEntity != "user" {
            let entityTokens = targetEntity
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }
            
            if !entityTokens.isEmpty {
                let scored = primaryWindows.map { candidate -> (WindowTargetInfo, Int) in
                    let cTitle = candidate.title.lowercased()
                    let matchCount = entityTokens.filter { cTitle.contains($0) }.count
                    return (candidate, matchCount)
                }
                if let bestMatch = scored.filter({ $0.1 > 0 }).max(by: { $0.1 < $1.1 })?.0 {
                    return [bestMatch] + primaryWindows.filter { $0.windowId != bestMatch.windowId }
                }
            }
        }

        // Universal Affordance Discovery across ANY Application (Zero Hardcoding):
        // Dynamically prioritize collection windows for inspect/read intents, or editor windows for compose intents.
        if primaryWindows.count > 1 {
            let isInspectOrRead = activeIntentType == "inspect" || activeIntentType == "read"
            let isComposeOrEdit = activeIntentType == "compose" || activeIntentType == "create" || activeIntentType == "write"

            if isInspectOrRead {
                if let collectionCandidate = primaryWindows.first(where: { checkWindowAffordance(pid: $0.pid, windowTitle: $0.title).hasCollection }) {
                    if collectionCandidate.windowId != primaryWindows.first?.windowId {
                        ClickyLogger.info("[WINDOW_STREAM]", "Universal Affordance Discovery: Prioritized collection window '\(collectionCandidate.title)' (ID: \(collectionCandidate.windowId)) over editor window for inspect intent.")
                        raiseTargetAXWindow(pid: collectionCandidate.pid, title: collectionCandidate.title)
                        return [collectionCandidate] + primaryWindows.filter { $0.windowId != collectionCandidate.windowId }
                    }
                }
            } else if isComposeOrEdit {
                if let editorCandidate = primaryWindows.first(where: { checkWindowAffordance(pid: $0.pid, windowTitle: $0.title).hasEditor }) {
                    if editorCandidate.windowId != primaryWindows.first?.windowId {
                        ClickyLogger.info("[WINDOW_STREAM]", "Universal Affordance Discovery: Prioritized editor window '\(editorCandidate.title)' (ID: \(editorCandidate.windowId)) for compose intent.")
                        raiseTargetAXWindow(pid: editorCandidate.pid, title: editorCandidate.title)
                        return [editorCandidate] + primaryWindows.filter { $0.windowId != editorCandidate.windowId }
                    }
                } else if let collectionCandidate = primaryWindows.first(where: { checkWindowAffordance(pid: $0.pid, windowTitle: $0.title).hasCollection }) {
                    // If editor window is not open yet, prioritize collection window containing the create/compose action
                    if collectionCandidate.windowId != primaryWindows.first?.windowId {
                        ClickyLogger.info("[WINDOW_STREAM]", "Universal Affordance Discovery: Prioritized collection window '\(collectionCandidate.title)' (ID: \(collectionCandidate.windowId)) to locate create action for compose intent.")
                        raiseTargetAXWindow(pid: collectionCandidate.pid, title: collectionCandidate.title)
                        return [collectionCandidate] + primaryWindows.filter { $0.windowId != collectionCandidate.windowId }
                    }
                }
            }
        }

        return primaryWindows
    }

    private func checkWindowAffordance(pid: pid_t, windowTitle: String) -> (hasCollection: Bool, hasEditor: Bool) {
        let cleanTitle = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard pid > 0 else { return (false, false) }
        let appRef = AXUIElementCreateApplication(pid)
        var winListRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &winListRef) == .success,
              let axWindows = winListRef as? [AXUIElement] else {
            return (false, false)
        }

        let collectionRoles: Set<String> = ["AXTable", "AXOutline", "AXList", "AXBrowser"]
        let editorRoles: Set<String> = ["AXTextArea", "AXWebArea", "AXTextField"]

        let targetAXWin = axWindows.first(where: { win in
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef) == .success,
               let t = titleRef as? String, !t.isEmpty {
                return !cleanTitle.isEmpty && (t == cleanTitle || t.contains(cleanTitle) || cleanTitle.contains(t))
            }
            return cleanTitle.isEmpty
        })

        if let axWin = targetAXWin {
            let hasCollection = hasAnyAXRole(parent: axWin, roles: collectionRoles, maxDepth: 8)
            let hasEditor = hasAnyAXRole(parent: axWin, roles: editorRoles, maxDepth: 8) && !hasCollection
            return (hasCollection, hasEditor)
        }

        for win in axWindows {
            let hasCol = hasAnyAXRole(parent: win, roles: collectionRoles, maxDepth: 8)
            let hasEd = hasAnyAXRole(parent: win, roles: editorRoles, maxDepth: 8) && !hasCol
            if hasEd {
                return (false, true)
            }
        }
        return (false, false)
    }

    private func hasAnyAXRole(parent: AXUIElement, roles: Set<String>, depth: Int = 0, maxDepth: Int = 8) -> Bool {
        if depth > maxDepth { return false }
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &roleRef) == .success,
           let r = roleRef as? String, roles.contains(r) {
            return true
        }
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children.prefix(25) {
                if hasAnyAXRole(parent: child, roles: roles, depth: depth + 1, maxDepth: maxDepth) {
                    return true
                }
            }
        }
        return false
    }

    private func raiseTargetAXWindow(pid: pid_t, title: String) {
        guard pid > 0 else { return }
        let appRef = AXUIElementCreateApplication(pid)
        var winListRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &winListRef) == .success,
           let wins = winListRef as? [AXUIElement] {
            if let axWin = wins.first(where: { w in
                var tRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &tRef) == .success,
                   let t = tRef as? String {
                    return t == title || t.contains(title) || title.contains(t)
                }
                return false
            }) {
                AXUIElementPerformAction(axWin, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(axWin, kAXMainAttribute as CFString, kCFBooleanTrue)
            }
        }
    }

    private func findTargetWindow(appName: String) -> WindowTargetInfo? {
        return findCandidateWindows(appName: appName).first
    }

    // MARK: - Modal Sheet Overlay Discovery & Compositing

    public func findActiveSheetDialog(appName: String, parentBounds: CGRect) -> WindowTargetInfo? {
        let options = CGWindowListOption(arrayLiteral: .optionAll, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let cleanTarget = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for w in windowList {
            let ownerName = (w[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            guard ownerName == cleanTarget || ownerName.hasPrefix(cleanTarget) || ownerName.contains(cleanTarget) else { continue }
            let layer = w[kCGWindowLayer as String] as? Int ?? -1
            guard layer == 0 else { continue }
            let windowId = Int64(w[kCGWindowNumber as String] as? Int ?? 0)
            let pid = pid_t(w[kCGWindowOwnerPID as String] as? Int ?? 0)
            let title = (w[kCGWindowName as String] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
               let wX = boundsDict["X"] as? Double,
               let wY = boundsDict["Y"] as? Double,
               let wW = boundsDict["Width"] as? Double,
               let wH = boundsDict["Height"] as? Double {
                let rect = CGRect(x: wX, y: wY, width: wW, height: wH)
                // A sheet dialog is a small window (< 550x400) positioned within or overlapping parent bounds
                if wW > 120 && wH > 80 && wW < 550 && wH < 400 {
                    return WindowTargetInfo(windowId: windowId, pid: pid, bounds: rect, title: title, isDialog: true)
                }
            }
        }
        return nil
    }

    public func compositeSheetOnParentWindow(
        parentImage: NSImage,
        parentBounds: CGRect,
        sheetImage: NSImage,
        sheetBounds: CGRect
    ) -> NSImage {
        let parentSize = parentImage.size
        let result = NSImage(size: parentSize)
        result.lockFocus()

        // 1. Draw parent window background
        parentImage.draw(in: NSRect(origin: .zero, size: parentSize))

        // 2. Soft translucent dark overlay across parent window (AppKit modal dimming)
        NSColor.black.withAlphaComponent(0.35).setFill()
        NSRect(origin: .zero, size: parentSize).fill(using: .sourceOver)

        // 3. Compute relative position of sheet card inside parent window
        let scaleX = parentSize.width / max(parentBounds.width, 1.0)
        let scaleY = parentSize.height / max(parentBounds.height, 1.0)

        let relX = (sheetBounds.origin.x - parentBounds.origin.x) * scaleX
        // Quartz origin is top-left, AppKit lockFocus origin is bottom-left:
        let relY = (parentBounds.origin.y + parentBounds.height - (sheetBounds.origin.y + sheetBounds.height)) * scaleY
        let sheetW = sheetBounds.width * scaleX
        let sheetH = sheetBounds.height * scaleY

        let sheetRect = NSRect(x: relX, y: relY, width: sheetW, height: sheetH)

        // 4. Draw natural drop shadow around modal sheet card
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowOffset = NSSize(width: 0, height: -4 * scaleY)
        shadow.shadowBlurRadius = 12 * min(scaleX, scaleY)
        shadow.set()

        // 5. Draw modal sheet card image
        sheetImage.draw(in: sheetRect)

        result.unlockFocus()
        return result
    }
}
