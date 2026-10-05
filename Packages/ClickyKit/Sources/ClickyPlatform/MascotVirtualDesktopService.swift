import ClickyFoundation
import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit

// MARK: - MascotVirtualDesktopService
/// Layanan Virtual Desktop Space per maskot untuk Connected Apps (Mail.app, Xcode, Safari, dll).
/// Membuka ruang desktop virtual terisolasi (Display 2 / Virtual Display) yang berjalan 100%
/// di background tanpa mengintervensi atau muncul di layar fisik Mac pengguna.
@MainActor
public final class MascotVirtualDesktopService: ObservableObject {
    public static let shared = MascotVirtualDesktopService()

    @Published public private(set) var isVirtualDisplayActive: Bool = false
    @Published public private(set) var displayID: CGDirectDisplayID = 0
    @Published public private(set) var displayBounds: CGRect = .zero
    @Published public private(set) var activeSnapshot: NSImage?
    @Published public private(set) var activeSnapshotPath: String?
    @Published public private(set) var currentAppName: String?
    @Published public private(set) var currentAppPid: pid_t?
    @Published public var currentWindowBounds: CGRect? = nil
    @Published public var virtualReticle: CGPoint = CGPoint(x: 0.5, y: 0.5) // Normalized (0...1, 0...1)
    @Published public var isClickingReticle: Bool = false
    @Published public var isHumanTakeoverActive: Bool = false
    @Published public private(set) var isStreaming: Bool = false

    // Public allocation lock to prevent didChangeScreenParametersNotification from destroying BoringNotch window
    public static var isAllocatingVirtualDisplay: Bool = false
    public static var accessibilityClickExecutor: (@Sendable (_ pid: pid_t, _ screenPoint: CGPoint, _ targetHint: String) async -> Void)?

    // Private Runtime References
    private static let descClass = NSClassFromString("CGVirtualDisplayDescriptor") as? NSObject.Type
    private static let displayClass = NSClassFromString("CGVirtualDisplay") as? NSObject.Type
    private static let settingsClass = NSClassFromString("CGVirtualDisplaySettings") as? NSObject.Type
    private static let modeClass = NSClassFromString("CGVirtualDisplayMode") as? NSObject.Type

    private static var displaySerialCounter: UInt32 = 100

    private var virtualDisplayObj: AnyObject?
    private var streamingTimer: Timer?
    private var activeSlug: String = "inbox-buddy"
    private var isCapturingFallback: Bool = false

    private init() {}

    // MARK: - Virtual Display Lifecycle
    /// Menginisialisasi virtual display macOS murni (1920x1080 @ 60Hz)
    @discardableResult
    public func ensureVirtualDisplay(slug: String = "inbox-buddy") -> Bool {
        if isVirtualDisplayActive && displayID > 0 {
            return true
        }

        guard let descClass = Self.descClass,
              let displayClass = Self.displayClass,
              let settingsClass = Self.settingsClass,
              let modeClass = Self.modeClass else {
            ClickyLogger.warning("[VIRTUAL_DESKTOP]", "CGVirtualDisplay classes not found on this macOS version.")
            return false
        }

        self.activeSlug = slug
        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Creating isolated virtual display for mascot: \"\(slug)\"...")

        Self.isAllocatingVirtualDisplay = true
        defer {
            Self.isAllocatingVirtualDisplay = false
        }

        Self.displaySerialCounter &+= 1

        let desc = descClass.init()
        desc.setValue("Izanotchy VM Space", forKey: "name")
        desc.setValue(1920, forKey: "maxPixelsWide")
        desc.setValue(1080, forKey: "maxPixelsHigh")
        desc.setValue(CGSize(width: 400, height: 250), forKey: "sizeInMillimeters")
        desc.setValue(0x1234, forKey: "productID")
        desc.setValue(0x3456, forKey: "vendorID")
        desc.setValue(Self.displaySerialCounter, forKey: "serialNum")
        desc.setValue(DispatchQueue.main, forKey: "queue")

