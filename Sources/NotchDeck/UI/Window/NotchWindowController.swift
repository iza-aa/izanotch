import AppKit
import SwiftUI
import Combine

@MainActor
public final class NotchWindowController: NSWindowController {
    public let stateController: NotchStateController
    private var cancellables = Set<AnyCancellable>()

    public init(stateController: NotchStateController) {
        self.stateController = stateController
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let hasNotch = NotchGeometryCalculator.hasPhysicalNotch(screen: screen)
        let initialFrame = NotchGeometryCalculator.calculateFrame(
            for: stateController.currentState,
            screenFrame: screen.frame,
            hasPhysicalNotch: hasNotch
        )

        let panel = NotchPanel(contentRect: initialFrame)
        super.init(window: panel)

        let rootView = NotchRootView(stateController: stateController, hasPhysicalNotch: hasNotch)
        let hostingView = NSHostingView(rootView: rootView)
        panel.contentView = hostingView

        observeStateChanges()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func observeStateChanges() {
        stateController.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.updateFrame(for: newState)
            }
            .store(in: &cancellables)
    }

    public func updateFrame(for state: NotchState) {
        guard let window = self.window, let screen = window.screen ?? NSScreen.main else { return }
        let hasNotch = NotchGeometryCalculator.hasPhysicalNotch(screen: screen)
        let targetFrame = NotchGeometryCalculator.calculateFrame(
            for: state,
            screenFrame: screen.frame,
            hasPhysicalNotch: hasNotch
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
        }
    }
}
