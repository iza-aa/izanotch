//
//  CompanionPopoverCardView.swift
//  izaNotch
//
//  Created for Izanotchy - Multi-Agent Desktop System
//

import SwiftUI

public struct CompanionPopoverCardView: View {
    public let companion: CompanionProfile
    public var onClose: () -> Void
    
    @ObservedObject private var companionManager = CompanionManager.shared
    @State private var isEditHovered: Bool = false
    @State private var isCloseHovered: Bool = false
    @State private var isActionHovered: Bool = false
    @State private var isStopHovered: Bool = false
    @State private var isHistoryExpanded: Bool = false
    
    public init(companion: CompanionProfile, onClose: @escaping () -> Void) {
        self.companion = companion
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Header
            HStack(spacing: 10) {
                GrokBotMarkView(
                    name: companion.name,
                    tintColorHex: companion.cloudColorHex,
                    size: 34,
                    isWorking: isCompanionProcessing,
                    isSelected: true
                )
                .frame(width: 34, height: 34)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(companion.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(companion.status.dotColor)
                            .frame(width: 6, height: 6)
                        
                        Text(companion.status.rawValue)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(companion.status.dotColor)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    // Edit button [pencil]
                    Button(action: {
                        ClickySoundEngine.shared.play(.open)
                        onClose()
                        NotificationCenter.default.post(
                            name: Notification.Name("HomeSpaceEditCompanion"),
                            object: companion.id
                        )
                        HomeSpaceWindowManager.shared.show()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(isEditHovered ? 0.18 : 0.08))
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "pencil")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Edit character")
                    .onHover { isEditHovered = $0 }

                    // Close button [x]
                    Button(action: onClose) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(isCloseHovered ? 0.18 : 0.08))
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { isCloseHovered = $0 }
                }
            }
            
            // MARK: - Message Text (Cleaned from raw markdown table & rendered with native markdown support)
            if !displayMessageText.isEmpty {
                Text(LocalizedStringKey(displayMessageText))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.92))
                    .lineSpacing(3)
                    .lineLimit(4)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            // Thinking Dots (if working)
            if isCompanionProcessing {
                HStack(spacing: 3.5) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(Color.white.opacity(0.4)).frame(width: 4, height: 4)
                    }
                }
                .padding(.vertical, 2)
            }
            
            // MARK: - Primary Action Button (Liquid-Gel Foto 2 Style)
            primaryActionButton
            
            // MARK: - Footer (History ⌄) — Only shown if history actually exists
            if hasHistory {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isHistoryExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("History")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: isHistoryExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
                
                if isHistoryExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(recentMessages.suffix(3)) { msg in
                            HStack(alignment: .top, spacing: 6) {
                                Text(msg.isUser ? "You:" : "\(companion.name):")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(msg.isUser ? Color(hex: "#93C5FD") : Color(hex: companion.cloudColorHex))
                                Text(msg.text)
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(14)
        .frame(width: 290)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#101216"), Color(hex: "#181B22")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                // Clean dark card shadow (Zero glowing colored aura)
                .shadow(color: Color.black.opacity(0.6), radius: 14, x: 0, y: 3)
        )
    }

    private var recentMessages: [HomeSpaceChatMessage] {
        if let session = CompanionManager.shared.sessions.first(where: {
            $0.name.lowercased() == companion.name.lowercased() || companion.name.lowercased().contains($0.name.lowercased())
        }) {
            return session.messages
        }
        return companion.messages
    }

    private var hasHistory: Bool {
        return !recentMessages.isEmpty
    }

    private var isCompanionProcessing: Bool {
        if companion.status == .done || companion.status == .idle {
            return false
        }
        if companion.status == .working {
            return true
        }
        if companionManager.activeBuddy.name == companion.name || companionManager.activeBuddy.id == companion.id {
            return companionManager.isProcessingTask
        }
        return false
    }

    private var displayMessageText: String {
        let raw = companion.lastMessage.isEmpty ? companion.summary : companion.lastMessage
        let lines = raw.components(separatedBy: "\n")
        let nonTableLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("|") && !trimmed.hasPrefix("|-") && !trimmed.hasPrefix("+") && trimmed != "---"
        }
        let cleanedLines = nonTableLines.compactMap { line -> String? in
            var l = line.trimmingCharacters(in: .whitespaces)
            while l.hasPrefix("#") {
                l = l.dropFirst().trimmingCharacters(in: .whitespaces)
            }
            return l.isEmpty ? nil : l
        }
        var result = cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let starCount = result.components(separatedBy: "**").count - 1
        if starCount % 2 != 0 {
            result = result.replacingOccurrences(of: "**", with: "")
        }
        return result
    }

    private var primaryActionButton: some View {
        HStack(spacing: 8) {
            if isCompanionProcessing {
                Button {
                    companionManager.stopCurrentTask()
                    CompanionRosterStore.shared.updateCompanionStatus(id: companion.id, status: .idle)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Stop")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "#7F1D1D"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8.5)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color(hex: "#FEE2E2"), location: 0.0),
                                            .init(color: Color(hex: "#FECACA"), location: 0.35),
                                            .init(color: Color(hex: "#FCA5A5"), location: 0.70),
                                            .init(color: Color(hex: "#F87171"), location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(0.9), location: 0.0),
                                            .init(color: Color.white.opacity(0.25), location: 0.45),
                                            .init(color: Color.white.opacity(0.0), location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.2
                                )
                        }
                    )
                    .shadow(color: Color(hex: "#EF4444").opacity(0.4), radius: 8, x: 0, y: 3)
                    .scaleEffect(isStopHovered ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { isStopHovered = $0 }
            }

            Button {
                // 1. Activate companion in Roster
                CompanionRosterStore.shared.selectCompanion(id: companion.id)
                // 2. Activate matching session in CompanionManager
                CompanionManager.shared.selectSession(named: companion.name)
                // 3. Open actual HomeSpace chat
                HomeSpaceWindowManager.shared.show()
                onClose()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: companion.status == .done ? "arrow.up.right" : "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(companion.status == .done ? "Show me" : "Open Chat")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(hex: "#0C1D38"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8.5)
                .background(
                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color(hex: "#DCE8FD"), location: 0.0),
                                        .init(color: Color(hex: "#B2CCFB"), location: 0.35),
                                        .init(color: Color(hex: "#8FBDF8"), location: 0.70),
                                        .init(color: Color(hex: "#72A7F3"), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.9), location: 0.0),
                                        .init(color: Color.white.opacity(0.25), location: 0.45),
                                        .init(color: Color.white.opacity(0.0), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.2
                            )
                    }
                )
                .shadow(color: Color(hex: "#60A5FA").opacity(0.4), radius: 8, x: 0, y: 3)
                .scaleEffect(isActionHovered ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { isActionHovered = $0 }
        }
        .padding(.top, 2)
    }
}
