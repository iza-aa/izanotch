import Foundation
import AppKit
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
        enterDebounceDuration: TimeInterval = 0.1,
        exitDebounceDuration: TimeInterval = 0.5
    ) {
        self.stateController = stateController
        self.enterDebounceDuration = enterDebounceDuration
        self.exitDebounceDuration = exitDebounceDuration
    }

    public func mouseEntered() {
        exitTask?.cancel()
        exitTask = nil

        // Allow hover-expansion from collapsed OR liveActivity states
        switch stateController.currentState {
        case .collapsed, .liveActivity:
            break
        default:
            return
        }

        enterTask?.cancel()
        enterTask = Task { @MainActor in
            let nano = UInt64(enterDebounceDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nano)
            guard !Task.isCancelled else { return }
            
            switch self.stateController.currentState {
            case .collapsed, .liveActivity:
                self.stateController.transition(to: .expanded)
            default:
                break
            }
        }
    }

    public func mouseExited() {
        enterTask?.cancel()
        enterTask = nil

        guard stateController.currentState == .expanded else { return }

        // Prevent false exit events caused by SwiftUI re-layout / window animation:
        // If the mouse pointer is physically still inside the window frame, ignore the exit event.
        if isMouseInsideNotchWindow() {
            return
        }

        exitTask?.cancel()
        exitTask = Task { @MainActor in
            let nano = UInt64(exitDebounceDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nano)
            guard !Task.isCancelled else { return }

            // Re-verify mouse location when debounce timer fires
            if self.isMouseInsideNotchWindow() {
                return
            }

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

    /// Verifies if the physical mouse pointer is currently located inside the NotchPanel window frame.
    private func isMouseInsideNotchWindow() -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        for window in NSApp.windows where window is NotchPanel {
            if window.isVisible && window.frame.contains(mouseLocation) {
                return true
            }
        }
        return false
    }
}
