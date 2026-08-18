import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: NotchWindowController?
    var stateController = NotchStateController()
    var hoverMonitor: NotchHoverMonitor?
    var speechManager: SpeechRecognitionManager?
    var alarmMonitor: ReminderAlarmMonitor?
    var transcriptWatcher = LiveTranscriptWatcher()
    private var globalEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let hover = NotchHoverMonitor(stateController: stateController)
        self.hoverMonitor = hover
        self.speechManager = SpeechRecognitionManager(stateController: stateController)
        self.alarmMonitor = ReminderAlarmMonitor(stateController: stateController)

        let wc = NotchWindowController(
            stateController: stateController,
            hoverMonitor: hover,
            onSubmitPrompt: { [weak self] in
                self?.submitCurrentPrompt()
            },
            onToggleMic: { [weak self] in
                self?.toggleMicrophone()
            },
            onStopMic: { [weak self] in
                self?.stopMicrophone()
            }
        )
        self.windowController = wc
        wc.showWindow(nil)

        setupHotkeys()
        requestSystemPermissions()
        startClipboardObserver()
        startLiveTranscriptWatcher()
    }

    private func requestSystemPermissions() {
        Task {
            _ = try? await EventKitService.shared.requestAccess()
            _ = await SystemNotificationService.shared.requestAuthorization()
        }
    }

    private func startClipboardObserver() {
        ClipboardMonitor.shared.startMonitoring(interval: 0.5)
    }

    private func startLiveTranscriptWatcher() {
        let brainDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".gemini/antigravity/brain")
        // Check for latest session transcript
        if let contents = try? FileManager.default.contentsOfDirectory(at: brainDir, includingPropertiesForKeys: [.contentModificationDateKey]),
           let latestSession = contents.filter({ $0.hasDirectoryPath }).sorted(by: {
               let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
               let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
               return d1 > d2
           }).first {
            let logFile = latestSession.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            transcriptWatcher.startWatching(fileURL: logFile) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleTranscriptEvent(event)
                }
            }
        }
    }

    private func handleTranscriptEvent(_ event: TranscriptEvent) {
        switch event {
        case .taskCompleted(let summary):
            VoiceOverSpeaker.shared.speak(text: "Antigravity: Task selesai.", language: "id-ID")
            stateController.transition(to: .liveActivity(title: "✨ Antigravity: Done", countdown: "Complete"))
            CardDataStore.shared.items.insert(
                CardItem(title: "Antigravity Task Done", subtitle: summary, category: .prompts, badge: "AI Done", timestamp: "Just now"),
                at: 0
            )

        case .userClarificationNeeded(let question, _):
            VoiceOverSpeaker.shared.speak(text: "Antigravity membutuhkan respon Anda.", language: "id-ID")
            stateController.transition(to: .liveActivity(title: "⚠️ Need Approval", countdown: "Action Req"))
            CardDataStore.shared.items.insert(
                CardItem(title: "Needs Approval", subtitle: question, category: .prompts, badge: "Action", timestamp: "Just now"),
                at: 0
            )

        case .toolExecuted(let name, let summary):
            stateController.transition(to: .liveActivity(title: "⚙️ \(name)", countdown: summary.isEmpty ? "Running" : summary))

        case .streamingContent(let text):
            stateController.commandPrompt = text

        case .none:
            break
        }
    }

    private func setupHotkeys() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.handleKey(keyCode: event.keyCode, flags: event.modifierFlags) {
                return nil
            }
            return event
        }

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
            toggleMicrophone()
            return true
        case .dismiss:
            if self.stateController.currentState != .collapsed {
                stopMicrophone()
                self.stateController.transition(to: .collapsed)
                return true
            }
        case .none:
            break
        }
        return false
    }

    public func toggleMicrophone() {
        if stateController.currentState == .voiceActive {
            speechManager?.stopRecording()
            submitCurrentPrompt()
        } else {
            stateController.transition(to: .voiceActive)
            try? speechManager?.startRecording()
        }
    }

    public func stopMicrophone() {
        speechManager?.stopRecording()
        if stateController.currentState == .voiceActive {
            stateController.transition(to: .collapsed)
        }
    }

    public func submitCurrentPrompt() {
        let prompt = stateController.commandPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            stateController.transition(to: .collapsed)
            return
        }

        let model = stateController.activeAIModel
        let geminiKey = KeychainManager.load(key: "notchdeck.gemini.apikey")
        let claudeKey = KeychainManager.load(key: "notchdeck.claude.apikey")

        Task { @MainActor in
            // Check if prompt is a schedule request
            let lower = prompt.lowercased()
            if lower.contains("meeting") || lower.contains("ingatkan") || lower.contains("jadwal") || lower.contains("jam ") {
                if let detail = await ScheduleCoordinator.shared.processUtterance(prompt, apiKey: geminiKey) {
                    self.alarmMonitor?.scheduleAlarm(for: detail)
                }
            } else {
                // Route to MultiAIClient
                let provider: AIProvider
                switch model {
                case "Claude Code": provider = .claudeCode
                case "Gemini Flash": provider = .gemini
                case "Codex": provider = .codex
                default: provider = .antigravity
                }

                if let res = try? await MultiAIClient.shared.prompt(text: prompt, provider: provider, geminiApiKey: geminiKey, claudeApiKey: claudeKey) {
                    CardDataStore.shared.items.insert(
                        CardItem(title: "✨ \(model) Response", subtitle: res.text, category: .prompts, badge: "\(res.executionTimeMs)ms", timestamp: "Just now"),
                        at: 0
                    )
                }
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
