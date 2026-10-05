import SwiftUI
import AppKit
import Darwin

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
    private var codexActivityMonitorTask: Task<Void, Never>?
    private var lastCodexWorkingState = false
    private var instanceLockFD: Int32 = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireInstanceLock() else {
            // `swift run NotchDeck` can be invoked more than once while the
            // previous binary is still alive. Keep only one overlay process.
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        let hover = NotchHoverMonitor(stateController: stateController)
        self.hoverMonitor = hover
        self.speechManager = SpeechRecognitionManager(stateController: stateController)
        self.alarmMonitor = ReminderAlarmMonitor(stateController: stateController)

        let wc = NotchWindowController(
            stateController: stateController,
            hoverMonitor: hover,
            onAIModelSelected: { [weak self] modelID in
                self?.handleAIModelSelected(modelID)
            },
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
            },
            onAddSchedule: { [weak self] scheduleText in
                self?.addSchedulePrompt(scheduleText)
            }
        )
        self.windowController = wc
        wc.showWindow(nil)

        setupHotkeys()
        requestSystemPermissions()
        startClipboardObserver()
        startLiveTranscriptWatcher()
        startCodexActivityMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard instanceLockFD >= 0 else { return }
        flock(instanceLockFD, LOCK_UN)
        close(instanceLockFD)
        instanceLockFD = -1
    }

    private func acquireInstanceLock() -> Bool {
        let lockPath = "/tmp/notchdeck.instance.lock"
        let fd = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { return false }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return false
        }
        instanceLockFD = fd
        return true
    }

    private func startCodexActivityMonitor() {
        codexActivityMonitorTask?.cancel()
        codexActivityMonitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                if let snapshot = try? await CodexAppServerBridge.shared.currentActivitySnapshot() {
                    self?.handleCodexActivity(snapshot)
                }

                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }

    private func handleCodexActivity(_ snapshot: CodexAppServerBridge.ActivitySnapshot) {
        // Record Codex while idle too, so the compact bar does not fall back
        // to the default Antigravity provider.
        stateController.setProviderStatus(
            "Codex",
            status: snapshot.isWorking ? "Working" : "Ready",
            isActive: snapshot.isWorking
        )
        guard snapshot.isWorking != lastCodexWorkingState else { return }
        lastCodexWorkingState = snapshot.isWorking

        if snapshot.isWorking {
            stateController.showLiveActivity(
                title: "Codex • Working",
                countdown: "Working",
                for: "Codex"
            )
        } else {
            stateController.showLiveActivity(
                title: "Codex • Ready",
                countdown: "Ready",
                for: "Codex"
            )
        }
    }

    private func handleAIModelSelected(_ modelID: String) {
        guard modelID == "Codex" else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let session = try await CodexAppServerBridge.shared.connectToCurrentThread()
                let messages = session.messages.map {
                    ChatMessageItem(
                        id: $0.id,
                        sender: $0.sender,
                        text: $0.text,
                        isUser: $0.isUser,
                        timestamp: $0.timestamp
                    )
                }
                self.stateController.replaceChatMessages(messages, for: "Codex")
                self.stateController.systemStatusMessage = "Connected: \(session.title)"
            } catch {
                self.stateController.systemStatusMessage = "Codex session error: \(error.localizedDescription)"
            }
        }
    }

    private func requestSystemPermissions() {
        Task { @MainActor in
            _ = try? await EventKitService.shared.requestAccess()
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
                    // Register active conversation with agentapi bridge so the notch
                    // can send messages directly into the Antigravity 2.0 session.
                    await AntigravityAgentAPI.shared.setActiveConversation(sessionDirectory: sessionDir)
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
        case .userMessage(let text):
            // User's own message from the Antigravity conversation — show as a right-side bubble
            stateController.setProviderStatus("Antigravity", status: "Working", isActive: true)
            stateController.appendChatMessage(sender: "You", text: text, isUser: true, for: "Antigravity")

        case .taskCompleted(let summary):
            stateController.setProviderStatus("Antigravity", status: "Ready", isActive: false)
            VoiceOverSpeaker.shared.speak(text: "Antigravity: Task selesai.", language: "id-ID")
            stateController.appendChatMessage(sender: "Antigravity", text: summary, isUser: false, for: "Antigravity")
            stateController.showLiveActivity(title: "Antigravity • Ready", countdown: "Ready", for: "Antigravity")
            CardDataStore.shared.items.insert(
                CardItem(title: "Task Done", subtitle: summary, category: .prompts, badge: "Done", timestamp: "Just now"),
                at: 0
            )

        case .userClarificationNeeded(let question, let options):
            stateController.setProviderStatus("Antigravity", status: "Waiting", isActive: true)
            VoiceOverSpeaker.shared.speak(text: "Antigravity membutuhkan respon Anda.", language: "id-ID")
            stateController.appendChatMessage(sender: "Antigravity", text: question, isUser: false, for: "Antigravity")
            stateController.setClarification(question: question, options: options, for: "Antigravity")
            if stateController.activeAIModel == "Antigravity" {
                stateController.selectTab(.aiChat)
                stateController.transition(to: .expanded)
            }
            CardDataStore.shared.items.insert(
                CardItem(title: "Needs Clarification", subtitle: question, category: .prompts, badge: "Action", timestamp: "Just now"),
                at: 0
            )

        case .toolExecuted(let name, let summary):
            stateController.setProviderStatus("Antigravity", status: "Working", isActive: true)
            stateController.showLiveActivity(title: "Antigravity • \(name)", countdown: summary.isEmpty ? "Running" : summary, for: "Antigravity")

        case .streamingContent(let text):
            stateController.setProviderStatus("Antigravity", status: "Working", isActive: true)
            stateController.appendChatMessage(sender: "Antigravity", text: text, isUser: false, for: "Antigravity")

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
            do {
                try speechManager?.startRecording()
            } catch {
                stateController.systemStatusMessage = "Mic error: \(error.localizedDescription)"
                stateController.transition(to: .collapsed)
            }
        }
    }

    public func stopMicrophone() {
        speechManager?.stopRecording()
        if stateController.currentState == .voiceActive {
            stateController.transition(to: .collapsed)
        }
    }

    public func replyToActiveSession(_ response: String) {
        guard stateController.activeAIModel == "Antigravity" else {
            submitPrompt(response)
            return
        }

        Task { @MainActor in
            do {
                // Clarification replies use the same official Antigravity
                // transport as ordinary prompts. ActiveSessionBridge is only
                // for a locally spawned subprocess and must not be used here.
                try await AntigravityAgentAPI.shared.sendMessage(response)
                self.stateController.appendChatMessage(sender: "You", text: response, isUser: true, for: "Antigravity")
                self.stateController.clearClarification(for: "Antigravity")
                CardDataStore.shared.items.insert(
                    CardItem(title: "Answer Dispatched", subtitle: response, category: .prompts, badge: "Sent", timestamp: "Just now"),
                    at: 0
                )
            } catch {
                self.stateController.systemStatusMessage = "Dispatch error: \(error.localizedDescription)"
                CardDataStore.shared.items.insert(
                    CardItem(title: "Dispatch Failed", subtitle: error.localizedDescription, category: .prompts, badge: "Error", timestamp: "Just now"),
                    at: 0
                )
            }
        }
    }

    public func addSchedulePrompt(_ prompt: String) {
        let geminiKey = KeychainManager.load(key: "notchdeck.gemini.apikey")
        Task { @MainActor in
            if let detail = await ScheduleCoordinator.shared.processUtterance(prompt, apiKey: geminiKey) {
                self.alarmMonitor?.scheduleAlarm(for: detail)
            } else {
                CardDataStore.shared.addItem(CardItem(title: prompt, subtitle: "Schedule", category: .schedule, badge: "Upcoming"))
            }
        }
    }

    public func submitPrompt(_ rawText: String) {
        let prompt = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        let model = stateController.activeAIModel
        let geminiKey = KeychainManager.load(key: "notchdeck.gemini.apikey")
        let claudeKey = KeychainManager.load(key: "notchdeck.claude.apikey")
        let openAiKey = KeychainManager.load(key: "notchdeck.openai.apikey")
        let activeDir = currentActiveSessionDir

        // Append user bubble exactly once — the UI layer must NOT do this.
        stateController.appendChatMessage(sender: "You", text: prompt, isUser: true, for: model)

        Task { @MainActor in
            let lower = prompt.lowercased()
            if lower.contains("meeting") || lower.contains("ingatkan") || lower.contains("jadwal") || lower.contains("jam ") {
                self.addSchedulePrompt(prompt)
            } else {
                if model == "Codex" {
                    // Keep the compact status bar visible while the same
                    // Codex session is processing the request.
                    self.stateController.setProviderStatus("Codex", status: "Working", isActive: true)
                    self.stateController.showLiveActivity(
                        title: "Codex • Working",
                        countdown: "Working",
                        for: model
                    )
                    do {
                        let response = try await CodexAppServerBridge.shared.sendMessage(prompt)
                        self.stateController.appendChatMessage(
                            sender: "Codex ChatGPT",
                            text: response.text,
                            isUser: false,
                            for: model
                        )
                        CardDataStore.shared.items.insert(
                            CardItem(title: "Codex ChatGPT Response", subtitle: response.text, category: .prompts, badge: "App Server", timestamp: "Just now"),
                            at: 0
                        )
                        self.stateController.showLiveActivity(
                            title: "Codex • Ready",
                            countdown: "Ready",
                            for: model
                        )
                    } catch {
                        self.stateController.systemStatusMessage = "Codex ChatGPT error: \(error.localizedDescription)"
                        self.stateController.setProviderStatus("Codex", status: "Error", isActive: false)
                        self.stateController.showLiveActivity(
                            title: "Codex • Error",
                            countdown: "Error",
                            for: model
                        )
                    }
                    self.stateController.commandPrompt = ""
                    self.stateController.clearClarification(for: model)
                    return
                }

                // Determine provider to actually call.
                // "Antigravity" mode means the notch is observing an Antigravity session passively —
                // the notch chat input here acts as a quick AI assistant using the best available API key.
                let provider: AIProvider
                switch model {
                case "Claude Code":
                    provider = claudeKey?.isEmpty == false ? .claudeCode : (geminiKey?.isEmpty == false ? .gemini : .claudeCode)
                case "Gemini Flash":
                    provider = .gemini
                default:
                    // "Antigravity" mode: send directly into the active Antigravity 2.0
                    // conversation via agentapi send-message. The response will appear
                    // automatically via LiveTranscriptWatcher reading the updated transcript.
                    do {
                        self.stateController.setProviderStatus("Antigravity", status: "Working", isActive: true)
                        self.stateController.showLiveActivity(
                            title: "Antigravity • Working",
                            countdown: "Working",
                            for: "Antigravity"
                        )
                        try await AntigravityAgentAPI.shared.sendMessage(prompt)
                        // Don't append a response bubble — the real reply will stream in
                        // via the transcript watcher as Antigravity processes the message.
                    } catch AntigravityAgentAPI.AgentAPIError.noActiveConversation {
                        self.stateController.appendChatMessage(
                            sender: "Antigravity",
                            text: "Belum ada sesi Antigravity yang terdeteksi. Buka Antigravity 2.0 dan mulai percakapan, lalu pesan kamu akan tersambung otomatis.",
                            isUser: false,
                            for: "Antigravity"
                        )
                    } catch {
                        self.stateController.systemStatusMessage = "agentapi error: \(error.localizedDescription)"
                        self.stateController.setProviderStatus("Antigravity", status: "Error", isActive: false)
                    }
                    self.stateController.commandPrompt = ""
                    self.stateController.clearClarification()
                    return
                }

                do {
                    self.stateController.setProviderStatus(model, status: "Working", isActive: true)
                    let res = try await MultiAIClient.shared.prompt(
                        text: prompt,
                        provider: provider,
                        geminiApiKey: geminiKey,
                        claudeApiKey: claudeKey,
                        openAiApiKey: openAiKey,
                        activeBrainSessionDir: activeDir
                    )
                    self.stateController.appendChatMessage(sender: model, text: res.text, isUser: false, for: model)
                    self.stateController.setProviderStatus(model, status: "Ready", isActive: false)
                    CardDataStore.shared.items.insert(
                        CardItem(title: "\(model) Response", subtitle: res.text, category: .prompts, badge: "\(res.executionTimeMs)ms", timestamp: "Just now"),
                        at: 0
                    )
                } catch AIClientError.sessionUnavailable {
                    self.stateController.setProviderStatus(model, status: "Error", isActive: false)
                    self.stateController.appendChatMessage(
                        sender: "Antigravity",
                        text: "Tidak ada sesi Antigravity yang aktif. Buka Antigravity terlebih dahulu, lalu notch akan otomatis memantau percakapannya di sini.",
                        isUser: false,
                        for: "Antigravity"
                    )
                } catch {
                    self.stateController.setProviderStatus(model, status: "Error", isActive: false)
                    self.stateController.systemStatusMessage = "\(model) error: \(error.localizedDescription)"
                }
            }

            self.stateController.commandPrompt = ""
            self.stateController.clearClarification()
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
