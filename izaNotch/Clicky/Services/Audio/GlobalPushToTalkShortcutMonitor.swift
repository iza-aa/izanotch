//
//  GlobalPushToTalkShortcutMonitor.swift
//  leanring-buddy
//
//  Captures push-to-talk keyboard shortcuts while makesomething is running in the
//  background. Uses a listen-only CGEvent tap so modifier-only shortcuts like
//  ctrl + option behave more like a real system-wide voice tool.
//

import AppKit
import Combine
import CoreGraphics
import Foundation

final class GlobalPushToTalkShortcutMonitor: ObservableObject {
    public static var isSynthesizingInput: Bool = false
    let shortcutTransitionPublisher = PassthroughSubject<BuddyPushToTalkShortcut.ShortcutTransition, Never>()

    private var globalEventTap: CFMachPort?
    private var globalEventTapRunLoopSource: CFRunLoopSource?
    private var globalNSEventMonitor: Any?
    /// Mutated exclusively from the CGEvent tap callback and global NSEvent monitor on main thread.
    /// Published so the overlay can hide immediately on key release without
    /// waiting for the async dictation state pipeline to catch up.
    @Published private(set) var isShortcutCurrentlyPressed = false

    deinit {
        stop()
    }
    private var lastEscapeTimestamp: TimeInterval = 0

    public var onEscapePressed: (@MainActor () -> Void)? = nil

    private func triggerEscapePressedDeduplicated() {
        let now = Date().timeIntervalSince1970
        guard now - lastEscapeTimestamp > 0.35 else { return }
        lastEscapeTimestamp = now
        DispatchQueue.main.async { [weak self] in
            self?.onEscapePressed?()
        }
    }

    func start() {
        if globalEventTap != nil || globalNSEventMonitor != nil {
            ClickyLogger.info("[SHORTCUT]", "SHORTCUT handler deduplicated (tap already active)")
            return
        }

        if globalNSEventMonitor == nil {
            globalNSEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
                guard let self = self else { return }

                if event.type == .keyDown && event.keyCode == 53 {
                    guard !Self.isSynthesizingInput else { return }
                    self.triggerEscapePressedDeduplicated()
                    return
                }

                let transition = BuddyPushToTalkShortcut.shortcutTransition(
                    for: event,
                    wasShortcutPreviouslyPressed: self.isShortcutCurrentlyPressed
                )
                DispatchQueue.main.async {
                    switch transition {
                    case .pressed:
                        guard !self.isShortcutCurrentlyPressed else { return }
                        self.isShortcutCurrentlyPressed = true
                        ClickyLogger.info("[SHORTCUT]", "NSEvent monitor detected .pressed transition")
                        self.shortcutTransitionPublisher.send(.pressed)
                    case .released:
                        guard self.isShortcutCurrentlyPressed else { return }
                        self.isShortcutCurrentlyPressed = false
                        ClickyLogger.info("[SHORTCUT]", "NSEvent monitor detected .released transition")
                        self.shortcutTransitionPublisher.send(.released)
                    case .none:
                        break
                    }
                }
            }
            ClickyLogger.success("[SHORTCUT]", "NSEvent global monitor successfully registered")
        }

        guard globalEventTap == nil else {
            ClickyLogger.info("[SHORTCUT]", "SHORTCUT handler deduplicated (tap already active)")
            return
        }

        let monitoredEventTypes: [CGEventType] = [.flagsChanged, .keyDown, .keyUp]
        let eventMask = monitoredEventTypes.reduce(CGEventMask(0)) { currentMask, eventType in
            currentMask | (CGEventMask(1) << eventType.rawValue)
        }

        let eventTapCallback: CGEventTapCallBack = { _, eventType, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let globalPushToTalkShortcutMonitor = Unmanaged<GlobalPushToTalkShortcutMonitor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            return globalPushToTalkShortcutMonitor.handleGlobalEventTap(
                eventType: eventType,
                event: event
            )
        }

        guard let globalEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            ClickyLogger.warning("[SHORTCUT]", "Could not create CGEvent tap (will rely on NSEvent global monitor)")
            print("⚠️ Global push-to-talk: couldn't create CGEvent tap")
            return
        }

        guard let globalEventTapRunLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            globalEventTap,
            0
        ) else {
            CFMachPortInvalidate(globalEventTap)
            ClickyLogger.error("[SHORTCUT]", "Failed to create event tap run loop source")
            print("⚠️ Global push-to-talk: couldn't create event tap run loop source")
            return
        }

        self.globalEventTap = globalEventTap
        self.globalEventTapRunLoopSource = globalEventTapRunLoopSource

        CFRunLoopAddSource(CFRunLoopGetMain(), globalEventTapRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: globalEventTap, enable: true)
        ClickyLogger.success("[SHORTCUT]", "CGEvent tap successfully created and enabled")
    }

    func stop() {
        ClickyLogger.info("[SHORTCUT]", "GlobalPushToTalkShortcutMonitor stopped")
        isShortcutCurrentlyPressed = false

        if let monitor = globalNSEventMonitor {
            NSEvent.removeMonitor(monitor)
            self.globalNSEventMonitor = nil
        }

        if let globalEventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), globalEventTapRunLoopSource, .commonModes)
            self.globalEventTapRunLoopSource = nil
        }

        if let globalEventTap {
            CGEvent.tapEnable(tap: globalEventTap, enable: false)
            CFMachPortInvalidate(globalEventTap)
            self.globalEventTap = nil
        }
    }

    private func handleGlobalEventTap(
        eventType: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            if let globalEventTap {
                CGEvent.tapEnable(tap: globalEventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if eventType == .keyDown && eventKeyCode == 53 {
            if !Self.isSynthesizingInput {
                triggerEscapePressedDeduplicated()
            }
        }

        let shortcutTransition = BuddyPushToTalkShortcut.shortcutTransition(
            for: eventType,
            keyCode: eventKeyCode,
            modifierFlagsRawValue: event.flags.rawValue,
            wasShortcutPreviouslyPressed: isShortcutCurrentlyPressed
        )

        switch shortcutTransition {
        case .none:
            break
        case .pressed:
            if !isShortcutCurrentlyPressed {
                isShortcutCurrentlyPressed = true
                shortcutTransitionPublisher.send(.pressed)
            }
        case .released:
            if isShortcutCurrentlyPressed {
                isShortcutCurrentlyPressed = false
                shortcutTransitionPublisher.send(.released)
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
