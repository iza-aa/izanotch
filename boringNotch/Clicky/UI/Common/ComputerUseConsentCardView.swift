//
//  ComputerUseConsentCardView.swift
//  boringNotch (Izanotchy)
//
//  Authentic HeyClicky "Want me to do it?" Computer Use Consent Card.
//  Matches ref_clickys_suggestions.png with peeking mascot holding the card edge,
//  action summary, and [✕ No] + [✓ Yes, do it] buttons with HeyClickyGelButtonStyle.
//

import SwiftUI
import AppKit
import Defaults

// MARK: - ComputerUseProposedAction
public struct ComputerUseProposedAction: Identifiable, Equatable {
    public let id = UUID()
    public var category: String
    public var appName: String
    public var appIcon: String
    public var title: String
    public var details: String
    public var targetCoordinate: CGPoint?
    public var actionType: ActionType

    public enum ActionType: String, Equatable {
        case click
        case keyCombo
        case launchApp
        case runScript
    }

    public init(
        category: String = "Action Suggestion",
        appName: String = "System",
        appIcon: String = "macwindow",
        title: String,
        details: String,
        targetCoordinate: CGPoint? = nil,
        actionType: ActionType = .click
    ) {
        self.category = category
        self.appName = appName
        self.appIcon = appIcon
        self.title = title
        self.details = details
        self.targetCoordinate = targetCoordinate
        self.actionType = actionType
    }
}

// MARK: - Peeking Mascot Header View
struct PeekingMascotView: View {
    @State private var blink = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Character head
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color(hex: "#34D399").opacity(0.35))
                    .frame(width: 86, height: 86)
                    .blur(radius: 10)

                // Hair / Head
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 78, height: 78)

                // Face skin
                Circle()
                    .fill(Color(hex: "#8D5B4C"))
                    .frame(width: 58, height: 58)
                    .offset(y: 8)

                // Big anime eyes
                HStack(spacing: 12) {
                    MascotAnimeEye(isBlinking: blink)
                    MascotAnimeEye(isBlinking: blink)
                }
                .offset(y: 8)

                // Small mouth
                Capsule()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 6, height: 2)
                    .offset(y: 24)
            }
            .offset(y: -18)

            // Two little hands holding the top card edge
            HStack(spacing: 50) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "#8D5B4C"))
                    .frame(width: 14, height: 10)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.2), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "#8D5B4C"))
                    .frame(width: 14, height: 10)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.2), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
            }
            .offset(y: 5)
        }
        .frame(height: 74)
        .onAppear {
            Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 3.5...7.0)))
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeOut(duration: 0.1)) { blink = true }
                    try? await Task.sleep(for: .milliseconds(120))
                    withAnimation(.easeIn(duration: 0.1)) { blink = false }
                }
            }
        }
    }
}

private struct MascotAnimeEye: View {
    var isBlinking: Bool

    var body: some View {
        ZStack {
            if isBlinking {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 18, height: 2)
            } else {
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#38BDF8"), Color(hex: "#0369A1")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 17, height: 17)

                Circle()
                    .fill(Color.black)
                    .frame(width: 12, height: 12)

                // Eye specular highlights
                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
                    .offset(x: -2, y: -2)

                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: 2.5, y: 2.5)
            }
        }
    }
}

// MARK: - ComputerUseConsentCardView (1:1 Matching media_1789717035502.png)
public struct ComputerUseConsentCardView: View {
    public var request: ComputerUseRequest
    public var onAllowOnce: () -> Void
    public var onAlwaysAllow: () -> Void
    public var onNotNow: () -> Void
    public var onClose: () -> Void
    public var onHistory: (() -> Void)?

    public init(
        request: ComputerUseRequest,
        onAllowOnce: @escaping () -> Void,
        onAlwaysAllow: @escaping () -> Void,
        onNotNow: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onHistory: (() -> Void)? = nil
    ) {
        self.request = request
        self.onAllowOnce = onAllowOnce
        self.onAlwaysAllow = onAlwaysAllow
        self.onNotNow = onNotNow
        self.onClose = onClose
        self.onHistory = onHistory
    }

