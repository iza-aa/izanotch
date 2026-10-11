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
    @Published public var isReticleVisible: Bool = false
    @Published public var isClickingReticle: Bool = false
    @Published public var isHumanTakeoverActive: Bool = false
    @Published public private(set) var isStreaming: Bool = false

    // Public allocation lock to prevent didChangeScreenParametersNotification from destroying BoringNotch window
    public static var isAllocatingVirtualDisplay: Bool = false

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
        
        // Quartz WindowServer Coordinate System:
        // Native window bounds in AppleScript and WindowServer require CGDisplayBounds (Y=0 is top-left).
        // NSScreen.frame uses Cocoa coordinates (Y=0 at bottom-left), which produces negative Y values (-98.0)
        // that AppleScript rejects and WindowServer clamps back to the primary host display!
        let qBounds = CGDisplayBounds(dID)
        let validQBounds = qBounds.width > 0 ? qBounds : CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        self.displayBounds = CGRect(
            x: validQBounds.origin.x > 0 ? validQBounds.origin.x : 1512.0,
            y: max(validQBounds.origin.y, 0.0),
            width: validQBounds.width,
            height: validQBounds.height
        )
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
        let originY = max(displayBounds.origin.y, 0.0)
        let dW = displayBounds.width > 0 ? displayBounds.width : 1920.0
        let dH = displayBounds.height > 0 ? displayBounds.height : 1080.0
        let targetX1 = Int(originX + 20)
        let targetY1 = max(Int(originY + 20), 20)
        let targetX2 = Int(originX + dW - 20)
        let targetY2 = max(Int(originY + dH - 20), Int(dH - 20))

        // 1. Hide-First Rule: Hide workflow app via NSWorkspace PID immediately so windows NEVER show on host screen!
        var targetAppRef: NSRunningApplication?
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            let name = $0.localizedName?.lowercased() ?? ""
            let clean = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return name == clean || name.hasPrefix(clean) || name.contains(clean)
        }) {
            targetAppRef = app
            app.hide()
            ClickyLogger.info("[VIRTUAL_DESKTOP]", "Hide-First: Hid \"\(appName)\" (PID \(app.processIdentifier)) before window relocation.")
        }

        // 2. Resolve PID & Candidate Windows
        let candidates = CompanionWindowStreamService.shared.findCandidateWindows(appName: appName)
        let effectivePid = candidates.first?.pid ?? targetAppRef?.processIdentifier ?? resolveEffectivePid()

        if let pid = effectivePid, pid > 0 {
            self.currentAppPid = pid
            if let firstCandidate = candidates.first {
                self.currentWindowBounds = firstCandidate.bounds
            }

            // Move all windows of target application to Virtual Display via native AXUIElement IPC (Zero AppleScript)
            let appRef = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appRef, 0.25)

            var windowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement] {
                for win in windows {
                    var pt = CGPoint(x: CGFloat(targetX1), y: CGFloat(targetY1))
                    if let val = AXValueCreate(.cgPoint, &pt) {
                        AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, val)
                    }
                    let winW = CGFloat(max(Int(dW - 40), 100))
                    let winH = CGFloat(max(Int(dH - 40), 100))
                    var sz = CGSize(width: winW, height: winH)
                    if let val = AXValueCreate(.cgSize, &sz) {
                        AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, val)
                    }
                }
                ClickyLogger.info("[VIRTUAL_DESKTOP]", "Moved \"\(appName)\" (\(windows.count) windows) via native AXUIElement IPC to (\(targetX1), \(targetY1))")

                if let topWin = windows.first {
                    AXUIElementSetAttributeValue(topWin, kAXMainAttribute as CFString, kCFBooleanTrue)
                    AXUIElementPerformAction(topWin, kAXRaiseAction as CFString)
                    AXUIElementSetAttributeValue(topWin, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                }
            }
        }

        // 3. Complete Cycle: Unhide via NSRunningApplication.unhide (WITHOUT activate - does NOT steal focus, but makes windows visible to Virtual Display camera!)
        if let app = targetAppRef {
            app.unhide()
            ClickyLogger.info("[VIRTUAL_DESKTOP]", "Hide-First Complete Cycle: Unhid \"\(appName)\" (PID \(app.processIdentifier)) onto Virtual Display without activation.")
        }

        // Ambil initial snapshot segera
        captureSnapshot()
        return true
    }

    /// Scans and relocates any newly created or displaced windows of appName onto the Virtual Display.
    /// Zero Host Screen Intrusion: Guarantees that windows spawned mid-task (e.g. "New Message" compose sheets)
    /// are immediately moved away from the host desktop into the isolated virtual workspace.
    public func relocateAppWindowsToVirtualDesktop(appName: String) {
        guard isVirtualDisplayActive, displayID > 0 else { return }

        let originX = displayBounds.origin.x > 0 ? displayBounds.origin.x : 1512.0
        let originY = max(displayBounds.origin.y, 0.0)
        let dW = displayBounds.width > 0 ? displayBounds.width : 1920.0
        let dH = displayBounds.height > 0 ? displayBounds.height : 1080.0
        let targetX1 = Int(originX + 20)
        let targetY1 = max(Int(originY + 20), 20)
        // Move all application windows whose origin is on the host screen (x < originX - 100) to virtual display
        // Native AXUIElement IPC - Zero AppleScript, Zero Activation, Zero Split Screen
        if let pid = currentAppPid, pid > 0 {
            let appRef = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appRef, 0.20)
            var windowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement] {
                for win in windows {
                    var posRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
                       let val = posRef {
                        var pt = CGPoint.zero
                        if AXValueGetValue((val as! AXValue), .cgPoint, &pt), pt.x < (originX - 100) {
                            var newPt = CGPoint(x: CGFloat(targetX1), y: CGFloat(targetY1))
                            if let newPosVal = AXValueCreate(.cgPoint, &newPt) {
                                AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, newPosVal)
                            }
                            let winW = CGFloat(max(Int(dW - 40), 100))
                            let winH = CGFloat(max(Int(dH - 40), 100))
                            var sz = CGSize(width: winW, height: winH)
                            if let newSzVal = AXValueCreate(.cgSize, &sz) {
                                AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, newSzVal)
                            }
                            ClickyLogger.info("[VIRTUAL_DESKTOP]", "Relocated host-stranded window of PID \(pid) to (\(targetX1), \(targetY1)) via AX")
                        }
                    }
                }
            }
        }
    }

    /// Startup Orphan Sweep (Invariant 39): Sweeps any workflow app windows left stranded on the host screen
    /// due to previous app crashes or kills while on virtual desktop. Hides them immediately via NSWorkspace PID without activation.
    public func sweepOrphanWindowsOnStartup() {
        let workflowAppNames = ["Mail", "Safari", "Notes", "Terminal"]
        let runningApps = NSWorkspace.shared.runningApplications

        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for win in windowList {
                let owner = win[kCGWindowOwnerName as String] as? String ?? ""
                let boundsDict = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
                let x = boundsDict["X"] as? CGFloat ?? 0
                let w = boundsDict["Width"] as? CGFloat ?? 0

                // If a workflow app has windows on host screen (x < 1500)
                if x < 1500 && w > 200, workflowAppNames.contains(where: { owner.localizedCaseInsensitiveContains($0) }) {
                    if let app = runningApps.first(where: { $0.localizedName?.localizedCaseInsensitiveContains(owner) == true }) {
                        app.hide()
                        ClickyLogger.info("[ORPHAN_SWEEP]", "Swept and hid orphaned window '\(win[kCGWindowName as String] ?? "")' for app '\(owner)' on host display.")
                    }
                }
            }
        }
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

        // Method 1: Fast in-memory window capture (1-3ms, 0 process overhead) with screencapture fallback
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

        // All captures handled cleanly via in-memory Quartz (CGWindowListCreateImage / CGDisplayCreateImage)

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
        let dW = displayBounds.width > 0 ? displayBounds.width : 1920.0
        let dH = displayBounds.height > 0 ? displayBounds.height : 1080.0
        let win = currentWindowBounds ?? CGRect(x: originX + 20, y: originY + 20, width: dW - 40, height: dH - 40)
        let targetX = win.origin.x + (normalizedPoint.x * win.width)
        let targetY = win.origin.y + (normalizedPoint.y * win.height)
        return CGPoint(x: targetX, y: targetY)
    }

    /// Resolves the valid PID for workflow app, synchronizing currentAppPid thread-safely.
    /// Zero Host Screen Intrusion: Never relies on ambient global desktop focus.
    public func resolveEffectivePid(explicitPid: pid_t? = nil) -> pid_t? {
        if let explicit = explicitPid, explicit > 0 {
            self.currentAppPid = explicit
            return explicit
        }
        if let cur = currentAppPid, cur > 0 {
            return cur
        }
        let clean = (currentAppName ?? "Mail").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            let name = $0.localizedName?.lowercased() ?? ""
            return name == clean || name.hasPrefix(clean) || name.contains(clean)
        }) {
            let pid = app.processIdentifier
            self.currentAppPid = pid
            return pid
        }
        return nil
    }

    /// Menggerakkan kursor maskot secara halus dengan lintasan kurva manusiawi (Human-like Kinematic Gliding)
    /// Beroperasi secara murni pada layer visual kanvas SwiftUI tanpa menyentuh mouse fisik host (Zero Host Screen Intrusion).
    @MainActor
    public func glideReticleTo(target: CGPoint, duration: TimeInterval = 0.45, steps: Int = 18) async {
        self.isReticleVisible = true
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
            try? await Task.sleep(nanoseconds: stepDelay)
        }
        
        // Settle precisely at destination
        self.virtualReticle = target
        
        // Human dwell time before action (120ms pause)
        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    /// Menggerakkan kursor maskot secara halus ke posisi target (Stay & Ready)
    public func performCuaMove(normalizedPoint: CGPoint, pid explicitPid: pid_t? = nil) {
        self.virtualReticle = normalizedPoint
        self.isReticleVisible = true
        let clickPos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = resolveEffectivePid(explicitPid: explicitPid)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            if !self.isClickingReticle {
                self.isReticleVisible = false
            }
        }

        if let pid = pid, pid > 0 {
            DispatchQueue.global(qos: .userInitiated).async {
                if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: clickPos, mouseButton: .left) {
                    move.postToPid(pid)
                }
            }
        }
    }

    /// Klik kiri standar virtual dari maskot (titik ternormalisasi 0.0...1.0)
    public func performCuaLeftClick(normalizedPoint: CGPoint, pid explicitPid: pid_t? = nil) {
        let clickPos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = resolveEffectivePid(explicitPid: explicitPid)

        self.virtualReticle = normalizedPoint
        self.isReticleVisible = true
        self.isClickingReticle = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isClickingReticle = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if !self.isClickingReticle {
                self.isReticleVisible = false
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let src = CGEventSource(stateID: .combinedSessionState)
            if let pid = pid, pid > 0 {
                if let move = CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: clickPos, mouseButton: .left) {
                    move.postToPid(pid)
                }
                usleep(20000)
                if let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: clickPos, mouseButton: .left) {
                    down.setIntegerValueField(.mouseEventClickState, value: 1)
                    down.postToPid(pid)
                }
                usleep(65000)
                if let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: clickPos, mouseButton: .left) {
                    up.setIntegerValueField(.mouseEventClickState, value: 1)
                    up.postToPid(pid)
                }
                // Dual-Layer IPC Trigger: Direct Accessibility action execution on buttons
                let appRef = AXUIElementCreateApplication(pid)
                var hitElemRef: AXUIElement?
                if AXUIElementCopyElementAtPosition(appRef, Float(clickPos.x), Float(clickPos.y), &hitElemRef) == .success,
                   let hitElem = hitElemRef {
                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(hitElem, kAXRoleAttribute as CFString, &roleRef)
                    let role = (roleRef as? String) ?? ""
                    if role == "AXButton" || role == "AXPopUpButton" || role == "AXRadioButton" || role == "AXCheckBox" || role == "AXMenuItem" {
                        let pressRes = AXUIElementPerformAction(hitElem, kAXPressAction as CFString)
                        if pressRes == .success {
                            ClickyLogger.info("[VIRTUAL_DESKTOP]", "Triggered AXPressAction successfully via Accessibility IPC on \(role) at (\(Int(clickPos.x)), \(Int(clickPos.y)))")
                        }
                    }
                }
            } else {
                ClickyLogger.warning("[VIRTUAL_DESKTOP]", "performCuaLeftClick: target PID is nil, skipping physical click to protect host cursor.")
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
    public func performCuaRightClick(normalizedPoint: CGPoint, pid explicitPid: pid_t? = nil) {
        let clickPos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = resolveEffectivePid(explicitPid: explicitPid)

        self.virtualReticle = normalizedPoint
        self.isReticleVisible = true
        self.isClickingReticle = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isClickingReticle = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if !self.isClickingReticle {
                self.isReticleVisible = false
            }
        }

        if let pid = pid, pid > 0 {
            DispatchQueue.global(qos: .userInitiated).async {
                if let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: clickPos, mouseButton: .right) {
                    down.postToPid(pid)
                }
                usleep(25000)
                if let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: clickPos, mouseButton: .right) {
                    up.postToPid(pid)
                }
            }
        } else {
            ClickyLogger.warning("[VIRTUAL_DESKTOP]", "performCuaRightClick: target PID is nil, skipping physical click to protect host cursor.")
        }

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA Right Click at (\(Int(clickPos.x)), \(Int(clickPos.y))) [Norm: (\(String(format: "%.3f", normalizedPoint.x)), \(String(format: "%.3f", normalizedPoint.y)))]")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.captureSnapshot()
        }
    }

    /// Menyembunyikan kursor efemeral setelah aksi selesai
    public func hideReticle(afterDwell: Bool = true) {
        if afterDwell {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isReticleVisible = false
            }
        } else {
            self.isReticleVisible = false
        }
    }

    /// Scroll roda mouse / 2-finger swipe fisik pada posisi kursor (deltaY: positif ke atas, negatif ke bawah)
    public func performCuaScroll(normalizedPoint: CGPoint, deltaY: Int32, deltaX: Int32 = 0, pid explicitPid: pid_t? = nil) {
        let scrollPos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = resolveEffectivePid(explicitPid: explicitPid)
        self.virtualReticle = normalizedPoint

        if let pid = pid, pid > 0 {
            DispatchQueue.global(qos: .userInitiated).async {
                let src = CGEventSource(stateID: .combinedSessionState)
                let steps = 3
                let stepDeltaY = deltaY / Int32(steps)
                let stepDeltaX = deltaX / Int32(steps)

                for _ in 0..<steps {
                    if let ev = CGEvent(scrollWheelEvent2Source: src, units: .pixel, wheelCount: 2, wheel1: stepDeltaY, wheel2: stepDeltaX, wheel3: 0) {
                        ev.location = scrollPos
                        ev.postToPid(pid)
                    }
                    usleep(20000)
                }
            }
        } else {
            ClickyLogger.warning("[VIRTUAL_DESKTOP]", "performCuaScroll: target PID is nil, skipping physical scroll to protect host screen.")
        }

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA Scroll (deltaY: \(deltaY), deltaX: \(deltaX)) at (\(Int(scrollPos.x)), \(Int(scrollPos.y))) [Target PID: \(pid ?? -1)]")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.captureSnapshot()
        }
    }

    /// Tekan dan tahan (mouse down, delay, mouse up)
    public func performCuaPressAndHold(normalizedPoint: CGPoint, durationMs: Int = 500, pid explicitPid: pid_t? = nil) {
        let pos = targetDisplayCoordinate(for: normalizedPoint)
        let pid = resolveEffectivePid(explicitPid: explicitPid)
        self.virtualReticle = normalizedPoint
        self.isClickingReticle = true

        if let pid = pid, pid > 0 {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left) {
                    down.postToPid(pid)
                }
                usleep(useconds_t(durationMs * 1000))
                if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left) {
                    up.postToPid(pid)
                }
                DispatchQueue.main.async {
                    self?.isClickingReticle = false
                }
            }
        } else {
            ClickyLogger.warning("[VIRTUAL_DESKTOP]", "performCuaPressAndHold: target PID is nil, skipping.")
        }

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA Press and Hold (\(durationMs)ms) at (\(Int(pos.x)), \(Int(pos.y)))")
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(durationMs) / 1000.0 + 0.3) { [weak self] in
            self?.captureSnapshot()
        }
    }

    /// Drag & Drop virtual (geser kursor dengan mouse down dari titik awal ke titik akhir)
    public func performCuaDrag(from startNorm: CGPoint, to endNorm: CGPoint, pid explicitPid: pid_t? = nil) {
        let startPos = targetDisplayCoordinate(for: startNorm)
        let endPos = targetDisplayCoordinate(for: endNorm)

        let pid = resolveEffectivePid(explicitPid: explicitPid)
        self.virtualReticle = startNorm
        self.isClickingReticle = true

        if let pid = pid, pid > 0 {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: startPos, mouseButton: .left) {
                    down.postToPid(pid)
                }
                usleep(30000)

                let steps = 10
                for i in 1...steps {
                    let frac = CGFloat(i) / CGFloat(steps)
                    let curX = startPos.x + (endPos.x - startPos.x) * frac
                    let curY = startPos.y + (endPos.y - startPos.y) * frac
                    let curPos = CGPoint(x: curX, y: curY)

                    if let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: curPos, mouseButton: .left) {
                        drag.postToPid(pid)
                    }
                    usleep(20000)
                }

                if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: endPos, mouseButton: .left) {
                    up.postToPid(pid)
                }

                DispatchQueue.main.async {
                    self?.virtualReticle = endNorm
                    self?.isClickingReticle = false
                }
            }
        } else {
            ClickyLogger.warning("[VIRTUAL_DESKTOP]", "performCuaDrag: target PID is nil, skipping.")
        }

        ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA Dragged from \(startNorm) to \(endNorm)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.captureSnapshot()
        }
    }

    /// Mengetik teks virtual secara langsung ke jendela aplikasi di virtual desktop (awaited hingga seluruh karakter selesai)
    public func performCuaType(text: String, pid explicitPid: pid_t? = nil) async {
        guard let pid = resolveEffectivePid(explicitPid: explicitPid) else {
            ClickyLogger.warning("[VIRTUAL_DESKTOP]", "Cannot type: process not found for \(currentAppName ?? "unknown app").")
            return
        }

        await withCheckedContinuation { continuation in
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
                    continuation.resume()
                }
            }
        }
    }

    /// Mengirim penekanan tombol keyboard virtual (seperti Return 0x24 atau Tab 0x30) ke PID target
    public func performCuaKey(keyCode: CGKeyCode, pid explicitPid: pid_t? = nil) {
        guard let pid = resolveEffectivePid(explicitPid: explicitPid) else {
            ClickyLogger.warning("[VIRTUAL_DESKTOP]", "Cannot send key: process not found for \(currentAppName ?? "unknown app").")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
                down.postToPid(pid)
            }
            usleep(25000)
            if let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                up.postToPid(pid)
            }
            ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA posted keyCode 0x\(String(keyCode, radix: 16)) to PID: \(pid)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.captureSnapshot()
            }
        }
    }

    /// Meng-commit chip token aktif pada token field (AXTokenField recipients / tags) via Return
    public func commitTokenField(pid explicitPid: pid_t? = nil) {
        performCuaKey(keyCode: 0x24, pid: explicitPid)
    }

    /// Memilih seluruh teks pada input field aktif (⌘A) dan opsional menghapusnya via Backspace (0x33)
    public func performCuaSelectAll(clearAfter: Bool = false, pid explicitPid: pid_t? = nil) {
        guard let pid = resolveEffectivePid(explicitPid: explicitPid) else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // KeyCode 0x00 is 'A' (kVK_ANSI_A) with Command flag (.maskCommand)
            if let down = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) {
                down.flags = .maskCommand
                down.postToPid(pid)
            }
            usleep(25000)
            if let up = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: false) {
                up.flags = .maskCommand
                up.postToPid(pid)
            }
            usleep(25000)
            if clearAfter {
                // KeyCode 0x33 is Backspace / Delete (kVK_Delete)
                if let delDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true) {
                    delDown.postToPid(pid)
                }
                usleep(20000)
                if let delUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: false) {
                    delUp.postToPid(pid)
                }
            }
            ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA performed Select All (⌘A)\(clearAfter ? " + Backspace" : "") on PID: \(pid)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.captureSnapshot()
            }
        }
    }

    /// Mengirim kombinasi tombol Command + KeyCode ke PID target (misal: ⌘D untuk Don't Save atau ⌘W untuk Close)
    public func performCuaKeyWithCommand(keyCode: CGKeyCode, pid explicitPid: pid_t? = nil) {
        guard let pid = resolveEffectivePid(explicitPid: explicitPid) else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
                down.flags = .maskCommand
                down.postToPid(pid)
            }
            usleep(25000)
            if let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                up.flags = .maskCommand
                up.postToPid(pid)
            }
            ClickyLogger.info("[VIRTUAL_DESKTOP]", "Virtual CUA posted Command+keyCode 0x\(String(keyCode, radix: 16)) to PID: \(pid)")
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
        let pid = resolveEffectivePid()

        DispatchQueue.global(qos: .userInitiated).async {
            let src = CGEventSource(stateID: .combinedSessionState)
            if let pid = pid, pid > 0 {
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
                ClickyLogger.warning("[VIRTUAL_DESKTOP]", "handleUserDirectClick: target PID is nil, skipping to protect host cursor.")
            }
        }

        // Also trigger background accessibility click for direct user takeover click
        if let pid = pid, pid > 0 {
            Task {
                await CUAClickActionTool.executeBackgroundAccessibilityClick(pid: pid, screenPoint: clickPos, targetHint: "")
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
            Task { [weak self] in
                await self?.performCuaType(text: character)
            }
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