        guard let displayAlloc = displayClass.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() else {
            ClickyLogger.error("[VIRTUAL_DESKTOP]", "Failed to allocate CGVirtualDisplay.")
            return false
        }
        let initSel = NSSelectorFromString("initWithDescriptor:")
        typealias InitFn = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject?
        let initImp = displayAlloc.method(for: initSel)
        let initFn = unsafeBitCast(initImp, to: InitFn.self)
        guard let display = initFn(displayAlloc, initSel, desc) else {
            ClickyLogger.error("[VIRTUAL_DESKTOP]", "Failed to initialize CGVirtualDisplay with descriptor.")
            return false
        }

        guard let modeAlloc = modeClass.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() else {
            ClickyLogger.error("[VIRTUAL_DESKTOP]", "Failed to allocate CGVirtualDisplayMode.")
            return false
        }
        let modeInitSel = NSSelectorFromString("initWithWidth:height:refreshRate:")
        typealias ModeInitFn = @convention(c) (AnyObject, Selector, UInt, UInt, Double) -> AnyObject?
        let modeImp = modeAlloc.method(for: modeInitSel)
        let modeInit = unsafeBitCast(modeImp, to: ModeInitFn.self)
        guard let mode = modeInit(modeAlloc, modeInitSel, 1920, 1080, 60.0) else {
            ClickyLogger.error("[VIRTUAL_DESKTOP]", "Failed to initialize CGVirtualDisplayMode.")
            return false
        }

        let settings = settingsClass.init()
        settings.setValue([mode], forKey: "modes")
        settings.setValue(1, forKey: "hiDPI")

        let applySel = NSSelectorFromString("applySettings:")
        typealias ApplyFn = @convention(c) (AnyObject, Selector, AnyObject) -> Bool
        let applyImp = display.method(for: applySel)
        let apply = unsafeBitCast(applyImp, to: ApplyFn.self)
        let ok = apply(display, applySel, settings)
        guard ok else {
            ClickyLogger.error("[VIRTUAL_DESKTOP]", "Failed to apply settings to virtual display.")
            return false
        }

        let displayIDSel = NSSelectorFromString("displayID")
        typealias DisplayIDFn = @convention(c) (AnyObject, Selector) -> CGDirectDisplayID
        let idImp = display.method(for: displayIDSel)
        let getDisplayID = unsafeBitCast(idImp, to: DisplayIDFn.self)
        let dID = getDisplayID(display, displayIDSel)

        self.virtualDisplayObj = display
        self.displayID = dID
        
