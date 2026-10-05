//
//  CompanionManager+ReActExecution.swift
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
    func sendTranscriptToClaudeWithScreenshot(transcript: String) {
        self.ongoingTaskGoal = transcript
        currentResponseTask?.cancel()
        elevenLabsTTSClient.stopPlayback()
        hideResponseBubbleImmediately()
        clearDetectedElementLocation()
        hasTriggeredStreamingFlight = false
        flownTargetExpression = nil
        lastTTSDurationEstimate = 0
        lastFlightEndEstimate = nil
        grounderTask?.cancel()
        grounderTask = nil
        grounderEarlyFiredThisTurn = false
        grounderEarlyExpression = nil
        accumulatedRawStreamingText = ""
        currentActiveWorkSurface = ActiveWorkSurfaceManager.getActiveWorkSurface(queryHint: transcript)
        if let ws = currentActiveWorkSurface {
            ClickyLogger.info("[SURFACE]", "Active frontmost app: \"\(ws.appName)\" bounds: [X: \(Int(ws.frame.origin.x)), Y: \(Int(ws.frame.origin.y)), W: \(Int(ws.frame.width)), H: \(Int(ws.frame.height))] close: (\(Int(ws.trafficLightCloseCenter.x)), \(Int(ws.trafficLightCloseCenter.y)))")
        }

        // Record user query in conversation transcript if not already appended
        if chatMessages.last?.text != transcript || chatMessages.last?.isUser != true {
            appendChatMessage(HomeSpaceChatMessage(isUser: true, text: transcript))
        }

        currentResponseTask = Task {
            voiceState = .processing
            var finalSpokenText = ""

            do {
                let screenCaptures: [CompanionScreenCapture]
                do {
                    screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()
                } catch {
                    ClickyLogger.warning("[SCREEN]", "Screen capture unavailable (\(error.localizedDescription)). Proceeding with text-only voice query.")
                    screenCaptures = []
                }

                guard !Task.isCancelled else { return }

                // Plan perbaikan 22 Sep (3.1b): SoM/legenda DIHAPUS dari pipeline.
                // Model tidak lagi lihat nomor/legenda (sumber [CANDIDATE:] liar).
                // Pipeline kirim JPEG MENTAH + TARGET-expression. Annotate hidup hanya
                // via buildSoMDebugImage() manual (IZANOTCHY_SOM_DEBUG=1, Fase 4 tool).
                // screenCaptures immutable di sini — mutableCaptures = salinan mentah.
                let mutableCaptures = screenCaptures
                let somLegends: [[String]] = Array(repeating: [], count: mutableCaptures.count)
                let labeledImages = mutableCaptures.map { capture in
                    let dimensionInfo = " (image dimensions: \(capture.screenshotWidthInPixels)x\(capture.screenshotHeightInPixels) pixels)"
                    return (data: capture.imageData, label: capture.label + dimensionInfo)
                }

                // 1. Build initial conversation history for multi-turn context
                // Use rawResponseWithTags so the model sees [POINT:x,y:label] tags from
                // prior turns and can imitate the same format in its next response.
                var messagesForAPI: [[String: Any]] = []
                for entry in conversationHistory {
                    messagesForAPI.append(["role": "user", "content": entry.userTranscript])
                    // SoM: miss turns must not become few-shot exemplars — neutralize
                    // their tags so the model imitates format, not wrong coordinates.
                    if entry.groundingHit {
                        messagesForAPI.append(["role": "assistant", "content": entry.rawResponseWithTags])
                    } else {
                        messagesForAPI.append(["role": "assistant", "content": Self.neutralizeMissTags(in: entry.rawResponseWithTags)])
                    }
                }

                // 2. Build current turn user content with labeled screenshot images + raw transcript
                var currentTurnContent: [[String: Any]] = []
                for (idx, image) in labeledImages.enumerated() {
                    currentTurnContent.append([
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": image.data.base64EncodedString()
                        ]
                    ])
                    currentTurnContent.append([
                        "type": "text",
                        "text": image.label
                    ])
                    // Plan perbaikan: legenda MATI permanen (array selalu kosong).
                    // Blok dipertahankan agar debug-tool Fase 4 bisa tempel manual.
                    if idx < somLegends.count, !somLegends[idx].isEmpty {
                        currentTurnContent.append([
                            "type": "text",
                            "text": "numbered marks legend (nomor = id = label ID / label EN):\n" + somLegends[idx].joined(separator: "\n")
                        ])
                    }
                }
                currentTurnContent.append([
                    "type": "text",
                    "text": transcript
                ])
                messagesForAPI.append(["role": "user", "content": currentTurnContent])

                // MARK: - 3-Layer Deterministic Pipeline (TUNJUK, AKSI, TANYA)
                // Replaces 56-tool blackbox ReAct loop with fast-path router, category-scoped tools & local gates
                await ClickyDeterministicPipeline.shared.processCommand(
                    transcript: transcript,
                    screenCaptures: mutableCaptures,
                    workSurface: currentActiveWorkSurface
                )
                return

                // 3. Load all 56 native tools from embedded cua-driver MCP (instant RAM/disk cache + KV prompt caching)
                let nativeTools = await CuaDriverClient.shared.getAllNativeTools()

                let siriPlanner = self.isSiriAI
                let systemPrompt = Self.buildCompanionVoiceResponseSystemPrompt(
                    workSurface: currentActiveWorkSurface,
                    buddy: self.activeBuddy,
                    isPreApproved: self.isTaskSessionPreApproved,
                    isSiriAIPlannerPath: siriPlanner
                )

                var currentMessages = messagesForAPI
                var fullResponseText = ""
                var hadGroundingMissThisTurn = false
                var turnCount = 0
                let maxTurns = 25

                // 4. ReAct Autonomous Multi-Turn Loop (HeyClicky Continuous Execution Contract)
                while turnCount < maxTurns {
                    turnCount += 1
                    ClickyLogger.info("[REACT_LOOP]", "Starting Turn \(turnCount)/\(maxTurns) with \(nativeTools.count) native tools...")

                    // Reset per-turn streaming accumulator so text from previous turns isn't mashed together.
                    // turnCount > 1 marks a correction turn: a newly parsed tag may
                    // replace the prior flight (Stage 1 correction unlock).
                    self.accumulatedRawStreamingText = ""
                    self.hasTriggeredStreamingFlight = false
                    // Plan perbaikan 22 Sep: reset early-grounder per ReAct-turn.
                    self.grounderEarlyFiredThisTurn = false
                    self.grounderEarlyExpression = nil
                    let isCorrectionTurn = turnCount > 1

                    let turnResult: ClaudeTurnResult
                    if self.isSiriAI {
                        ClickyLogger.info("[SIRI_AI]", "Routing Turn \(turnCount) to on-device Apple Foundation Models (/usr/bin/fm serve)")
                        turnResult = try await SiriAIEngine.shared.analyzeMessagesWithToolsStreaming(
                            messages: currentMessages,
                            systemPrompt: systemPrompt,
                            tools: nativeTools,
                            maxTokens: 1024,
                            onTextChunk: { [weak self] chunk in
                                Task { @MainActor in
                                    self?.showStreamingChunk(chunk, screenCaptures: mutableCaptures, isCorrectionTurn: isCorrectionTurn)
                                }
                            }
                        )
                    } else {
                        turnResult = try await claudeAPI.analyzeMessagesWithToolsStreaming(
                            messages: currentMessages,
                            systemPrompt: systemPrompt,
                            tools: nativeTools,
                            maxTokens: 1024,
                            onTextChunk: { [weak self] chunk in
                                Task { @MainActor in
                                    self?.showStreamingChunk(chunk, screenCaptures: mutableCaptures, isCorrectionTurn: isCorrectionTurn)
                                }
                            }
                        )
                    }

                    guard !Task.isCancelled else { return }

                    if !turnResult.text.isEmpty {
                        fullResponseText = turnResult.text
                    }

                    // If intermediate status was spoken and tools are about to run,
                    // allow a brief reading dwell time (1.2s) so the user can read the status
                    if !turnResult.text.isEmpty && !turnResult.toolCalls.isEmpty {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                    }

                    // If model did not call any tools, final answer has been produced!
                    if turnResult.toolCalls.isEmpty {
                        ClickyLogger.success("[REACT_LOOP]", "Turn \(turnCount): Model completed turn without further tool calls.")
                        break
                    }

                    // Model called native tools — log with arguments for full transparency:
                    let callSummary = turnResult.toolCalls.map { c -> String in
                        let argsStr = (try? JSONSerialization.data(withJSONObject: c.arguments)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                        return "\(c.name)(\(argsStr))"
                    }.joined(separator: ", ")
                    ClickyLogger.info("[REACT_LOOP]", "Turn \(turnCount): Model invoked \(turnResult.toolCalls.count) tool(s): [\(callSummary)]")

                    var assistantContent: [[String: Any]] = []
                    if !turnResult.text.isEmpty {
                        assistantContent.append(["type": "text", "text": turnResult.text])
                    }
                    for call in turnResult.toolCalls {
                        assistantContent.append([
                            "type": "tool_use",
                            "id": call.id,
                            "name": call.name,
                            "input": call.arguments
                        ])
                    }
                    currentMessages.append(["role": "assistant", "content": assistantContent])

                    var toolResultBlocks: [[String: Any]] = []
                    var shouldAbortLoop = false

                    for call in turnResult.toolCalls {
                        ClickyLogger.info("[TOOL_EXEC]", "Preparing to execute tool: \(call.name)")

                        // CONSENT GATE: Input tools require user approval unless pre-approved
                        let reactInputTools = Set(["click", "right_click", "type_text", "press_key", "hotkey", "scroll", "set_value", "page", "launch_app", "kill_app"])
                        let isApprovedForInput = Defaults[.alwaysAllowComputerUse] || self.isTaskSessionPreApproved

                        if reactInputTools.contains(call.name) && !isApprovedForInput {
                            let argsStr = (try? JSONSerialization.data(withJSONObject: call.arguments, options: [])).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                            let consentBody = "Saya ingin mengeksekusi `\(call.name)` pada layar Anda.\nArgumen: \(String(argsStr.prefix(150)))\n\nApakah Anda mengizinkan?"

                            ClickyLogger.info("[CONSENT_GATE]", "Turn \(turnCount): Pausing for consent — tool '\(call.name)' requires approval.")

                            // Save continuation state so we can resume after user approves
                            self.pendingReActMessages = currentMessages
                            self.pendingReActSystemPrompt = systemPrompt
                            self.pendingReActNativeTools = nativeTools
                            self.pendingReActScreenCaptures = screenCaptures
                            self.pendingReActOriginalTranscript = transcript

                            let consentReq = ComputerUseRequest(
                                companionName: self.activeBuddy.name,
                                companionMood: .happy,
                                cloudColorHex: self.activeBuddy.avatarColorHex,
                                ringColorHex: "#BAE6FD",
                                heading: "Ingin mengontrol layar Anda",
                                bodyText: consentBody,
                                payload: ComputerUseActionPayload(
                                    type: .click,
                                    targetCoordinate: nil,
                                    targetApp: "System",
                                    rawDetails: consentBody
                                )
                            )

                            Task { @MainActor in
                                self.pendingComputerUseRequest = consentReq
                                ClickySoundEngine.shared.play(.question)
                                CompanionUIHostRegistry.shared?.showConsent(with: consentReq)
                            }

                            shouldAbortLoop = true
                            break
                        }

                        var executionResult: [String: Any] = [:]
                        var toolErrorMessage: String? = nil
                        do {
                            executionResult = try await CuaDriverClient.shared.executeTool(name: call.name, arguments: call.arguments)
                        } catch {
                            toolErrorMessage = error.localizedDescription
                            executionResult = ["error": error.localizedDescription]
                            ClickyLogger.error("[TOOL_EXEC]", "✗ \(call.name) THREW: \(error.localizedDescription)")
                        }

                        // --- Detect degraded/error result from structured content ---
                        // Special case: get_window_state on Electron apps (e.g. TradingView) always returns
                        // degraded AX tree (ax_window_unresolved), but STILL returns a valid screenshot.
                        // In this case, do NOT fail-fast — pass the screenshot to the model as visual context
                        // and let it navigate via pixel coordinates instead of AX elements.
                        let hasScreenshotInContent = (executionResult["content"] as? [[String: Any]])?
                            .contains(where: { $0["type"] as? String == "image" }) ?? false

                        if toolErrorMessage == nil {
                            if let err = executionResult["error"] as? String {
                                toolErrorMessage = err
                            } else if let sc = executionResult["structuredContent"] as? [String: Any],
                                      let degraded = sc["degraded"] as? Bool, degraded,
                                      let reason = sc["degraded_reason"] as? String {
                                // Only treat as hard failure if there is NO screenshot to fall back on
                                if hasScreenshotInContent {
                                    ClickyLogger.info("[TOOL_EXEC]", "⚠️ \(call.name) AX degraded (\(reason.prefix(80))...) but screenshot available — continuing with visual-only mode.")
                                } else {
                                    toolErrorMessage = reason
                                }
                            }
                        }

                        // --- Log result transparently ---
                        let resultPreview: String
                        if let textContent = (executionResult["content"] as? [[String: Any]])?
                            .first(where: { $0["type"] as? String == "text" })?["text"] as? String {
                            resultPreview = String(textContent.prefix(300))
                        } else if let err = toolErrorMessage {
                            resultPreview = "ERROR: \(err)"
                        } else if let sc = executionResult["structuredContent"] as? [String: Any],
                                  let scData = try? JSONSerialization.data(withJSONObject: sc),
                                  let scStr = String(data: scData, encoding: .utf8) {
                            resultPreview = String(scStr.prefix(300))
                        } else {
                            resultPreview = "ok"
                        }
                        ClickyLogger.info("[TOOL_EXEC]", "← \(call.name) | \(resultPreview)")

                        // --- FAIL-FAST: if tool failed, stop loop and show fallback error to user ---
                        if let errMsg = toolErrorMessage {
                            let userFacing = "⚠️ Aksi `\(call.name)` gagal: \(String(errMsg.prefix(200))). Silakan coba lagi atau berikan instruksi lebih spesifik."
                            ClickyLogger.error("[REACT_LOOP]", "FAIL-FAST on '\(call.name)': \(errMsg). Stopping loop.")
                            Task { @MainActor in
                                self.showStreamingChunk(userFacing, screenCaptures: screenCaptures)
                            }
                            fullResponseText = userFacing
                            shouldAbortLoop = true
                            break
                        }

                        var resultContent: [[String: Any]] = []

                        // 1. Extract native image or text items directly from cua-driver's content array
                        if let contentBlocks = executionResult["content"] as? [[String: Any]], !contentBlocks.isEmpty {
                            for block in contentBlocks {
                                let blockType = block["type"] as? String ?? ""
                                if blockType == "image", let base64Data = block["data"] as? String {
                                    let mime = block["mimeType"] as? String ?? "image/png"
                                    resultContent.append([
                                        "type": "image",
                                        "source": [
                                            "type": "base64",
                                            "media_type": mime,
                                            "data": base64Data
                                        ]
                                    ])
                                    ClickyLogger.info("[TOOL_EXEC]", "📸 \(call.name) → screenshot attached (\(mime))")
                                } else if blockType == "text", let text = block["text"] as? String {
                                    resultContent.append([
                                        "type": "text",
                                        "text": text
                                    ])
                                }
                            }
                        }

                        // 2. Fallback text representation if no text block was populated
                        if !resultContent.contains(where: { ($0["type"] as? String) == "text" }) {
                            let resultString: String
                            if let sc = executionResult["structuredContent"] as? [String: Any],
                               let scData = try? JSONSerialization.data(withJSONObject: sc, options: [.prettyPrinted]),
                               let scStr = String(data: scData, encoding: .utf8) {
                                resultString = scStr
                            } else if let err = executionResult["error"] as? String {
                                resultString = "Error: \(err)"
                            } else if let resData = try? JSONSerialization.data(withJSONObject: executionResult),
                                      let resStr = String(data: resData, encoding: .utf8) {
                                resultString = resStr
                            } else {
                                resultString = "success: true"
                            }
                            resultContent.insert(["type": "text", "text": resultString], at: 0)
                        }

                        // 3. Fallback file-path screenshot if returned
                        if let shotPath = executionResult["screenshot_file_path"] as? String,
                           let shotData = try? Data(contentsOf: URL(fileURLWithPath: shotPath)) {
                            resultContent.append([
                                "type": "image",
                                "source": [
                                    "type": "base64",
                                    "media_type": "image/png",
                                    "data": shotData.base64EncodedString()
                                ]
                            ])
                            ClickyLogger.info("[TOOL_EXEC]", "📸 \(call.name) → file screenshot attached")
                        }

                        toolResultBlocks.append([
                            "type": "tool_result",
                            "tool_use_id": call.id,
                            "content": resultContent
                        ])
                    }

                    if shouldAbortLoop { break }
                    currentMessages.append(["role": "user", "content": toolResultBlocks])
                }

                guard !Task.isCancelled else { return }

                // 5. Final Verbal Synthesis Pass (Anti-Blank / HeyClicky Guaranteed Voice Response)
                // If the loop finished executing tools but the model did not emit a final text report,
                // give the model one final synthesis turn without tools so it speaks its findings!
                if fullResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ClickyLogger.info("[REACT_LOOP]", "ReAct loop finished. Executing final verbal synthesis pass...")
                    let synthesisMessages = currentMessages + [
                        ["role": "user", "content": [
                            ["type": "text", "text": "Seluruh observasi dan tindakan fisik telah selesai dijalankan. Berikan jawaban, laporan analisis visual, dan kesimpulan lengkap kepada pengguna sekarang secara ramah dan profesional."]
                        ]]
                    ]
                    let finalSynthesisResult: ClaudeTurnResult?
                    if self.isSiriAI {
                        finalSynthesisResult = try? await SiriAIEngine.shared.analyzeMessagesWithToolsStreaming(
                            messages: synthesisMessages,
                            systemPrompt: systemPrompt,
                            tools: [],
                            maxTokens: 1536,
                            onTextChunk: { [weak self] chunk in
                                Task { @MainActor in
                                    self?.showStreamingChunk(chunk, screenCaptures: screenCaptures, isCorrectionTurn: true)
                                }
                            }
                        )
                    } else {
                        finalSynthesisResult = try? await claudeAPI.analyzeMessagesWithToolsStreaming(
                            messages: synthesisMessages,
                            systemPrompt: systemPrompt,
                            tools: [], // Empty tools array forces the model to speak text
                            maxTokens: 1536,
                            onTextChunk: { [weak self] chunk in
                                Task { @MainActor in
                                    self?.showStreamingChunk(chunk, screenCaptures: screenCaptures, isCorrectionTurn: true)
                                }
                            }
                        )
                    }
                    if let synthesis = finalSynthesisResult, !synthesis.text.isEmpty {
                        fullResponseText = synthesis.text
                        ClickyLogger.success("[REACT_LOOP]", "Final verbal synthesis successfully generated (\(fullResponseText.count) chars)")
                    }
                }

                let parseResult = Self.parsePointingCoordinates(from: fullResponseText)
                // Opsi D Fase 2 final parse (lawan reorder chunk): TARGET lengkap
                // pertama menang per turn; diobservasi via log, belum gerakkan flight.
                if let targetExpr = Self.parseTargetExpression(from: fullResponseText) {
                    let enriched = Self.enrichTargetExpressionFixed(targetExpr, workSurface: currentActiveWorkSurface)
                    ClickyLogger.info("[TARGET_PLANNER]", "final expression: \"\(enriched)\"")
                }
                var spokenText = parseResult.spokenText

                let (cleanedAfterRequest, computerUseReq) = Self.parseComputerUseRequest(from: spokenText, activeBuddy: self.activeBuddy)
                let (cleanedAfterAction, proposedAction) = Self.parseProposedAction(from: cleanedAfterRequest)
                let tvPayload = Self.extractTradingViewPayload(from: fullResponseText)

                // When native Cua Driver tools are enabled, all actions were executed inside the ReAct loop.
                // Only fall back to legacy regex-parsed actions if native tools were not available (empty).
                if nativeTools.isEmpty, let req = computerUseReq {
                    spokenText = cleanedAfterRequest
                    hideResponseBubbleImmediately()
                    if Defaults[.alwaysAllowComputerUse] || self.isTaskSessionPreApproved {
                        ClickyLogger.info("[COMPUTER_USE]", "Full Access / Session pre-approved. Executing directly in autonomous loop: \(req.payload.rawDetails)")
                        let goal = self.ongoingTaskGoal ?? transcript
                        currentResponseTask?.cancel()
                        currentResponseTask = Task { @MainActor in
                            await self.executeAndContinueAutonomousLoop(payload: req.payload, initialGoal: goal)
                        }
                        return
                    } else {
                        self.pendingComputerUseRequest = req
                        ClickySoundEngine.shared.play(.question)
                        CompanionUIHostRegistry.shared?.showConsent(with: req)
                    }
                } else if nativeTools.isEmpty, let action = proposedAction {
                    spokenText = cleanedAfterAction
                    if Defaults[.alwaysAllowComputerUse] || self.isTaskSessionPreApproved {
                        let payload = ComputerUseActionPayload(
                            type: tvPayload != nil ? .tradingViewAction : (action.actionType == .keyCombo ? .keyCombo : (action.actionType == .launchApp ? .launchApp : .click)),
                            targetCoordinate: action.targetCoordinate,
                            targetApp: action.appName,
                            tradingViewPayload: tvPayload,
                            rawDetails: action.title
                        )
                        let goal = self.ongoingTaskGoal ?? transcript
                        currentResponseTask?.cancel()
                        currentResponseTask = Task { @MainActor in
                            await self.executeAndContinueAutonomousLoop(payload: payload, initialGoal: goal)
                        }
                        return
                    } else {
                        self.proposedComputerUseAction = action
                        ClickySoundEngine.shared.play(.question)
                    }
                } else {
                    spokenText = Self.stripTechnicalTags(from: spokenText)
                    finishStreamingResponseText(spokenText)
                }

                // Restore local Farza assistant cursor after Cua Driver actions finish (only if not already visible)
                if self.isClickyCursorEnabled && !self.isOverlayVisible {
                    self.showOverlay()
                }

                spokenText = Self.stripTechnicalTags(from: spokenText)
                finalSpokenText = spokenText

                // Fallback flight trigger (Opsi D Fase 3a): [CANDIDATE:] passive,
                // then TARGET->AX rarity-match, else legacy [POINT:] guess.
                var resolvedCoordinate = parseResult.coordinate
                var resolvedLabel = parseResult.elementLabel
                var resolvedRadius = parseResult.targetRadius

                // Hotfix live-test: intent gate juga di fallback. Tanpa ini,
                // "halo" + [CANDIDATE:] pasif tetap terbang (bug 10:28).
                let fallbackAllowed = Self.hasPointingIntent(transcript: transcript)
                if !fallbackAllowed {
                    ClickyLogger.info("[INTENT_GATE]", "suppressed fallback flight for non-spatial transcript")
                }
                if fallbackAllowed, !hasTriggeredStreamingFlight {
                    if resolvedCoordinate != nil {
                        // Opsi D Fase 3a: enforcement + semantic keyword fallback
                        // dihapus. Coba TARGET-expression -> AX rarity-match dulu;
                        // gagal = pertahankan tebakan legacy (grounder Fase 3b tangani).
                        // Hotfix #3: verifikasi flight streaming vs final — tak sepakat
                        // = flight salah (kasus 10:51) -> clear + flight ulang final.
                        if let targetExpr = Self.parseTargetExpression(from: fullResponseText),
                           Self.isMatureTargetExpression(targetExpr) {
                            let enriched = Self.enrichTargetExpressionFixed(targetExpr, workSurface: currentActiveWorkSurface)
                            if !Self.targetExpressionsAgree(flownTargetExpression ?? "", enriched) {
                                ClickyLogger.warning("[POINTING]", "streaming flight DISAGREES with final (flown=\"\(flownTargetExpression ?? "-")\" final=\"\(enriched)\") - re-flying")
                                clearDetectedElementLocation()
                                hasTriggeredStreamingFlight = false
                                flownTargetExpression = nil
                            }
                        }
                    }
                    if resolvedCoordinate == nil {
                        // Opsi D Fase 3a: semantic keyword fallback (dock/icon/mana,
                        // tombol-merah/close/tutup) DIHAPUS — sumber tembakan keyword.
                        // AX-miss diteruskan ke grounder primer (Fase 3b) di bawah.
                        ClickyLogger.info("[TARGET_PLANNER]", "AX miss at fallback - grounder path")
                    }

                    if let pointCoordinate = resolvedCoordinate {
                        triggerElementFlight(
                            coordinate: pointCoordinate,
                            normalizedBox: parseResult.normalizedBox,
                            targetRadius: resolvedRadius,
                            elementLabel: resolvedLabel,
                            screenNumber: parseResult.screenNumber,
                            screenCaptures: mutableCaptures
                        )
                    } else if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ClickySoundEngine.shared.play(.question)
                    } else {
                        // Opsi D Fase 3b: AX-miss -> grounder primer. Instruction =
                        // planner TARGET-expression (enriched) bila ada, else transcript
                        // mentah (planner wajib; terbukti MISS tanpa planner — tetap coba).
                        // Hotfix #3: final matang SELALU menang atas transcript mentah.
                        // ID mentah tanpa planner TERBUKTI miss total (uji 21 Sep) —
                        // grounder wajib dapat EN Long-RE, bukan transcript ID.
                        let grounderInstruction: String
                        if let targetExpr = Self.parseTargetExpression(from: fullResponseText),
                           Self.isMatureTargetExpression(targetExpr) {
                            grounderInstruction = Self.enrichTargetExpressionFixed(targetExpr, workSurface: currentActiveWorkSurface)
                        } else if let flown = flownTargetExpression, Self.isMatureTargetExpression(flown) {
                            grounderInstruction = flown
                        } else {
                            grounderInstruction = transcript
                        }
                        if fallbackAllowed {
                            if let early = grounderEarlyExpression,
                               !Self.targetExpressionsAgree(early, grounderInstruction) {
                                ClickyLogger.warning("[GROUNDER]", "early guess DISAGREES with final - restarting")
                                grounderTask?.cancel()
                                grounderTask = nil
                                grounderEarlyExpression = nil
                            }
                            if grounderTask == nil {
                                ClickyLogger.info("[GROUNDER]", "starting primary at fallback for \"(grounderInstruction.prefix(60))\"")
                                grounderEarlyExpression = nil
                                requestGrounderPrimary(
                                    expression: grounderInstruction,
                                    screenCaptures: mutableCaptures,
                                    screenNumber: parseResult.screenNumber
                                )
                                if grounderTask != nil {
                                    // Grounder jalan: TUNDA chat/TTS sampai selesai.
                                    pendingGroundedDelivery = (spoken: spokenText, final: finalSpokenText)
                                    ClickyLogger.info("[SYNC]", "deferring chat+TTS until grounder completes")
                                }
                            } else {
                                // BUKAN leak bila ini task EARLY yang cocok dengan final:
                                // ia masih jalan dan hasilnya dipakai. Tunda chat/TTS juga.
                                if grounderEarlyExpression != nil {
                                    pendingGroundedDelivery = (spoken: spokenText, final: finalSpokenText)
                                    ClickyLogger.info("[SYNC]", "deferring chat+TTS until early grounder completes")
                                } else {
                                    ClickyLogger.warning("[GROUNDER]", "fallback skipped: stale grounderTask busy (lifecycle leak?)")
                                }
                            }
                        }
                    }
                }

                // State machine: turn selesai TANPA flight + TANPA grounder jalan =
                // lepas hold, kirim biasa (jangan bungkam). Grounder jalan = pending
                // (callback deliver). history tetap dicatat dua-duanya.
                if groundingHoldActive, grounderTask == nil, pendingGroundedDelivery == nil {
                    groundingHoldActive = false
                    ClickyLogger.info("[SYNC]", "hold released at turn end (no flight, no grounder)")
                }

                // LOGIC PENUH (opsi user 22 Sep): grounder masih jalan (fresh dari
                // fallback ATAU early-cocok yang dipertahankan) -> TAHAN SEMUA.
                // Tidak chat, tidak TTS, tidak hide, tidak idle. Callback grounder
                // (grounded/infeasible/cancel/fail) kirim semuanya sekaligus.
                if grounderTask != nil, pendingGroundedDelivery == nil {
                    pendingGroundedDelivery = (spoken: spokenText, final: finalSpokenText)
                    ClickyLogger.info("[SYNC]", "holding ALL output until grounder completes")
                }

                // Save this exchange to conversation history.
                // rawResponseWithTags preserves [POINT:x,y:label] tags so the model can
                // imitate the same format in future turns (in-context few-shot memory).
                conversationHistory.append((
                    userTranscript: transcript,
                    assistantResponse: spokenText,
                    rawResponseWithTags: fullResponseText,
                    groundingHit: !hadGroundingMissThisTurn && !Self.pendingGroundingMiss
                ))
                Self.pendingGroundingMiss = false

                // Opsi user 22 Sep: grounder jalan -> chat/TTS ditunda, callback kirim.
                // (history tetap dicatat agar konteks tidak hilang.)
                if pendingGroundedDelivery == nil {
                    appendChatMessage(HomeSpaceChatMessage(isUser: false, text: spokenText))
                } else {
                    ClickyLogger.info("[SYNC]", "chat held for grounder")
                }

                // Immediately clear HomeSpace active streaming state upon successful message arrival
                self.homeSpaceStreamingText = ""
                self.isHomeSpaceStreaming = false
                self.ongoingTaskGoal = nil

                // Keep only the last 10 exchanges to avoid unbounded context growth
                if conversationHistory.count > 10 {
                    conversationHistory.removeFirst(conversationHistory.count - 10)
                }

                print("🧠 Conversation history: \(conversationHistory.count) exchanges")

                ClickyAnalytics.trackAIResponseReceived(response: spokenText)

                // Opsi user 22 Sep: TTS ikut ditunda bila grounder jalan.
                let grounderPending = pendingGroundedDelivery != nil
                // Play the response via TTS if voice output is enabled
                let isVoiceOutputEnabled = Defaults[.cursorAssistantVoiceOutputEnabled] && !grounderPending
                let speechClean = Self.stripTechnicalTags(from: spokenText)
                if isVoiceOutputEnabled && !speechClean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Plan sinkron-teks S3: estimasi durasi audio (~2.5 kata/dtk) untuk
                    // hold bubble = max(wordDelay, TTS+1.0, flightEnd+3.0). Event started
                    // dipost agar view bisa hold; presisi tidak perlu (±30% diterima).
                    let ttsWords = speechClean.split { $0.isWhitespace }.count
                    lastTTSDurationEstimate = max(2.0, Double(ttsWords) / 2.5)
                    NotificationCenter.default.post(name: .clickyTTSStarted, object: nil)
                    do {
                        try await elevenLabsTTSClient.speakText(speechClean)
                        // speakText returns after player.play() — audio is now playing.
                        // Plan perbaikan 22 Sep (3.3): durasi RIIL menimpa estimasi.
                        if elevenLabsTTSClient.lastSpokenDuration > 0 {
                            lastTTSDurationEstimate = elevenLabsTTSClient.lastSpokenDuration
                        }
                        voiceState = .responding
                    } catch {
                        ClickyAnalytics.trackTTSError(error: error.localizedDescription)
                        print("⚠️ ElevenLabs TTS error: \(error), falling back to macOS native TTS")
                        let synthesizer = NSSpeechSynthesizer()
                        synthesizer.startSpeaking(speechClean)
                        voiceState = .responding
                    }
                } else if !grounderPending, !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Silent Mode (Text Bubble Only):
                    voiceState = .responding
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }
            } catch is CancellationError {
                // User spoke again — response was interrupted
                self.homeSpaceStreamingText = ""
                self.isHomeSpaceStreaming = false
                self.ongoingTaskGoal = nil
            } catch {
                self.homeSpaceStreamingText = ""
                self.isHomeSpaceStreaming = false
                self.ongoingTaskGoal = nil
                ClickyAnalytics.trackResponseError(error: error.localizedDescription)
                print("⚠️ Companion response error: \(error)")
                speakCreditsErrorFallback()
            }

            if !Task.isCancelled, pendingGroundedDelivery == nil {
                voiceState = .idle
                isHomeSpaceStreaming = false
                homeSpaceStreamingText = ""
                self.ongoingTaskGoal = nil
                scheduleTransientHideIfNeeded()
                scheduleResponseBubbleHide(for: finalSpokenText)
            }
        }
    }

    /// If the cursor is in transient mode (user toggled "Show Clicky" off),
    /// waits for TTS playback and any pointing animation to finish, then
    /// fades out the overlay after a 1-second pause. Cancelled automatically
    /// if the user starts another push-to-talk interaction.
    func scheduleTransientHideIfNeeded() {
        guard !isClickyCursorEnabled && isOverlayVisible else { return }

        transientHideTask?.cancel()
        transientHideTask = Task {
            // Wait for TTS audio to finish playing
            while elevenLabsTTSClient.isPlaying {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
            }

            // Wait for pointing animation to finish (location is cleared
            // when the buddy flies back to the cursor, max 4s)
            var flightWaitSteps = 0
            while detectedElementScreenLocation != nil && flightWaitSteps < 20 {
                flightWaitSteps += 1
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
            }

            // Pause 1s after everything finishes, then fade out
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            fadeOutOverlay()
        }
    }

    /// Speaks an informative error message using macOS system TTS when AI
    /// connection fails or bridge is unreachable.
    func speakCreditsErrorFallback() {
        let isBridgeRunning = GeminiBridgeClient.bridgeProvider?.isRunning ?? true
        let utterance: String
        if !isBridgeRunning {
            utterance = "Clicky tidak dapat terhubung ke Gemini AI Bridge. Silakan periksa status AI Bridge di pengaturan BoringNotch."
        } else {
            utterance = "Maaf, terjadi kendala saat meminta respon ke Gemini. Silakan coba lagi."
        }
        let synthesizer = NSSpeechSynthesizer()
        synthesizer.startSpeaking(utterance)
        voiceState = .responding
    }

}
