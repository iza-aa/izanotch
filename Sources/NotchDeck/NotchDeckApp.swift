import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: NotchWindowController?
    var stateController = NotchStateController()
    var hoverMonitor: NotchHoverMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let wc = NotchWindowController(stateController: stateController)
        self.windowController = wc
        self.hoverMonitor = NotchHoverMonitor(stateController: stateController)
        wc.showWindow(nil)

        setupGlobalHotkeys()
    }

    private func setupGlobalHotkeys() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let action = HotkeyManager.resolveAction(keyCode: event.keyCode, flags: event.modifierFlags)
            switch action {
            case .toggleExpand:
                let target: NotchState = self.stateController.currentState == .expanded ? .collapsed : .expanded
                self.stateController.transition(to: target)
                return nil
            case .pushToTalk:
                let target: NotchState = self.stateController.currentState == .voiceActive ? .collapsed : .voiceActive
                self.stateController.transition(to: target)
                return nil
            case .dismiss:
                if self.stateController.currentState != .collapsed {
                    self.stateController.transition(to: .collapsed)
                    return nil
                }
            case .none:
                break
            }
            return event
        }
    }
}

@main
struct NotchDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("NotchDeck Settings & BYOK API Keys")
                .frame(width: 380, height: 260)
        }
    }
}
