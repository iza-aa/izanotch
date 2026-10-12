//
//  izaNotchApp.swift
//  izaNotchApp
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//

import AVFoundation
import Combine
import Defaults
import KeyboardShortcuts
import Sparkle
import SwiftUI

@main
struct DynamicNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Default(.menubarIcon) var showMenuBarIcon
    @Environment(\.openWindow) var openWindow

    let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        // Initialize the settings window controller with the updater controller
        SettingsWindowController.shared.setUpdaterController(updaterController)
    }

    var body: some Scene {
        MenuBarExtra("izanotchy", systemImage: "sparkle", isInserted: $showMenuBarIcon) {
            Button("Settings") {
                DispatchQueue.main.async {
                    SettingsWindowController.shared.showWindow()
                }
            }
            .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            CheckForUpdatesView(updater: updaterController.updater)
            Button(CompanionManager.shared.isClickyCursorEnabled ? "Hide Clicky Cursor" : "Show Clicky Cursor") {
                CompanionManager.shared.setClickyCursorEnabled(!CompanionManager.shared.isClickyCursorEnabled)
            }
            Button("IzaClicky HomeSpace") {
                CompanionManager.shared.toggleHomeSpace()
            }
            .keyboardShortcut(KeyEquivalent("a"), modifiers: [.command, .control])
            Button("Toggle Companion Rail") {
                FloatingCompanionRailWindowManager.shared.toggleRail()
            }
            .keyboardShortcut(KeyEquivalent("r"), modifiers: [.command, .control])
            Button("Permission Setup...") {
                _ = WindowPositionManager.requestAccessibilityPermission()
                WindowPositionManager.openAccessibilitySettings()
            }
            Button("Toggle Task HUD") {
                CompanionManager.shared.toggleHUD()
            }
            Divider()
            Button("Restart Izanotchy") {
                ApplicationRelauncher.restart()
            }
            Button("Quit Izanotchy", role: .destructive) {
                NSApplication.shared.terminate(self)
            }
            .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windows: [String: NSWindow] = [:] // UUID -> NSWindow
    var viewModels: [String: IzaViewModel] = [:] // UUID -> IzaViewModel
    var window: NSWindow?
    let vm: IzaViewModel = .init()
    @ObservedObject var coordinator = IzaViewCoordinator.shared
    var quickShareService = QuickShareService.shared
    var whatsNewWindow: NSWindow?
    var timer: Timer?
    var closeNotchTask: Task<Void, Never>?
    private var previousScreens: [NSScreen]?
    private var onboardingWindowController: NSWindowController?
    private var screenLockedObserver: Any?
    private var screenUnlockedObserver: Any?
    private var isScreenLocked: Bool = false
    private var windowScreenDidChangeObserver: Any?
    private var dragDetectors: [String: DragDetector] = [:] // UUID -> DragDetector

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleIncomingURL(url)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "izanotchy" || url.scheme == "heyclicky" {
            if url.host == "homespace" {
                Task { @MainActor in
                    CompanionManager.shared.toggleHomeSpace()
                }
            } else if url.host == "character-inspector" {
                Task { @MainActor in
                    HomeSpaceWindowManager.shared.show()
                    NotificationCenter.default.post(name: Notification.Name("HomeSpaceToggleCharacterSidebar"), object: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NotificationCenter.default.post(name: Notification.Name("HomeSpaceToggleCharacterSidebar"), object: nil)
                    }
                }
            } else if url.host == "edit-character" {
                Task { @MainActor in
                    HomeSpaceWindowManager.shared.show()
                    NotificationCenter.default.post(name: Notification.Name("HomeSpaceEditCompanion"), object: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NotificationCenter.default.post(name: Notification.Name("HomeSpaceEditCompanion"), object: nil)
                    }
                }
            } else if url.host == "connected-apps" {
                Task { @MainActor in
                    HomeSpaceWindowManager.shared.show()
                    NotificationCenter.default.post(name: Notification.Name("HomeSpaceOpenConnectedApps"), object: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NotificationCenter.default.post(name: Notification.Name("HomeSpaceOpenConnectedApps"), object: nil)
                    }
                }
            } else if url.host == "toggle-sidebar" {
                Task { @MainActor in
                    NotificationCenter.default.post(name: Notification.Name("HomeSpaceToggleSidebar"), object: nil)
                }
            } else if url.host == "set-theme" {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems {
                    let cloudHex = queryItems.first(where: { $0.name == "cloud" })?.value ?? "FB923C"
                    let ringHex = queryItems.first(where: { $0.name == "ring" })?.value ?? "FED7AA"
                    let name = queryItems.first(where: { $0.name == "name" })?.value ?? "Research Buddy"
                    let role = queryItems.first(where: { $0.name == "role" })?.value ?? "Market Researcher"
                    Task { @MainActor in
                        if let activeId = CompanionRosterStore.shared.allCompanions.first(where: { $0.name.lowercased().contains(name.lowercased()) })?.id {
                            CompanionRosterStore.shared.updateCompanion(
                                id: activeId,
                                name: name,
                                role: role,
                                cloudColorHex: "#" + cloudHex.replacingOccurrences(of: "#", with: ""),
                                ringColorHex: "#" + ringHex.replacingOccurrences(of: "#", with: "")
                            )
                        }
                    }
                }
            } else if url.host == "toggle-sidebar" {
                Task { @MainActor in
                    HomeSpaceWindowManager.shared.show()
                    NotificationCenter.default.post(name: Notification.Name("HomeSpaceToggleSidebar"), object: nil)
                }
            } else if url.host == "trigger-computer-card" {
                Task { @MainActor in
                    HomeSpaceWindowManager.shared.show()
                    var status: ComputerCardStatus = .done
                    var appName = "Mail"
                    var instruction = "Drafting outreach emails and syncing inbox via Mail.app."
                    var reason: String? = nil
                    if url.query?.contains("takeover") == true {
                        status = .takeoverNeeded
                        instruction = "Human takeover requested: 2-Factor Authentication required."
                        reason = "Two-factor authentication code required to connect Mail server."
                    }
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                        if let app = components.queryItems?.first(where: { $0.name == "app" })?.value {
                            appName = app
                        }
                    }
                    let payload = ComputerCardPayload(
                        cardTitle: "Computer",
                        status: status,
                        instructionText: instruction,
                        snapshotImagePath: nil,
                        targetAppName: appName,
                        activeWorkflowApp: appName,
                        takeoverReason: reason,
                        queueSummary: "3 drafts queued"
                    )
                    let assistantMsg = HomeSpaceChatMessage(
                        isUser: false,
                        text: "",
                        computerPayload: payload
                    )
                    CompanionManager.shared.appendChatMessage(assistantMsg)
                }
            } else if url.host == "test-check-email" || url.host == "check-email" {
                Task { @MainActor in
                    HomeSpaceWindowManager.shared.show()
                    NotificationCenter.default.post(name: Notification.Name("HomeSpaceSubmitPrompt"), object: "Tolong check email terbaru saya")
                }
            } else if url.host == "test-send-email" || url.host == "send-email" {
                Task { @MainActor in
                    HomeSpaceWindowManager.shared.show()
                    NotificationCenter.default.post(name: Notification.Name("HomeSpaceSubmitPrompt"), object: "Tolong kirimkan email laporan ke rezkyhaikal2@gmail.com")
                }
            } else if url.host == "test-proactive-alert" || url.host == "proactive-alert" {
                Task { @MainActor in
                    CompanionVMBackgroundWatcher.shared.triggerProactiveAlert(
                        companionSlug: "inbox-buddy",
                        subject: "Update Kontrak Kemitraan Q4",
                        sender: "Rezky Haikal",
                        preview: "Halo, mohon tinjau draf kontrak kemitraan Q4 terlampir..."
                    )
                }
            } else if url.host == "trigger-computer-modal" || url.host == "trigger-workflow-modal" {
                Task { @MainActor in
                    HomeSpaceWindowManager.shared.show()
                    var status: ComputerCardStatus = .done
                    var appName = "Mail"
                    var instruction = "Drafting outreach emails and syncing inbox via Mail.app."
                    var reason: String? = nil
                    if url.query?.contains("takeover") == true {
                        status = .takeoverNeeded
                        instruction = "Human takeover requested: 2-Factor Authentication required."
                        reason = "Two-factor authentication code required to connect Mail server."
                    }
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                        if let app = components.queryItems?.first(where: { $0.name == "app" })?.value {
                            appName = app
                        }
                    }
                    let payload = ComputerCardPayload(
                        cardTitle: "Computer",
                        status: status,
                        instructionText: instruction,
                        snapshotImagePath: nil,
                        targetAppName: appName,
                        activeWorkflowApp: appName,
                        takeoverReason: reason,
                        queueSummary: "3 drafts queued"
                    )
                    NotificationCenter.default.post(
                        name: Notification.Name("HomeSpaceOpenComputerModal"),
                        object: nil,
                        userInfo: ["payload": payload]
                    )
                }
            } else if url.host == "dismiss-computer-modal" {
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: Notification.Name("HomeSpaceCloseComputerModal"),
                        object: nil
                    )
                }
            } else if url.host == "new-buddy" {
                Task { @MainActor in
                    HomeSpaceWindowManager.shared.show()
                    NotificationCenter.default.post(name: Notification.Name("HomeSpaceOpenNewBuddy"), object: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NotificationCenter.default.post(name: Notification.Name("HomeSpaceOpenNewBuddy"), object: nil)
                    }
                }
            } else if url.host == "interview-answer" {
                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let answer = queryItems?.first(where: { $0.name == "text" })?.value ?? "Saya butuh asisten riset pasar dan kompetitor"
                Task { @MainActor in
                    CompanionInterviewEngine.shared.submitUserAnswer(answer)
                }
            } else if url.host == "interview-stage" {
                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let targetStage = queryItems?.first(where: { $0.name == "stage" })?.value ?? "spec"
                Task { @MainActor in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if targetStage == "spec" {
                            CompanionInterviewEngine.shared.stage = .reviewingSpec
                        } else if targetStage == "character" {
                            CompanionInterviewEngine.shared.stage = .customizingCharacter
                        } else {
                            CompanionInterviewEngine.shared.stage = .interviewing
                        }
                    }
                }
            } else if url.host == "interview-mood" {
                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let moodStr = queryItems?.first(where: { $0.name == "mood" })?.value ?? "thinking"
                Task { @MainActor in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        if let mood = AgentCloudFaceMood(rawValue: moodStr) {
                            CompanionInterviewEngine.shared.selectedMood = mood
                        }
                    }
                }
            } else if url.host == "interview-launch" {
                Task { @MainActor in
                    _ = CompanionInterviewEngine.shared.finalizeAndLaunch()
                    NotificationCenter.default.post(name: Notification.Name("HomeSpaceCloseNewBuddy"), object: nil)
                }
            } else if url.host == "select-buddy" || url.host == "select-companion" {
                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let name = queryItems?.first(where: { $0.name == "name" })?.value ?? ""
                let idStr = queryItems?.first(where: { $0.name == "id" })?.value ?? ""
                Task { @MainActor in
                    if let uuid = UUID(uuidString: idStr) {
                        CompanionRosterStore.shared.selectCompanion(id: uuid)
                    } else if !name.isEmpty {
                        if let comp = CompanionRosterStore.shared.allCompanions.first(where: { $0.name.lowercased().contains(name.lowercased()) }) {
                            CompanionRosterStore.shared.selectCompanion(id: comp.id)
                        }
                    }
                }
            } else if url.host == "ask" {
                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let prompt = queryItems?.first(where: { $0.name == "text" })?.value ?? "What do you see?"
                Task { @MainActor in
                    CompanionManager.shared.askViaText(prompt: prompt)
                }
            } else if url.host == "test-tradingview" {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems {
                    let action = queryItems.first(where: { $0.name == "action" })?.value?.lowercased() ?? "timeframe"
                    let tf = queryItems.first(where: { $0.name == "tf" })?.value
                    let symbol = queryItems.first(where: { $0.name == "symbol" })?.value
                    let tool = queryItems.first(where: { $0.name == "tool" })?.value
                    let pointsStr = queryItems.first(where: { $0.name == "points" })?.value
                    let indicator = queryItems.first(where: { $0.name == "indicator" })?.value
                    let pine = queryItems.first(where: { $0.name == "pine" })?.value

                    var pts: [CGPoint]? = nil
                    if let pointsStr = pointsStr {
                        pts = pointsStr.split(separator: "|").compactMap { pair in
                            let coords = pair.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                            if coords.count >= 2 {
                                return CGPoint(x: coords[0], y: coords[1])
                            }
                            return nil
                        }
                    }

                    Task { @MainActor in
                        let payload: TradingViewActionPayload
                        switch action {
                        case "timeframe":
                            payload = TradingViewActionPayload(actionType: .timeframe, parameter: tf ?? "15", rawDetails: "Switch timeframe to \(tf ?? "15")")
                        case "symbol":
                            payload = TradingViewActionPayload(actionType: .symbol, parameter: symbol ?? "BTCUSDT", rawDetails: "Switch symbol to \(symbol ?? "BTCUSDT")")
                        case "draw":
                            payload = TradingViewActionPayload(actionType: .drawWithTool, toolName: tool ?? "Rectangle", points: pts, rawDetails: "Draw \(tool ?? "Rectangle") at \(pointsStr ?? "")")
                        case "indicator":
                            payload = TradingViewActionPayload(actionType: .addIndicator, parameter: indicator ?? "Relative Strength Index", rawDetails: "Add indicator \(indicator ?? "")")
                        case "pine":
                            payload = TradingViewActionPayload(actionType: .injectPineScript, pineScript: pine ?? "// TradingView Script", rawDetails: "Inject Pine Script")
                        case "clear":
                            payload = TradingViewActionPayload(actionType: .clearDrawings, rawDetails: "Clear drawings")
                        default:
                            payload = TradingViewActionPayload(actionType: .timeframe, parameter: "15", rawDetails: "Default timeframe")
                        }
                        await TradingViewActionDispatcher.shared.execute(action: payload)
                    }
                }
            } else if url.host == "permission" {
                Task { @MainActor in
                    WindowPositionManager.openAccessibilitySettings()
                }
            } else if url.host == "cursor" {
                Task { @MainActor in
                    CompanionManager.shared.enableCursor()
                }
            } else if url.host == "disable-cursor" {
                Task { @MainActor in
                    CompanionManager.shared.disableCursor()
                }
            } else if url.host == "toggle-cursor" {
                Task { @MainActor in
                    if CompanionManager.shared.isClickyCursorEnabled {
                        CompanionManager.shared.disableCursor()
                    } else {
                        CompanionManager.shared.enableCursor()
                    }
                }
            } else if url.host == "approve-action" {
                Task { @MainActor in
                    CompanionManager.shared.approveComputerUseOnce()
                }
            } else if url.host == "reject-action" {
                Task { @MainActor in
                    CompanionManager.shared.rejectComputerUse()
                }
            } else if url.host == "settings" {
                let tab = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "tab" })?.value
                Task { @MainActor in
                    SettingsWindowController.shared.showWindow()
                    if let tab = tab {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(name: Notification.Name("SelectSettingsTab"), object: tab)
                        }
                    }
                }
            } else if url.host == "open-popover" {
                Task { @MainActor in
                    FloatingCompanionRailWindowManager.shared.showRail()
                    if let first = CompanionRosterStore.shared.allCompanions.first {
                        CompanionRosterStore.shared.activePopoverCompanionId = first.id
                    }
                }
            } else if url.host == "open-notch" {
                Task { @MainActor in
                    self.vm.open()
                    try? await Task.sleep(for: .milliseconds(400))
                    NotificationCenter.default.post(name: Notification.Name("ShowClickyHoverSpace"), object: nil)
                }
            } else if url.host == "open-hover-space" {
                Task { @MainActor in
                    self.vm.open()
                    try? await Task.sleep(for: .milliseconds(400))
                    NotificationCenter.default.post(name: Notification.Name("ShowClickyHoverSpace"), object: nil)
                }
            } else if url.host == "propose-action" || url.host == "test-computer-use" {
                let targetApp = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "app" })?.value ?? "Calculator"
                let keyCombo = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "combo" })?.value ?? "cmd+q"
                let bodyText = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "text" })?.value ?? "aku akan menutup aplikasi \(targetApp) untukmu, boleh aku lanjutkan?"
                Task { @MainActor in
                    let req = ComputerUseRequest(
                        companionName: "Clicky",
                        companionMood: .happy,
                        cloudColorHex: "#38BDF8",
                        ringColorHex: "#BAE6FD",
                        heading: "Wants to use your Mac",
                        bodyText: bodyText,
                        payload: ComputerUseActionPayload(
                            type: .keyCombo,
                            targetCoordinate: nil,
                            targetApp: targetApp,
                            keyCombo: keyCombo,
                            rawDetails: keyCombo
                        )
                    )
                    CompanionManager.shared.pendingComputerUseRequest = req
                    NotchComputerUseConsentWindow.shared.show(with: req)
                }
            } else if url.host == "approve-computer-use" {
                Task { @MainActor in
                    CompanionManager.shared.approveComputerUseOnce()
                }
            } else if url.host == "always-allow-computer-use" {
                Task { @MainActor in
                    CompanionManager.shared.alwaysAllowComputerUse()
                }
            } else if url.host == "reject-computer-use" {
                Task { @MainActor in
                    CompanionManager.shared.rejectComputerUse()
                }
            } else if url.host == "test-switching" || url.host == "toggle-glow" {
                Task { @MainActor in
                    self.vm.open()
                    AntigravityUsageManager.shared.isSwitching.toggle()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        if let observer = screenLockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenLockedObserver = nil
        }
        if let observer = screenUnlockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenUnlockedObserver = nil
        }
        MusicManager.shared.destroy()
        cleanupDragDetectors()
        cleanupWindows()
        OverlayWindowManager.shared.hideOverlay()
        AntigravityBridgeManager.shared.stopBridge()
        XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
        CuaDriverClient.shared.stopDaemon()
        LayaDecisionEngine.shared.stopDaemon()
    }

    @MainActor
    func onScreenLocked(_ notification: Notification) {
        isScreenLocked = true
        if !Defaults[.showOnLockScreen] {
            cleanupWindows()
        } else {
            enableSkyLightOnAllWindows()
        }
    }

    @MainActor
    func onScreenUnlocked(_ notification: Notification) {
        isScreenLocked = false
        if !Defaults[.showOnLockScreen] {
            adjustWindowPosition(changeAlpha: true)
        } else {
            disableSkyLightOnAllWindows()
        }
    }
    
    @MainActor
    private func enableSkyLightOnAllWindows() {
        if Defaults[.showOnAllDisplays] {
            windows.values.forEach { window in
                if let skyWindow = window as? IzaNotchSkyLightWindow {
                    skyWindow.enableSkyLight()
                }
            }
        } else {
            if let skyWindow = window as? IzaNotchSkyLightWindow {
                skyWindow.enableSkyLight()
            }
        }
    }
    
    @MainActor
    private func disableSkyLightOnAllWindows() {
        // Delay disabling SkyLight to avoid flicker during unlock transition
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run {
                if Defaults[.showOnAllDisplays] {
                    self.windows.values.forEach { window in
                        if let skyWindow = window as? IzaNotchSkyLightWindow {
                            skyWindow.disableSkyLight()
                        }
                    }
                } else {
                    if let skyWindow = self.window as? IzaNotchSkyLightWindow {
                        skyWindow.disableSkyLight()
                    }
                }
            }
        }
    }

    private func cleanupWindows(shouldInvert: Bool = false) {
        let shouldCleanupMulti = shouldInvert ? !Defaults[.showOnAllDisplays] : Defaults[.showOnAllDisplays]
        
        if shouldCleanupMulti {
            windows.values.forEach { window in
                window.close()
                NotchSpaceManager.shared.notchSpace.windows.remove(window)
            }
            windows.removeAll()
            viewModels.removeAll()
        } else if let window = window {
            window.close()
            NotchSpaceManager.shared.notchSpace.windows.remove(window)
            if let obs = windowScreenDidChangeObserver {
                NotificationCenter.default.removeObserver(obs)
                windowScreenDidChangeObserver = nil
            }
            self.window = nil
        }
    }

    private func cleanupDragDetectors() {
        dragDetectors.values.forEach { detector in
            detector.stopMonitoring()
        }
        dragDetectors.removeAll()
    }

    // MARK: - Physical Screen Filtering
    static func isVirtualDisplay(screen: NSScreen) -> Bool {
        if screen.frame.origin == .zero && screen.frame.width == 1512 {
            // Built-in MacBook notch display is never virtual
            return false
        }
        if MascotVirtualDesktopService.isAllocatingVirtualDisplay && screen != NSScreen.screens.first {
            return true
        }
        if MascotVirtualDesktopService.shared.isVirtualDisplayActive {
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               num == MascotVirtualDesktopService.shared.displayID {
                return true
            }
            if screen != NSScreen.screens.first && screen.frame.origin != .zero {
                return true
            }
        }
        let name = screen.localizedName
        if name.contains("Izanotchy VM") || name.contains("Virtual") || name.contains("Null Display") || name.contains("AirPlay") || name.contains("Sidecar") {
            return true
        }
        // Geometric & bounds check: Virtual desktop is configured as 1920x1080 at x >= 1400
        let frame = screen.frame
        if frame.origin.x >= 1400 || (frame.width == 1920 && frame.height == 1080 && frame.origin != .zero) {
            return true
        }
        return false
    }

    static func physicalScreens() -> [NSScreen] {
        let screens = NSScreen.screens.filter { !isVirtualDisplay(screen: $0) }
        return screens.isEmpty ? NSScreen.screens : screens
    }

    private func setupDragDetectors() {
        cleanupDragDetectors()

        guard Defaults[.expandedDragDetection] else { return }

        let physical = Self.physicalScreens()
        if Defaults[.showOnAllDisplays] {
            for screen in physical {
                setupDragDetectorForScreen(screen)
            }
        } else {
            let preferredScreen: NSScreen? = window?.screen
                ?? NSScreen.screen(withUUID: coordinator.selectedScreenUUID)
                ?? physical.first
                ?? NSScreen.main

            if let screen = preferredScreen {
                setupDragDetectorForScreen(screen)
            }
        }
    }

    private func setupDragDetectorForScreen(_ screen: NSScreen) {
        guard let uuid = screen.displayUUID else { return }
        
        let screenFrame = screen.frame
        let notchHeight = openNotchSize.height
        let notchWidth = openNotchSize.width
        
        // Create notch region at the top-center of the screen where an open notch would occupy
        let notchRegion = CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        
        let detector = DragDetector(notchRegion: notchRegion)
        
        detector.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                self?.handleDragEntersNotchRegion(onScreen: screen)
            }
        }
        
        dragDetectors[uuid] = detector
        detector.startMonitoring()
    }

    private func handleDragEntersNotchRegion(onScreen screen: NSScreen) {
        guard let uuid = screen.displayUUID else { return }
        
        if Defaults[.showOnAllDisplays], let viewModel = viewModels[uuid] {
            viewModel.open()
            coordinator.currentView = .shelf
        } else if !Defaults[.showOnAllDisplays], let windowScreen = window?.screen, screen == windowScreen {
            vm.open()
            coordinator.currentView = .shelf
        }
    }

    private func createIzaNotchWindow(for screen: NSScreen, with viewModel: IzaViewModel) -> NSWindow {
        let rect = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]
        
        let window = IzaNotchSkyLightWindow(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)
        window.viewModel = viewModel
        
        // Enable SkyLight only when screen is locked
        if isScreenLocked {
            window.enableSkyLight()
        } else {
            window.disableSkyLight()
        }

        let hostingView = IzaNotchHostingView(
            rootView: ContentView()
                .environmentObject(viewModel)
        )
        hostingView.viewModel = viewModel
        window.contentView = hostingView

        if HomeSpaceWindowManager.shared.isVisible {
            window.alphaValue = 0.0
            window.ignoresMouseEvents = true
        } else {
            window.alphaValue = 1.0
            window.updateMouseInteractivity()
            window.orderFrontRegardless()
        }
        window.startMouseTracking()
        NotchSpaceManager.shared.notchSpace.windows.insert(window)

        // Observe when the window's screen changes so we can update drag detectors
        windowScreenDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: window,
            queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.setupDragDetectors()
                }
        }
        return window
    }

    @MainActor
    private func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false) {
        let screenFrame = screen.frame
        window.setFrameOrigin(
            NSPoint(
                x: screenFrame.origin.x + (screenFrame.width / 2) - window.frame.width / 2,
                y: screenFrame.origin.y + screenFrame.height - window.frame.height
            ))
        if HomeSpaceWindowManager.shared.isVisible {
            window.alphaValue = 0.0
            window.ignoresMouseEvents = true
        } else {
            window.alphaValue = 1.0
            (window as? IzaNotchSkyLightWindow)?.updateMouseInteractivity()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Startup Orphan Sweep (Invariant 39): Sweeps any workflow app windows stranded on host display
        MascotVirtualDesktopService.shared.sweepOrphanWindowsOnStartup()

        _ = AntigravityBridgeManager.shared
        CompanionUIHostRegistry.shared = CompanionUIHostBridge.shared
        DomainActionDispatcherRegistry.shared = TradingViewActionDispatcher.shared
        
        // Start Clicky companion pipeline (permissions, shortcut monitor, voice pipeline, overlay)
        CompanionManager.shared.start()
        FloatingCompanionRailWindowManager.shared.start()

        // Start Futures Scout Background Watcher (Passive Opt-In Canon)
        Task {
            await FuturesScoutBackgroundWatcher.shared.start()
        }

        // Start Companion VM Background Watcher (1:1 Grok Bot Proactive Notifier)
        Task { @MainActor in
            CompanionVMBackgroundWatcher.shared.start()
        }


        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            forName: Notification.Name.selectedScreenChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition(changeAlpha: true)
                self?.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.notchHeightChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.automaticallySwitchDisplayChanged, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            Task { @MainActor in
                window.alphaValue = self.coordinator.selectedScreenUUID == self.coordinator.preferredScreenUUID ? 1 : 0
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.showOnAllDisplaysChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.cleanupWindows(shouldInvert: true)
                self.adjustWindowPosition(changeAlpha: true)
                self.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.expandedDragDetectionChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setupDragDetectors()
            }
        }

        // F-14 Opsi 1A & Bugfix: Auto-hide BoringNotch when HomeSpace is open and guarantee instant hover recovery upon close
        NotificationCenter.default.addObserver(
            forName: Notification.Name("HomeSpaceVisibilityDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                let isVisible = (notification.object as? Bool) ?? false
                var allWindows = Set(NotchSpaceManager.shared.notchSpace.windows)
                if let appWindows = self?.windows.values {
                    allWindows.formUnion(appWindows)
                }
                if let singleWindow = self?.window {
                    allWindows.insert(singleWindow)
                }

                if isVisible {
                    // Close expanded notch state immediately so it doesn't freeze in open state
                    self?.vm.close()
                    self?.viewModels.values.forEach { $0.close() }

                    for window in allWindows {
                        window.alphaValue = 0.0
                        window.ignoresMouseEvents = true
                    }
                } else {
                    // HomeSpace closed: restore notch to closed resting state and full opacity
                    self?.vm.close()
                    self?.viewModels.values.forEach { $0.close() }

                    for window in allWindows {
                        window.alphaValue = 1.0
                        if let skyWindow = window as? IzaNotchSkyLightWindow {
                            skyWindow.updateMouseInteractivity()
                        } else {
                            window.ignoresMouseEvents = false
                        }
                        window.orderFrontRegardless()
                    }

                    // Reinforce orderFrontRegardless after HomeSpace panel completes orderOut animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        for window in allWindows {
                            window.alphaValue = 1.0
                            if let skyWindow = window as? IzaNotchSkyLightWindow {
                                skyWindow.updateMouseInteractivity()
                            } else {
                                window.ignoresMouseEvents = false
                            }
                            window.orderFrontRegardless()
                        }
                    }
                }
            }
        }

        // Use closure-based observers for DistributedNotificationCenter and keep tokens for removal
        screenLockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenLocked(notification)
                }
        }

        screenUnlockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenUnlocked(notification)
                }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchyTestTriggerPopover"),
            object: nil, queue: .main) { _ in
                Task { @MainActor in
                    CompanionRosterStore.shared.activePopoverCompanionId = CompanionRosterStore.shared.activeCompanionId
                }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchyTestTriggerUnread"),
            object: nil, queue: .main) { _ in
                Task { @MainActor in
                    if !CompanionRosterStore.shared.allCompanions.isEmpty {
                        CompanionRosterStore.shared.allCompanions[0].hasUnreadMessages = true
                    }
                }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchyToggleClicky"),
            object: nil, queue: .main) { _ in
                Task { @MainActor in
                    let clicky = CompanionManager.shared
                    if clicky.isClickyCursorEnabled {
                        clicky.disableCursor()
                        FloatingCompanionRailWindowManager.shared.hideRail()
                    } else {
                        clicky.enableCursor()
                        FloatingCompanionRailWindowManager.shared.showRail()
                    }
                }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchyShowHoverSpace"),
            object: nil, queue: .main) { _ in
                NotificationCenter.default.post(name: Notification.Name("ShowClickyHoverSpace"), object: nil)
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchyShowHomeSpace"),
            object: nil, queue: .main) { notif in
                Task { @MainActor in
                    let prompt = notif.userInfo?["prompt"] as? String
                    HomeSpaceWindowManager.shared.show()
                    if let prompt = prompt, !prompt.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            NotificationCenter.default.post(name: Notification.Name("HomeSpaceSubmitPrompt"), object: prompt)
                        }
                    }
                }
        }

        #if DEBUG
        // TASK-044 Ground-Truth Oracle E2E Injection Contract
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("iza.e2e.task"),
            object: nil, queue: .main) { notif in
                Task { @MainActor in
                    let prompt = notif.userInfo?["text"] as? String ?? notif.userInfo?["prompt"] as? String
                    let runId = notif.userInfo?["runId"] as? String ?? UUID().uuidString
                    let companionSlug = notif.userInfo?["companionSlug"] as? String ?? notif.userInfo?["companion"] as? String ?? notif.userInfo?["buddy"] as? String
                    CompanionManager.shared.activeE2ERunId = runId
                    ClickyLogger.info("[E2E_IPC]", "Received task injection: runId=\(runId), text='\(prompt ?? "")', companion='\(companionSlug ?? "current")'")

                    if let slug = companionSlug, !slug.isEmpty {
                        CompanionManager.shared.selectCompanion(bySlug: slug)
                    }

                    HomeSpaceWindowManager.shared.show()
                    if let prompt = prompt, !prompt.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            NotificationCenter.default.post(name: Notification.Name("HomeSpaceSubmitPrompt"), object: prompt)
                        }
                    }
                }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("iza.e2e.ax_query"),
            object: nil, queue: .main) { notif in
                Task { @MainActor in
                    let queryId = notif.userInfo?["queryId"] as? String ?? ""
                    let appName = notif.userInfo?["targetAppName"] as? String ?? ""
                    let specJson = notif.userInfo?["specJson"] as? String ?? "[]"

                    ClickyLogger.info("[E2E_IPC]", "Received ax_query for: \(appName), queryId=\(queryId)")

                    var expectedAX: [[String: Any]] = []
                    if let data = specJson.data(using: .utf8),
                       let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        expectedAX = list
                    }

                    let result = ClickyUIObservationService.shared.evaluateAXTreeForE2E(
                        targetAppName: appName,
                        expectedAX: expectedAX
                    )

                    ClickyLogger.info("[E2E_IPC]", "Posting ax_result for: \(queryId), passed=\(result.passed), reason=\(result.reason)")

                    DistributedNotificationCenter.default().postNotificationName(
                        NSNotification.Name("iza.e2e.ax_result"),
                        object: nil,
                        userInfo: [
                            "queryId": queryId,
                            "passed": result.passed,
                            "reason": result.reason
                        ],
                        deliverImmediately: true
                    )
                }
        }
        #endif
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchyTestMaximizeModal"),
            object: nil, queue: .main) { _ in
                Task { @MainActor in
                    NotificationCenter.default.post(name: Notification.Name("HomeSpaceOpenComputerModal"), object: nil)
                }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchySelectShippy"),
            object: nil, queue: .main) { _ in
                Task { @MainActor in
                    if let shippy = CompanionRosterStore.shared.allCompanions.first(where: { $0.slug == "shippy" }) {
                        CompanionRosterStore.shared.selectCompanion(id: shippy.id)
                    }
                }
        }

        // Test harness observer for Phase 2 CUA Symbol Switching
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchyTestPhase2SwitchSymbol"),
            object: nil, queue: .main) { notif in
                Task { @MainActor in
                    let symbol = notif.userInfo?["symbol"] as? String ?? "ETHUSDT"
                    ClickyLogger.info("[TEST_IPC]", "Received IzanotchyTestPhase2SwitchSymbol for: \(symbol)")
                    _ = await TradingViewNavigationTool.shared.switchSymbol(symbol)
                }
        }

        // Test harness observer for Phase 3 CUA Timeframe Switching
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchyTestPhase3SwitchTimeframe"),
            object: nil, queue: .main) { notif in
                Task { @MainActor in
                    let tf = notif.userInfo?["timeframe"] as? String ?? "15m"
                    ClickyLogger.info("[TEST_IPC]", "Received IzanotchyTestPhase3SwitchTimeframe for: \(tf)")
                    _ = await TradingViewNavigationTool.shared.switchTimeframe(tf)
                }
        }

        // Test harness observer for Phase 4 CUA Sidebar Collapse & Auto-Fit
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchyTestPhase4CollapseSidebar"),
            object: nil, queue: .main) { _ in
                Task { @MainActor in
                    ClickyLogger.info("[TEST_IPC]", "Received IzanotchyTestPhase4CollapseSidebar")
                    _ = await TradingViewLayoutTool.shared.collapseSidebarIfOpen()
                    _ = await TradingViewLayoutTool.shared.resetChartScale()
                }
        }

        // Test harness observer for Full Closed-Loop E2E Analisa (All 5 Phases)
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("IzanotchyTestE2EAnalisa"),
            object: nil, queue: .main) { notif in
                Task { @MainActor in
                    let symbol = notif.userInfo?["symbol"] as? String ?? "BTCUSDT"
                    let tf = notif.userInfo?["timeframe"] as? String ?? "15"
                    ClickyLogger.info("[TEST_IPC]", "Received IzanotchyTestE2EAnalisa for symbol: \(symbol), timeframe: \(tf)")
                    await FuturesScoutChartAnalyst.shared.analyzeAndReport(symbol: symbol, preferredTimeframe: tf)
                }
        }

        KeyboardShortcuts.onKeyDown(for: .toggleSneakPeek) { [weak self] in
            guard let self = self else { return }
            if Defaults[.sneakPeekStyles] == .inline {
                let newStatus = !self.coordinator.expandingView.show
                self.coordinator.toggleExpandingView(status: newStatus, type: .music)
            } else {
                self.coordinator.toggleSneakPeek(
                    status: !self.coordinator.sneakPeek.show,
                    type: .music,
                    duration: 3.0
                )
            }
        }

        KeyboardShortcuts.onKeyDown(for: .toggleNotchOpen) { [weak self] in
            Task { [weak self] in
                guard let self = self else { return }

                let mouseLocation = NSEvent.mouseLocation

                var viewModel = self.vm

                if Defaults[.showOnAllDisplays] {
                    for screen in NSScreen.screens {
                        if screen.frame.contains(mouseLocation) {
                            if let uuid = screen.displayUUID, let screenViewModel = self.viewModels[uuid] {
                                viewModel = screenViewModel
                                break
                            }
                        }
                    }
                }

                self.closeNotchTask?.cancel()
                self.closeNotchTask = nil

                switch viewModel.notchState {
                case .closed:
                    await MainActor.run {
                        viewModel.open()
                    }

                    let task = Task { [weak viewModel] in
                        do {
                            try await Task.sleep(for: .seconds(3))
                            await MainActor.run {
                                viewModel?.close()
                            }
                        } catch { }
                    }
                    self.closeNotchTask = task
                case .open:
                    await MainActor.run {
                        viewModel.close()
                    }
                }
            }
        }

        if !Defaults[.showOnAllDisplays] {
            let viewModel = self.vm
            let window = createIzaNotchWindow(
                for: NSScreen.main ?? NSScreen.screens.first!, with: viewModel)
            self.window = window
            adjustWindowPosition(changeAlpha: true)
        } else {
            adjustWindowPosition(changeAlpha: true)
        }

        setupDragDetectors()

        if coordinator.firstLaunch {
            DispatchQueue.main.async {
                self.showOnboardingWindow(step: .welcome)
            }
            playWelcomeSound()
        } else if MusicManager.shared.isNowPlayingDeprecated
            && Defaults[.mediaController] == .nowPlaying
        {
            DispatchQueue.main.async {
                self.showOnboardingWindow(step: .musicPermission)
            }
        }

        previousScreens = Self.physicalScreens()
    }

    func playWelcomeSound() {
        let audioPlayer = AudioPlayer()
        audioPlayer.play(fileName: "boring", fileExtension: "m4a")
    }

    func deviceHasNotch() -> Bool {
        if #available(macOS 12.0, *) {
            for screen in Self.physicalScreens() {
                if screen.safeAreaInsets.top > 0 {
                    return true
                }
            }
        }
        return false
    }

    @objc func screenConfigurationDidChange() {
        let currentScreens = Self.physicalScreens()

        let screensChanged =
            currentScreens.count != previousScreens?.count
            || Set(currentScreens.compactMap { $0.displayUUID })
                != Set(previousScreens?.compactMap { $0.displayUUID } ?? [])
            || Set(currentScreens.map { $0.frame }) != Set(previousScreens?.map { $0.frame } ?? [])

        previousScreens = currentScreens

        if screensChanged {
            DispatchQueue.main.async { [weak self] in
                if HomeSpaceWindowManager.shared.isVisible {
                    self?.adjustWindowPosition()
                    self?.setupDragDetectors()
                } else {
                    self?.cleanupWindows()
                    self?.adjustWindowPosition()
                    self?.setupDragDetectors()
                }
            }
        }
    }

    @objc func adjustWindowPosition(changeAlpha: Bool = false) {
        let physical = Self.physicalScreens()
        if Defaults[.showOnAllDisplays] {
            let currentScreenUUIDs = Set(physical.compactMap { $0.displayUUID })

            // Remove windows for screens that no longer exist
            for uuid in windows.keys where !currentScreenUUIDs.contains(uuid) {
                if let window = windows[uuid] {
                    window.close()
                    NotchSpaceManager.shared.notchSpace.windows.remove(window)
                    windows.removeValue(forKey: uuid)
                    viewModels.removeValue(forKey: uuid)
                }
            }

            // Create or update windows for all physical screens
            for screen in physical {
                guard let uuid = screen.displayUUID else { continue }
                
                if windows[uuid] == nil {
                    let viewModel = IzaViewModel(screenUUID: uuid)
                    let window = createIzaNotchWindow(for: screen, with: viewModel)

                    windows[uuid] = window
                    viewModels[uuid] = viewModel
                }

                if let window = windows[uuid], let viewModel = viewModels[uuid] {
                    positionWindow(window, on: screen, changeAlpha: changeAlpha)

                    if viewModel.notchState == .closed {
                        viewModel.close()
                    }
                }
            }
        } else {
            let selectedScreen: NSScreen

            if let preferredScreen = NSScreen.screen(withUUID: coordinator.preferredScreenUUID ?? "") {
                coordinator.selectedScreenUUID = coordinator.preferredScreenUUID ?? ""
                selectedScreen = preferredScreen
            } else if Defaults[.automaticallySwitchDisplay], let mainScreen = physical.first(where: { $0 == NSScreen.main }) ?? physical.first ?? NSScreen.main,
                      let mainUUID = mainScreen.displayUUID {
                coordinator.selectedScreenUUID = mainUUID
                selectedScreen = mainScreen
            } else {
                if let window = window {
                    window.alphaValue = 0
                }
                return
            }

            vm.screenUUID = selectedScreen.displayUUID
            vm.notchSize = getClosedNotchSize(screenUUID: selectedScreen.displayUUID)

            if window == nil {
                window = createIzaNotchWindow(for: selectedScreen, with: vm)
            }

            if let window = window {
                positionWindow(window, on: selectedScreen, changeAlpha: changeAlpha)

                if vm.notchState == .closed {
                    vm.close()
                }
            }
        }
    }

    @objc func togglePopover(_ sender: Any?) {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            window?.orderFrontRegardless()
        }
    }

    @objc func showMenu() {
        statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc func quitAction() {
        NSApplication.shared.terminate(self)
    }

    private func showOnboardingWindow(step: OnboardingStep = .welcome) {
        if onboardingWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Onboarding"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentView = NSHostingView(
                rootView: OnboardingView(
                    step: step,
                    onFinish: {
                        window.orderOut(nil)
//                        NSApp.setActivationPolicy(.accessory)
                        window.close()
                        NSApp.deactivate()
                    },
                    onOpenSettings: {
                        window.close()
                        SettingsWindowController.shared.showWindow()
                    }
                ))
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")

            onboardingWindowController = NSWindowController(window: window)
        }

//        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}

extension Notification.Name {
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
    static let notchHeightChanged = Notification.Name("NotchHeightChanged")
    static let showOnAllDisplaysChanged = Notification.Name("showOnAllDisplaysChanged")
    static let automaticallySwitchDisplayChanged = Notification.Name("automaticallySwitchDisplayChanged")
    static let expandedDragDetectionChanged = Notification.Name("expandedDragDetectionChanged")
}

extension CGRect: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }

    public static func == (lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
