//
//  IzaViewModel.swift
//  izaNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Combine
import Defaults
import SwiftUI

class IzaViewModel: NSObject, ObservableObject {
    @ObservedObject var coordinator = IzaViewCoordinator.shared
    @ObservedObject var detector = FullscreenMediaDetector.shared

    let animationLibrary: IzaAnimations = .init()
    let animation: Animation?

    @Published var contentType: ContentType = .normal
    @Published private(set) var notchState: NotchState = .closed

    @Published var dragDetectorTargeting: Bool = false
    @Published var generalDropTargeting: Bool = false
    @Published var dropZoneTargeting: Bool = false
    @Published var dropEvent: Bool = false
    @Published var anyDropZoneTargeting: Bool = false
    var cancellables: Set<AnyCancellable> = []
    
    @Published var hideOnClosed: Bool = true

    @Published var edgeAutoOpenActive: Bool = false
    @Published var isHoveringCalendar: Bool = false
    @Published var isBatteryPopoverActive: Bool = false
    @Published var isClickyPopoverActive: Bool = false

    @Published var screenUUID: String?

    @Published var notchSize: CGSize = getClosedNotchSize()
    @Published var closedNotchSize: CGSize = getClosedNotchSize()
    
    let webcamManager = WebcamManager.shared
    @Published var isCameraExpanded: Bool = false
    @Published var isRequestingAuthorization: Bool = false
    
    deinit {
        destroy()
    }

    func destroy() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    init(screenUUID: String? = nil) {
        animation = animationLibrary.animation

        super.init()
        
        self.screenUUID = screenUUID
        notchSize = getClosedNotchSize(screenUUID: screenUUID)
        closedNotchSize = notchSize

        Publishers.CombineLatest3($dropZoneTargeting, $dragDetectorTargeting, $generalDropTargeting)
            .map { shelf, drag, general in
                shelf || drag || general
            }
            .assign(to: \.anyDropZoneTargeting, on: self)
            .store(in: &cancellables)
        
        setupDetectorObserver()
    }
    
    private func setupDetectorObserver() {
        // Publisher for the user’s fullscreen detection setting
        let enabledPublisher = Defaults
            .publisher(.hideNotchOption)
            .map(\.newValue)
            .map { $0 != .never }
            .removeDuplicates()

        // Publisher for the current screen UUID (non-nil, distinct)
        let screenPublisher = $screenUUID
            .compactMap { $0 }
            .removeDuplicates()

        // Publisher for fullscreen status dictionary
        let fullscreenStatusPublisher = detector.$fullscreenStatus
            .removeDuplicates()

        // Combine all three: screen UUID, fullscreen status, and enabled setting
        Publishers.CombineLatest3(screenPublisher, fullscreenStatusPublisher, enabledPublisher)
            .map { screenUUID, fullscreenStatus, enabled in
                let isFullscreen = fullscreenStatus[screenUUID] ?? false
                return enabled && isFullscreen
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldHide in
                withAnimation(.smooth) {
                    self?.hideOnClosed = shouldHide
                }
            }
            .store(in: &cancellables)
    }

