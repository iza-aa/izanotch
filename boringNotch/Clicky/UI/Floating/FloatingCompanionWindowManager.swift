//
//  FloatingCompanionWindowManager.swift
//  boringNotch (Izanotchy)
//
//  Manages the lifecycle and positioning of the floating Aqua Glass Sphere
//  companion panel anchored to the right edge of the screen.
//

import AppKit
import SwiftUI
import Defaults

@MainActor
public final class FloatingCompanionWindowManager: ObservableObject {
    public static let shared = FloatingCompanionWindowManager()

    private var panel: NSPanel?
    private var isVisible = false
    private var currentYFraction: CGFloat = 0.5 // Mid-screen by default

    private init() {}

    public func setup() {
        guard Defaults[.floatingCompanionSphereEnabled] else { return }
        show()
    }

    public func show() {
        guard Defaults[.floatingCompanionSphereEnabled] else { return }

        if panel == nil {
            createPanel()
        }

        updatePosition()
        panel?.orderFrontRegardless()
        isVisible = true
        ClickyLogger.info("[FLOATING]", "Companion sphere shown on right screen edge")
    }

    public func hide() {
        panel?.orderOut(nil)
        isVisible = false
        ClickyLogger.info("[FLOATING]", "Companion sphere hidden")
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    private func createPanel() {
        guard let screen = NSScreen.main else { return }

        let size: CGFloat = 64
        let initialRect = NSRect(
            x: screen.visibleFrame.maxX - size - 8,
            y: screen.visibleFrame.midY - (size / 2),
            width: size,
            height: size
        )

        let newPanel = NSPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.level = .floating
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.isMovableByWindowBackground = false
        newPanel.ignoresMouseEvents = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let sphereView = AquaGlassSphereView(onToggleHomeSpace: {
            HomeSpaceWindowManager.shared.toggle()
        })

        newPanel.contentView = NSHostingView(rootView: sphereView)
        self.panel = newPanel
    }

    public func updatePosition() {
        guard let panel = panel, let screen = NSScreen.main else { return }
        let size: CGFloat = 64
        let x = screen.visibleFrame.maxX - size - 6
        let minY = screen.visibleFrame.minY + 40
        let maxY = screen.visibleFrame.maxY - size - 40
        let y = minY + (maxY - minY) * currentYFraction

        panel.setFrame(NSRect(x: x, y: y, width: size, height: size), display: true)
    }

    public func setVerticalFraction(_ fraction: CGFloat) {
        currentYFraction = max(0.05, min(0.95, fraction))
        updatePosition()
    }
}
