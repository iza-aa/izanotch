import SwiftUI
import AppKit

// MARK: - HomeSpaceInteractiveComputerModalView (F-09: Live Window Projection & Takeover)
/// Modal semi-fullscreen interaktif yang mekar saat kartu "Computer" diklik di chat HomeSpace.
/// Menampilkan proyeksi jendela nyata aplikasi macOS (Safari / Mail) tanpa wallpaper palsu,
/// dilengkapi workflow app switcher dock dan protokol Human Takeover.
public struct HomeSpaceInteractiveComputerModalView: View {
    public let payload: ComputerCardPayload
    public let onDismiss: () -> Void

    @ObservedObject private var streamService = CompanionWindowStreamService.shared
    @ObservedObject private var companion = CompanionManager.shared
    @State private var hoveredDockApp: String? = nil
    @State private var selectedDockApp: String = "mail"
    @State private var isTakeoverActive: Bool = false

    public init(payload: ComputerCardPayload, onDismiss: @escaping () -> Void) {
        self.payload = payload
        self.onDismiss = onDismiss
        let initialApp = payload.targetAppName?.lowercased() ??
                         CompanionManager.shared.activeBuddy.workflowAppNames.first?.lowercased() ??
                         "mail"
        _selectedDockApp = State(initialValue: initialApp)
    }

    public var body: some View {
        ZStack {
            // 1. Semi-transparent Dimmed Backdrop (Covers whole window including sidebar)
            Color.black.opacity(0.70)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }

            // 2. Centered Interactive Computer Modal
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    if companion.activeBuddy.isSandboxedVM {
                        CompanionVMViewportView(onDismiss: onDismiss)
                            .frame(width: 740, height: 470)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        liveWindowProjectionCanvas
                            .frame(width: 740, height: 470)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    // Close Button [✕] at Top-Right
                    Button(action: {
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.90))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.black.opacity(0.45)))
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(14)

