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
    private var currentActiveSessionDir: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let hover = NotchHoverMonitor(stateController: stateController)
        self.hoverMonitor = hover
        self.speechManager = SpeechRecognitionManager(stateController: stateController)
        self.alarmMonitor = ReminderAlarmMonitor(stateController: stateController)

        let wc = NotchWindowController(
            stateController: stateController,
            hoverMonitor: hover,
            onSubmitPrompt: { [weak self] promptText in
                self?.submitPrompt(promptText)
            },
            onReplyClarification: { [weak self] responseText in
                self?.replyToActiveSession(responseText)
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
        Task { @MainActor in
            do {
                let permissions = try await EventKitService.shared.requestAccess()
                if !permissions.calendarGranted || !permissions.reminderGranted {
                    self.stateController.systemStatusMessage = "ℹ️ Calendar/Reminder access limited in System Settings."
                }
            } catch {
                self.stateController.systemStatusMessage = "⚠️ EventKit error: \(error.localizedDescription)"
            }
            _ = await SystemNotificationService.shared.requestAuthorization()
        }
    }

    private func startClipboardObserver() {
        ClipboardMonitor.shared.startMonitoring(interval: 0.5)
    }

    private func startLiveTranscriptWatcher() {
        let brainDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".gemini/antigravity/brain")
        transcriptWatcher.startWatchingBrainDirectory(
            brainDirectory: brainDir,
            onSessionChanged: { [weak self] sessionDir in
                Task { @MainActor [weak self] in
                    self?.currentActiveSessionDir = sessionDir
                }
            },
            onEvent: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleTranscriptEvent(event)
                }
            }
        )
    }

    private func handleTranscriptEvent(_ event: TranscriptEvent) {
        switch event {
        case .taskCompleted(let summary):
            VoiceOverSpeaker.shared.speak(text: "Antigravity: Task selesai.", language: "id-ID")
            stateController.transition(to: .liveActivity(title: "✨ Task Done", countdown: "Complete"))
            CardDataStore.shared.items.insert(
                CardItem(title: "Antigravity Task Done", subtitle: summary, category: .prompts, badge: "AI Done", timestamp: "Just now"),
                at: 0
            )

        case .userClarificationNeeded(let question, let options):
            VoiceOverSpeaker.shared.speak(text: "Antigravity membutuhkan respon Anda.", language: "id-ID")
            stateController.setClarification(question: question, options: options)
            stateController.transition(to: .expanded)
            CardDataStore.shared.items.insert(
                CardItem(title: "Needs Clarification", subtitle: question, category: .prompts, badge: "Action", timestamp: "Just now"),
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
            submitPrompt(stateController.commandPrompt)
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

    public func replyToActiveSession(_ response: String) {
        let activeDir = currentActiveSessionDir
        Task { @MainActor in
            try? await ActiveSessionBridge.shared.sendClarificationResponse(response, sessionDirectory: activeDir)
            self.stateController.clearClarification()
            self.stateController.transition(to: .collapsed)
            CardDataStore.shared.items.insert(
                CardItem(title: "Answer Dispatched", subtitle: response, category: .prompts, badge: "Sent", timestamp: "Just now"),
                at: 0
            )
        }
    }

    public func submitPrompt(_ rawText: String) {
        let prompt = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            stateController.transition(to: .collapsed)
            return
        }

        let model = stateController.activeAIModel
        let geminiKey = KeychainManager.load(key: "notchdeck.gemini.apikey")
        let claudeKey = KeychainManager.load(key: "notchdeck.claude.apikey")
        let openAiKey = KeychainManager.load(key: "notchdeck.openai.apikey")
        let activeDir = currentActiveSessionDir

        Task { @MainActor in
            let lower = prompt.lowercased()
            if lower.contains("meeting") || lower.contains("ingatkan") || lower.contains("jadwal") || lower.contains("jam ") {
                if let detail = await ScheduleCoordinator.shared.processUtterance(prompt, apiKey: geminiKey) {
                    self.alarmMonitor?.scheduleAlarm(for: detail)
                }
            } else {
                let provider: AIProvider
                switch model {
                case "Claude Code": provider = .claudeCode
                case "Gemini Flash": provider = .gemini
                case "Codex": provider = .codex
                default: provider = .antigravity
                }

                if let res = try? await MultiAIClient.shared.prompt(
                    text: prompt,
                    provider: provider,
                    geminiApiKey: geminiKey,
                    claudeApiKey: claudeKey,
                    openAiApiKey: openAiKey,
                    activeBrainSessionDir: activeDir
                ) {
                    CardDataStore.shared.items.insert(
                        CardItem(title: "✨ \(model) Response", subtitle: res.text, category: .prompts, badge: "\(res.executionTimeMs)ms", timestamp: "Just now"),
                        at: 0
                    )
                }
            }

            self.stateController.commandPrompt = ""
            self.stateController.clearClarification()
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
