//
//  CompanionManager.swift
//  leanring-buddy
//
//  Central state manager for the companion voice mode. Owns the push-to-talk
//  pipeline (dictation manager + global shortcut monitor + overlay) and
//  exposes observable voice state for the panel UI.
//

import AVFoundation
import Combine
import Defaults
import Foundation
import ScreenCaptureKit
import Speech
import SwiftUI
import Vision

enum CompanionVoiceState {
    case idle
    case listening
    case processing
    case responding
}

/// Metadata about the user's active frontmost application window

@MainActor
final class CompanionManager: ObservableObject {
    static let shared = CompanionManager()

    func enableCursor() {
        setClickyCursorEnabled(true)
    }

    func disableCursor() {
        setClickyCursorEnabled(false)
    }

    func toggleHomeSpace() {
        if let host = CompanionUIHostRegistry.shared {
            host.toggleHomeSpace()
        } else {
            HomeSpaceWindowManager.shared.toggle()
        }
    }

    func openHomeSpace() {
        if let host = CompanionUIHostRegistry.shared {
            host.showHomeSpace()
        } else {
            HomeSpaceWindowManager.shared.show()
        }
    }

    func toggleHUD() {}

    @Published var proposedComputerUseAction: ComputerUseProposedAction? = nil
    @Published public var pendingComputerUseRequest: ComputerUseRequest? = nil

    @Published internal(set) var voiceState: CompanionVoiceState = .idle
    @Published internal(set) var lastTranscript: String?
    @Published internal(set) var currentAudioPowerLevel: CGFloat = 0
    @Published internal(set) var hasAccessibilityPermission = false
    @Published internal(set) var hasScreenRecordingPermission = false
    @Published internal(set) var hasMicrophonePermission = false
    @Published internal(set) var hasSpeechRecognitionPermission = false
    @Published internal(set) var hasScreenContentPermission = false

    /// Screen location (global AppKit coords) of a detected UI element the
    /// buddy should fly to and point at. Parsed from Claude's response;
    /// observed by BlueCursorView to trigger the flight animation.
    @Published var detectedElementScreenLocation: CGPoint?
    /// The display frame (global AppKit coords) of the screen the detected
    /// element is on, so BlueCursorView knows which screen overlay should animate.
    @Published var detectedElementDisplayFrame: CGRect?
    /// Custom speech bubble text for the pointing animation. When set,
    /// BlueCursorView uses this instead of a random pointer phrase.
    @Published var detectedElementBubbleText: String?
    /// Target halo radius in points (parsed from [TARGET:x,y,r:label])
    @Published var detectedElementTargetRadius: CGFloat = 35.0
    /// Short element label for the pointing bubble
    @Published var detectedElementLabel: String?
    /// Whether streaming has already triggered flight for the active turn
    var hasTriggeredStreamingFlight: Bool = false
    /// Hotfix #3: expression yang dipakai flight streaming (UNVERIFIED) —
    /// diverifikasi vs expression final di fallback; dibersihkan tiap turn baru.
    var flownTargetExpression: String? = nil
    /// Buffer of raw incoming streaming chunks to parse early tags
    var accumulatedRawStreamingText: String = ""
    /// Current frontmost active application work surface
    var currentActiveWorkSurface: ActiveWorkSurface?
    /// Watchdog work item to ensure detectedElementScreenLocation never traps cursor
    var flightWatchdogWorkItem: DispatchWorkItem?
    /// Plan sinkron-teks S3: estimasi durasi TTS terakhir (dtk) untuk hold bubble.
    var lastTTSDurationEstimate: TimeInterval = 0
    /// Plan sinkron-teks S3: kapan flight terakhir selesai (untuk hold bubble).
    var lastFlightEndEstimate: Date? = nil

    // MARK: - Onboarding Video State (shared across all screen overlays)

    @Published var onboardingVideoPlayer: AVPlayer?
    @Published var showOnboardingVideo: Bool = false
    @Published var onboardingVideoOpacity: Double = 0.0
    var onboardingVideoEndObserver: NSObjectProtocol?
    var onboardingDemoTimeObserver: Any?

    // MARK: - Onboarding Prompt Bubble

    /// Text streamed character-by-character on the cursor after the onboarding video ends.
    @Published var onboardingPromptText: String = ""
    @Published var onboardingPromptOpacity: Double = 0.0
    @Published var showOnboardingPrompt: Bool = false

