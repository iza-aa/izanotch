//
//  CompanionManager+ComputerUse.swift
//  izaNotch (Izanotchy)
//
//  Decomposed extension for CompanionManager.
//

import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Defaults
import Foundation

extension CompanionManager {
    // MARK: - ReAct Loop Consent Resume

    /// Called when user approves computer use for the pending ReAct loop turn.
    /// Resumes the loop with isTaskSessionPreApproved = true so input tools are allowed.
    public func approveReActLoopAndResume() {
        guard !pendingReActMessages.isEmpty else { return }
        ClickyLogger.info("[CONSENT_GATE]", "User approved ReAct loop continuation. Resuming with pre-approval.")
        NotchComputerUseConsentWindow.shared.dismiss()
        self.pendingComputerUseRequest = nil
        self.isTaskSessionPreApproved = true

        let msgs = self.pendingReActMessages
        let sysPrompt = self.pendingReActSystemPrompt
        let tools = self.pendingReActNativeTools
        let captures = self.pendingReActScreenCaptures
        let originalTranscript = self.pendingReActOriginalTranscript

        // Clear pending state
        self.pendingReActMessages = []
        self.pendingReActSystemPrompt = ""
        self.pendingReActNativeTools = []
        self.pendingReActScreenCaptures = []
        self.pendingReActOriginalTranscript = ""

        self.voiceState = .processing
        self.hideResponseBubbleImmediately()

        currentResponseTask?.cancel()
        currentResponseTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Restart the full voice processing pipeline with pre-approval
            // The stored messages already include all observation turns done so far;
            // the model will continue from where it left off (now allowed to call input tools)
            self.sendTranscriptToClaudeWithScreenshot(transcript: "[Computer use approved for this turn] " + originalTranscript)
        }
    }

    /// Called when user clicks Allow Once on the consent card for ReAct loop
    public func approveReActLoopOnce() {
        approveReActLoopAndResume()
    }

    /// Called when user clicks Always Allow on the consent card for ReAct loop
    public func alwaysAllowAndResumeReActLoop() {
        Defaults[.alwaysAllowComputerUse] = true
        approveReActLoopAndResume()
    }

    // MARK: - Authentic HeyClicky Computer Use ("Wants to use your Mac")

    public func approveComputerUseOnce() {
        guard let request = pendingComputerUseRequest else { return }
        ClickyLogger.info("[COMPUTER_USE]", "User clicked Allow Once for action: \(request.payload.rawDetails)")
        NotchComputerUseConsentWindow.shared.dismiss()
        self.pendingComputerUseRequest = nil
        self.isTaskSessionPreApproved = true
        self.voiceState = .processing

        if ClickyDeterministicPipeline.shared.pendingConsentContinuation != nil {
            ClickyDeterministicPipeline.shared.resumePendingConsent(approved: true)
            return
        }

        self.hideResponseBubbleImmediately()
        let goal = self.ongoingTaskGoal ?? request.payload.rawDetails

        currentResponseTask?.cancel()
        currentResponseTask = Task { @MainActor in
            await self.executeAndContinueAutonomousLoop(payload: request.payload, initialGoal: goal)
        }
    }

    public func alwaysAllowComputerUse() {
        guard let request = pendingComputerUseRequest else { return }
        ClickyLogger.info("[COMPUTER_USE]", "User enabled Always Allow for action: \(request.payload.rawDetails)")
        Defaults[.alwaysAllowComputerUse] = true
        self.isTaskSessionPreApproved = true
        NotchComputerUseConsentWindow.shared.dismiss()
        self.pendingComputerUseRequest = nil
        self.voiceState = .processing

        if ClickyDeterministicPipeline.shared.pendingConsentContinuation != nil {
            ClickyDeterministicPipeline.shared.resumePendingConsent(approved: true)
            return
        }

        self.hideResponseBubbleImmediately()
        let goal = self.ongoingTaskGoal ?? request.payload.rawDetails

        currentResponseTask?.cancel()
        currentResponseTask = Task { @MainActor in
            await self.executeAndContinueAutonomousLoop(payload: request.payload, initialGoal: goal)
        }
    }

    public func rejectComputerUse() {
        guard let request = pendingComputerUseRequest else { return }
        ClickyLogger.info("[COMPUTER_USE]", "User rejected action: \(request.payload.rawDetails)")
        ClickySoundEngine.shared.play(.close)
        NotchComputerUseConsentWindow.shared.dismiss()
        self.pendingComputerUseRequest = nil
        self.isTaskSessionPreApproved = false
        self.ongoingTaskGoal = nil
        self.voiceState = .idle

        if ClickyDeterministicPipeline.shared.pendingConsentContinuation != nil {
            ClickyDeterministicPipeline.shared.resumePendingConsent(approved: false)
            return
        }

        self.hideResponseBubbleImmediately()
        appendChatMessage(HomeSpaceChatMessage(
            isUser: false,
            text: "Understood, I won't perform this action."
        ))
    }

    public func stopCurrentTask() {
        disarmStreamingWatchdog()
        ClickyLogger.info("[COMPANION]", "User stopped current task / loop")
        grounderTask?.cancel()
        grounderTask = nil
        currentResponseTask?.cancel()
        currentResponseTask = nil
        elevenLabsTTSClient.stopPlayback()
        hideResponseBubbleImmediately()
        isTaskSessionPreApproved = false
        ongoingTaskGoal = nil
        voiceState = .idle
        isShowingStreamingResponse = false
        streamingResponseText = ""
        isHomeSpaceStreaming = false
        homeSpaceStreamingText = ""
        CompanionWindowStreamService.shared.stopStreaming()
        MascotVirtualDesktopService.shared.stopVirtualDesktop()
        CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
        ClickySoundEngine.shared.play(.close)
    }

    // MARK: - Continuous Autonomous ReAct Loop (Zero Artificial Limits)

    func executeAndContinueAutonomousLoop(payload: ComputerUseActionPayload, initialGoal: String) async {
        var currentPayload: ComputerUseActionPayload? = payload
        var stepCount = 0

        ClickyLogger.info("[AUTONOMOUS_LOOP]", "Starting continuous autonomous task loop for goal: \"\(initialGoal)\"")
        self.voiceState = .processing
        CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .working)

        // Automatically hide HomeSpace chat studio so it does not block the visual screenshot of TradingView
        let wasHomeSpaceVisible = await MainActor.run {
            CompanionUIHostRegistry.shared?.isHomeSpaceVisible ?? HomeSpaceWindowManager.shared.isVisible
        }
        if wasHomeSpaceVisible {
            await MainActor.run {
                CompanionUIHostRegistry.shared?.hideHomeSpace() ?? HomeSpaceWindowManager.shared.hide()
            }
            ClickyLogger.info("[AUTONOMOUS_LOOP]", "Temporarily hid HomeSpace chat window to ensure unobstructed visual analysis")
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        defer {
            self.voiceState = .idle
            self.isTaskSessionPreApproved = false
            self.ongoingTaskGoal = nil
            let currentStatus = CompanionRosterStore.shared.activeCompanion.status
            if currentStatus == .working {
                CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
            }
            if wasHomeSpaceVisible {
                Task { @MainActor in
                    CompanionUIHostRegistry.shared?.showHomeSpace() ?? HomeSpaceWindowManager.shared.show()
                }
            }
        }

        // Verify Accessibility permission upfront so user is alerted if macOS blocks keystrokes/clicks
        if !WindowPositionManager.hasAccessibilityPermission() {
            ClickyLogger.warning("[AUTONOMOUS_LOOP]", "Accessibility permission is missing (AXIsProcessTrusted = false)! Prompting user via System Settings.")
            WindowPositionManager.requestAccessibilityPermission()
            WindowPositionManager.openAccessibilitySettings()
            self.appendChatMessage(HomeSpaceChatMessage(
                isUser: false,
                text: "⚠️ Accessibility permission is required to interact with the screen and control TradingView physically. System Settings has been opened — please enable 'boringNotch' under Privacy & Security > Accessibility."
            ))
        }

        while let activePayload = currentPayload {
            guard !Task.isCancelled else {
                ClickyLogger.info("[AUTONOMOUS_LOOP]", "Task loop cancelled by user")
                self.voiceState = .idle
                self.isTaskSessionPreApproved = false
                self.ongoingTaskGoal = nil
                CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
                return
            }

            stepCount += 1
            ClickyLogger.info("[AUTONOMOUS_LOOP]", "Executing Step #\(stepCount): \(activePayload.rawDetails) [Type: \(activePayload.type.rawValue)]")

            let targetTf = (activePayload.tradingViewPayload?.actionType == .timeframe) ? activePayload.tradingViewPayload?.parameter : nil

            // 1. Physically execute the current action
            await ComputerUsePhysicalExecutor.shared.execute(payload: activePayload)

            guard !Task.isCancelled else { return }

            // 2. Allow UI & graphics to settle
            let settleDelay: UInt64 = (activePayload.type == .launchApp) ? 1_400_000_000 : 750_000_000
            try? await Task.sleep(nanoseconds: settleDelay)

            guard !Task.isCancelled else { return }

            // Reset streaming accumulators for next turn without killing on-screen bubble
            self.hasTriggeredStreamingFlight = false
            self.accumulatedRawStreamingText = ""

            // 3. Capture updated screen state
            let screenCaptures: [CompanionScreenCapture]
            do {
                screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()
            } catch {
                ClickyLogger.warning("[AUTONOMOUS_LOOP]", "Screen capture failed: \(error.localizedDescription)")
                screenCaptures = []
            }

            let labeledImages = screenCaptures.map { capture in
                let dimensionInfo = " (image dimensions: \(capture.screenshotWidthInPixels)x\(capture.screenshotHeightInPixels) pixels)"
                return (data: capture.imageData, label: capture.label + dimensionInfo)
            }

            let activeWorkSurface = ActiveWorkSurfaceManager.getActiveWorkSurface(queryHint: initialGoal)

            // Fetch live BingX perpetual swap multi-timeframe market data & concrete candle proof (ONLY for TradingView tasks)
            let isTradingIntent = activePayload.tradingViewPayload != nil ||
                                  activePayload.targetApp?.localizedCaseInsensitiveContains("TradingView") == true ||
                                  initialGoal.localizedCaseInsensitiveContains("chart") ||
                                  initialGoal.localizedCaseInsensitiveContains("trading") ||
                                  initialGoal.localizedCaseInsensitiveContains("crypto") ||
                                  initialGoal.localizedCaseInsensitiveContains("analis")
            var bingXMarketContext = ""
            if isTradingIntent {
                let targetCoin = Self.extractTradingSymbol(from: initialGoal, activeWorkSurface: activeWorkSurface)
                if let mtf = try? await BingXMarketDataEngine.shared.fetchMultiTimeframeAnalysis(symbol: targetCoin) {
                    bingXMarketContext = """

                    \(mtf.promptContextString())
                    """
                    ClickyLogger.info("[AUTONOMOUS_LOOP]", "Injected BingX Multi-Timeframe TA context for \(targetCoin): Last $\(Int(mtf.lastPrice)), Direction: \(mtf.overallDirection.rawValue), WinRate: \(mtf.winRatePercent)%, Trigger: \(mtf.triggerCandleProof.timestampWIB) WIB")
                }
            }

            // 4. Formulate autonomous feedback prompt with Strict Visual Verification Gate & Meta-Cognitive Self-Healing
            let targetTfHint = targetTf != nil ? " (Target timeframe: \(targetTf!))" : ""
            let activeSlug = CompanionRosterStore.shared.allCompanions.first(where: { $0.id == activeBuddy.id })?.slug
                             ?? activeBuddy.name.lowercased().replacingOccurrences(of: " ", with: "-")

            // Ground-Truth System Verification Notice (Anti-Hallucination Gate)
            var factualVerificationNotice = ""
            if let targetAppName = activePayload.targetApp,
               targetAppName.lowercased() != "active app",
               targetAppName.lowercased() != "current" {
                let cleanApp = targetAppName.trimmingCharacters(in: .whitespaces).lowercased()
                let isStillRunning = NSWorkspace.shared.runningApplications.contains {
                    ($0.localizedName?.localizedCaseInsensitiveContains(cleanApp) == true ||
                     $0.bundleIdentifier?.localizedCaseInsensitiveContains(cleanApp) == true) && !$0.isTerminated
                }
                let detailsLower = activePayload.rawDetails.lowercased()
                let isClose = detailsLower.contains("close") || detailsLower.contains("quit") || detailsLower.contains("tutup")
                if isClose {
                    if !isStillRunning {
                        factualVerificationNotice = "\nGROUND-TRUTH SYSTEM VERIFICATION:\n[VERIFIED: '\(targetAppName)' has been confirmed TERMINATED and closed. Its process and windows no longer exist.]\n"
                    } else {
                        factualVerificationNotice = "\nGROUND-TRUTH SYSTEM VERIFICATION:\n[WARNING: '\(targetAppName)' is STILL RUNNING in the operating system. Close/quit was not completed. You must NOT claim it is closed.]\n"
                    }
                }
            }

            let loopPrompt = """
            [AUTONOMOUS TASK IN PROGRESS - STEP #\(stepCount)]:
            Last action executed: "\(activePayload.rawDetails)"\(targetTfHint).
            User's primary objective: "\(initialGoal)"
            \(bingXMarketContext)
            \(factualVerificationNotice)
            OBSTACLE & MODAL SELF-HEALING DIRECTIVE:
            1. Look at the attached screenshot: Is there an unexpected popup, modal, dialog, or text box blocking your view?
            2. If YES, close or dismiss it via [ACTION:tv_close_modal] or [ACTION:tv_clear] before doing any analysis or drawing.

            COMPANION AUTONOMOUS SOP & PROTOCOL DIRECTIVE:
            You are operating autonomously as "\(activeBuddy.name)" (\(activeBuddy.roleDescription)).
            Review the attached screenshot, the latest market data context above, and strictly follow the protocol, capabilities, and standing rules defined in your companion specification markdown (\(activeSlug).md).

            DECISION RULES:
            - If you still need to inspect other timeframes, switch symbols, clear old clutter ([ACTION:tv_clear]), or draw tools on the chart ([ACTION:tv_tool:...]), output ONE action tag [ACTION:...] along with your concrete empirical findings for this step (e.g. [TEMUAN 1H MAKRO], [TEMUAN 15M STRUKTUR], or [TEMUAN 5M TRIGGER]) and a short natural spoken sentence for audio.
            - DILARANG KERAS mencetak tabel pada langkah 1, 2, 3, atau 4! Tabel HANYA boleh dicetak pada langkah terakhir setelah seluruh timeframe (1H, 15m, 5m) diinspeksi dan tool posisi selesai dipasang di chart.
            - If you have completed the required inspections and chart actions according to your markdown specification, DO NOT output any action tags! Instead, synthesize all previous findings without bias and output your complete final report with the structured tables specified in your markdown specification.
            - Never use raw '###' header characters. Always start with a 1-sentence spoken summary for TTS/audio.
            """

            let historyForAPI = conversationHistory.map { entry in
                (userPlaceholder: entry.userTranscript, assistantResponse: entry.assistantResponse)
            }

            do {
                let (fullResponseText, _) = try await claudeAPI.analyzeImageStreaming(
                    images: labeledImages,
                    systemPrompt: Self.buildCompanionVoiceResponseSystemPrompt(workSurface: activeWorkSurface, buddy: self.activeBuddy, isPreApproved: true),
                    conversationHistory: historyForAPI,
                    userPrompt: loopPrompt,
                    onTextChunk: { [weak self] chunk in
                        Task { @MainActor in
                            self?.showStreamingChunk(chunk, screenCaptures: screenCaptures)
                        }
                    }
                )

                guard !Task.isCancelled else { return }

                // Check if the companion is requesting a new missing feature
                if let req = Self.extractFeatureRequest(from: fullResponseText) {
                    ClickyLogger.warning("[AUTONOMOUS_LOOP]", "Companion requested new feature: \(req.featureName) — Reason: \(req.reason)")
                    let politeMessage = """
                    ⚠️ **This feature is not available yet.**

                    I need the **\(req.featureName)** capability (\(req.reason)) to complete this task. This feature request has been saved to the backlog.
                    """
                    self.saveFeatureRequest(featureName: req.featureName, reason: req.reason, goal: initialGoal)
                    ClickySoundEngine.shared.play(.question)
                    self.finishStreamingResponseText(politeMessage)
                    self.appendChatMessage(HomeSpaceChatMessage(isUser: false, text: politeMessage))
                    self.voiceState = .idle
                    self.isTaskSessionPreApproved = false
                    self.ongoingTaskGoal = nil
                    CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
                    return
                }

                let parseResult = Self.parsePointingCoordinates(from: fullResponseText)
                var spokenText = parseResult.spokenText

                let (cleanedAfterRequest, computerUseReq) = Self.parseComputerUseRequest(from: spokenText, activeBuddy: self.activeBuddy)
                let (cleanedAfterAction, proposedAction) = Self.parseProposedAction(from: cleanedAfterRequest)

                var nextPayload: ComputerUseActionPayload? = nil
                if let req = computerUseReq {
                    spokenText = cleanedAfterRequest
                    nextPayload = req.payload
                } else if let action = proposedAction {
                    spokenText = cleanedAfterAction
                    let tvPayload = Self.extractTradingViewPayload(from: fullResponseText)
                    nextPayload = ComputerUseActionPayload(
                        type: tvPayload != nil ? .tradingViewAction : (action.actionType == .keyCombo ? .keyCombo : (action.actionType == .launchApp ? .launchApp : .click)),
                        targetCoordinate: action.targetCoordinate,
                        targetApp: action.appName,
                        tradingViewPayload: tvPayload,
                        rawDetails: action.title
                    )
                }

                if let next = nextPayload {
                    // Next step required: log, post progress snippet if available, and continue loop
                    ClickyLogger.info("[AUTONOMOUS_LOOP]", "Step #\(stepCount) completed. Next action requested: \(next.rawDetails)")
                    let progressSnippet = Self.stripTechnicalTags(from: spokenText)
                    if !progressSnippet.isEmpty {
                        ClickyLogger.info("[AUTONOMOUS_LOOP]", "Step #\(stepCount) note: \"\(progressSnippet)\"")
                        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: progressSnippet))
                        conversationHistory.append((
                            userTranscript: "Step \(stepCount): \(activePayload.rawDetails)",
                            assistantResponse: progressSnippet,
                            rawResponseWithTags: spokenText,
                            groundingHit: true
                        ))
                        finishStreamingResponseText(progressSnippet)

                        // Option 1A: Dynamic reading delay between consecutive autonomous steps (min 3.5s)
                        let words = progressSnippet.split { $0.isWhitespace }.count
                        let paceDuration = max(3.5, min(6.5, 1.5 + Double(words) * 0.25))
                        try? await Task.sleep(nanoseconds: UInt64(paceDuration * 1_000_000_000))
                    }
                    currentPayload = next
                } else {
                    // RUNTIME SOP CONTRACT VALIDATOR (Loop Premature Conclusion Guard):
                    let isFuturesScout = self.activeBuddy.name.localizedCaseInsensitiveContains("Futures") ||
                                         self.activeBuddy.roleDescription.localizedCaseInsensitiveContains("Futures") ||
                                         self.activeBuddy.roleDescription.localizedCaseInsensitiveContains("Analyst")
                    let hasTableMarkup = fullResponseText.contains("| No |") || fullResponseText.contains("| Koin |") || fullResponseText.contains("| Setup |") || (fullResponseText.contains("|---") && fullResponseText.contains("| :---"))

                    if isFuturesScout && hasTableMarkup && stepCount < 4 {
                        let violationError = """
                        ⚠️ **SOP CONTRACT VIOLATION DETECTED**

                        Companion melanggar spesifikasi SOP (`futures-scout.md`):
                        • **Kesalahan**: Menyelesaikan analisis dan mencetak tabel secara prematur pada langkah #\(stepCount) sebelum menyelesaikan siklus inspeksi multi-timeframe (1H, 15m, 5m) dan penempatan tool di chart.
                        • **Aturan SOP yang Dilanggar**: SOP mewajibkan penalaran berurutan (Sequential Thinking) melalui audit 1H, 15m, 5m, dan penempatan tool fisik sebelum mencetak tabel akhir.
                        • **Tindakan Sistem**: Sesuai instruksi mutlak pengguna ("companion dilarang keras melanggar MD nya, jika dilanggar kirimkan errornya, bukan hasil pelanggaran"), hasil kesimpulan prematur ini **DITOLAK**.
                        """
                        ClickyLogger.error("[SOP_VALIDATOR]", "SOP Violation intercepted at step #\(stepCount): Premature conclusion tables. Rejecting illegal output.")
                        finishStreamingResponseText(violationError)
                        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: violationError))
                        voiceState = .idle
                        isTaskSessionPreApproved = false
                        ongoingTaskGoal = nil
                        CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
                        return
                    }

                    // No further action tags: The autonomous analysis is completely finished!
                    let cleanFinal = Self.stripTechnicalTags(from: spokenText)
                    ClickyLogger.success("[AUTONOMOUS_LOOP]", "Autonomous task loop completed after \(stepCount) steps")
                    finishStreamingResponseText(cleanFinal)
                    currentPayload = nil

                    // Save final analysis to history & chat
                    conversationHistory.append((
                        userTranscript: initialGoal,
                        assistantResponse: cleanFinal,
                        rawResponseWithTags: fullResponseText,
                        groundingHit: true
                    ))
                    appendChatMessage(HomeSpaceChatMessage(isUser: false, text: cleanFinal))

                    // Chime celebration
                    ClickySoundEngine.shared.play(.done)
                    CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .done)

                    // Speak conclusion if voice output is enabled (filtering out table markdown for speech)
                    let isVoiceOutputEnabled = Defaults[.cursorAssistantVoiceOutputEnabled]
                    let spokenSummary = Self.stripTableForSpeech(from: cleanFinal)
                    if isVoiceOutputEnabled && !spokenSummary.isEmpty {
                        do {
                            try await elevenLabsTTSClient.speakText(spokenSummary)
                            voiceState = .responding
                        } catch {
                            let synthesizer = NSSpeechSynthesizer()
                            synthesizer.startSpeaking(spokenSummary)
                            voiceState = .responding
                        }
                    } else {
                        voiceState = .idle
                    }

                    // Reset session pre-approval and goal
                    self.isTaskSessionPreApproved = false
                    self.ongoingTaskGoal = nil
                }
            } catch is CancellationError {
                ClickyLogger.info("[AUTONOMOUS_LOOP]", "Loop cancelled during API call")
                self.voiceState = .idle
                self.isTaskSessionPreApproved = false
                self.ongoingTaskGoal = nil
                return
            } catch {
                ClickyLogger.error("[AUTONOMOUS_LOOP]", "Error during autonomous loop API call: \(error.localizedDescription)")
                self.voiceState = .idle
                self.isTaskSessionPreApproved = false
                self.ongoingTaskGoal = nil
                speakCreditsErrorFallback()
                return
            }
        }

        self.voiceState = .idle
        self.isTaskSessionPreApproved = false
        self.ongoingTaskGoal = nil
    }

    public func proposeAction(_ action: ComputerUseProposedAction) {
        self.proposedComputerUseAction = action
        ClickySoundEngine.shared.play(.question)
    }

    public func approveComputerUseAction() {
        guard let action = proposedComputerUseAction else { return }
        ClickyLogger.info("[ACTION]", "User approved computer use action: \(action.title)")

        switch action.actionType {
        case .click:
            if let target = action.targetCoordinate {
                executeMouseClick(at: target)
            }
        case .keyCombo:
            executeKeyCombo(key: 0x0D /* 'w' */, flags: .maskCommand)
        case .launchApp:
            if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.\(action.appName.lowercased())") ??
                            NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/System/Applications/\(action.appName).app")) {
                NSWorkspace.shared.openApplication(at: appUrl, configuration: .init(), completionHandler: nil)
            }
        case .runScript:
            break
        }

        ClickySoundEngine.shared.play(.done)
        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: "Done! I've executed \"\(action.title)\"."))
        proposedComputerUseAction = nil
    }

    public func rejectComputerUseAction() {
        guard let action = proposedComputerUseAction else { return }
        ClickyLogger.info("[ACTION]", "User cancelled action: \(action.title)")
        ClickySoundEngine.shared.play(.close)
        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: "Understood, I won't execute \"\(action.title)\"."))
        proposedComputerUseAction = nil
    }

    public func executeMouseClick(at point: CGPoint) {
        if MascotVirtualDesktopService.shared.isVirtualDisplayActive {
            if let pid = MascotVirtualDesktopService.shared.currentAppPid {
                let source = CGEventSource(stateID: .hidSystemState)
                let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
                let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
                downEvent?.postToPid(pid)
                usleep(30000)
                upEvent?.postToPid(pid)
            }
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let moveEvent = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)

        moveEvent?.post(tap: .cghidEventTap)
        usleep(30000)
        downEvent?.post(tap: .cghidEventTap)
        usleep(30000)
        upEvent?.post(tap: .cghidEventTap)
    }

    public func executeKeyCombo(key: CGKeyCode, flags: CGEventFlags) {
        if MascotVirtualDesktopService.shared.isVirtualDisplayActive {
            if let pid = MascotVirtualDesktopService.shared.currentAppPid {
                let source = CGEventSource(stateID: .hidSystemState)
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
                keyDown?.flags = flags
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
                keyUp?.flags = flags
                keyDown?.postToPid(pid)
                usleep(30000)
                keyUp?.postToPid(pid)
            }
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        usleep(30000)
        keyUp?.post(tap: .cghidEventTap)
    }

}