                    // Human Takeover Control Bar (Always accessible: View Mode by default, Takeover on demand)
                    takeoverNotificationBanner
                        .padding(.top, 14)
                        .padding(.leading, 18)
                        .padding(.trailing, 56)
                }
            }
            .frame(width: 740, height: 470)
            .background(Color(hex: "#141517"))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.85), radius: 24, x: 0, y: 12)
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94)),
            removal: .opacity.combined(with: .scale(scale: 0.94))
        ))
        .onAppear {
            if payload.status == .working || payload.status == .takeoverNeeded || isTakeoverActive {
                let appName = payload.targetAppName ?? companion.activeBuddy.workflowAppNames.first(where: { $0.lowercased() == selectedDockApp }) ?? selectedDockApp.capitalized
                streamService.startStreaming(appName: appName, slug: companion.activeBuddy.slug)
            }
        }
        .onDisappear {
            streamService.stopStreaming()
        }
    }

    // MARK: - Live Window Projection Canvas (F-09: No Fake Sonoma Wallpaper)
    private var liveWindowProjectionCanvas: some View {
        ZStack {
            // Dark Neutral Slate Canvas Base
            Color(hex: "#0D0E11")
                .edgesIgnoringSafeArea(.all)

            // Subtle Background Gradient Glow
            RadialGradient(
                colors: [Color(hex: "#1E293B").opacity(0.45), Color(hex: "#0A0B0E")],
                center: .center,
                startRadius: 40,
                endRadius: 420
            )

            // Live Virtual Desktop Canvas or Fallback App Workspace Placeholder
            let displaySnapshot: NSImage? = streamService.activeSnapshot ?? (payload.snapshotImagePath.flatMap { NSImage(contentsOfFile: $0) }) ?? MascotVirtualDesktopService.shared.activeSnapshot
            if let snapshot = displaySnapshot {
                ZStack(alignment: .topTrailing) {
                    InteractiveVirtualDesktopView(
                        targetAppName: payload.targetAppName ?? companion.activeBuddy.workflowAppNames.first(where: { $0.lowercased() == selectedDockApp }) ?? selectedDockApp.capitalized,
                        slug: companion.activeBuddy.slug,
                        customSnapshot: snapshot,
                        isInteractive: isTakeoverActive
                    )
                    .frame(maxWidth: 710, maxHeight: 390)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.7), radius: 18, x: 0, y: 8)

                    // "You" Takeover Focus Badge (Only if Takeover is active or needed)
                    if isTakeoverActive || payload.status == .takeoverNeeded {
                        youCursorBadge
                            .padding(12)
                    }
                }
            } else {
                // If Target App is Not Currently Running / Focused
                appReadyToConnectPlaceholder
            }
        }
    }


    // MARK: - App Ready To Connect Placeholder
    private var appReadyToConnectPlaceholder: some View {
        VStack(spacing: 16) {
            AppSystemIconView(appName: selectedDockApp, size: 72)

            VStack(spacing: 6) {
                Text("\(selectedDockApp.capitalized) Workspace Ready")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("\(companion.activeBuddy.name) connects to \(selectedDockApp.capitalized) via background automation.\nLaunch or bring \(selectedDockApp.capitalized) to front to mirror live screen.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button(action: {
                let targetApp = companion.activeBuddy.workflowAppNames.first(where: { $0.lowercased() == selectedDockApp }) ?? selectedDockApp.capitalized
                streamService.launchOrFocusWorkflowApp(appName: targetApp)
                streamService.switchTargetApp(appName: targetApp, slug: companion.activeBuddy.slug)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Launch \(selectedDockApp.capitalized)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#2563EB"))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(maxWidth: 580)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#16181D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    // MARK: - "You" Takeover Cursor Badge
    private var youCursorBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: "#38BDF8"))
                .frame(width: 6, height: 6)

            Text("You")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Human Takeover Notification Banner (F-09)
    private var takeoverNotificationBanner: some View {
        TakeoverStatusView(
            isTakeoverActive: isTakeoverActive,
            title: isTakeoverActive ? "Takeover Mode: Direct Input" : (payload.status == .takeoverNeeded ? "Takeover Needed: Input Required" : "Viewing Mode: Autonomous Operation"),
            subtitle: isTakeoverActive ? "Direct input control active." : (payload.takeoverReason ?? "View-only mode. Click 'Take Over Screen' to interact."),
            onToggleTakeover: {
                if isTakeoverActive {
                    isTakeoverActive = false
                    ClickySoundEngine.shared.play(.open)
                } else {
                    isTakeoverActive = true
                    let targetApp = companion.activeBuddy.workflowAppNames.first(where: { $0.lowercased() == selectedDockApp }) ?? selectedDockApp.capitalized
                    streamService.startStreaming(appName: targetApp, slug: companion.activeBuddy.slug)
                    streamService.launchOrFocusWorkflowApp(appName: targetApp)
                    ClickySoundEngine.shared.play(.open)
                }
            }
        )
    }

    // MARK: - Floating Mini macOS Dock (Workflow App Switcher)
    @ViewBuilder
    private var miniDock: some View {
        let apps = companion.activeBuddy.workflowAppNames
        if apps.isEmpty {
            Text(String(localized: "Belum ada aplikasi terhubung"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.55))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                )
        } else {
            HStack(spacing: 14) {
                ForEach(apps, id: \.self) { appName in
                    let cleanApp = appName.lowercased()
                    Button(action: {
                        selectedDockApp = cleanApp
                        if !companion.activeBuddy.isSandboxedVM {
                            streamService.switchTargetApp(appName: appName, slug: companion.activeBuddy.slug)
                        }
                    }) {
                        ZStack {
                            AppSystemIconView(appName: appName, size: 40)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selectedDockApp == cleanApp ? Color(hex: "#60A5FA") : Color.clear, lineWidth: 2)
                        )
                        .scaleEffect(hoveredDockApp == cleanApp ? 1.14 : (selectedDockApp == cleanApp ? 1.05 : 1.0))
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hoveredDockApp)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedDockApp)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredDockApp = isHovered ? cleanApp : nil
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.65))
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 4)
            )
        }
    }
}