    // MARK: - Onboarding Music

    var onboardingMusicPlayer: AVAudioPlayer?
    var onboardingMusicFadeTimer: Timer?

    let buddyDictationManager = BuddyDictationManager()
    let globalPushToTalkShortcutMonitor = GlobalPushToTalkShortcutMonitor()
    let overlayWindowManager = OverlayWindowManager.shared

    // MARK: - Streaming Response Bubble State

    /// The text currently being streamed from the AI response.
    @Published var streamingResponseText: String = ""
    /// Whether the response bubble is currently active.
    @Published var isShowingStreamingResponse: Bool = false
    /// Opacity of the response bubble for smooth transitions.
    @Published var streamingResponseOpacity: Double = 0.0
    /// Work item to auto-hide the response bubble after reading delay.
    var responseBubbleHideWorkItem: DispatchWorkItem?

    public var isResponding: Bool {
        voiceState == .responding || isShowingStreamingResponse
    }

    public var currentStreamingResponse: String {
        streamingResponseText
    }

    /// On-Device Apple Foundation Models engine (replaces legacy cloud APIs)
    var claudeAPI: SiriAIEngine {
        SiriAIEngine.shared
    }

    lazy var elevenLabsTTSClient: ElevenLabsTTSClient = {
        return ElevenLabsTTSClient(proxyURL: "https://your-worker-name.your-subdomain.workers.dev/tts")
    }()

