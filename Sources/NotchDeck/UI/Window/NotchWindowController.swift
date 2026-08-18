import AppKit
import SwiftUI
import Combine

@MainActor
public final class NotchWindowController: NSWindowController {
    public let stateController: NotchStateController
    public let hoverMonitor: NotchHoverMonitor?
    private var cancellables = Set<AnyCancellable>()

    public init(
        stateController: NotchStateController,
        hoverMonitor: NotchHoverMonitor? = nil,
        onSubmitPrompt: (@MainActor (String) -> Void)? = nil,
        onReplyClarification: (@MainActor (String) -> Void)? = nil,
        onToggleMic: (@MainActor () -> Void)? = nil,
        onStopMic: (@MainActor () -> Void)? = nil,
        onAddSchedule: (@MainActor (String) -> Void)? = nil
    ) {
        self.stateController = stateController
        self.hoverMonitor = hoverMonitor
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let hasNotch = NotchGeometryCalculator.hasPhysicalNotch(screen: screen)
        let notchW   = NotchGeometryCalculator.notchWidth(for: screen)
        let initialFrame = NotchGeometryCalculator.calculateFrame(
            for: stateController.currentState,
            screen: screen
        )

        let panel = NotchPanel(contentRect: initialFrame)
        super.init(window: panel)

        let rootView = NotchRootView(
            stateController: stateController,
            hoverMonitor: hoverMonitor,
            hasPhysicalNotch: hasNotch,
            hardwareNotchWidth: notchW,
            onSubmitPrompt: onSubmitPrompt,
            onReplyClarification: onReplyClarification,
            onToggleMic: onToggleMic,
            onStopMic: onStopMic,
            onAddSchedule: onAddSchedule
        )

        // Use a container NSView to isolate NSHostingView from direct NSWindow constraint cycles.
        // This completely prevents AppKit _postWindowNeedsUpdateConstraints / SIGABRT crashes on macOS 26.
        let containerView = NSView(frame: NSRect(origin: .zero, size: initialFrame.size))
        containerView.autoresizingMask = [.width, .height]

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = []
        }
        containerView.addSubview(hostingView)

        panel.contentView = containerView

        observeStateChanges()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func observeStateChanges() {
        stateController.$currentState
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                // Defer frame resizing to the next runloop turn so SwiftUI finishes its current render pass.
                DispatchQueue.main.async {
                    self?.updateFrame(for: newState)
                }
            }
            .store(in: &cancellables)
    }

    public func updateFrame(for state: NotchState) {
        guard let window = self.window, let screen = window.screen ?? NSScreen.main else { return }

        if state == .hidden {
            window.orderOut(nil)
            return
        } else {
            if !window.isVisible {
                window.orderFrontRegardless()
            }
        }

        // Calculate hardware-accurate target frame
        let targetFrame = NotchGeometryCalculator.calculateFrame(for: state, screen: screen)

        // Avoid redundant animations if frame is already matching
        guard window.frame != targetFrame else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
        }
    }
}
