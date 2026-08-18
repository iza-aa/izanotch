import Foundation
import Combine

@MainActor
public final class NotchHoverMonitor: ObservableObject {
    private let stateController: NotchStateController
    public let enterDebounceDuration: TimeInterval
    public let exitDebounceDuration: TimeInterval
    private var enterTask: Task<Void, Never>?
    private var exitTask: Task<Void, Never>?

    public init(
        stateController: NotchStateController,
        enterDebounceDuration: TimeInterval = 0.15,
        exitDebounceDuration: TimeInterval = 0.6
    ) {
        self.stateController = stateController
        self.enterDebounceDuration = enterDebounceDuration
        self.exitDebounceDuration = exitDebounceDuration
    }

    public func mouseEntered() {
        exitTask?.cancel()
        exitTask = nil

        guard stateController.currentState == .collapsed else { return }

        enterTask?.cancel()
        enterTask = Task { @MainActor in
            let nano = UInt64(enterDebounceDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nano)
            guard !Task.isCancelled else { return }
            if self.stateController.currentState == .collapsed {
                self.stateController.transition(to: .expanded)
            }
        }
    }

    public func mouseExited() {
        enterTask?.cancel()
        enterTask = nil

        guard stateController.currentState == .expanded else { return }

        exitTask?.cancel()
        exitTask = Task { @MainActor in
            let nano = UInt64(exitDebounceDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nano)
            guard !Task.isCancelled else { return }
            if self.stateController.currentState == .expanded {
                self.stateController.transition(to: .collapsed)
            }
        }
    }

    public func cancelAll() {
        enterTask?.cancel()
        enterTask = nil
        exitTask?.cancel()
        exitTask = nil
    }
}
