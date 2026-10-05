//
//  HomeSpaceWindowManager.swift
//  boringNotch (Izanotchy)
//
//  Manages the NSPanel lifecycle for Home Space (Chat & Action Studio).
//

import AppKit
import SwiftUI
import ClickyFoundation
import ClickyPlatform
import ClickyRoster
import ClickyAgent

/// Custom NSPanel that accepts keyboard focus and can reach top bezel wrapping notch
final class HomeSpacePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override var hidesOnDeactivate: Bool {
        get { false }
        set { }
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override func cancelOperation(_ sender: Any?) {
        HomeSpaceWindowManager.shared.hide()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            HomeSpaceWindowManager.shared.hide()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
public final class HomeSpaceWindowManager: ObservableObject {
    public static let shared = HomeSpaceWindowManager()

    private var panel: HomeSpacePanel?
    @Published public private(set) var isVisible = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            self.repositionToHostScreen()
        }
    }

    public static var hostScreen: NSScreen? {
        let physical = WindowPositionManager.physicalScreens()
        return physical.first(where: { $0.frame.origin == .zero && $0.frame.width > 0 })
            ?? physical.first
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    public func repositionToHostScreen() {
        guard let panel = panel, let screen = Self.hostScreen else { return }
        let width: CGFloat = 900
        let contentHeight: CGFloat = 580
        let screenFrame = screen.frame
        guard screenFrame.width >= 800 && screenFrame.height >= 500 else { return }

        let notchHeight: CGFloat = {
            if #available(macOS 12.0, *), screen.safeAreaInsets.top > 0 {
                return screen.safeAreaInsets.top
            }
            return max(32, screen.frame.maxY - screen.visibleFrame.maxY)
        }()
        let totalHeight: CGFloat = contentHeight + notchHeight
        let x = screenFrame.origin.x + (screenFrame.width / 2) - (width / 2)
        let targetY = screenFrame.origin.y + screenFrame.height - totalHeight
        let targetRect = NSRect(x: x, y: targetY, width: width, height: totalHeight)

        if panel.frame != targetRect {
            panel.setFrame(targetRect, display: true)
        }
        if isVisible {
            panel.orderFrontRegardless()
        }
    }

    public func ensureOrderFront() {
        guard let panel = panel, isVisible else { return }
        panel.orderFrontRegardless()
    }

    public func show(withPrompt prompt: String? = nil) {
        if panel == nil {
            createPanel()
        }

        guard let panel = panel, let screen = Self.hostScreen else { return }

        let width: CGFloat = 900
        let contentHeight: CGFloat = 580
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        // Exact physical notch height on macOS
        let notchHeight: CGFloat = {
            if #available(macOS 12.0, *), screen.safeAreaInsets.top > 0 {
                return screen.safeAreaInsets.top
            }
            return max(32, screen.frame.maxY - screen.visibleFrame.maxY)
        }()

        let totalHeight: CGFloat = contentHeight + notchHeight

        let x = screenFrame.origin.x + (screenFrame.width / 2) - (width / 2)
        // Opsi 1A: Card top hugs the physical notch with 0-gap wallpaper
        let targetY = screenFrame.origin.y + screenFrame.height - totalHeight

        let targetRect = NSRect(x: x, y: targetY, width: width, height: totalHeight)

        panel.setFrame(targetRect, display: true)
        if !isVisible {
            panel.alphaValue = 0.0
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1.0
            }
        } else {
            panel.alphaValue = 1.0
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        isVisible = true
        NotificationCenter.default.post(name: Notification.Name("HomeSpaceVisibilityDidChange"), object: true)
        ClickyLogger.info("[HOMESPACE]", "Home Space window presented (notch-wrapped at screen top - Persistent Workspace Mode)")
        CompanionRosterStore.shared.markAsRead(id: CompanionRosterStore.shared.activeCompanionId)

        if let prompt = prompt, !prompt.isEmpty {
            // Give window a brief moment to draw before triggering query
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                CompanionManager.shared.askViaText(prompt: prompt)
            }
        }
    }

    public func hide() {
        guard let panel = panel, isVisible else { return }

        NotificationCenter.default.post(name: Notification.Name("HomeSpaceVisibilityDidChange"), object: false)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                self?.isVisible = false
                ClickyLogger.info("[HOMESPACE]", "Home Space window closed")
                NotificationCenter.default.post(name: Notification.Name("HomeSpaceVisibilityDidChange"), object: false)
            }
        })
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    private func createPanel() {
        let width: CGFloat = 900
        let height: CGFloat = 612 // 580 card + 32 notch height
        let rect = NSRect(x: 0, y: 0, width: width, height: height)

        // Clean borderless panel that accepts keyboard input (NO .nonactivatingPanel, NO .hudWindow)
        let newPanel = HomeSpacePanel(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        newPanel.level = .mainMenu + 4
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false // SwiftUI renders the shadow on the NotchShape, eliminating 90-degree black bitmap artifact
        newPanel.isMovableByWindowBackground = false
        newPanel.hidesOnDeactivate = false
        newPanel.isFloatingPanel = true
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let rootView = HomeSpaceRootView(onClose: { [weak self] in
            self?.hide()
        })

        newPanel.contentView = NSHostingView(rootView: rootView)
        self.panel = newPanel
    }
}
