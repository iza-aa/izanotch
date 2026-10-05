//
//  FloatingCompanionRailView.swift
//  izaNotch
//
//  Created for Izanotchy - Multi-Agent Desktop System
//  Refactored for Fitur F-04: Event-Driven Reactive Companion Bubble (Hover-Activated)
//

import SwiftUI
import ClickyFoundation
import ClickyAgent
import ClickyRoster

// MARK: - Unread Notification Circle Badge (Dedicated Solid Red Indicator with Dark Contrast Border)
public struct UnreadNotificationCircleBadge: View {
    public var badgeColor: Color
    public var borderColor: Color

    public init(badgeColor: Color? = nil, borderColor: Color? = nil) {
        self.badgeColor = badgeColor ?? Color(hex: "#FF3C2F")
        self.borderColor = borderColor ?? Color(hex: "#1C1C1C")
    }

    public var body: some View {
        ZStack {
            // Dark contrast outer border ring (#1C1C1C) matching reference
            Circle()
                .fill(borderColor)
                .frame(width: 16, height: 16)

            // Solid vibrant red inner circle (#FF3C2F)
            Circle()
                .fill(badgeColor)
                .frame(width: 12, height: 12)
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Event-Driven Reactive Companion Bubble (Tepi Kanan Layar)
public struct FloatingCompanionRailView: View {
    @ObservedObject private var rosterStore = CompanionRosterStore.shared
    @ObservedObject private var companionManager = CompanionManager.shared
    @ObservedObject private var homeSpaceManager = HomeSpaceWindowManager.shared
    
    @State private var hoveredMascotId: UUID? = nil
    @State private var isCardHovered: Bool = false
    @State private var dismissTask: Task<Void, Never>? = nil
    
    public init() {}
    
    /// Dedicated Unread Mascot Rail:
    /// Appears at the far right edge of the screen when unread notification arrived.
    /// Does NOT display working state (working state is reserved for notch area).
    /// If read, stays at the edge until explicitly dismissed via card [x] button.
    private var activeMascots: [CompanionProfile] {
        guard !homeSpaceManager.isVisible else { return [] }

        var list: [CompanionProfile] = []
        for c in rosterStore.allCompanions {
            if rosterStore.presentedRailCompanionIds.contains(c.id) && !rosterStore.dismissedCompanionIds.contains(c.id) {
                list.append(c)
            }
        }
        return list
    }

    private func isCompanionUnread(_ companion: CompanionProfile) -> Bool {
        if companion.hasUnreadMessages { return true }
        if let matchingSession = companionManager.sessions.first(where: {
            $0.name.lowercased() == companion.name.lowercased() ||
            companion.name.lowercased().contains($0.name.lowercased()) ||
            $0.name.lowercased().contains(companion.name.lowercased())
        }) {
            return matchingSession.isUnread
        }
        return false
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Popover Card anchored to the left of the mascot
            if let popoverId = rosterStore.activePopoverCompanionId,
               let companion = rosterStore.allCompanions.first(where: { $0.id == popoverId }) {
                CompanionPopoverCardView(companion: companion) {
                    rosterStore.dismissCompanion(id: companion.id)
                }
                .onHover { isHovering in
                    isCardHovered = isHovering
                    if isHovering {
                        dismissTask?.cancel()
                    } else {
                        scheduleDismiss()
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .trailing)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .trailing))
                ))
            }
            
            // The Floating Mascots Column (Tepi Kanan Layar)
            if !activeMascots.isEmpty {
                VStack(spacing: 12) {
                    ForEach(activeMascots) { companion in
                        mascotView(for: companion)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.7)),
                                removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.7))
                            ))
                    }
                }
                .frame(width: 56)
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: rosterStore.activePopoverCompanionId)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: activeMascots.map(\.id))
    }
    
    // MARK: - Standalone Floating Mascot View (Pure 3D Strobi + Dedicated Unread Badge)
    @ViewBuilder
    private func mascotView(for companion: CompanionProfile) -> some View {
        let isUnread = isCompanionUnread(companion)
        
        ZStack(alignment: .topTrailing) {
            // Pure 3D Avatar
            CompanionProceduralAvatarView(
                definition: companion.avatarDefinition,
                expressionName: companion.currentExpressionKey ?? "happy",
                autoBlink: true,
                size: 48
            )
            .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
            
            // Red Notification Circle pinned to Top-Right (Only when unread)
            if isUnread {
                UnreadNotificationCircleBadge()
                    .offset(x: -1, y: 1)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 52, height: 52)
        .scaleEffect(hoveredMascotId == companion.id ? 1.08 : 1.0)
        .onHover { isHovering in
            handleMascotHover(companion: companion, isHovering: isHovering)
        }
    }
    
    private func handleMascotHover(companion: CompanionProfile, isHovering: Bool) {
        if isHovering {
            dismissTask?.cancel()
            hoveredMascotId = companion.id
            rosterStore.markAsRead(id: companion.id)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                rosterStore.activePopoverCompanionId = companion.id
            }
        } else {
            if hoveredMascotId == companion.id {
                hoveredMascotId = nil
            }
            scheduleDismiss()
        }
    }
    
    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if !Task.isCancelled {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    if !isCardHovered && hoveredMascotId == nil {
                        rosterStore.activePopoverCompanionId = nil
                    }
                }
            }
        }
    }
}
