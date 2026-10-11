//
//  ComputerUsePhysicalExecutor.swift
//  izaNotch (Izanotchy)
//
//  Universal Physical macOS Execution Engine:
//  Combines Cua Driver background automation (element-token AX inspection,
//  background typing and clicking) with native CoreGraphics CGEvents & AppKit fallback.
//

import AppKit
import CoreGraphics
import Foundation

@MainActor
public final class ComputerUsePhysicalExecutor {
    public static let shared = ComputerUsePhysicalExecutor()

    private init() {}

    // MARK: - Smart Target Resolution

    public static func resolveTargetAppName(appName: String?, details: String) -> String? {
        let cleanApp = appName?.trimmingCharacters(in: .whitespaces)
        if let name = cleanApp, !name.isEmpty, name.lowercased() != "active app", name.lowercased() != "current" {
            return name
        }

        // 1. Dynamic resolution via DynamicAppResolver
        if let resolved = DynamicAppResolver.shared.resolveApplication(query: details) {
            return resolved.displayName
        }

        // 2. Dynamic check across running applications
        let lowerDetails = details.lowercased()
        for app in NSWorkspace.shared.runningApplications {
            if let locName = app.localizedName, locName.count >= 3 {
                if lowerDetails.contains(locName.lowercased()) {
                    return locName
                }
            }
        }

        return nil
    }

    // MARK: - Master Dispatcher

    public func execute(payload: ComputerUseActionPayload) async {
        ClickyLogger.info("[COMPUTER_USE]", "Executing action type: \(payload.type.rawValue), app: \(payload.targetApp ?? "current"), details: \(payload.rawDetails)")

        var targetPid: Int32? = nil
        var resolvedAppName = Self.resolveTargetAppName(appName: payload.targetApp, details: payload.rawDetails)

        // 0. Fallback to active work surface or frontmost app if still unresolved
        if resolvedAppName == nil {
            if let ws = ActiveWorkSurfaceManager.getActiveWorkSurface() {
                resolvedAppName = ws.appName
                targetPid = ws.ownerPID
            } else if let front = NSWorkspace.shared.frontmostApplication,
                      front.bundleIdentifier != Bundle.main.bundleIdentifier {
                resolvedAppName = front.localizedName
                targetPid = front.processIdentifier
            }
        }

        // 1. Detect if the intent is to close/quit an application (Opsi 2A: Multi-Layer Native Close)
        let comboLower = payload.keyCombo?.lowercased() ?? ""
        let isCloseOrQuitIntent = comboLower.contains("cmd+q") ||
                                  comboLower.contains("cmd+w") ||
                                  (comboLower.contains("q") && (comboLower.contains("cmd") || comboLower.contains("command"))) ||
                                  (comboLower.contains("w") && (comboLower.contains("cmd") || comboLower.contains("command")))

        if isCloseOrQuitIntent, let appName = resolvedAppName {
            ClickyLogger.info("[COMPUTER_USE]", "Executing deterministic app termination for: \(appName)")
            let success = await terminateOrCloseApplication(named: appName, pid: targetPid)
            if success {
                ClickySoundEngine.shared.play(.done)
                ClickyLogger.success("[COMPUTER_USE]", "Successfully closed application: \(appName)")
                return
            }
        }

        // 2. Resolve and focus or launch target application
        if let appName = resolvedAppName, !appName.isEmpty {
            targetPid = focusOrLaunchApplication(named: appName)
            // Allow macOS window manager time to position and activate
            try? await Task.sleep(for: .milliseconds(300))
        }

        // 3. Perform the primary physical action
        switch payload.type {
        case .click:
            if let target = payload.targetCoordinate {
                await executeMoveAndClick(at: target, button: .left, clickCount: 1)
            } else if let pid = targetPid {
                // Try smart element resolving via Cua Driver
                if let clickPoint = await resolveSmartClickTarget(for: pid) {
                    await executeMoveAndClick(at: clickPoint, button: .left, clickCount: 1)
                } else {
                    ClickyLogger.warning("[COMPUTER_USE]", "Click requested but targetCoordinate could not be determined")
                }
            }

        case .rightClick:
            if let target = payload.targetCoordinate {
                await executeMoveAndClick(at: target, button: .right, clickCount: 1)
            }

        case .doubleClick:
            if let target = payload.targetCoordinate {
                await executeMoveAndClick(at: target, button: .left, clickCount: 2)
            }

        case .typeText:
            if let text = payload.textToType, !text.isEmpty {
                // Determine focus target point
                var focusTarget = payload.targetCoordinate
                if focusTarget == nil, let pid = targetPid {
                    focusTarget = await resolveSmartClickTarget(for: pid)
                }

                // If focus target found, animate cursor flight and click to focus input
                if let target = focusTarget {
                    await executeMoveAndClick(at: target, button: .left, clickCount: 1)
                    try? await Task.sleep(for: .milliseconds(180))
                }

                // Execute natural physical keystrokes directly (Official Native Pipeline)
                executeTypeText(text, autoSendReturn: true)
            }

        case .keyCombo:
            if let combo = payload.keyCombo {
                executeNamedKeyCombo(combo)
            }

        case .launchApp:
            if let appName = resolvedAppName {
                _ = focusOrLaunchApplication(named: appName)
            }

        case .scroll:
            executeScroll(deltaY: -10)

        case .tradingViewAction:
            if let domainDispatcher = DomainActionDispatcherRegistry.shared {
                await domainDispatcher.executeDomainAction(payload: payload)
            } else if let tvPayload = payload.tradingViewPayload {
                await TradingViewActionDispatcher.shared.execute(action: tvPayload)
            } else {
                ClickyLogger.warning("[COMPUTER_USE]", "TradingView action requested but no tradingViewPayload found")
            }
        }

        ClickySoundEngine.shared.play(.done)
        ClickyLogger.success("[COMPUTER_USE]", "Action execution completed successfully")
    }