    // Computed property for effective notch height
    var effectiveClosedNotchHeight: CGFloat {
        let currentScreen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) }
        let noNotchAndFullscreen = hideOnClosed && (currentScreen?.safeAreaInsets.top ?? 0 <= 0 || currentScreen == nil)
        if noNotchAndFullscreen { return 0 }
        if IzaTimerManager.shared.isRunning && notchState == .closed {
            return closedNotchSize.height + 34
        }
        return closedNotchSize.height
    }

    var chinHeight: CGFloat {
        if !Defaults[.hideTitleBar] {
            return 0
        }

        guard let currentScreen = screenUUID.flatMap({ NSScreen.screen(withUUID: $0) }) else {
            return 0
        }

        if notchState == .open { return 0 }

        let menuBarHeight = currentScreen.frame.maxY - currentScreen.visibleFrame.maxY
        let currentHeight = effectiveClosedNotchHeight

        if currentHeight == 0 { return 0 }

        return max(0, menuBarHeight - currentHeight)
    }

    var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = closedNotchSize.width

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && notchState == .closed && Defaults[.showPowerStatusNotifications]
        {
            chinWidth = 640
        } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && notchState == .closed && (MusicManager.shared.isPlaying || !MusicManager.shared.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled && !hideOnClosed
        {
            chinWidth += (2 * max(0, closedNotchSize.height - 12) + 20)
        } else if !coordinator.expandingView.show && notchState == .closed
            && (!MusicManager.shared.isPlaying && MusicManager.shared.isPlayerIdle) && Defaults[.showNotHumanFace]
            && !hideOnClosed
        {
            chinWidth += (2 * max(0, closedNotchSize.height - 12) + 20)
        } else if IzaTimerManager.shared.isRunning && notchState == .closed && !hideOnClosed {
            chinWidth += (2 * max(0, closedNotchSize.height - 12) + 20)
        }

        return chinWidth
    }

    /// The exact interactive bounding box of the notch in window local coordinates (AppKit origin at bottom-left).
    /// Window frame is 640x210. When closed, only this compact rectangle intercepts mouse clicks/hovers.
    var activeClosedNotchRect: NSRect {
        let effectiveWidth = max(computedChinWidth, closedNotchSize.width) + 24.0
        let effectiveHeight = max(32.0, effectiveClosedNotchHeight + chinHeight) + 6.0
        let minX = (windowSize.width - effectiveWidth) / 2.0
        let minY = windowSize.height - effectiveHeight
        // Include +4.0 height buffer to ensure top-most edge pixels (y = windowSize.height) are always contained
        return NSRect(x: minX, y: minY - 2.0, width: effectiveWidth, height: effectiveHeight + 6.0)
    }

    func toggleCameraPreview() {
        if isRequestingAuthorization {
            return
        }

        switch webcamManager.authorizationStatus {
        case .authorized:
            if webcamManager.isSessionRunning {
                webcamManager.stopSession()
                isCameraExpanded = false
            } else if webcamManager.cameraAvailable {
                webcamManager.startSession()
                isCameraExpanded = true
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)

                let alert = NSAlert()
                alert.messageText = "Camera Access Required"
                alert.informativeText = "Please allow camera access in System Settings."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }

                NSApp.setActivationPolicy(.accessory)
                NSApp.deactivate()
            }

        case .notDetermined:
            isRequestingAuthorization = true
            webcamManager.checkAndRequestVideoAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isRequestingAuthorization = false
            }

        default:
            break
        }
    }
    
    func isMouseHovering(position: NSPoint = NSEvent.mouseLocation) -> Bool {
        let screenFrame = getScreenFrame(screenUUID)
        if let frame = screenFrame {
            
            let baseY = frame.maxY - notchSize.height
            let baseX = frame.midX - notchSize.width / 2
            
            return position.y >= baseY && position.x >= baseX && position.x <= baseX + notchSize.width
        }
        
        return false
    }

    func open() {
        self.notchSize = openNotchSize
        self.notchState = .open
        
        // Force music information update when notch is opened
        MusicManager.shared.forceUpdate()
    }

    func close() {
        // Do not close while a share picker or sharing service is active
        if SharingStateManager.shared.preventNotchClose {
            return
        }
        if isCameraExpanded {
            webcamManager.stopSession()
            isCameraExpanded = false
        }
        self.notchSize = getClosedNotchSize(screenUUID: self.screenUUID)
        self.closedNotchSize = self.notchSize
        self.notchState = .closed
        self.isBatteryPopoverActive = false
        self.isClickyPopoverActive = false
        self.coordinator.sneakPeek.show = false
        // Set the current view to shelf if it contains files and the user enables openShelfByDefault
        if !ShelfStateViewModel.shared.isEmpty && Defaults[.openShelfByDefault] {
            coordinator.currentView = .shelf
        }
    }

    func closeHello() {
        Task { @MainActor in
            withAnimation(animationLibrary.animation) {
                coordinator.helloAnimationRunning = false
                close()
            }
        }
    }
}

// MARK: - IzaTimerManager (Global Persistent Countdown Engine)

@MainActor
final class IzaTimerManager: ObservableObject {
    static let shared = IzaTimerManager()

    @Published var hours: Int = 0
    @Published var minutes: Int = 1
    @Published var seconds: Int = 0

    @Published var remainingSeconds: Int = 60
    @Published var totalDuration: Int = 60

    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var isCompleted: Bool = false

    private var targetEndTime: Date?
    private var pausedRemainingSeconds: Int = 0
    private var timerCancellable: AnyCancellable?

    private init() {
        // Start background ticker in common mode so it runs without pausing during tracking/gestures
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCountdown()
            }
    }

    var currentConfiguredDuration: Int {
        let total = (hours * 3600) + (minutes * 60) + seconds
        return total > 0 ? total : 60
    }

    func start(hours: Int, minutes: Int, seconds: Int) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        let total = (hours * 3600) + (minutes * 60) + seconds
        let duration = total > 0 ? total : 60
        self.totalDuration = duration
        self.remainingSeconds = duration
        self.targetEndTime = Date().addingTimeInterval(TimeInterval(duration))
        self.isPaused = false
        self.isCompleted = false
        self.isRunning = true
    }

    func start() {
        start(hours: hours, minutes: minutes, seconds: seconds)
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        pausedRemainingSeconds = remainingSeconds
        targetEndTime = nil
    }

    func resume() {
        guard isRunning, isPaused else { return }
        isPaused = false
        targetEndTime = Date().addingTimeInterval(TimeInterval(pausedRemainingSeconds))
    }

    func togglePauseResume() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    func stop() {
        isRunning = false
        isPaused = false
        targetEndTime = nil
        remainingSeconds = currentConfiguredDuration
        isCompleted = false
    }

    func setPreset(hours: Int, minutes: Int, seconds: Int) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        let total = (hours * 3600) + (minutes * 60) + seconds
        self.totalDuration = total > 0 ? total : 60
        self.remainingSeconds = self.totalDuration
        self.isRunning = false
        self.isPaused = false
        self.isCompleted = false
        self.targetEndTime = nil
    }

    func isMatchingPreset(h: Int, m: Int, s: Int) -> Bool {
        return hours == h && minutes == m && seconds == s
    }

    func formatCountdown(_ customSeconds: Int? = nil) -> String {
        let secs = customSeconds ?? remainingSeconds
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private func updateCountdown() {
        guard isRunning, !isPaused, let targetEndTime = targetEndTime else { return }
        let diff = Int(ceil(targetEndTime.timeIntervalSince(Date())))
        if diff > 0 {
            self.remainingSeconds = diff
        } else {
            self.remainingSeconds = 0
            self.isRunning = false
            self.isPaused = false
            self.isCompleted = true
            self.targetEndTime = nil
        }
    }
}
