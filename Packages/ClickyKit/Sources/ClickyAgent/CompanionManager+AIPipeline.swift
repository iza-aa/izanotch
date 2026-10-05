//
//  CompanionManager+AIPipeline.swift
//  boringNotch (Izanotchy)
//
//  Decomposed extension for CompanionManager.
//

import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Defaults
import Foundation
import ClickyFoundation
import ClickyPlatform
import ClickyAIProviders
import ClickySpeech
import ClickyCUA
import ClickyReasoning
import ClickyAstronacci
import ClickyTradingView
import ClickyFuturesScout
import ClickyRoster
import ClickyDesignSystem

extension CompanionManager {
    // MARK: - AI Response Pipeline

    /// Public method to submit queries via text (Home Space silent chat & quick chips)
    public func askViaText(prompt: String) {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { return }
        self.ongoingTaskGoal = cleanPrompt
        self.isTaskSessionPreApproved = false
        sendTranscriptToClaudeWithScreenshot(transcript: cleanPrompt)
    }

    /// Captures a screenshot, sends it along with the transcript to Claude/Gemini,
    /// and plays the response aloud via ElevenLabs TTS or native TTS.
    /// Opsi D Fase 3b — grounder primer ber-budget (pengganti requestGrounderFallback).
    /// Tetap background Task (JANGAN await di MainActor — temuan A), tapi terstruktur:
    /// SATU Task per turn, budget total ~15 dtk (T0 8s + T1/T2 @6s, early-exit bila
    /// T0/T1 sepakat <=24px), cek Task.isCancelled tiap tingkat, handle disimpan di
    /// grounderTask agar stopCurrentTask/Escape bisa cancel. Callback via MainActor.run.
    /// T0 full-frame lossless -> T1 crop DIDILATASI (roiT1Size, tetangga dipertahankan)
    /// -> T2 ketat (roiT2Size) hanya bila tak sepakat/HSV FAIL. Confidence = kesepakatan
    /// Flush teks yang ditahan ke display (sekali, saat flight terpicu).
    func flushHeldTextForFlight() {
        guard groundingHoldActive else { return }
        groundingHoldActive = false
        homeSpaceStreamingText = Self.stripTechnicalTags(from: Self.stripPointingTags(from: accumulatedRawStreamingText))
        isHomeSpaceStreaming = !homeSpaceStreamingText.isEmpty
        streamingResponseText = Self.condenseForCursorHUD(homeSpaceStreamingText)
        isShowingStreamingResponse = !streamingResponseText.isEmpty
        streamingResponseOpacity = 1.0
        ClickyLogger.info("[SYNC]", "held text flushed with flight — together")
    }


    func requestGrounderEarly(
        expression: String,
        screenCaptures: [CompanionScreenCapture],
        screenNumber: Int?
    ) {
        // Plan perbaikan 22 Sep (Bug B): guard bungkam = misteri orange 13:28.
        // Tiap penolakan WAJIB log agar terlacak.
        guard grounderTask == nil, !grounderEarlyFiredThisTurn else {
            ClickyLogger.info("[GROUNDER]", "early skipped (task busy or fired this turn)")
            return
        }
        grounderEarlyFiredThisTurn = true
        grounderEarlyExpression = expression
        requestGrounderPrimary(expression: expression, screenCaptures: screenCaptures, screenNumber: screenNumber)
    }