        let screens = NSScreen.screens
        if let vmScreen = screens.first(where: {
            $0.localizedName.contains("VM") ||
            $0.localizedName.contains("Izanotchy") ||
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == dID
        }) {
            self.displayBounds = vmScreen.frame
        } else {
            let b = CGDisplayBounds(dID)
            self.displayBounds = b.width > 0 ? b : CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        }
        self.isVirtualDisplayActive = true

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual display created successfully! ID: \(dID), Bounds: \(self.displayBounds)")
        return true
    }

    /// Menutup dan membersihkan virtual display saat selesai
    public func stopVirtualDesktop() {
        stopStreaming()

        // Zero Host Screen Intrusion: Sembunyikan aplikasi terlebih dahulu sebelum display dimatikan
        // agar macOS WindowServer tidak memindahkan jendela aplikasi ke layar utama secara paksa
        // dan memicu Split Screen / Tiling bersama Safari atau aplikasi host pengguna.
        if let appName = currentAppName {
            hideWorkflowApp(appName: appName)
        }

        virtualDisplayObj = nil
        displayID = 0
        displayBounds = .zero
        isVirtualDisplayActive = false
        activeSnapshot = nil
        activeSnapshotPath = nil
        currentAppName = nil
        currentAppPid = nil
        currentWindowBounds = nil
        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual display dismantled cleanly.")
    }

    /// Menyembunyikan aplikasi di background agar tidak menginvasi layar fisik pengguna
    public func hideWorkflowApp(appName: String) {
        let clean = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for app in NSWorkspace.shared.runningApplications {
            let name = app.localizedName?.lowercased() ?? ""
            if name == clean || name.contains(clean) {
                app.hide()
                ClickyLogger.info("[VIRTUAL_DESKTOP]", "Hid workflow application \"\(appName)\" (PID \(app.processIdentifier)) to preserve host screen isolation.")
            }
        }
    }

    // MARK: - App Assignment & Window Positioning
    /// Memastikan aplikasi berjalan dan memindahkan jendelanya ke koordinat virtual display
    @discardableResult
    public func assignAppToVirtualDesktop(appName: String, slug: String? = nil, intentType: String? = nil) -> Bool {
        if let s = slug { self.activeSlug = s }
        self.currentAppName = appName
        ensureVirtualDisplay(slug: activeSlug)

        // Pastikan aplikasi terbuka di background tanpa mencuri fokus
        let candidatesBefore = CompanionWindowStreamService.shared.findCandidateWindows(appName: appName)
        if candidatesBefore.isEmpty {
            CompanionWindowStreamService.shared.ensureWorkflowAppRunning(appName: appName)
            Thread.sleep(forTimeInterval: 0.3)
        }

        let originX = displayBounds.origin.x > 0 ? displayBounds.origin.x : 1512.0
        let originY = displayBounds.origin.y
        let targetX1 = Int(originX + 40)
        let targetY1 = Int(originY + 40)
        let targetX2 = Int(originX + 1300)
        let targetY2 = Int(originY + 840)

        // 1. Move all application windows to virtual desktop via AppleScript
        // If Mail, route the correct window (inbox viewer vs compose) to index 1 based on intent
        let scriptSource = """
        tell application "\(appName)"
            if (count of windows) > 0 then
                repeat with win in windows
                    set bounds of win to {\(targetX1), \(targetY1), \(targetX2), \(targetY2)}
                end repeat
            end if
            return (count of windows) > 0
        end tell
        """
        var appleScriptMoved = false
        if let appleScript = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            let result = appleScript.executeAndReturnError(&errorInfo)
            if errorInfo == nil && result.booleanValue {
                appleScriptMoved = true
                ClickyLogger.info("[VIRTUAL_DESKTOP]", "Moved all \"\(appName)\" windows to virtual desktop via AppleScript: {\(targetX1), \(targetY1), \(targetX2), \(targetY2)}")
            }
        }

        // 2. Resolve PID & Candidate Windows
        let candidates = CompanionWindowStreamService.shared.findCandidateWindows(appName: appName)
        if let firstCandidate = candidates.first {
            self.currentAppPid = firstCandidate.pid
            self.currentWindowBounds = firstCandidate.bounds

            // Universal WindowServer Stacking: Raise dynamically chosen candidate to index 1 by window ID
            let raiseScript = """
            tell application "\(appName)"
                try
                    set targetWins to (every window whose id is \(firstCandidate.windowId))
                    if (count of targetWins) > 0 then
                        set index of item 1 of targetWins to 1
                    end if
                end try
            end tell
            """
            if let rScript = NSAppleScript(source: raiseScript) {
                var rErr: NSDictionary?
                rScript.executeAndReturnError(&rErr)
            }

            // Fallback AXUIElement jika AppleScript tidak memindahkan
            if !appleScriptMoved {
                let appRef = AXUIElementCreateApplication(firstCandidate.pid)
                var windowsRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                   let windows = windowsRef as? [AXUIElement] {
                    for win in windows {
                        var pt = CGPoint(x: CGFloat(targetX1), y: CGFloat(targetY1))
                        if let val = AXValueCreate(.cgPoint, &pt) {
                            AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, val)
                        }
                        var sz = CGSize(width: 1260, height: 800)
                        if let val = AXValueCreate(.cgSize, &sz) {
                            AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, val)
                        }
                    }
                    ClickyLogger.info("[VIRTUAL_DESKTOP]", "Moved \"\(appName)\" (\(windows.count) windows) via AXUIElement to (\(targetX1), \(targetY1))")
                }
            }
        }

        // Ambil initial snapshot segera
        captureSnapshot()
        return true
    }

    // MARK: - Frame Capture & Streaming
    /// Menangkap snapshot frame terkini dari virtual display secara non-blocking
    @discardableResult
    public func captureSnapshot() -> NSImage? {
        guard isVirtualDisplayActive, displayID > 0 else {
            return nil
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let snapshotsDir = "\(homeDir)/.izanotchy/companions/\(activeSlug)/workspace/snapshots"
        let targetFilePath = "\(snapshotsDir)/active_frame.png"
        try? FileManager.default.createDirectory(atPath: snapshotsDir, withIntermediateDirectories: true)

        // Method 0: Use real target window frame if captured by CompanionWindowStreamService
        if let streamSnap = CompanionWindowStreamService.shared.activeSnapshot {
            self.activeSnapshot = streamSnap
            self.activeSnapshotPath = CompanionWindowStreamService.shared.activeWindowFramePath
            return streamSnap
        }

        // Method 1: Fast in-memory window capture (1-3ms, 0 process overhead)
        if let appName = currentAppName {
            let candidates = CompanionWindowStreamService.shared.findCandidateWindows(appName: appName)
            if let target = candidates.first {
                if let cgImage = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    CGWindowID(target.windowId),
                    [.boundsIgnoreFraming, .bestResolution]
                ) {
                    let img = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    self.activeSnapshotPath = targetFilePath
                    self.activeSnapshot = img

                    // Write to disk in background queue so MainActor doesn't stall on PNG compression
                    DispatchQueue.global(qos: .utility).async {
                        let rep = NSBitmapImageRep(cgImage: cgImage)
                        if let pngData = rep.representation(using: .png, properties: [:]) {
                            try? pngData.write(to: URL(fileURLWithPath: targetFilePath), options: .atomic)
                        }
                    }
                    return img
                }
            }
        }

        // Method 2: Fast in-memory display capture (1-3ms)
        if let cgImage = CGDisplayCreateImage(displayID) {
            let img = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            self.activeSnapshotPath = targetFilePath
            self.activeSnapshot = img

            DispatchQueue.global(qos: .utility).async {
                let rep = NSBitmapImageRep(cgImage: cgImage)
                if let pngData = rep.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: URL(fileURLWithPath: targetFilePath), options: .atomic)
                }
            }
            return img
        }

        // Method 3: Background screencapture fallback (Non-blocking: protects MainActor & Event Tap)
        if !isCapturingFallback {
            isCapturingFallback = true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                defer {
                    DispatchQueue.main.async {
                        self?.isCapturingFallback = false
                    }
                }
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                p.arguments = ["-x", "-D", "2", targetFilePath]
                try? p.run()
                p.waitUntilExit()

                if p.terminationStatus == 0,
                   FileManager.default.fileExists(atPath: targetFilePath),
                   let img = NSImage(contentsOfFile: targetFilePath) {
                    DispatchQueue.main.async {
                        self?.activeSnapshotPath = targetFilePath
                        self?.activeSnapshot = img
                    }
                }
            }
        }

        return self.activeSnapshot
    }

    /// Memulai streaming berkala untuk update kartu UI
    public func startStreaming(interval: TimeInterval = 0.8) {
        guard !isStreaming else { return }
        self.isStreaming = true

        captureSnapshot()

        streamingTimer?.invalidate()
        streamingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isStreaming else { return }
                self.captureSnapshot()
            }
        }
        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Started live streaming for virtual desktop (interval: \(interval)s)")
    }

    public func stopStreaming() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        isStreaming = false
    }

    // MARK: - Virtual CUA (Mascot Autonomous Actions - Universal Physical Hands)

    /// Mengonversi titik normalisasi jendela (0.0...1.0) ke koordinat display virtual nyata
    public func targetDisplayCoordinate(for normalizedPoint: CGPoint) -> CGPoint {
        let originX = displayBounds.origin.x > 0 ? displayBounds.origin.x : 1512.0
        let originY = displayBounds.origin.y
        let win = currentWindowBounds ?? CGRect(x: originX + 40, y: originY + 40, width: 1260, height: 800)

        let targetX = win.origin.x + (normalizedPoint.x * win.width)
        let targetY = win.origin.y + (normalizedPoint.y * win.height)
        return CGPoint(x: targetX, y: targetY)
    }

    /// Menggerakkan kursor maskot secara halus dengan lintasan kurva manusiawi (Human-like Kinematic Gliding)
    @MainActor
    public func glideReticleTo(target: CGPoint, duration: TimeInterval = 0.45, steps: Int = 18) async {
        let start = self.virtualReticle
        let dx = target.x - start.x
        let dy = target.y - start.y
        let distance = hypot(dx, dy)
        
        guard distance > 0.003 else {
            self.virtualReticle = target
            return
        }
        
        let stepCount = max(8, min(steps, Int(distance * 60.0) + 10))
        let stepDelay = UInt64((duration / Double(stepCount)) * 1_000_000_000)
        
        // Subtle organic curvature perpendicular to direction (mimics human wrist/finger arc on trackpad)
        let perpX = -dy * 0.08
        let perpY = dx * 0.08
        
        for i in 1...stepCount {
            let t = Double(i) / Double(stepCount)
            // Smooth ease-in-out cubic curve (acceleration then deceleration)
            let easeT = t < 0.5 ? (4.0 * t * t * t) : (1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0)
            
            // Arch parameter sin(pi * t) peaks in middle of movement
            let arch = sin(Double.pi * t)
            let currX = start.x + (dx * easeT) + (perpX * arch)
            let currY = start.y + (dy * easeT) + (perpY * arch)
            
            let currentNorm = CGPoint(
                x: min(max(currX, 0.02), 0.98),
                y: min(max(currY, 0.02), 0.98)
            )
            
            self.virtualReticle = currentNorm
            
            // Post physical mouseMoved event to target PID
            let screenPos = targetDisplayCoordinate(for: currentNorm)
            if let pid = self.currentAppPid {
                if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: screenPos, mouseButton: .left) {
                    moveEvent.postToPid(pid)
                }
            } else {
                if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: screenPos, mouseButton: .left) {
                    moveEvent.post(tap: .cgSessionEventTap)
                }
            }
            
            try? await Task.sleep(nanoseconds: stepDelay)
        }
        
        // Settle precisely at destination
        self.virtualReticle = target
        let finalPos = targetDisplayCoordinate(for: target)
        if let pid = self.currentAppPid {
            if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: finalPos, mouseButton: .left) {
                moveEvent.postToPid(pid)
            }
        } else {
            if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: finalPos, mouseButton: .left) {
                moveEvent.post(tap: .cgSessionEventTap)
            }
        }
        
        // Human dwell time before action (120ms pause)
        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    /// Menggerakkan kursor maskot secara halus ke posisi target (Stay & Ready)
    public func performCuaMove(normalizedPoint: CGPoint) {
        self.virtualReticle = normalizedPoint
        let clickPos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = self.currentAppPid

        DispatchQueue.global(qos: .userInitiated).async {
            if let pid = pid {
                if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: clickPos, mouseButton: .left) {
                    move.postToPid(pid)
                }
            } else {
                if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: clickPos, mouseButton: .left) {
                    move.post(tap: .cgSessionEventTap)
                }
            }
        }
    }

    /// Klik kiri standar virtual dari maskot (titik ternormalisasi 0.0...1.0)
    public func performCuaLeftClick(normalizedPoint: CGPoint) {
        let clickPos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = self.currentAppPid

        self.virtualReticle = normalizedPoint
        self.isClickingReticle = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isClickingReticle = false
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let src = CGEventSource(stateID: .combinedSessionState)
            if let pid = pid {
                if let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: clickPos, mouseButton: .left) {
                    down.setIntegerValueField(.mouseEventClickState, value: 1)
                    down.postToPid(pid)
                }
                usleep(25000)
                if let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: clickPos, mouseButton: .left) {
                    up.setIntegerValueField(.mouseEventClickState, value: 1)
                    up.postToPid(pid)
                }
            } else {
                if let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: clickPos, mouseButton: .left) {
                    down.setIntegerValueField(.mouseEventClickState, value: 1)
                    down.post(tap: .cgSessionEventTap)
                }
                usleep(25000)
                if let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: clickPos, mouseButton: .left) {
                    up.setIntegerValueField(.mouseEventClickState, value: 1)
                    up.post(tap: .cgSessionEventTap)
                }
            }
        }

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA Left Click at (\(Int(clickPos.x)), \(Int(clickPos.y))) [Norm: (\(String(format: "%.3f", normalizedPoint.x)), \(String(format: "%.3f", normalizedPoint.y)))]")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.captureSnapshot()
        }
    }

    /// Kompatibilitas mundur untuk pemanggil performCuaClick
    public func performCuaClick(normalizedPoint: CGPoint) {
        performCuaLeftClick(normalizedPoint: normalizedPoint)
    }

    /// Klik kanan virtual dari maskot (2-finger click di macOS)
    public func performCuaRightClick(normalizedPoint: CGPoint) {
        let clickPos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = self.currentAppPid

        self.virtualReticle = normalizedPoint
        self.isClickingReticle = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isClickingReticle = false
        }

        DispatchQueue.global(qos: .userInitiated).async {
            if let pid = pid {
                if let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: clickPos, mouseButton: .right) {
                    down.postToPid(pid)
                }
                usleep(25000)
                if let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: clickPos, mouseButton: .right) {
                    up.postToPid(pid)
                }
            } else {
                if let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: clickPos, mouseButton: .right) {
                    down.post(tap: .cgSessionEventTap)
                }
                usleep(25000)
                if let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: clickPos, mouseButton: .right) {
                    up.post(tap: .cgSessionEventTap)
                }
            }
        }

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA Right Click at (\(Int(clickPos.x)), \(Int(clickPos.y))) [Norm: (\(String(format: "%.3f", normalizedPoint.x)), \(String(format: "%.3f", normalizedPoint.y)))]")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.captureSnapshot()
        }
    }

    /// Scroll roda mouse / 2-finger swipe fisik pada posisi kursor (deltaY: positif ke atas, negatif ke bawah)
    public func performCuaScroll(normalizedPoint: CGPoint, deltaY: Int32, deltaX: Int32 = 0) {
        let scrollPos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = self.currentAppPid
        self.virtualReticle = normalizedPoint

        DispatchQueue.global(qos: .userInitiated).async {
            let src = CGEventSource(stateID: .combinedSessionState)
            let steps = 3
            let stepDeltaY = deltaY / Int32(steps)
            let stepDeltaX = deltaX / Int32(steps)

            // Post pixel-based wheel scroll events to session, HID taps, and target PID
            for _ in 0..<steps {
                if let ev = CGEvent(scrollWheelEvent2Source: src, units: .pixel, wheelCount: 2, wheel1: stepDeltaY, wheel2: stepDeltaX, wheel3: 0) {
                    ev.location = scrollPos
                    if let pid = pid {
                        ev.postToPid(pid)
                    }
                    ev.post(tap: .cgSessionEventTap)
                    ev.post(tap: .cghidEventTap)
                }
                usleep(20000)
            }
        }

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA Scroll (deltaY: \(deltaY), deltaX: \(deltaX)) at (\(Int(scrollPos.x)), \(Int(scrollPos.y))) [Target PID: \(pid ?? -1)]")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.captureSnapshot()
        }
    }

    /// Tekan dan tahan (mouse down, delay, mouse up)
    public func performCuaPressAndHold(normalizedPoint: CGPoint, durationMs: Int = 500) {
        let pos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = self.currentAppPid
        self.virtualReticle = normalizedPoint
        self.isClickingReticle = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let pid = pid {
                if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left) {
                    down.postToPid(pid)
                }
                usleep(useconds_t(durationMs * 1000))
                if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left) {
                    up.postToPid(pid)
                }
            } else {
                if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left) {
                    down.post(tap: .cgSessionEventTap)
                }
                usleep(useconds_t(durationMs * 1000))
                if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left) {
                    up.post(tap: .cgSessionEventTap)
                }
            }
            DispatchQueue.main.async {
                self?.isClickingReticle = false
            }
        }

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA Press and Hold (\(durationMs)ms) at (\(Int(pos.x)), \(Int(pos.y)))")
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(durationMs) / 1000.0 + 0.3) { [weak self] in
            self?.captureSnapshot()
        }
    }

    /// Drag & Drop virtual (geser kursor dengan mouse down dari titik awal ke titik akhir)
    public func performCuaDrag(from startNorm: CGPoint, to endNorm: CGPoint) {
        let startPos = targetDisplayCoordinate(for: startNorm)
        let endPos = targetDisplayCoordinate(for: endNorm)

        let pid = self.currentAppPid
        self.virtualReticle = startNorm
        self.isClickingReticle = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 1. Mouse down at start
            if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: startPos, mouseButton: .left) {
                if let pid = pid { down.postToPid(pid) } else { down.post(tap: .cgSessionEventTap) }
            }
            usleep(30000)

            // 2. Drag in 10 intermediate steps
            let steps = 10
            for i in 1...steps {
                let frac = CGFloat(i) / CGFloat(steps)
                let curX = startPos.x + (endPos.x - startPos.x) * frac
                let curY = startPos.y + (endPos.y - startPos.y) * frac
                let curPos = CGPoint(x: curX, y: curY)

                if let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: curPos, mouseButton: .left) {
                    if let pid = pid { drag.postToPid(pid) } else { drag.post(tap: .cgSessionEventTap) }
                }
                usleep(20000)
            }

            // 3. Mouse up at end
            if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: endPos, mouseButton: .left) {
                if let pid = pid { up.postToPid(pid) } else { up.post(tap: .cgSessionEventTap) }
            }

            DispatchQueue.main.async {
                self?.virtualReticle = endNorm
                self?.isClickingReticle = false
            }
        }

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA Dragged from \(startNorm) to \(endNorm)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.captureSnapshot()
        }
    }

    /// Mengetik teks virtual secara langsung ke jendela aplikasi di virtual desktop (non-blocking)
    public func performCuaType(text: String) {
        guard let pid = currentAppPid else {
            ClickyLogger.warning("[VIRTUAL_DESKTOP]", "Cannot type: currentAppPid is nil.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for char in text {
                let utf16 = Array(String(char).utf16)
                if let keyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                    keyEvent.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                    keyEvent.postToPid(pid)
                }
                usleep(15000)
                if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                    keyUp.postToPid(pid)
                }
                usleep(10000)
            }

            ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA typed \(text.count) characters into PID: \(pid)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.captureSnapshot()
            }
        }
    }

    // MARK: - Human-In-The-Loop Takeover
    /// Pengguna mengklik langsung pada viewport kanvas (Human Takeover)
    /// Beroperasi tanpa menyentuh virtualReticle AI agar kursor fisik pengguna berdaulat 100%.
    public func handleUserDirectClick(normalizedPoint: CGPoint) {
        let clickPos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = self.currentAppPid

        DispatchQueue.global(qos: .userInitiated).async {
            let src = CGEventSource(stateID: .combinedSessionState)
            if let pid = pid {
                if let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: clickPos, mouseButton: .left) {
                    down.setIntegerValueField(.mouseEventClickState, value: 1)
                    down.postToPid(pid)
                }
                usleep(25000)
                if let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: clickPos, mouseButton: .left) {
                    up.setIntegerValueField(.mouseEventClickState, value: 1)
                    up.postToPid(pid)
                }
            } else {
                if let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: clickPos, mouseButton: .left) {
                    down.setIntegerValueField(.mouseEventClickState, value: 1)
                    down.post(tap: .cgSessionEventTap)
                }
                usleep(25000)
                if let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: clickPos, mouseButton: .left) {
                    up.setIntegerValueField(.mouseEventClickState, value: 1)
                    up.post(tap: .cgSessionEventTap)
                }
            }
        }

        // Also trigger background accessibility click for direct user takeover click
        if let pid = pid {
            Task {
                if let executor = Self.accessibilityClickExecutor {
                    await executor(pid, clickPos, "")
                }
            }
        }

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Direct Human Takeover Click at (\(Int(clickPos.x)), \(Int(clickPos.y))) [Norm: (\(String(format: "%.3f", normalizedPoint.x)), \(String(format: "%.3f", normalizedPoint.y)))]")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.captureSnapshot()
        }
    }

    /// Pengguna mengklik langsung pada viewport kanvas di chat card / modal
    public func handleUserViewClick(viewPoint: CGPoint, viewSize: CGSize) {
        guard viewSize.width > 0 && viewSize.height > 0 else { return }

        let normX = max(0.0, min(1.0, viewPoint.x / viewSize.width))
        let normY = max(0.0, min(1.0, viewPoint.y / viewSize.height))

        handleUserDirectClick(normalizedPoint: CGPoint(x: normX, y: normY))
    }

    /// Pengguna mengetik langsung pada viewport kanvas
    public func handleUserViewKey(character: String, keyCode: UInt16) {
        if !character.isEmpty {
            performCuaType(text: character)
        } else if let pid = currentAppPid {
            if let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true) {
                down.postToPid(pid)
            }
            usleep(15000)
            if let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: false) {
                up.postToPid(pid)
            }
        }
    }
}
