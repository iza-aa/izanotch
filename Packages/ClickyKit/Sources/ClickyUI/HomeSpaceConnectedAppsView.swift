//
//  HomeSpaceConnectedAppsView.swift
//  izaNotch (Izanotchy)
//
//  Decomposed extension for HomeSpaceRootView.
//

import AppKit
import Defaults
import Foundation
import SwiftUI
import ClickyFoundation
import ClickySpeech

extension HomeSpaceRootView {
    // MARK: - Dedicated Connected Apps Workspace View (F-14)
    var connectedAppsWorkspaceView: some View {
        let currentSession = companion.activeBuddy
        let allowedApps = currentSession.workflowAppNames
        let displayedApps = appsDiscovery.filteredApps(query: searchAppQuery)

        return VStack(spacing: 0) {
            // Header Bar: Centered Title and Trailing Close Button (✕)
            ZStack {
                Text("Connected Applications")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack {
                    Spacer()

                    // Top-Right Close Button (Close Only — Back to Chat is in Sidebar)
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Mac Apps Search Bar & Rescan Button
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))

                    TextField("Search installed Mac apps...", text: $searchAppQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)

                    if !searchAppQuery.isEmpty {
                        Button(action: { searchAppQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                )

                // Reload Installed Apps Button
                Button(action: {
                    ClickySoundEngine.shared.play(.send)
                    appsDiscovery.scanInstalledApplications(forceReload: true)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Rescan installed macOS applications")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Scrollable List of Installed macOS Apps
            if displayedApps.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No applications found")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(displayedApps) { app in
                            let isAllowed = allowedApps.contains(where: {
                                $0.caseInsensitiveCompare(app.name) == .orderedSame ||
                                (app.bundleId != nil && $0.caseInsensitiveCompare(app.bundleId!) == .orderedSame)
                            })

                            HStack(spacing: 12) {
                                // Real Native 3D System App Icon
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)

                                // App Name (Clean, Bold White)
                                Text(app.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)

                                Spacer()

                                // Native Toggle Switch
                                Toggle("", isOn: Binding(
                                    get: { isAllowed },
                                    set: { newValue in
                                        toggleCompanionAppPermission(session: currentSession, appName: app.name, enabled: newValue)
                                    }
                                ))
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#38BDF8")))
                                .labelsHidden()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isAllowed ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isAllowed ? Color(hex: "#38BDF8").opacity(0.25) : Color.white.opacity(0.04), lineWidth: 0.8)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    func editPromptFileName(for name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "\(cleaned).md"
    }

    func animationStepSummary(_ anim: AvatarLabAnimation) -> String {
        let stepChain = anim.steps.map { $0.semanticKey }.joined(separator: " → ")
        return "\(anim.steps.count) steps • \(stepChain)"
    }
}

// MARK: - Edit Studio Helper Subviews
struct EditStudioPresetTile: View {
    let preset: AvatarLabPreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Text(preset.badgeNumber)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .white : Color(hex: "#38BDF8"))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isSelected ? Color(hex: "#38BDF8") : Color.white.opacity(0.08))
                    )

                Text(preset.displayName)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isSelected {
                    Circle()
                        .fill(Color(hex: "#10B981"))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color(hex: "#38BDF8").opacity(0.18) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? Color(hex: "#38BDF8").opacity(0.6) : Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct EditStudioAnimationRow: View {
    let anim: AvatarLabAnimation
    let isPlaying: Bool
    let summary: String
    let onTogglePlay: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(anim.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(anim.category.rawValue)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }

                Text(summary)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onTogglePlay) {
                HStack(spacing: 4) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 8, weight: .bold))
                    Text(isPlaying ? "Stop" : "Play")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(isPlaying ? Color.white : Color(hex: "#0F172A"))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isPlaying ? Color(hex: "#EF4444") : Color(hex: "#38BDF8"))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isPlaying ? Color(hex: "#38BDF8").opacity(0.12) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isPlaying ? Color(hex: "#38BDF8").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
}
