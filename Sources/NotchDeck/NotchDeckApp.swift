import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: NotchWindowController?
    var stateController = NotchStateController()
    var hoverMonitor: NotchHoverMonitor?
    var speechManager: SpeechRecognitionManager?
    var alarmMonitor: ReminderAlarmMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let wc = NotchWindowController(stateController: stateController)
        self.windowController = wc
        self.hoverMonitor = NotchHoverMonitor(stateController: stateController)
        self.speechManager = SpeechRecognitionManager(stateController: stateController)
        self.alarmMonitor = ReminderAlarmMonitor(stateController: stateController)
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
                if self.stateController.currentState == .voiceActive {
                    self.speechManager?.stopRecording()
                    self.submitCurrentPrompt()
                } else {
                    self.stateController.transition(to: .voiceActive)
                    try? self.speechManager?.startRecording()
                }
                return nil
            case .dismiss:
                if self.stateController.currentState != .collapsed {
                    self.speechManager?.stopRecording()
                    self.stateController.transition(to: .collapsed)
                    return nil
                }
            case .none:
                break
            }
            return event
        }
    }

    public func submitCurrentPrompt() {
        let prompt = stateController.commandPrompt
        guard !prompt.isEmpty else {
            stateController.transition(to: .collapsed)
            return
        }

        let apiKey = KeychainManager.load(key: "notchdeck.gemini.apikey")
        Task { @MainActor in
            if let detail = await ScheduleCoordinator.shared.processUtterance(prompt, apiKey: apiKey) {
                self.alarmMonitor?.scheduleAlarm(for: detail)
            }
            self.stateController.commandPrompt = ""
            self.stateController.transition(to: .collapsed)
        }
    }
}

@main
struct NotchDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
