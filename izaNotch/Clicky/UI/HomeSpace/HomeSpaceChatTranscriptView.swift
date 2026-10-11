//
//  HomeSpaceChatTranscriptView.swift
//  izaNotch (Izanotchy)
//
//  Decomposed extension for HomeSpaceRootView.
//

import AppKit
import Defaults
import Foundation
import SwiftUI

extension HomeSpaceRootView {
    // MARK: - Section 2: Active Chat Workspace View
    var chatWorkspaceView: some View {
        ZStack(alignment: .trailing) {
            if isCreatingNewBuddy {
                newBuddyCreationView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if activeViewMode == .connectedApps {
                connectedAppsWorkspaceView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if activeViewMode == .editCharacter || isEditingCharacter {
                editCharacterFullWorkspaceView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                VStack(spacing: 0) {
                    // Sub-Section 2A: Clean Header Bar (Clean, NO iza logo, NO capsule card)
                    HStack {
                        Spacer()

                        // Top-Right Action Buttons (Close Only — Expand Eliminated)
                        Button(action: {
                            ClickySoundEngine.shared.play(.close)
                            onClose()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        .help("Close back to notch")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 6)

                    if companion.activeBuddy.messages.isEmpty && !companion.isResponding {
                        // Sub-Section 2B: Clean Modern Centered Welcome State (Zero badge, zero chips, vertically & horizontally centered)
                        VStack(spacing: 0) {
                            Spacer()

                            VStack(spacing: 10) {
                                Text(dynamicWelcomeTitle)
                                    .font(.system(size: 21, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)

                                Text(dynamicWelcomeSubtitle)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white.opacity(0.55))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 36)

                                // Real suggestions based on passive active app inspector
                                if let suggestion = suggestionMonitor.activeSuggestion, !suggestion.prompt.isEmpty {
                                    FollowUpPillButton(text: suggestion.prompt) {
                                        submitPrompt(suggestion.prompt)
                                    }
                                    .padding(.top, 12)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Sub-Section 2B: Real Chat Stream & Functional Transcript
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 14) {
                                    let allMessages = companion.activeBuddy.messages
                                    let olderCount = max(0, allMessages.count - visibleMessageLimit)
                                    let displayedMessages = Array(allMessages.suffix(visibleMessageLimit))
                                    let latestComputerMessageId = displayedMessages.last(where: { $0.computerPayload != nil })?.id

                                    if olderCount > 0 {
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                visibleMessageLimit += 25
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.up.circle.fill")
                                                    .font(.system(size: 11))
                                                Text("Load older messages (\(olderCount) more)")
                                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                            }
                                            .foregroundColor(Color(hex: "#38BDF8"))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.white.opacity(0.06))
                                                    .overlay(
                                                        Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                    }

                                    // Real Messages Stream
                                    ForEach(displayedMessages) { message in
                                        if message.isUser {
                                            HStack {
                                                Spacer()
                                                Text(message.text)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(Color(hex: "#0C1D38"))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color(hex: "#C7E5FE"), Color(hex: "#93C5FD")],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        )
                                                )
                                                .frame(maxWidth: 420, alignment: .trailing)
                                            }
                                            .id(message.id)
                                        } else {
                                            VStack(alignment: .leading, spacing: 10) {
                                                if let payload = message.computerPayload {
                                                    if message.id == latestComputerMessageId {
                                                        // SINGLE ACTIVE COMPUTER CARD: Placed inline directly with this turn!
                                                        HomeSpaceComputerCardView(
                                                            payload: payload,
                                                            onTakeoverClicked: {
                                                                ClickySoundEngine.shared.play(.open)
                                                                withAnimation(.spring(response: 0.25)) {
                                                                    CompanionVMViewportController.shared.isTakeoverActive.toggle()
                                                                }
                                                            },
                                                            onOpenWindowClicked: {
                                                                if let app = payload.targetAppName ?? payload.activeWorkflowApp {
                                                                    CompanionWindowStreamService.shared.launchOrFocusWorkflowApp(appName: app)
                                                                }
                                                            },
                                                            onCardTapped: nil,
                                                            isCollapsible: true,
                                                            isCollapsed: $companion.isWorkspaceCollapsed
                                                        )
                                                        .id("active-workspace-\(message.id)")
                                                    } else {
                                                        // PAST TURN: "meninggalkan stepnya yg sudah selesai tadi"
                                                        let pastItems = (payload.queueItems?.isEmpty == false ? payload.queueItems : nil)
                                                            ?? [ComputerCardQueueItem(name: payload.deliverableSummary ?? payload.queueSummary ?? payload.instructionText, statusBadge: "Done", isChecked: true)]

                                                        HomeSpaceComputerStepsView(
                                                            queueItems: pastItems,
                                                            status: payload.status,
                                                            isPastTurn: true,
                                                            targetAppName: payload.targetAppName ?? payload.activeWorkflowApp,
                                                            summary: payload.deliverableSummary ?? payload.queueSummary ?? payload.instructionText,
                                                            onTapped: {
                                                                ClickySoundEngine.shared.play(.open)
                                                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                                                    activeComputerModalPayload = payload
                                                                }
                                                            }
                                                        )
                                                        .id("past-steps-\(message.id)")
                                                    }
                                                }

                                                if !message.text.isEmpty {
                                                    MarkdownFormattedMessageView(text: message.text)
                                                }

                                                HStack(spacing: 8) {
                                                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                                                        .font(.system(size: 10, weight: .regular))
                                                        .foregroundColor(.white.opacity(0.4))

                                                    Button(action: {
                                                        NSPasteboard.general.clearContents()
                                                        NSPasteboard.general.setString(message.text, forType: .string)
                                                        copiedMessageID = message.id
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                            if copiedMessageID == message.id { copiedMessageID = nil }
                                                        }
                                                    }) {
                                                        Image(systemName: copiedMessageID == message.id ? "checkmark" : "doc.on.doc")
                                                            .font(.system(size: 9.5))
                                                            .foregroundColor(.white.opacity(0.4))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 4)
                                            .id(message.id)
                                        }
                                    }

                                    // Live Streaming Response Chunk (Clean State Separation)
                                    if companion.isHomeSpaceStreaming && !companion.homeSpaceStreamingText.isEmpty && companion.pendingComputerUseRequest == nil {
                                        VStack(alignment: .leading, spacing: 6) {
                                            MarkdownFormattedMessageView(text: companion.homeSpaceStreamingText)

                                            HStack(spacing: 6) {
                                                if let activeTool = toolDispatcher.currentExecutingToolName {
                                                    ProgressView()
                                                        .scaleEffect(0.55)
                                                        .frame(width: 12, height: 12)
                                                    Text("⚙️ Tool: \(activeTool)")
                                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                        .foregroundColor(Color(hex: "#38BDF8"))
                                                } else {
                                                    HStack(spacing: 4) {
                                                        Circle().fill(Color(hex: "#60A5FA")).frame(width: 4, height: 4)
                                                        Circle().fill(Color(hex: "#60A5FA").opacity(0.6)).frame(width: 4, height: 4)
                                                        Circle().fill(Color(hex: "#60A5FA").opacity(0.3)).frame(width: 4, height: 4)
                                                        Text("\(companion.activeBuddy.name) is responding...")
                                                            .font(.system(size: 10, weight: .medium))
                                                            .foregroundColor(Color(hex: "#60A5FA"))
                                                    }
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 4)
                                    }

                                    if let request = companion.pendingComputerUseRequest {
                                        ComputerUseConsentCardView(
                                            request: request,
                                            onAllowOnce: {
                                                companion.approveComputerUseOnce()
                                            },
                                            onAlwaysAllow: {
                                                companion.alwaysAllowComputerUse()
                                            },
                                            onNotNow: {
                                                companion.rejectComputerUse()
                                            },
                                            onClose: {
                                                companion.rejectComputerUse()
                                            }
                                        )
                                        .id("pendingComputerUseConsentCard")
                                        .padding(.top, 8)
                                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                                    } else if let action = companion.proposedComputerUseAction {
                                        ComputerUseConsentCardView(
                                            action: action,
                                            onApprove: { companion.approveComputerUseAction() },
                                            onReject: { companion.rejectComputerUseAction() }
                                        )
                                        .id("pendingComputerUseConsentCard")
                                        .padding(.top, 8)
                                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .padding(.bottom, 28)
                            }
                        .onAppear {
                            // Immediate Instant Bottom Pinning (Zero downward scroll animation)
                            if companion.pendingComputerUseRequest != nil || companion.proposedComputerUseAction != nil {
                                proxy.scrollTo("pendingComputerUseConsentCard", anchor: .bottom)
                            } else if let lastID = companion.activeBuddy.messages.last?.id {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                        .onChange(of: companion.activeSessionID) { _, _ in
                            visibleMessageLimit = 20
                            DispatchQueue.main.async {
                                if let lastID = companion.activeBuddy.messages.last?.id {
                                    proxy.scrollTo(lastID, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: companion.pendingComputerUseRequest != nil) { _, hasPending in
                            if hasPending {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    withAnimation { proxy.scrollTo("pendingComputerUseConsentCard", anchor: .bottom) }
                                }
                            }
                        }
                        .onChange(of: companion.activeBuddy.messages.count) { _, _ in
                            if let lastID = companion.activeBuddy.messages.last?.id {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(lastID, anchor: .bottom) }
                            }
                        }
                    }
                }

                // Sub-Section 2C: Floating Action Dock (1:1 Foto 1 & Foto 5, Centered compact width, zero color patch)
                    HStack {
                        Spacer()

                        VStack(spacing: 4) {
                            if let activeTool = toolDispatcher.currentExecutingToolName {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.55)
                                        .frame(width: 12, height: 12)
                                    Text("⚙️ Tool: \(activeTool)")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Color(hex: "#38BDF8"))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3.5)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#0369A1").opacity(0.18))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: "#38BDF8").opacity(0.35), lineWidth: 0.8)
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            HStack(spacing: 10) {
                                // Blue Circular Mic Button (Foto 1 - Clean Minimal)
                                Button(action: {
                                    if companion.buddyDictationManager.isRecordingFromMicrophoneButton {
                                        ClickySoundEngine.shared.play(.close)
                                        companion.buddyDictationManager.stopPersistentDictationFromMicrophoneButton()
                                    } else {
                                        ClickySoundEngine.shared.play(.open)
                                        Task {
                                            await companion.buddyDictationManager.startPersistentDictationFromMicrophoneButton(
                                                currentDraftText: inputText,
                                                updateDraftText: { transcribed in
                                                    inputText = transcribed
                                                },
                                                submitDraftText: { finalTranscript in
                                                    submitPrompt(finalTranscript)
                                                }
                                            )
                                        }
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: companion.buddyDictationManager.isRecordingFromMicrophoneButton ?
                                                        [Color(hex: "#FCA5A5"), Color(hex: "#EF4444")] :
                                                        [Color(hex: "#C7E5FE"), Color(hex: "#72B5FD")],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 38, height: 38)
                                            .overlay(
                                                Circle().stroke(Color.white.opacity(0.8), lineWidth: 1)
                                            )
                                            .shadow(
                                                color: companion.buddyDictationManager.isRecordingFromMicrophoneButton ?
                                                    Color.red.opacity(0.5) : Color(hex: "#60A5FA").opacity(0.4),
                                                radius: 5, y: 2
                                            )

                                        Image(systemName: companion.buddyDictationManager.isRecordingFromMicrophoneButton ? "stop.fill" : "mic.fill")
                                            .font(.system(size: companion.buddyDictationManager.isRecordingFromMicrophoneButton ? 11 : 13, weight: .bold))
                                            .foregroundColor(companion.buddyDictationManager.isRecordingFromMicrophoneButton ? .white : Color(hex: "#0F172A"))
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(companion.buddyDictationManager.isRecordingFromMicrophoneButton ? "Click to stop recording" : "Click to dictate voice or hold Control + Option")

                                // Input Pill (Foto 1)
                                HStack(spacing: 8) {
                                    Button(action: {
                                        ClickySoundEngine.shared.play(.open)
                                    }) {
                                        Image(systemName: "paperclip")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.55))
                                            .padding(6)
                                            .background(Circle().fill(Color.white.opacity(0.06)))
                                    }
                                    .buttonStyle(.plain)

                                    TextField("Message \(companion.activeBuddy.name)...", text: $inputText)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.white)
                                        .onSubmit {
                                            submitPrompt(inputText)
                                        }

                                    Spacer(minLength: 4)

                                    if companion.isProcessingTask {
                                        Button(action: {
                                            companion.stopCurrentTask()
                                            CompanionRosterStore.shared.updateCompanionStatus(id: companion.activeBuddy.id, status: .idle)
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 28, height: 28)
                                                    .shadow(color: Color(hex: "#EF4444").opacity(0.4), radius: 4, x: 0, y: 1)

                                                Image(systemName: "stop.fill")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Button(action: {
                                            submitPrompt(inputText)
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.12) : Color(hex: "#72B5FD"))
                                                    .frame(width: 28, height: 28)

                                                Image(systemName: "arrow.up")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white.opacity(0.4) : Color(hex: "#0F172A"))
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.45))
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color(hex: "#93C5FD").opacity(0.8), Color.white.opacity(0.15)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.2
                                                )
                                        )
                                )
                            }

                            // Microtext below input (Foto 1)
                            HStack {
                                Text("Return to send • Shift Return for a new line")
                                    .font(.system(size: 9.5, weight: .regular))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.leading, 50)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: 580) // Compact locked width!

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }

            // Section 3: Character Inspector Sidebar (1:1 Foto 1, Slide-Over Overlay)
            if isCharacterSidebarOpen && !isCreatingNewBuddy && !isEditingCharacter {
                characterInspectorSidebar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

        }
    }

}