    // Backward-compatible initializer for legacy ComputerUseProposedAction
    public init(
        action: ComputerUseProposedAction,
        onApprove: @escaping () -> Void,
        onReject: @escaping () -> Void
    ) {
        self.request = ComputerUseRequest(
            companionName: action.appName.isEmpty ? "Clicky" : action.appName,
            companionMood: .happy,
            cloudColorHex: "#38BDF8",
            ringColorHex: "#BAE6FD",
            heading: "Wants to use your Mac",
            bodyText: action.details.isEmpty ? action.title : action.details,
            payload: ComputerUseActionPayload(
                type: .click,
                targetCoordinate: action.targetCoordinate,
                targetApp: action.appName,
                rawDetails: action.details
            )
        )
        self.onAllowOnce = onApprove
        self.onAlwaysAllow = {
            Defaults[.alwaysAllowComputerUse] = true
            onApprove()
        }
        self.onNotNow = onReject
        self.onClose = onReject
        self.onHistory = nil
    }

    private var accentColor: Color {
        Color(hex: request.cloudColorHex)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // MARK: - Top Header Row (Avatar, Name, Status, Close Button)
            HStack(alignment: .center, spacing: 12) {
                // Circular Mascot Avatar with Ambient Aura
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.35))
                        .frame(width: 48, height: 48)
                        .blur(radius: 8)

                    CompanionProceduralAvatarView(
                        definition: request.avatarDefinition,
                        expressionName: "attentive-left",
                        autoBlink: true,
                        size: 44
                    )
                }
                .frame(width: 46, height: 46)

                // Companion Name & "Needs a yes" Status Badge
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.companionName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 6, height: 6)

                        Text("Needs a yes")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(accentColor)
                    }
                }

                Spacer()

                // Close Button (✕)
                Button(action: {
                    ClickySoundEngine.shared.play(.close)
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }

            // MARK: - Headline
            Text(request.heading)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 2)

            // MARK: - TradingView Action Badge (if applicable)
            if request.payload.type == .tradingViewAction {
                HStack(spacing: 7) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#38BDF8"))

                    Text(request.payload.tradingViewPayload?.toolName ?? request.payload.tradingViewPayload?.actionType.rawValue.capitalized ?? "Analysis")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    if let param = request.payload.tradingViewPayload?.parameter, !param.isEmpty {
                        Text(param)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#38BDF8"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: "#38BDF8").opacity(0.18)))
                    }

                    Spacer()

                    Text("TradingView.app")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#1E222D"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(hex: "#38BDF8").opacity(0.22), lineWidth: 1)
                        )
                )
            }

            // MARK: - Natural Conversational Body Text
            Text(request.bodyText)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // MARK: - Action Buttons (Vertical Capsule Stack)
            VStack(spacing: 9) {
                // 1. Allow Once (Solid White Primary Button)
                Button(action: {
                    ClickySoundEngine.shared.play(.open)
                    onAllowOnce()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.circle")
                            .font(.system(size: 13, weight: .bold))
                        Text("Allow once")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Capsule().fill(Color.white))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
                .buttonStyle(.plain)

                // 2. Always Allow (Dark Translucent Capsule)
                Button(action: {
                    ClickySoundEngine.shared.play(.open)
                    onAlwaysAllow()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "infinity")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Always allow")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#26272B"))
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)

                // 3. Not Now (Dark Translucent Capsule)
                Button(action: {
                    ClickySoundEngine.shared.play(.close)
                    onNotNow()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Not now")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#26272B"))
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            // MARK: - Footer (Info Note & History Button)
            HStack(alignment: .center) {
                Text("Always allow can be turned off in Settings → Agent")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))

                Spacer()

                Button(action: {
                    onHistory?()
                }) {
                    HStack(spacing: 3) {
                        Text("History")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(width: 350)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "#161719"))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.65), radius: 24, x: 0, y: 12)
        )
    }
}