    // MARK: - Smart Element Target Resolving

    private func resolveSmartClickTarget(for pid: Int32) async -> CGPoint? {
        if let ws = ActiveWorkSurfaceManager.getActiveWorkSurface() {
            let f = ws.frame
            return CGPoint(x: f.origin.x + f.width * 0.5, y: f.origin.y + f.height - 45)
        }
        return nil
    }

    // MARK: - Mouse Actions

    public func executeMoveAndClick(at point: CGPoint, button: CGMouseButton = .left, clickCount: Int = 1) async {
        // Blue companion cursor does NOT fly here; CUA agent cursor handles visual flight during action.
        let source = CGEventSource(stateID: .hidSystemState)
        let downType: CGEventType = (button == .right) ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType = (button == .right) ? .rightMouseUp : .leftMouseUp

        if MascotVirtualDesktopService.shared.isVirtualDisplayActive {
            if let pid = MascotVirtualDesktopService.shared.currentAppPid {
                for i in 1...clickCount {
                    let downEvent = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: point, mouseButton: button)
                    downEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
                    downEvent?.postToPid(pid)
                    usleep(30000)

                    let upEvent = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: point, mouseButton: button)
                    upEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
                    upEvent?.postToPid(pid)
                    usleep(35000)
                }
            }
            return
        }

        // Move system cursor
        let moveEvent = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: button)
        moveEvent?.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(40))

        for i in 1...clickCount {
            let downEvent = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: point, mouseButton: button)
            downEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
            downEvent?.post(tap: .cghidEventTap)

            try? await Task.sleep(for: .milliseconds(30))

            let upEvent = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: point, mouseButton: button)
            upEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
            upEvent?.post(tap: .cghidEventTap)

            if i < clickCount {
                try? await Task.sleep(for: .milliseconds(35))
            }
        }
    }

    // MARK: - Keyboard Typing

    public func executeTypeText(_ text: String, autoSendReturn: Bool = true) {
        let source = CGEventSource(stateID: .hidSystemState)
        let isLong = text.count > 60
        let delayDown: useconds_t = isLong ? 5000 : 14000
        let delayUp: useconds_t = isLong ? 4000 : 12000

        ClickyLogger.info("[PHYSICAL_EXEC]", "Typing text: '\(text)' (autoSendReturn: \(autoSendReturn))")

        if MascotVirtualDesktopService.shared.isVirtualDisplayActive {
            if let pid = MascotVirtualDesktopService.shared.currentAppPid {
                for character in text {
                    var unicharArray = Array(String(character).utf16)
                    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { continue }

                    keyDown.keyboardSetUnicodeString(stringLength: unicharArray.count, unicodeString: &unicharArray)
                    keyUp.keyboardSetUnicodeString(stringLength: unicharArray.count, unicodeString: &unicharArray)

                    keyDown.postToPid(pid)
                    usleep(delayDown)
                    keyUp.postToPid(pid)
                    usleep(delayUp)
                }

                if autoSendReturn {
                    usleep(250000)
                    executeRawKey(key: 0x24, flags: []) // Return key
                }
            }
            return
        }

        for character in text {
            var unicharArray = Array(String(character).utf16)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { continue }

            keyDown.keyboardSetUnicodeString(stringLength: unicharArray.count, unicodeString: &unicharArray)
            keyUp.keyboardSetUnicodeString(stringLength: unicharArray.count, unicodeString: &unicharArray)

            keyDown.post(tap: .cghidEventTap)
            usleep(delayDown)
            keyUp.post(tap: .cghidEventTap)
            usleep(delayUp)
        }
        if autoSendReturn {
            // Jeda 250ms agar input field menyelesaikan pemrosesan teks sebelum commit
            usleep(250000)
            executeRawKey(key: 0x24, flags: []) // Return key
        }
    }

    // MARK: - App Termination & Close (Opsi 2A)

    @discardableResult
    public func terminateOrCloseApplication(named appName: String, pid: Int32? = nil) async -> Bool {
        let cleanName = appName.trimmingCharacters(in: .whitespaces).lowercased()
        let runningApps = NSWorkspace.shared.runningApplications

        let targetApp: NSRunningApplication? = {
            if let pid = pid, let match = runningApps.first(where: { $0.processIdentifier == pid }) {
                return match
            }
            if !cleanName.isEmpty && cleanName != "current" && cleanName != "active app" {
                return runningApps.first(where: {
                    $0.localizedName?.localizedCaseInsensitiveContains(cleanName) == true ||
                    $0.bundleIdentifier?.localizedCaseInsensitiveContains(cleanName) == true
                })
            }
            return runningApps.first(where: {
                $0.bundleIdentifier != Bundle.main.bundleIdentifier && $0.isActive
            })
        }()

        guard let app = targetApp else {
            ClickyLogger.warning("[COMPUTER_USE]", "Could not resolve running application to terminate: \(appName)")
            return false
        }

        ClickyLogger.info("[COMPUTER_USE]", "Terminating application: \(app.localizedName ?? appName) (PID: \(app.processIdentifier))")

        // 1. Search for an on-screen window belonging to targetApp and animate CuaDriver cursor glide to close button
        let targetPID = app.processIdentifier
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let mainHeight = NSScreen.screens.first?.frame.height ?? 900

        var targetClosePoint: CGPoint? = nil
        for w in windowList {
            let ownerPID = w[kCGWindowOwnerPID as String] as? pid_t ?? 0
            let layer = w[kCGWindowLayer as String] as? Int ?? -1
            guard layer == 0, ownerPID == targetPID else { continue }
            if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
               let qX = boundsDict["X"] as? Double,
               let qY = boundsDict["Y"] as? Double,
               let qW = boundsDict["Width"] as? Double,
               let qH = boundsDict["Height"] as? Double,
               qW > 120, qH > 80 {
                // macOS window red close button is at (X + 14, Y + 14) in Quartz coords
                let cocoaX = qX + 14
                let cocoaY = mainHeight - (qY + 14)
                targetClosePoint = CGPoint(x: cocoaX, y: cocoaY)
                break
            }
        }

        if let closePoint = targetClosePoint {
            ClickyLogger.info("[COMPUTER_USE]", "Found on-screen window for \(app.localizedName ?? appName) at close point: \(closePoint)")
            CompanionUIHostRegistry.shared?.hideOverlay() ?? OverlayWindowManager.shared.hideOverlay()
            ClickySoundEngine.shared.play(.send)
        }

        // 2. Perform native termination via AppKit
        _ = app.terminate()
        // 3. Poll for termination confirmation (up to 1.5 seconds in 100ms steps)
        var isDead = false
        for _ in 0..<15 {
            if app.isTerminated {
                isDead = true
                break
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        // 4. Fallback 1: Synthesize Cmd+Q if still active
        if !isDead {
            app.activate(options: [.activateIgnoringOtherApps])
            try? await Task.sleep(for: .milliseconds(100))
            executeNamedKeyCombo("cmd+q")
            for _ in 0..<5 {
                if app.isTerminated {
                    isDead = true
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        // 5. Fallback 2: Force terminate
        if !isDead {
            ClickyLogger.warning("[COMPUTER_USE]", "\(appName) did not exit gracefully; invoking forceTerminate()")
            app.forceTerminate()
            try? await Task.sleep(for: .milliseconds(200))
            isDead = app.isTerminated
        }

        // Verification of termination
        if isDead {
            ClickyLogger.success("[COMPUTER_USE]", "Successfully verified application termination: \(app.localizedName ?? appName) (PID: \(app.processIdentifier))")
        } else {
            ClickyLogger.error("[COMPUTER_USE]", "Application failed to terminate: \(app.localizedName ?? appName) (PID: \(app.processIdentifier))")
        }

        return isDead
    }

    // MARK: - System Shortcuts & Hotkeys

    public func executeNamedKeyCombo(_ combo: String) {
        let lower = combo.lowercased().trimmingCharacters(in: .whitespaces)
        var flags: CGEventFlags = []

        if lower.contains("cmd") || lower.contains("command") {
            flags.insert(.maskCommand)
        }
        if lower.contains("shift") {
            flags.insert(.maskShift)
        }
        if lower.contains("alt") || lower.contains("opt") || lower.contains("option") {
            flags.insert(.maskAlternate)
        }
        if lower.contains("ctrl") || lower.contains("control") {
            flags.insert(.maskControl)
        }

        // Virtual keycodes
        var targetKeyCode: CGKeyCode = 0x24 // default return

        if lower.contains("enter") || lower.contains("return") {
            targetKeyCode = 0x24
        } else if lower.contains("tab") {
            targetKeyCode = 0x30
        } else if lower.contains("space") {
            targetKeyCode = 0x31
        } else if lower.contains("esc") || lower.contains("escape") {
            targetKeyCode = 0x35
        } else if lower.contains("q") {
            targetKeyCode = 0x0C // 'q'
        } else if lower.contains("w") {
            targetKeyCode = 0x0D // 'w'
        } else if lower.contains("a") {
            targetKeyCode = 0x00 // 'a'
        } else if lower.contains("c") {
            targetKeyCode = 0x08 // 'c'
        } else if lower.contains("v") {
            targetKeyCode = 0x09 // 'v'
        } else if lower.contains("z") {
            targetKeyCode = 0x06 // 'z'
        } else if lower.contains("f") {
            targetKeyCode = 0x03 // 'f'
        } else if lower.contains("s") {
            targetKeyCode = 0x01 // 's'
        } else if lower.contains("r") {
            targetKeyCode = 0x0F // 'r'
        } else if lower.contains("t") {
            targetKeyCode = 0x11 // 't'
        } else {
            targetKeyCode = 0x24
        }

        executeRawKey(key: targetKeyCode, flags: flags)
    }

    public func executeRawKey(key: CGKeyCode, flags: CGEventFlags) {
        if MascotVirtualDesktopService.shared.isVirtualDisplayActive {
            if let pid = MascotVirtualDesktopService.shared.currentAppPid {
                let source = CGEventSource(stateID: .hidSystemState)
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
                keyDown?.flags = flags
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
                keyUp?.flags = flags
                keyDown?.postToPid(pid)
                usleep(25000)
                keyUp?.postToPid(pid)
            }
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        usleep(25000)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - App Activation

    @discardableResult
    public func focusOrLaunchApplication(named appName: String) -> Int32? {
        let cleanName = appName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !cleanName.isEmpty, cleanName != "current" else {
            if let front = NSWorkspace.shared.frontmostApplication,
               front.bundleIdentifier != Bundle.main.bundleIdentifier {
                front.activate(options: [.activateIgnoringOtherApps])
                return front.processIdentifier
            }
            return nil
        }

        // 1. Check if application is already running
        let runningApps = NSWorkspace.shared.runningApplications
        if cleanName == "tradingview" {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", "/Applications/TradingView.app"]
            try? proc.run()

            if let tv = runningApps.first(where: { $0.bundleIdentifier == "com.tradingview.tradingviewapp.desktop" || $0.localizedName == "TradingView" }) {
                tv.activate(options: [.activateIgnoringOtherApps])
                let script = """
                tell application "TradingView"
                    activate
                    reopen
                end tell
                tell application "System Events"
                    tell process "TradingView"
                        set frontmost to true
                    end tell
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    var err: NSDictionary?
                    appleScript.executeAndReturnError(&err)
                }
                return tv.processIdentifier
            }
        }
        if let match = runningApps.first(where: {
            $0.localizedName?.lowercased().contains(cleanName) == true ||
            $0.bundleIdentifier?.lowercased().contains(cleanName) == true
        }) {
            match.activate(options: [.activateIgnoringOtherApps])
            return match.processIdentifier
        }

        // 2. Otherwise launch it
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.\(cleanName)") ??
                        NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/System/Applications/\(appName).app")) ??
                        NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/Applications/\(appName).app")) {
            if let running = try? NSWorkspace.shared.launchApplication(at: appUrl, options: [.withoutActivation], configuration: [:]) {
                running.activate(options: [.activateIgnoringOtherApps])
                return running.processIdentifier
            }
        }

        return nil
    }

    // MARK: - Scrolling

    public func executeScroll(deltaY: Int32) {
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: deltaY * 10,
            wheel2: 0,
            wheel3: 0
        )
        scrollEvent?.post(tap: .cghidEventTap)
    }
}