    func requestGrounderPrimary(
        expression: String,
        screenCaptures: [CompanionScreenCapture],
        screenNumber: Int?
    ) {
        grounderTask?.cancel()
        let target: CompanionScreenCapture? = {
            if let n = screenNumber, n >= 1 && n <= screenCaptures.count { return screenCaptures[n - 1] }
            return screenCaptures.first(where: { $0.isCursorScreen }) ?? screenCaptures.first
        }()
        guard let target else {
            deliverPendingGrounded()
            return
        }

        groundingHoldActive = true
        let label = expression
        grounderTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let snapURL = tempDir.appendingPathComponent("companion_ground_\(UUID().uuidString).jpg")
                try target.imageData.write(to: snapURL)
                defer { try? FileManager.default.removeItem(at: snapURL) }

                let res = try await ChatGPTCodexVisionService.shared.queryCoordinates(
                    imagePath: snapURL.path,
                    targetElementPrompt: expression
                )
                let pt = CGPoint(x: res.x, y: res.y)
                ClickyLogger.success("[GROUNDER]", "Luna grounded '\(expression)' at (\(res.x), \(res.y))")
                self.triggerElementFlight(
                    coordinate: pt,
                    targetRadius: 24.0,
                    elementLabel: label,
                    screenNumber: screenNumber,
                    screenCaptures: screenCaptures
                )
                self.deliverPendingGrounded()
            } catch {
                ClickyLogger.warning("[GROUNDER]", "Luna grounding error: \(error.localizedDescription)")
                self.deliverPendingGrounded()
                self.announceGroundingInfeasible(expression: expression)
            }
            self.grounderTask = nil
        }
    }

    /// Fase 4-2: grounder menyerah ([-1,-1]) = target TIDAK TERLIHAT di layar.
    /// Jangan bungkam — katakan jujur + sebab yang bisa ditindak (app tidak terbuka?).
    /// Dipanggil async SETELAH turn selesai; chat susulan, bukan pengganti jawaban model.
    /// Opsi user 22 Sep: kirim paket chat/TTS/bubble yang ditunda menunggu grounder.
    /// Dipanggil saat grounded (bersamaan flight), infeasible, cancel, atau fail —
    /// agar user tidak pernah stuck tanpa jawaban.
    func deliverPendingGrounded() {
        // LOGIC PENUH (opsi user 22 Sep): akhir turn MENAHAN semua bila grounder
        // jalan. deliver kirim SEMUA sekaligus: chat + bubble + TTS + hide + idle.
        // Satu-satunya pengiriman — tidak ada duplikat karena turn menahan.
        guard let pending = pendingGroundedDelivery else { return }
        pendingGroundedDelivery = nil
        groundingHoldActive = false
        ClickyLogger.info("[SYNC]", "delivering ALL at once: chat+bubble+TTS+flight")
        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: pending.spoken))
        finishStreamingResponseText(pending.spoken)
        homeSpaceStreamingText = ""
        isHomeSpaceStreaming = false
        let speechClean = Self.stripTechnicalTags(from: pending.spoken)
        if Defaults[.cursorAssistantVoiceOutputEnabled] && !speechClean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let ttsWords = speechClean.split { $0.isWhitespace }.count
            lastTTSDurationEstimate = max(2.0, Double(ttsWords) / 2.5)
            NotificationCenter.default.post(name: .clickyTTSStarted, object: nil)
            Task {
                do {
                    try await elevenLabsTTSClient.speakText(speechClean)
                    if elevenLabsTTSClient.lastSpokenDuration > 0 {
                        lastTTSDurationEstimate = elevenLabsTTSClient.lastSpokenDuration
                    }
                    voiceState = .responding
                } catch {
                    let synthesizer = NSSpeechSynthesizer()
                    synthesizer.startSpeaking(speechClean)
                    voiceState = .responding
                }
            }
        } else if !pending.spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            voiceState = .responding
        }
        // Card nempel (22 Sep): hide di-arm SEBELUM TTS selesai karena speakText
        // async (Task tanpa await). Solusi: tahan hide sampai audio selesai —
        // polling isPlaying tiap 0.5 dtk, lalu schedule hide normal. Tanpa ini,
        // workItem hide 4-6 dtk bisa menang lawan audio yang baru mulai.
        scheduleHideAfterAudio(text: pending.final)
    }

    /// Tahan hide sampai TTS selesai (fix card-nempel 22 Sep). Polling ringan
    /// tiap 0.5 dtk: selama elevenLabsTTSClient.isPlaying, tunda. Begitu selesai
    /// (atau 30 dtk batas aman), schedule hide normal berbasis panjang teks.
    /// Native NSSpeech fallback tak terlacak isPlaying — beri jeda estimasi
    /// kata/2.5 per dtk sebelum hide (lebih baik telat 1 dtk daripada nempel).
    func scheduleHideAfterAudio(text: String) {
        responseBubbleHideWorkItem?.cancel()
        if !elevenLabsTTSClient.isPlaying {
            let words = text.split { $0.isWhitespace }.count
            let estimate = max(2.0, Double(words) / 2.5)
            ClickyLogger.info("[SYNC]", "hide after native-speech estimate \(String(format: "%.1f", estimate))s")
            scheduleResponseBubbleHide(for: text)
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.elevenLabsTTSClient.isPlaying {
                self.scheduleHideAfterAudio(text: text)
                return
            }
            self.scheduleResponseBubbleHide(for: text)
        }
        responseBubbleHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    func announceGroundingInfeasible(expression: String) {
        markGroundingMiss()
        // Opsi user 22 Sep: lepas hold juga di jalur infeasible — teks jawaban
        // model SUDAH tampil? Tidak (ditahan). Tampilkan jawaban model + pesan jujur.
        groundingHoldActive = false
        let wasID = (ongoingTaskGoal ?? "").range(of: "[a-zA-Z]{4,}", options: .regularExpression) == nil
            || (ongoingTaskGoal ?? "").lowercased().contains("mana")
            || (ongoingTaskGoal ?? "").lowercased().contains("dimana")
        let msg = wasID
            ? "itu tidak terlihat di layar sekarang — coba buka aplikasinya dulu lalu tanya lagi."
            : "that's not visible on screen right now — open the app first, then ask again."
        ClickyLogger.warning("[GROUNDER]", "announcing infeasible to user")
        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: msg))
        finishStreamingResponseText(msg)
    }

}
