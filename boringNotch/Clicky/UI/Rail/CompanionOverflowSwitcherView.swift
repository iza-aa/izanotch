//
//  CompanionOverflowSwitcherView.swift
//  boringNotch
//
//  Created for Izanotchy - Multi-Agent Desktop System
//

import SwiftUI

public struct CompanionOverflowSwitcherView: View {
    public var onSelect: (UUID) -> Void
    public var onDismiss: () -> Void
    
    @ObservedObject private var rosterStore = CompanionRosterStore.shared
    @State private var hoveredId: UUID? = nil
    
    public init(onSelect: @escaping (UUID) -> Void, onDismiss: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("All Companions")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
            
            // List of all companions
            VStack(spacing: 6) {
                ForEach(rosterStore.allCompanions) { companion in
                    let isCurrentActive = companion.id == rosterStore.activeCompanionId
                    
                    Button {
                        onSelect(companion.id)
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(companion.cloudColor.opacity(0.35))
                                    .frame(width: 26, height: 26)
                                    .blur(radius: 4)
                                
                                CompanionProceduralAvatarView(
                                    definition: companion.avatarDefinition,
                                    expressionName: "happy",
                                    autoBlink: true,
                                    size: 26
                                )
                            }
                            .frame(width: 28, height: 28)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(companion.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(companion.role)
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if isCurrentActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(companion.cloudColor)
                            } else {
                                Circle()
                                    .fill(companion.status.dotColor)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(hoveredId == companion.id ? Color.white.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        hoveredId = isHovering ? companion.id : nil
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.vertical, 2)
            
            // Add New Companion (+)
            Button {
                onDismiss()
                // Trigger onboarding interview in HomeSpace
                HomeSpaceWindowManager.shared.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#60A5FA"))
                    
                    Text("Found New Companion...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#60A5FA"))
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 250)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#181A1E").opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: -4, y: 4)
        )
    }
}
