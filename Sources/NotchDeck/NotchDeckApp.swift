import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: NotchWindowController?
    var stateController = NotchStateController()
    var hoverMonitor: NotchHoverMonitor?
    var speechManager: SpeechRecognitionManager?
    var alarmMonitor: ReminderAlarmMonitor?
    private var globalEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let wc = NotchWindowController(stateController: stateController)
        self.windowController = wc
        self.hoverMonitor = NotchHoverMonitor(stateController: stateController)
        self.speechManager = SpeechRecognitionManager(stateController: stateController)
        self.alarmMonitor = ReminderAlarmMonitor(stateController: stateController)
        wc.showWindow(nil)

        setupHotkeys()
    }

    private func setupHotkeys() {
        // Local Monitor (when NotchDeck is key/active)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.handleKey(keyCode: event.keyCode, flags: event.modifierFlags) {
                return nil
            }
            return event
        }

        // Global Monitor (when another app/IDE/browser is active)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                _ = self?.handleKey(keyCode: event.keyCode, flags: event.modifierFlags)
            }
        }
    }

    private func handleKey(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        let action = HotkeyManager.resolveAction(keyCode: keyCode, flags: flags)
        switch action {
        case .toggleExpand:
            let target: NotchState = self.stateController.currentState == .expanded ? .collapsed : .expanded
            self.stateController.transition(to: target)
            return true
        case .pushToTalk:
            if self.stateController.currentState == .voiceActive {
                self.speechManager?.stopRecording()
                self.submitCurrentPrompt()
            } else {
                self.stateController.transition(to: .voiceActive)
                try? self.speechManager?.startRecording()
            }
            return true
        case .dismiss:
            if self.stateController.currentState != .collapsed {
                self.speechManager?.stopRecording()
                self.stateController.transition(to: .collapsed)
                return true
            }
        case .none:
            break
        }
        return false
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
