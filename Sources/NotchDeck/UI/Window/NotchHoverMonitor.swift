import Foundation
import Combine

@MainActor
public final class NotchHoverMonitor: ObservableObject {
    private let stateController: NotchStateController
    public let debounceDuration: TimeInterval
    private var hoverTask: Task<Void, Never>?

    public init(stateController: NotchStateController, debounceDuration: TimeInterval = 0.2) {
        self.stateController = stateController
        self.debounceDuration = debounceDuration
    }

    public func mouseEntered() {
        hoverTask?.cancel()
        hoverTask = Task { @MainActor in
            let nano = UInt64(debounceDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nano)
            guard !Task.isCancelled else { return }
            if self.stateController.currentState == .collapsed {
                self.stateController.transition(to: .expanded)
            }
        }
    }

    public func mouseExited() {
        hoverTask?.cancel()
        if stateController.currentState == .expanded {
            stateController.transition(to: .collapsed)
        }
    }
}
