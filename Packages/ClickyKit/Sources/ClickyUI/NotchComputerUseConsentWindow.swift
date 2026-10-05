//
//  NotchComputerUseConsentWindow.swift
//  izaNotch (Izanotchy)
//
//  Floating drop-down panel anchored directly beside the MacBook Notch
//  displaying the authentic "Wants to use your Mac" Computer Use Consent Card.
//

import AppKit
import SwiftUI
import Defaults
import ClickyFoundation
import ClickyAgent
import ClickySpeech

@MainActor
public final class NotchComputerUseConsentWindow: ObservableObject {
    public static let shared = NotchComputerUseConsentWindow()

    private var panel: NSPanel?
    @Published public private(set) var isVisible = false

    private init() {}

    public func show(with request: ComputerUseRequest) {
        if panel == nil {
            createPanel()
        }

        guard let panel = panel, let screen = NSScreen.main else { return }

        let cardWidth: CGFloat = 350
        let cardHeight: CGFloat = 380
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        // Position anchored directly to the left of the Floating Companion Rail (Sidebar) - Opsi 1A
        let railTrailingMargin: CGFloat = 68.0
        let cardSpacing: CGFloat = 12.0
        var x = visibleFrame.maxX - railTrailingMargin - cardWidth - cardSpacing
        if x < visibleFrame.minX + 16 {
            x = visibleFrame.minX + 16
        }

        let targetY = visibleFrame.maxY - cardHeight - 16
        let targetRect = NSRect(x: x, y: targetY, width: cardWidth, height: cardHeight)

        // Update hosting content
        let contentView = ComputerUseConsentCardView(
            request: request,
            onAllowOnce: { [weak self] in
                self?.dismiss()
                if CompanionManager.shared.hasPendingReActMessages {
                    CompanionManager.shared.approveReActLoopOnce()
                } else {
                    CompanionManager.shared.approveComputerUseOnce()
                }
            },
            onAlwaysAllow: { [weak self] in
                self?.dismiss()
                if CompanionManager.shared.hasPendingReActMessages {
                    CompanionManager.shared.alwaysAllowAndResumeReActLoop()
                } else {
                    CompanionManager.shared.alwaysAllowComputerUse()
                }
            },
            onNotNow: { [weak self] in
                self?.dismiss()
                CompanionManager.shared.rejectComputerUse()
            },
            onClose: { [weak self] in
                self?.dismiss()
                CompanionManager.shared.rejectComputerUse()
            },
            onHistory: {
                HomeSpaceWindowManager.shared.show()
            }
        )

        panel.contentView = NSHostingView(rootView: contentView)

        if !isVisible {
            // Start 16pt to the right, springing smoothly out from the companion avatar on the sidebar
            let startRect = NSRect(x: x + 16, y: targetY, width: cardWidth, height: cardHeight)
            panel.setFrame(startRect, display: false)
            panel.alphaValue = 0.0
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetRect, display: true)
                panel.animator().alphaValue = 1.0
            } completionHandler: { [weak self] in
                Task { @MainActor in
                    self?.isVisible = true
                }
            }

            ClickySoundEngine.shared.play(.question)
        }
    }

    public func dismiss() {
        guard isVisible, let panel = panel else { return }

        let currentFrame = panel.frame
        let dismissFrame = NSRect(
            x: currentFrame.origin.x + 16,
            y: currentFrame.origin.y,
            width: currentFrame.width,
            height: currentFrame.height
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(dismissFrame, display: true)
            panel.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                panel.orderOut(nil)
                self?.isVisible = false
            }
        }
    }

    private func createPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 380),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.isMovableByWindowBackground = false
        p.ignoresMouseEvents = false

        self.panel = p
    }
}
