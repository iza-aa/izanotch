//
//  CompanionManager+Streaming.swift
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
import SwiftUI

extension CompanionManager {
    // MARK: - Streaming Response Bubble Control

    // MARK: - Cursor Assistant Text Condensation (HeyClicky HUD Pill)

    /// Condenses long responses for the floating cursor HUD so that it displays a compact, sleek status pill (HeyClicky HUD)
    /// while the full multi-paragraph response is preserved in the HomeSpace chat thread.
    static func condenseForCursorHUD(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        // Strip markdown tokens like **, ##, backticks
        let clean = trimmed
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Take the first non-empty line
        let firstLine = clean.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? clean

        // If line is short and concise, return it directly
        if firstLine.count <= 85 {
            return firstLine
        }

        // Check if there is a complete sentence within the first line under 85 chars
        if let match = firstLine.range(of: #"[.!?]"#, options: .regularExpression) {
            let sentence = String(firstLine[..<match.upperBound]).trimmingCharacters(in: .whitespaces)
            if sentence.count <= 85 && sentence.count >= 10 {
                return sentence
            }
        }

        // Otherwise, truncate cleanly at word boundary around 75 characters
        let prefix = String(firstLine.prefix(75))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return "\(prefix[..<lastSpace])..."
        }
        return "\(prefix)..."
    }

    /// Arms a self-healing watchdog to ensure detectedElementScreenLocation never traps the cursor in an invisible state
    func armFlightWatchdog(timeout: TimeInterval = 9.0) {
        flightWatchdogWorkItem?.cancel()
        let watchdog = DispatchWorkItem { [weak self] in
            guard let self = self, self.detectedElementScreenLocation != nil else { return }
            ClickyLogger.warning("[WATCHDOG]", "Flight watchdog auto-cleared detectedElementScreenLocation after \(timeout)s timeout")
            self.clearDetectedElementLocation()
            NotificationCenter.default.post(name: .clickyAbortFlight, object: nil)
        }
        self.flightWatchdogWorkItem = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: watchdog)
    }

    /// Public entrypoint to trigger visual element flight to an exact Cocoa screen coordinate (AppKit origin bottom-left)
    public func triggerVisualElementFlight(
        appKitScreenPoint: CGPoint,
        targetRadius: CGFloat = 24.0,
        elementLabel: String? = nil
    ) {
        voiceState = .idle
        detectedElementLabel = elementLabel
        if let label = elementLabel, !label.isEmpty {
            detectedElementBubbleText = "\(label) right here!"
        }
        // Opsi user hold-sejak-awal: AX-HIT = prediksi salah, grounder tak perlu.
        // Lepas hold SEGERA + tampilkan teks yang ditahan (jangan diam sia-sia).
        if groundingHoldActive {
            groundingHoldActive = false
            homeSpaceStreamingText = Self.stripTechnicalTags(from: Self.stripPointingTags(from: accumulatedRawStreamingText))
            isHomeSpaceStreaming = !homeSpaceStreamingText.isEmpty
            streamingResponseText = Self.condenseForCursorHUD(homeSpaceStreamingText)
            ClickyLogger.info("[SYNC]", "hold released at AX-hit — no grounder needed")
        }
        // Fase 4-1 (2026-09-22): tolak kandidat off-screen. Fakta: AX Dock lapor
        // Y goyang (907 vs 987) antar sesi; titik di luar bounds layar (mis. -40)
        // bila diterbangkan = mendarat di luar visual. Jangan flight — tandai miss
        // agar correction/grounder yang tangani, bukan ngarang ke tepi layar.
        let onAnyScreen = NSScreen.screens.contains(where: { $0.frame.contains(appKitScreenPoint) })
        guard onAnyScreen else {
            ClickyLogger.warning("[POINTING]", "rejected off-screen candidate (\(Int(appKitScreenPoint.x)), \(Int(appKitScreenPoint.y))) — no flight")
            markGroundingMiss()
            return
        }
        // Plan sinkron-teks S2: flight mulai -> bubble ditegakkan (jangan hide
        // saat cursor terbang). Reveal kata jalan paralel busur animasi.
        // Opsi user 22 Sep: lepas hold + tampilkan teks BERSAMAAN dengan flight.
        responseBubbleHideWorkItem?.cancel()
        if groundingHoldActive {
            groundingHoldActive = false
            homeSpaceStreamingText = Self.stripTechnicalTags(from: Self.stripPointingTags(from: accumulatedRawStreamingText))
            isHomeSpaceStreaming = !homeSpaceStreamingText.isEmpty
            streamingResponseText = Self.condenseForCursorHUD(homeSpaceStreamingText)
            ClickyLogger.info("[SYNC]", "hold released at flight — text+animation together")
        }
        isShowingStreamingResponse = true
        streamingResponseOpacity = 1.0
        lastFlightEndEstimate = Date().addingTimeInterval(5.0)
        NotificationCenter.default.post(name: .clickyFlightStarted, object: nil)

        let screen = NSScreen.screens.first(where: { $0.frame.contains(appKitScreenPoint) }) ?? NSScreen.main ?? NSScreen.screens[0]
        detectedElementDisplayFrame = screen.frame
        detectedElementTargetRadius = targetRadius
        detectedElementScreenLocation = appKitScreenPoint
        armFlightWatchdog()
        ClickySoundEngine.shared.play(.receive)
        ClickyLogger.info("[POINTING]", "Visual element flight triggered at AppKit point: (\(Int(appKitScreenPoint.x)), \(Int(appKitScreenPoint.y)))")
    }

    /// Sets transparent intermediate status text on the Clicky cursor bubble HUD
    @MainActor
    public func setIntermediateStatusText(_ text: String) {
        streamingResponseText = text
        isShowingStreamingResponse = true
        streamingResponseOpacity = 1.0
        voiceState = .processing
    }

    /// Appends message to chat, finishes HUD streaming, and plays speech aloud
    /// Appends message to chat, finishes HUD streaming, and plays speech aloud.
    /// If `speechNarrative` is provided, speech plays that clean narrative instead of raw `text` (TTS cleanliness contract).
    @MainActor
    public func speakAndReportText(_ text: String, speechNarrative: String? = nil) async {
        disarmStreamingWatchdog()
        self.isHomeSpaceStreaming = false
        self.homeSpaceStreamingText = ""
        voiceState = .responding
        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: text))
        finishStreamingResponseText(text)

        let isVoiceOutputEnabled = Defaults[.cursorAssistantVoiceOutputEnabled]
        let speechTarget = speechNarrative ?? text
        let speechClean = Self.stripTechnicalTags(from: speechTarget)
        if isVoiceOutputEnabled && !speechClean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let ttsWords = speechClean.split { $0.isWhitespace }.count
            lastTTSDurationEstimate = max(2.0, Double(ttsWords) / 2.5)
            NotificationCenter.default.post(name: .clickyTTSStarted, object: nil)
            do {
                try await elevenLabsTTSClient.speakText(speechClean)
                if elevenLabsTTSClient.lastSpokenDuration > 0 {
                    lastTTSDurationEstimate = elevenLabsTTSClient.lastSpokenDuration
                }
            } catch {
                let synthesizer = NSSpeechSynthesizer()
                synthesizer.startSpeaking(speechClean)
            }
        }

        try? await Task.sleep(nanoseconds: 1_200_000_000)
        self.voiceState = .idle
        CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
    }

    func showStreamingChunk(_ chunk: String, screenCaptures: [CompanionScreenCapture] = [], isCorrectionTurn: Bool = false) {
        if chunk.hasPrefix(accumulatedRawStreamingText) && accumulatedRawStreamingText.count > 0 {
            accumulatedRawStreamingText = chunk
        } else {
            accumulatedRawStreamingText += chunk
        }

        // Opsi D Fase 3a: TARGET-first instant flight. Planner expression ->
        // AX fast-path (enumerasi + rarity). Hit = flight instan 50ms.
        // Miss = diam (grounder primer Fase 3b yang lanjutkan). Legacy
        // bracket tags ([CANDIDATE:]/[POINT:]) dipertahankan pasif di bawah.
        let pointingAllowed = Self.hasPointingIntent(transcript: ongoingTaskGoal ?? "")
        if !pointingAllowed, !accumulatedRawStreamingText.isEmpty {
            ClickyLogger.info("[INTENT_GATE]", "suppressed flight for non-spatial transcript")
        }
        // Plan sinkron-teks: flight awal saat baris TARGET TERMINASI + matang.
        // String identik final -> akurasi tidak dikorbankan; fallback akhir turn
        // tetap penentu akhir (verifikasi + koreksi). Parsial tanpa \n = diam.
        if pointingAllowed, !hasTriggeredStreamingFlight {
            if let termExpr = Self.terminatedTargetLine(in: accumulatedRawStreamingText),
               Self.isMatureTargetExpression(termExpr) {
                let enriched = Self.enrichTargetExpressionFixed(termExpr, workSurface: currentActiveWorkSurface)
                // Grounder spekulatif (overlap selagi sisa stream jalan)
                ClickyLogger.info("[TARGET_PLANNER]", "Speculative grounder for \"\(enriched.prefix(60))\"")
                requestGrounderEarly(expression: enriched, screenCaptures: screenCaptures, screenNumber: nil)
            } else if Self.parseTargetExpression(from: accumulatedRawStreamingText) != nil {
                // Plan perbaikan: bedakan "belum terminasi" vs "tak matang".
                if Self.terminatedTargetLine(in: accumulatedRawStreamingText) == nil {
                    ClickyLogger.info("[TARGET_PLANNER]", "unterminated expression - waiting for line end")
                } else {
                    ClickyLogger.info("[TARGET_PLANNER]", "immature expression - waiting for object noun")
                }
            }
            // Plan perbaikan 22 Sep: sentinel hotfix7 DIHAPUS. Legacy bracket di
            // streaming TETAP nonaktif (prematur by-design) — flight legacy hanya
            // di fallback/final. Tanpa sentinel: cabang dihapus total, bukan dijaga
            // kondisi mustahil. parseResult tetap dipakai untuk subtitle/chat bersih.
            _ = Self.parsePointingCoordinates(from: accumulatedRawStreamingText)
        }

        // Plan sinkron-teks S2: anti-hide selama streaming — hide hanya boleh
        // di-arm dari scheduleResponseBubbleHide (final), bukan dari chunk.
        responseBubbleHideWorkItem?.cancel()
        // Opsi user 22 Sep (state machine): intent spasial + flight BELUM terpicu
        // = TAHAN display. Akumulator + parser + early-flight tetap jalan di atas.
        // Lepas: flushHeldTextForFlight saat latch true / deliver / akhir turn biasa.
        let spatialHold = Self.hasPointingIntent(transcript: ongoingTaskGoal ?? "") && !hasTriggeredStreamingFlight
        groundingHoldActive = spatialHold
        if spatialHold {
            return
        }
        let cleanText = Self.stripPointingTags(from: accumulatedRawStreamingText)
        let homeSpaceClean = Self.stripTechnicalTags(from: cleanText)
        self.homeSpaceStreamingText = homeSpaceClean
        self.isHomeSpaceStreaming = !homeSpaceClean.isEmpty
        if self.isHomeSpaceStreaming {
            armStreamingWatchdog()
        }

        guard Defaults[.cursorAssistantShowSubtitles], !cleanText.isEmpty else { return }
        let hudText = Self.condenseForCursorHUD(cleanText)
        streamingResponseText = hudText
        isShowingStreamingResponse = true
        withAnimation(.easeOut(duration: 0.2)) {
            streamingResponseOpacity = 1.0
        }
        // Ensure legacy separate overlay panel remains dismissed
        CompanionResponseOverlayManager.shared.hideOverlay()
    }

    func finishStreamingResponseText(_ finalText: String) {
        disarmStreamingWatchdog()
        self.isHomeSpaceStreaming = false
        self.homeSpaceStreamingText = ""
        guard Defaults[.cursorAssistantShowSubtitles] else { return }
        let cleanText = Self.stripPointingTags(from: finalText)
        let hudText = Self.condenseForCursorHUD(cleanText)
        streamingResponseText = hudText
        isShowingStreamingResponse = true
        withAnimation(.easeOut(duration: 0.2)) {
            streamingResponseOpacity = 1.0
        }
        scheduleResponseBubbleHide(for: hudText)
        CompanionResponseOverlayManager.shared.hideOverlay()
    }

    func scheduleResponseBubbleHide(delay: TimeInterval = 6.0) {
        scheduleResponseBubbleHide(for: streamingResponseText)
    }

    /// Dynamically schedules hide based on reading length (longer text stays longer on screen)
    func scheduleResponseBubbleHide(for text: String) {
        responseBubbleHideWorkItem?.cancel()
        let wordCount = text.split { $0.isWhitespace }.count
        let wordDelay = max(4.0, min(18.0, 4.0 + Double(wordCount) / 6.0))
        // Plan sinkron-teks S2: hide = max(wordDelay, TTS+1.0, flightEnd+3.0).
        // Hide #2 (akhir turn) tidak boleh potong TTS lambat / flight grounder.
        var dynamicDelay = wordDelay
        if lastTTSDurationEstimate > 0 {
            dynamicDelay = max(dynamicDelay, lastTTSDurationEstimate + 1.0)
        }
        if let flightEnd = lastFlightEndEstimate {
            let remain = flightEnd.timeIntervalSinceNow + 3.0
            if remain > 0 { dynamicDelay = max(dynamicDelay, remain) }
        }
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.4)) {
                self?.streamingResponseOpacity = 0.0
            }
            self?.isShowingStreamingResponse = false
            self?.streamingResponseText = ""
        }
        responseBubbleHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + dynamicDelay, execute: work)
    }

    func hideResponseBubbleImmediately() {
        responseBubbleHideWorkItem?.cancel()
        responseBubbleHideWorkItem = nil
        streamingResponseText = ""
        isShowingStreamingResponse = false
        streamingResponseOpacity = 0.0
        CompanionResponseOverlayManager.shared.hideOverlay()
    }

    /// Triggers the cursor flight and spatial halo ring towards a detected UI element
    func triggerElementFlight(
        coordinate: CGPoint,
        normalizedBox: (ymin: Double, xmin: Double, ymax: Double, xmax: Double)? = nil,
        targetRadius: CGFloat,
        elementLabel: String?,
        screenNumber: Int?,
        screenCaptures: [CompanionScreenCapture],
        isCorrection: Bool = false
    ) {
        if detectedElementScreenLocation != nil {
            guard isCorrection else { return }
            ClickyLogger.info("[POINTING]", "Correction turn: clearing prior flight before re-trigger")
            clearDetectedElementLocation()
        }

        voiceState = .idle
        detectedElementLabel = elementLabel
        if let label = elementLabel, !label.isEmpty {
            detectedElementBubbleText = "\(label) right here!"
        }
        // Plan perbaikan 22 Sep (3.3): re-assert S2 di JALUR GROUNDER.
        // Audit: re-assert hanya di triggerVisual — jalur grounder live tanpa hold.
        responseBubbleHideWorkItem?.cancel()
        isShowingStreamingResponse = true
        streamingResponseOpacity = 1.0
        lastFlightEndEstimate = Date().addingTimeInterval(7.0)
        NotificationCenter.default.post(name: .clickyFlightStarted, object: nil)

        let targetScreenCapture: CompanionScreenCapture? = {
            if let screenNumber = screenNumber,
               screenNumber >= 1 && screenNumber <= screenCaptures.count {
                return screenCaptures[screenNumber - 1]
            }
            return screenCaptures.first(where: { $0.isCursorScreen })
        }()

        guard let targetScreenCapture else { return }

        let screenshotWidth = CGFloat(targetScreenCapture.screenshotWidthInPixels)
        let screenshotHeight = CGFloat(targetScreenCapture.screenshotHeightInPixels)
        let displayWidth = CGFloat(targetScreenCapture.displayWidthInPoints)
        let displayHeight = CGFloat(targetScreenCapture.displayHeightInPoints)
        let displayFrame = targetScreenCapture.displayFrame

        var displayLocalX: CGFloat
        var displayLocalY: CGFloat
        var finalRadius: CGFloat
        var hasColorMismatch = false

        if let box = normalizedBox {
            // Normalized 0-1000 bounding box (Gemini spatial grounding)
            let normCenterX = (box.xmin + box.xmax) / 2000.0
            let normCenterY = (box.ymin + box.ymax) / 2000.0
            displayLocalX = normCenterX * displayWidth
            displayLocalY = normCenterY * displayHeight

            let boxWidthInPoints = abs(box.xmax - box.xmin) / 1000.0 * displayWidth
            finalRadius = max(24.0, min(50.0, boxWidthInPoints / 2.0 + 8.0))
        } else if coordinate.x > screenshotWidth || coordinate.y > screenshotHeight || coordinate.y >= 900.0 {
            // Already in screen point coordinates (e.g. Dock items at Y >= 900 or display points)
            displayLocalX = max(0, min(coordinate.x, displayWidth))
            displayLocalY = max(0, min(coordinate.y, displayHeight))
            finalRadius = targetRadius
        } else {
            // Raw pixel coordinates in screenshot space (e.g. 1280x800)
            let clampedX = max(0, min(coordinate.x, screenshotWidth))
            let clampedY = max(0, min(coordinate.y, screenshotHeight))


            // Fase 4-4 (Opsi D): saliency snap DICABUT dari jalur kontrol.
            // Bukti: objectness untuk foto, bukan UI datar kecil ("No salient
            // objects" = perilaku yang diharapkan, bukan bug). Titik grounder
            // dipakai apa adanya; file engine tetap ada untuk debug manual.
            finalRadius = targetRadius
            displayLocalX = clampedX * (displayWidth / screenshotWidth)
            displayLocalY = clampedY * (displayHeight / screenshotHeight)
        }

        // Magnetic Traffic Light Snapping for macOS Windows
        let label = (elementLabel ?? "").lowercased()
        let queryContext = (self.ongoingTaskGoal ?? "").lowercased()
        let bubbleContext = (detectedElementBubbleText ?? "").lowercased()
        let combinedContext = "\(label) \(queryContext) \(bubbleContext)"

        let targetWorkSurface = ActiveWorkSurfaceManager.getActiveWorkSurface(queryHint: combinedContext) ?? currentActiveWorkSurface

        if let ws = targetWorkSurface {
            let userWantsClose = queryContext.contains("close") ||
                                 queryContext.contains("tutup") ||
                                 queryContext.contains("exit") ||
                                 queryContext.contains("quit") ||
                                 queryContext.contains("keluar") ||
                                 ((queryContext.contains("tombol") || queryContext.contains("button")) && (queryContext.contains("red") || queryContext.contains("merah")))

            let userWantsMinimize = queryContext.contains("minimi") ||
                                   ((queryContext.contains("tombol") || queryContext.contains("button")) && (queryContext.contains("kuning") || queryContext.contains("yellow")))

            let userWantsZoom = queryContext.contains("zoom") ||
                                queryContext.contains("full") ||
                                queryContext.contains("perbesar") ||
                                ((queryContext.contains("tombol") || queryContext.contains("button")) && (queryContext.contains("hijau") || queryContext.contains("green")))

            let isClose = userWantsClose && (label.contains("close") || label.contains("red") || label.contains("merah") || label.contains("tutup"))
            let isMinimize = userWantsMinimize && (label.contains("minimi") || label.contains("kuning") || label.contains("yellow"))
            let isZoom = userWantsZoom && (label.contains("zoom") || label.contains("full") || label.contains("hijau") || label.contains("green"))

            // trafficLight*Center is in CG top-left global space (same convention as
            // ws.frame from CGWindowList). displayFrame is AppKit bottom-left, so
            // convert the CG Y into display-local top-left via the window frame:
            // localY = trafficY - windowTopCG, where windowTopCG = frame.origin.y
            // expressed in the same CG space. Using displayFrame.origin.y (AppKit)
            // here mixed two coordinate systems and shifted snaps vertically.
            let localCloseX = ws.trafficLightCloseCenter.x - displayFrame.origin.x
            let localCloseY = ws.trafficLightCloseCenter.y - ws.frame.origin.y

            let dx = abs(displayLocalX - localCloseX)
            let dy = abs(displayLocalY - localCloseY)

            let localWindowOriginX = ws.frame.origin.x - displayFrame.origin.x
            let isNearWindowTopLeft = (dx < 220 && dy < 140) || (displayLocalX < localWindowOriginX && displayLocalX >= localWindowOriginX - 120 && dy < 120)

            let windowBounds = ws.frame
            let isInsideOrNearWindow = displayLocalX >= (windowBounds.origin.x - 50) &&
                                       displayLocalX <= (windowBounds.origin.x + windowBounds.width + 50) &&
                                       displayLocalY >= (windowBounds.origin.y - 50) &&
                                       displayLocalY <= (windowBounds.origin.y + windowBounds.height + 50)

            if isClose && (isInsideOrNearWindow || isNearWindowTopLeft || combinedContext.contains(ws.appName.lowercased()) || combinedContext.contains("close") || combinedContext.contains("tutup")) {
                ClickyLogger.info("[POINTING]", "Magnetically snapped close button from (\(Int(displayLocalX)), \(Int(displayLocalY))) to active window (\(ws.appName)) close button at (\(Int(localCloseX)), \(Int(localCloseY)))")
                displayLocalX = localCloseX
                displayLocalY = localCloseY
                finalRadius = 24.0
            } else if isMinimize && (isInsideOrNearWindow || isNearWindowTopLeft || combinedContext.contains("minimi")) {
                let localMinX = ws.trafficLightMinimizeCenter.x - displayFrame.origin.x
                let localMinY = ws.trafficLightMinimizeCenter.y - ws.frame.origin.y
                ClickyLogger.info("[POINTING]", "Magnetically snapped minimize button from (\(Int(displayLocalX)), \(Int(displayLocalY))) to active window (\(ws.appName)) minimize button at (\(Int(localMinX)), \(Int(localMinY)))")
                displayLocalX = localMinX
                displayLocalY = localMinY
                finalRadius = 24.0
            } else if isZoom && (isInsideOrNearWindow || isNearWindowTopLeft || combinedContext.contains("zoom") || combinedContext.contains("full")) {
                let localZoomX = ws.trafficLightZoomCenter.x - displayFrame.origin.x
                let localZoomY = ws.trafficLightZoomCenter.y - ws.frame.origin.y
                ClickyLogger.info("[POINTING]", "Magnetically snapped zoom button from (\(Int(displayLocalX)), \(Int(displayLocalY))) to active window (\(ws.appName)) zoom button at (\(Int(localZoomX)), \(Int(localZoomY)))")
                displayLocalX = localZoomX
                displayLocalY = localZoomY
                finalRadius = 24.0
            }
        }

        let appKitY = displayHeight - displayLocalY

        let globalLocation = CGPoint(
            x: displayLocalX + displayFrame.origin.x,
            y: appKitY + displayFrame.origin.y
        )

        detectedElementTargetRadius = finalRadius
        detectedElementScreenLocation = globalLocation
        detectedElementDisplayFrame = displayFrame
        armFlightWatchdog()
        ClickySoundEngine.shared.play(.receive)
        ClickyAnalytics.trackElementPointed(elementLabel: elementLabel)
        if hasColorMismatch {
            ClickyLogger.warning("[POINTING]", "Element pointed with UNVERIFIED color: \"\(elementLabel ?? "element")\" at (\(Int(displayLocalX)), \(Int(displayLocalY))) pt — correction turn may re-ground")
            markGroundingMiss()
        } else {
            ClickyLogger.info("[POINTING]", "Element pointed: \"\(elementLabel ?? "element")\" at (\(Int(displayLocalX)), \(Int(displayLocalY))) pt")
        }
    }

    /// SoM history hygiene: flags the active turn so its tags are neutralized
    /// in future few-shot history instead of poisoning it with wrong coords.
    func markGroundingMiss() {
        // Called on @MainActor instance context; the Task-local flag is set via
        // the shared pending-miss handoff consumed after the turn completes.
        Self.pendingGroundingMiss = true
    }

    static var pendingGroundingMiss = false

    /// Stage 3 — ROI re-ground entry: crop around a prior guess on the lossless
    /// frame so a correction turn can localize inside the crop at full fidelity.

    public func navigateCursorTo(point: CGPoint, label: String? = nil) {
        self.detectedElementScreenLocation = point
        self.detectedElementLabel = label
        self.detectedElementTargetRadius = 24.0
        ClickySoundEngine.shared.play(.receive)
    }

}
