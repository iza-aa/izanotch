//
//  TakeoverStatusView.swift
//  izaNotch (Izanotchy)
//
//  Consolidated Single Source of Truth for Human Takeover Banners and Controls (F-09).
//  Used across in-chat cards, viewports, and modals.
//  Zero Duplicate Takeover UI.
//

import SwiftUI

public struct TakeoverStatusView: View {
    public let isTakeoverActive: Bool
    public let title: String
    public let subtitle: String
    public let onToggleTakeover: () -> Void

    public init(
        isTakeoverActive: Bool,
        title: String,
        subtitle: String,
        onToggleTakeover: @escaping () -> Void
    ) {
        self.isTakeoverActive = isTakeoverActive
        self.title = title
        self.subtitle = subtitle
        self.onToggleTakeover = onToggleTakeover
    }

    public var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: isTakeoverActive ? "hand.point.up.left.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isTakeoverActive ? Color(hex: "#10B981") : Color(hex: "#F59E0B"))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isTakeoverActive ? Color(hex: "#34D399") : Color.white)

                    Text(subtitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onToggleTakeover) {
                HStack(spacing: 5) {
                    Image(systemName: isTakeoverActive ? "play.fill" : "hand.raised.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(isTakeoverActive ? "Resume Companion" : "Take Over Screen")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isTakeoverActive
                                    ? [Color(hex: "#34D399"), Color(hex: "#10B981")]
                                    : [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .shadow(color: (isTakeoverActive ? Color(hex: "#10B981") : Color(hex: "#F59E0B")).opacity(0.35), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#141517").opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isTakeoverActive ? Color(hex: "#10B981").opacity(0.4) : Color(hex: "#F59E0B").opacity(0.4), lineWidth: 0.8)
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
    }
}
