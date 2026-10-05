//
//  HomeSpaceOnboardingWizardView.swift
//  izaNotch (Izanotchy)
//
//  Decomposed extension for HomeSpaceRootView.
//

import AppKit
import Defaults
import Foundation
import SwiftUI

extension HomeSpaceRootView {
    // MARK: - New Clicky Companion Onboarding View (Option A: 3-Step Native Stepper)
    var newBuddyCreationView: some View {
        Group {
            switch interviewEngine.stage {
            case .interviewing:
                newBuddyInterviewView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            case .reviewingSpec:
                newBuddySpecReviewView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            case .customizingCharacter:
                newBuddyCharacterCustomizationView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            }
        }
    }

    // MARK: - Step 1: Interactive Interview with Glowing Cloud (1:1 Foto 4)
    var newBuddyInterviewView: some View {
        VStack(spacing: 0) {
            // Header: < Back + New Clicky + Skip to Spec
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        isCreatingNewBuddy = false
                        newBuddyPromptText = ""
                        interviewEngine.reset()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)

                Text("New Clicky")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.leading, 6)

                Spacer()

                if interviewEngine.userTurnCount >= 1 {
                    Button(action: {
                        interviewEngine.proceedToCharacterCustomization()
                    }) {
                        HStack(spacing: 4) {
                            Text("Skip to Spec")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            // Center Area: Glowing Mascot + Thought Bubble (Foto 4)
            VStack(spacing: 24) {
                Spacer()

                HStack(alignment: .bottom, spacing: 14) {
                    // Golden Yellow Glowing Mascot (Avatar Lab 3D Strobi)
                    CompanionProceduralAvatarView(
                        definition: CompanionAvatarDefinition(
                            name: "Interview Companion",
                            colors: AvatarColors(
                                bodyHex: "#FDE047",
                                eyesHex: "#111316"
                            )
                        ),
                        expressionName: interviewEngine.isThinking ? "curious-left" : "happy",
                        autoBlink: true,
                        size: 72
                    )
                    .shadow(color: Color(hex: "#FACC15").opacity(interviewEngine.isThinking ? 0.75 : 0.5), radius: interviewEngine.isThinking ? 20 : 14)
                    .scaleEffect(interviewEngine.isThinking ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: interviewEngine.isThinking)

                    // Speech Bubble (Foto 4)
                    VStack(alignment: .leading, spacing: 6) {
                        if interviewEngine.isThinking {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking...")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(Color(hex: "#3D2B1F"))
                            }
                            Text("Formulating the next helpful question for your Clicky...")
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(Color(hex: "#574030"))
                                .lineSpacing(2)
                        } else {
                            Text(interviewEngine.currentBubbleTitle)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(Color(hex: "#3D2B1F"))

                            Text(interviewEngine.currentBubbleBody)
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(Color(hex: "#574030"))
                                .lineSpacing(2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FED7AA"), Color(hex: "#FDBA74")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 3)
                    )
                    .overlay(
                        // Tiny thought dots at the bottom-left of the bubble
                        HStack(spacing: 3) {
                            Circle().fill(Color(hex: "#FDBA74")).frame(width: 4, height: 4)
                            Circle().fill(Color(hex: "#FDBA74")).frame(width: 6, height: 6)
                        }
                        .offset(x: -8, y: 12),
                        alignment: .bottomLeading
                    )
                    .frame(maxWidth: 360, alignment: .leading)
                }

                Spacer()

                // Bottom Controls (Foto 4)
                VStack(spacing: 10) {
                    // Large Voice Button: "Hold Control + Option to answer"
                    Button(action: {
                        if companion.buddyDictationManager.isRecordingFromMicrophoneButton {
                            companion.buddyDictationManager.stopPersistentDictationFromMicrophoneButton()
                        } else {
                            Task {
                                await companion.buddyDictationManager.startPersistentDictationFromMicrophoneButton(
                                    currentDraftText: newBuddyPromptText,
                                    updateDraftText: { transcribed in
                                        newBuddyPromptText = transcribed
                                    },
                                    submitDraftText: { finalTranscript in
                                        interviewEngine.submitUserAnswer(finalTranscript)
                                        newBuddyPromptText = ""
                                    }
                                )
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: companion.buddyDictationManager.isRecordingFromMicrophoneButton ? "stop.fill" : "mic.fill")
                                .font(.system(size: 13, weight: .bold))

                            Text(companion.buddyDictationManager.isRecordingFromMicrophoneButton ? "Recording... Click to finish" : "Hold Control + Option to answer")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "#0F172A"))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: companion.buddyDictationManager.isRecordingFromMicrophoneButton ?
                                            [Color(hex: "#FCA5A5"), Color(hex: "#EF4444")] :
                                            [Color(hex: "#C7E5FE"), Color(hex: "#8EC5FC")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.2))
                        )
                        .shadow(color: Color(hex: "#60A5FA").opacity(0.4), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)

                    // Secondary Input: "or type your answer" (Foto 4)
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))

                        TextField("or type your answer", text: $newBuddyPromptText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .onSubmit {
                                let trimmed = newBuddyPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    interviewEngine.submitUserAnswer(trimmed)
                                    newBuddyPromptText = ""
                                }
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.35))
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                    )
                    .frame(maxWidth: 320)
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Step 2: Spec Review & Persona Markdown Editor
    var newBuddySpecReviewView: some View {
        VStack(spacing: 0) {
            // Header: < Back to Interview + Review Spec
            HStack {
                Button(action: {
                    interviewEngine.backToInterview()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Interview")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)

                Text("Review Companion Spec")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.leading, 6)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Identity Card: Name & Role
                    VStack(alignment: .leading, spacing: 12) {
                        Text("COMPANION IDENTITY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Name")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                TextField("Buddy Name", text: $interviewEngine.synthesizedName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                                    )
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                Text("Role")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                TextField("Role Title", text: $interviewEngine.synthesizedRole)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                                    )
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 0.8))
                    )

                    // Markdown Spec Editor Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("PERSONA SPEC & RULES (.md)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .tracking(0.6)

                            Spacer()

                            Text("Markdown Editable")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(Color(hex: "#38BDF8"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(hex: "#38BDF8").opacity(0.12)))
                        }

                        Text("Edit the persona, instructions, memory rules, and skills that define how this companion thinks and acts.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineSpacing(1.5)

                        TextEditor(text: $interviewEngine.synthesizedSpecMarkdown)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(hex: "#E2E8F0"))
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 180, maxHeight: 220)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.black.opacity(0.45))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                    )
                            )
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 0.8))
                    )

                    // Navigation to Character Studio
                    Button(action: {
                        interviewEngine.proceedToCharacterCustomization()
                    }) {
                        HStack(spacing: 8) {
                            Text("Continue to Character Design")
                                .font(.system(size: 12.5, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#0F172A"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
    }

}