    #if DEBUG
    // TASK-044 Ground-Truth Oracle E2E Reporting Contract
    public var activeE2ERunId: String? = nil
    public static func postE2EDone(runId: String? = nil, concluded: Bool, validatorIsDone: Bool, deliverableSaved: Bool) {
        let rId = runId ?? CompanionManager.shared.activeE2ERunId
        guard let resolvedRunId = rId else { return }
        let info: [String: Any] = [
            "runId": resolvedRunId,
            "concluded": concluded,
            "validatorIsDone": validatorIsDone,
            "deliverableSaved": deliverableSaved
        ]
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("iza.e2e.done"),
            object: nil,
            userInfo: info,
            deliverImmediately: true
        )
        ClickyLogger.info("[E2E_IPC]", "Posted iza.e2e.done: runId=\(resolvedRunId), concluded=\(concluded), isDone=\(validatorIsDone), deliverable=\(deliverableSaved)")
        CompanionManager.shared.activeE2ERunId = nil
    }
    #endif
    /// Conversation history so Claude remembers prior exchanges within a session.
    /// Each entry is the user's transcript, the stripped spoken text, and the raw response
    /// (preserving [POINT:x,y:label] tags) so subsequent turns can imitate the tag format.
    var conversationHistory: [(userTranscript: String, assistantResponse: String, rawResponseWithTags: String, groundingHit: Bool)] = []

    /// Published transcript for Home Space chat view
    @Published public var chatMessages: [HomeSpaceChatMessage] = []

    /// Dedicated live streaming state for Home Space chat view
    @Published public var homeSpaceStreamingText: String = ""
    @Published public var isHomeSpaceStreaming: Bool = false
    var streamingWatchdogWorkItem: DispatchWorkItem?

    func armStreamingWatchdog(timeout: TimeInterval = 6.0) {
        streamingWatchdogWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.isHomeSpaceStreaming {
                ClickyLogger.warning("[STREAM_WATCHDOG]", "Streaming chunk timeout (\(timeout)s) reached without clean handover. Forcing safe teardown.")
                let fallbackText = self.homeSpaceStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isHomeSpaceStreaming = false
                self.homeSpaceStreamingText = ""
                if !fallbackText.isEmpty {
                    self.appendChatMessage(HomeSpaceChatMessage(isUser: false, text: fallbackText))
                }
                self.voiceState = .idle
                CompanionRosterStore.shared.updateCompanionStatus(id: self.activeBuddy.id, status: .idle)
            }
        }
        streamingWatchdogWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    func disarmStreamingWatchdog() {
        streamingWatchdogWorkItem?.cancel()
        streamingWatchdogWorkItem = nil
    }

    /// Current autonomous task goal being executed across multi-step iterations
    public var ongoingTaskGoal: String? = nil
    /// Session-level pre-approval granted by user via "Allow once" or "Always allow" for ongoing task
    @Published public var isTaskSessionPreApproved: Bool = false

    // ReAct loop consent-gate state — stores pending loop state while awaiting user approval
    internal var pendingReActMessages: [[String: Any]] = []
    var pendingReActSystemPrompt: String = ""
    var pendingReActNativeTools: [[String: Any]] = []
    var pendingReActScreenCaptures: [CompanionScreenCapture] = []
    var pendingReActOriginalTranscript: String = ""

    public var isProcessingTask: Bool {
        voiceState == .processing || isHomeSpaceStreaming || isTaskSessionPreApproved
    }

    public var isSiriAI: Bool {
        Defaults[.selectedAIAssistant] == "Siri AI" || Defaults[.selectedAIAssistant] == "Siri AI (AFM)"
    }

    static let initialSessions: [BuddySession] = [
        BuddySession(
            name: "Research Buddy",
            roleDescription: "Competitor & web research specialist",
            avatarColorHex: "#4ADE80",
            ringColorHex: "#FBCFE8",
            timestampString: "Just now",
            lastSnippet: "Ready to research your active screen & documents.",
            messages: []
        ),
        BuddySession(
            name: "Shippy",
            roleDescription: "Single-screen workspace & code deployer",
            avatarColorHex: "#818CF8",
            ringColorHex: "#FEF08A",
            timestampString: "Just now",
            lastSnippet: "Ready to assist with Xcode and workspaces.",
            messages: []
        ),
        BuddySession(
            name: "Clicky Screen Assistant",
            roleDescription: "Screen navigation & Computer Use executor",
            avatarColorHex: "#38BDF8",
            ringColorHex: "#BAE6FD",
            timestampString: "Just now",
            lastSnippet: "Ready to guide, point, and execute tasks.",
            messages: []
        )
    ]

    /// Multi-Buddy Sessions list (Synchronized 1:1 with CompanionRosterStore)
    @Published public var sessions: [BuddySession] = initialSessions
    @Published public var activeSessionID: UUID = initialSessions[0].id

    /// Single Anchored Computer Workspace Payload (xAI Grok Bot Paradigm)
    @Published public var activeComputerPayload: ComputerCardPayload? = nil
    @Published public var isWorkspaceCollapsed: Bool = false

    public var activeBuddy: BuddySession {
        sessions.first(where: { $0.id == activeSessionID }) ?? (sessions.first ?? Self.initialSessions[0])
    }

    // MARK: - Stored Properties (Decomposed Extensions)

    var grounderTask: Task<Void, Never>?
    var grounderEarlyExpression: String? = nil
    var groundingHoldActive: Bool = false
    var pendingGroundedDelivery: (spoken: String, final: String)? = nil
    var grounderEarlyFiredThisTurn: Bool = false
    var lastGrounderExpression: String? = nil

    @Published var isClickyCursorEnabled: Bool = Defaults[.cursorAssistantEnabled] {
        didSet {
            Defaults[.cursorAssistantEnabled] = isClickyCursorEnabled
            UserDefaults.standard.set(isClickyCursorEnabled, forKey: "isClickyCursorEnabled")
            transientHideTask?.cancel()
            transientHideTask = nil

            ClickyLogger.info("[TOGGLE]", "isClickyCursorEnabled changed to \(isClickyCursorEnabled)")

            if isClickyCursorEnabled {
                overlayWindowManager.hasShownOverlayBefore = true
                overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
                isOverlayVisible = true
            } else {
                overlayWindowManager.hideOverlay()
                isOverlayVisible = false
            }
        }
    }
    @Published var hasSubmittedEmail: Bool = UserDefaults.standard.bool(forKey: "hasSubmittedEmail")

    var currentResponseTask: Task<Void, Never>?
    var shortcutTransitionCancellable: AnyCancellable?
    var voiceStateCancellable: AnyCancellable?
    var audioPowerCancellable: AnyCancellable?
    var accessibilityCheckTimer: Timer?
    var pendingKeyboardShortcutStartTask: Task<Void, Never>?
    var transientHideTask: Task<Void, Never>?
    @Published var isOverlayVisible: Bool = false
    @Published internal(set) var isRequestingScreenContent: Bool = false
    @Published public var activeCompanion: CompanionProfile = CompanionProfile.defaultResearchBuddy
    @Published var selectedModel: String = Defaults[.selectedAIModel]
}
