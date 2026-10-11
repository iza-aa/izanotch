//
//  AIUsageView.swift
//  izaNotch
//
//  Created by Antigravity on 30/08/2026.
//

import SwiftUI
import Defaults


// MARK: - Antigravity Ambiance Background Glow (Dynamic Full Blue based on Quota %)

struct AntigravityAmbianceView: View {
    var usageLevel: Double = 1.0 // 0.0 (empty) to 1.0 (full)
    
    private var dynamicOpacity: Double {
        let clamped = min(max(usageLevel, 0.0), 1.0)
        return 0.08 + (clamped * 0.72)
    }
    
    private var dynamicBlur: CGFloat {
        let clamped = min(max(usageLevel, 0.0), 1.0)
        return 14.0 + CGFloat(clamped * 10.0)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.50, blue: 1.00).opacity(0.48),
                            Color(red: 0.05, green: 0.32, blue: 0.95).opacity(0.42),
                            Color(red: 0.15, green: 0.60, blue: 1.00).opacity(0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.20, green: 0.62, blue: 1.00).opacity(0.45),
                            Color(red: 0.08, green: 0.38, blue: 0.92).opacity(0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 85
                    )
                )
        }
        .blur(radius: dynamicBlur)
        .padding(-4)
        .opacity(dynamicOpacity)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: usageLevel)
        .allowsHitTesting(false)
    }
}

// MARK: - Antigravity Fixed Size Icon Component

struct AntigravityIconView: View {
    var size: CGFloat = 14
    
    private var renderedImage: NSImage? {
        guard let nsImg = NSImage(named: "antigravity") ?? NSImage(contentsOfFile: "/Users/heizaaa/Downloads/Google-Antigravity-Icon-Full-Color.png") else {
            return nil
        }
        let targetSize = NSSize(width: size, height: size)
        let newImg = NSImage(size: targetSize)
        newImg.lockFocus()
        nsImg.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: nsImg.size),
                   operation: .sourceOver,
                   fraction: 1.0)
        newImg.unlockFocus()
        return newImg
    }
    
    var body: some View {
        Group {
            if let img = renderedImage {
                Image(nsImage: img)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.7, weight: .bold))
                    .foregroundColor(Color(red: 0.35, green: 0.65, blue: 1.0))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }
}


// MARK: - Circular Progress Ring Component (#3F7D35)

struct CircularRingView: View {
    let progress: Double // 0.0 to 1.0
    var size: CGFloat = 18
    var strokeWidth: CGFloat = 2.4
    
    private let primaryGreen = Color(red: 0x3F / 255.0, green: 0x7D / 255.0, blue: 0x35 / 255.0)
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: strokeWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(max(progress, 0.0), 1.0)))
                .stroke(
                    primaryGreen,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Antigravity Switching Loading View (Centered Shimmering Loading Text on Dark Notch Interior)

struct AntigravitySwitchingLoadingView: View {
    @State private var shimmerOffset: CGFloat = -1.2
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Base subtle text
                Text("Loading...")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.30))
                
                // Shimmering luminous pulse text (Left to Right)
                Text("Loading...")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.40, green: 0.80, blue: 1.00),
                                Color.white
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .mask(
                        GeometryReader { geo in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .clear, location: 0.0),
                                            .init(color: .white, location: 0.5),
                                            .init(color: .clear, location: 1.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(geo.size.width * 0.75, 40))
                                .offset(x: shimmerOffset * geo.size.width)
                        }
                    )
                    .shadow(color: Color(red: 0.20, green: 0.65, blue: 1.00).opacity(0.85), radius: 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.4)
                .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 1.4
            }
        }
    }
}

// MARK: - Main AI Usage View

struct AIUsageView: View {
    @ObservedObject var usageManager = AntigravityUsageManager.shared
    @ObservedObject var bridgeManager = AntigravityBridgeManager.shared
    @Default(.selectedAIAssistant) var selectedApp: String
    @State private var refreshAngle: Double = 0
    
    private var isSiriAI: Bool {
        selectedApp == "Siri AI" || selectedApp == "Siri AI (AFM)"
    }
    
    private var isChatGPT: Bool {
        selectedApp == "ChatGPT"
    }
    
    private var isAppSwitching: Bool {
        usageManager.isSwitching
    }

    var body: some View {
        Group {
            if isAppSwitching {
                AntigravitySwitchingLoadingView()
                    .transition(.opacity)
            } else {
                VStack(spacing: 5) {
                    // 1. Top Bar: App Switcher + Status / Email Switcher + Reload Button
                    topControlBar

                    // 2. Main Content: Siri AI (AFM) View OR ChatGPT Pool OR Disconnected View OR Active Live Cards
                    if isSiriAI {
                        siriAiSection
                    } else if isChatGPT {
                        ChatGPTAccountMonitorWidget()
                    } else if !usageManager.isConnected {
                        disconnectedCard
                    } else {
                        HStack(spacing: 16) {
                            geminiSection
                            claudeGptSection
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.35), value: isAppSwitching)
    }
    
    // MARK: - Disconnected State View (No Fake Usage)
    
    private var disconnectedCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.75), Color.black.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)
            
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                    
                    Text("Antigravity Belum Terhubung")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text("Buka aplikasi Antigravity untuk menyinkronkan akun & kuota secara langsung.")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Button(action: {
                    usageManager.refresh()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Hubungkan Ulang")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 2)
            }
            .padding(.vertical, 12)
        }
        .frame(height: 86)
    }

    
    // MARK: - Top Control Bar
    
    private var topControlBar: some View {
        let account = usageManager.activeAccount
        let hasProfiles = !usageManager.accounts.isEmpty
        let isCurrentSaved = usageManager.accounts.contains(where: { $0.email.lowercased() == account.email.lowercased() })
        
        return HStack(alignment: .center, spacing: 5) {
            // 1. App Switcher Badge Card
            Menu {
                Text("AI Assistants")
                
                Button(action: {
                    selectedApp = "Antigravity"
                }) {
                    if selectedApp == "Antigravity" {
                        Label("Antigravity", systemImage: "checkmark")
                    } else {
                        Text("Antigravity")
                    }
                }

                Button(action: {
                    selectedApp = "Siri AI"
                }) {
                    if isSiriAI {
                        Label("Siri AI", systemImage: "checkmark")
                    } else {
                        Text("Siri AI")
                    }
                }

                Button(action: {
                    selectedApp = "ChatGPT"
                }) {
                    if isChatGPT {
                        Label("ChatGPT", systemImage: "checkmark")
                    } else {
                        Text("ChatGPT")
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    if isSiriAI {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white, Color(hex: "#CBD5E1")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else if isChatGPT {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#10A37F"))
                    } else {
                        AntigravityIconView(size: 13)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .menuIndicator(.hidden)
            .fixedSize()

            // 2. Email / Engine Switcher Dropdown
            if isSiriAI {
                Menu {
                    Text("Apple Foundation Models (AFM)")
                    Label("Model: AFM 3 Core (On-Device)", systemImage: "cpu")
                    Label("Private Cloud Compute (E2EE)", systemImage: "lock.shield")
                    Label("Router: Cua Driver Hands (56 Tools)", systemImage: "hand.tap")
                } label: {
                    HStack(spacing: 3.5) {
                        Circle()
                            .fill(Color(hex: "#34D399"))
                            .frame(width: 5, height: 5)
                        
                        Text("Apple Silicon")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 6.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .menuIndicator(.hidden)
                .fixedSize()
            } else if isChatGPT {
                Menu {
                    Text("ChatGPT Multi-Account Pool")
                    Label("Model: 6 Luna Medium", systemImage: "eye.fill")
                    Label("Engine: OpenAI Codex CLI (Headless)", systemImage: "terminal.fill")
                    Divider()
                    ForEach(ChatGPTAccountPoolManager.shared.accounts) { acc in
                        Button(action: {
                            ChatGPTAccountPoolManager.shared.setAccountActive(id: acc.id)
                        }) {
                            if acc.id == ChatGPTAccountPoolManager.shared.activeAccountId {
                                Label(acc.label, systemImage: "checkmark.circle.fill")
                            } else {
                                Label(acc.label, systemImage: "person.circle")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Circle()
                            .fill(Color(hex: "#10A37F"))
                            .frame(width: 5, height: 5)
                        
                        Text(ChatGPTAccountPoolManager.shared.activeAccount?.label ?? "ChatGPT Pool")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 6.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .menuIndicator(.hidden)
                .fixedSize()

            } else {
                Menu {
                    Text("Profil Tersimpan di Vault")
                    
                    if hasProfiles {
                        ForEach(usageManager.accounts) { acc in
                            Button(action: {
                                usageManager.switchAccount(to: acc.id, autoRestart: true)
                            }) {
                                if acc.email.lowercased() == account.email.lowercased() {
                                    Label(acc.email, systemImage: "checkmark.circle.fill")
                                } else {
                                    Label(acc.email, systemImage: "person.circle")
                                }
                            }
                        }
                        
                        Divider()
                        
                        Menu("Hapus Profil") {
                            ForEach(usageManager.accounts) { acc in
                                Button(role: .destructive, action: {
                                    usageManager.deleteProfile(email: acc.email)
                                }) {
                                    Label("Hapus \(acc.email)", systemImage: "trash")
                                }
                            }
                            
                            Divider()
                            
                            Button(role: .destructive, action: {
                                usageManager.deleteAllProfiles()
                            }) {
                                Label("Hapus Semua Profil", systemImage: "trash.fill")
                            }
                        }
                    } else {
                        Text("Belum ada profil tersimpan")
                    }
                    
                    // Show save button if: account not saved at all, OR saved but missing token
                    let needsTokenUpdate = isCurrentSaved && !usageManager.currentProfileHasToken()
                    if usageManager.isConnected && !account.email.isEmpty && (!isCurrentSaved || needsTokenUpdate) {
                        Divider()
                        
                        Button(action: {
                            usageManager.saveLiveDetectedProfile()
                        }) {
                            if needsTokenUpdate {
                                Label("Update token \(account.email)", systemImage: "arrow.triangle.2.circlepath")
                            } else {
                                Label("Simpan \(account.email) ke Vault", systemImage: "square.and.arrow.down.fill")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        if !usageManager.isConnected {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 5, height: 5)
                            
                            Text("Belum Terhubung")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                        } else {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                            
                            Text(account.email.isEmpty ? "Antigravity" : account.email)
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 6.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .menuIndicator(.hidden)
                .fixedSize()
            }
            
            // Transient status pill
            if let status = usageManager.statusMessage {
                Text(status)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.4, green: 0.85, blue: 1.0))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.2))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            Spacer()
            
            // 3. AI Bridge Status & Control Button (Left of Reload)
            bridgeMenuButton
            
            // 4. Reload / Refresh Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.6)) {
                    refreshAngle += 360
                }
                usageManager.refresh()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .rotationEffect(.degrees(refreshAngle))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .fixedSize()
        }
        .padding(.horizontal, 2)
    }
    
    // MARK: - AI Bridge Menu Button
    
    private var bridgeMenuButton: some View {
        let isOnline = isSiriAI ? (CuaDriverClient.shared.isDaemonRunning || SiriAIEngine.shared.isDaemonRunning) : bridgeManager.isRunning
        let isStarting = isSiriAI ? false : bridgeManager.isStarting

        return Menu {
            if isSiriAI {
                Section("Siri AI & Cua Bridge") {
                    HStack {
                        Text("AFM Status: \(SiriAIEngine.shared.isDaemonRunning ? "🟢 Online (Neural Engine)" : "🟡 Standby")")
                    }
                    HStack {
                        Text("Cua Status: \(CuaDriverClient.shared.isDaemonRunning ? "🟢 Online (56 Tools)" : "🟡 Standby")")
                    }
                    HStack {
                        Text("Endpoint: http://127.0.0.1:1976")
                    }
                    if let sock = CuaDriverClient.shared.activeSocketPath {
                        HStack {
                            Text("Socket: \(sock)")
                        }
                    }
                }
                
                Section("Kontrol Engine") {
                    Button(action: {
                        SiriAIEngine.shared.warmUp()
                        CuaDriverClient.shared.warmUp()
                    }) {
                        Label("Restart Siri AI & Cua Daemons", systemImage: "arrow.clockwise")
                    }
                    Button(action: {
                        let logURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
                            .appendingPathComponent("Logs/Izanotchy/clicky.log")
                        NSWorkspace.shared.open(logURL)
                    }) {
                        Label("Buka Log Clicky & Siri AI", systemImage: "doc.text")
                    }
                }
            } else {
                Section("⚡ Antigravity AI Bridge") {
                    HStack {
                        Text("Status: \(bridgeManager.isRunning ? "🟢 Online" : (bridgeManager.isStarting ? "🟡 Starting..." : "⚪ Offline"))")
                    }
                    
                    let activeEmail = usageManager.activeAccount.email
                    if !activeEmail.isEmpty {
                        HStack {
                            Text("Active Routing: \(activeEmail)")
                        }
                    }
                }
                
                Section("Kontrol Proxy") {
                    if bridgeManager.isRunning {
                        Button(action: {
                            Task {
                                await bridgeManager.restartBridge()
                            }
                        }) {
                            Label("Restart Bridge (:8080)", systemImage: "arrow.clockwise")
                        }
                        
                        Button(role: .destructive, action: {
                            bridgeManager.stopBridge()
                        }) {
                            Label("Matikan Bridge", systemImage: "stop.circle")
                        }
                    } else {
                        Button(action: {
                            Task {
                                await bridgeManager.startBridge()
                            }
                        }) {
                            Label("Nyalakan Bridge (:8080)", systemImage: "play.fill")
                        }
                    }
                }
                
                Section("Integrasi Klien (OpenAI API)") {
                    Button(action: {
                        bridgeManager.copyBaseURLToClipboard()
                    }) {
                        Label("Salin Base URL (http://127.0.0.1:\(bridgeManager.port)/v1)", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: {
                        bridgeManager.copySampleConfigToClipboard()
                    }) {
                        Label("Salin Config OpenAI JSON", systemImage: "curlybraces")
                    }
                    
                    Button(action: {
                        bridgeManager.openLogFile()
                    }) {
                        Label("Buka Log Bridge", systemImage: "doc.text")
                    }
                }
                
                Section {
                    Button(action: {
                        bridgeManager.autoStartEnabled.toggle()
                    }) {
                        if bridgeManager.autoStartEnabled {
                            Label("Auto-start bersama iza-notch", systemImage: "checkmark.square.fill")
                        } else {
                            Label("Auto-start bersama iza-notch", systemImage: "square")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3.5) {
                Image(systemName: "server.rack")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(
                        isOnline
                            ? Color(red: 0.35, green: 0.85, blue: 0.45)
                            : (isStarting ? Color.yellow : Color.white.opacity(0.40))
                    )
                
                Circle()
                    .fill(
                        isOnline
                            ? Color(red: 0.30, green: 0.90, blue: 0.45)
                            : (isStarting ? Color.yellow : Color.white.opacity(0.25))
                    )
                    .frame(width: 4.5, height: 4.5)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        isOnline
                            ? Color.green.opacity(0.12)
                            : Color.white.opacity(0.06)
                    )
            )
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
        .fixedSize()
        .help(isSiriAI ? "Siri AI & Cua Driver Daemon" : "Antigravity AI Bridge Proxy (:8080)")
    }
    
    // MARK: - Siri AI (AFM) Section (Opsi B: Minimalist Siri Orb & Telemetry)

    private var siriAiSection: some View {
        HStack(spacing: 16) {
            siriOnDeviceCard
            siriIntegrationCard
        }
        .frame(maxWidth: .infinity)
    }

    private var siriOnDeviceCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Apple Foundation Models")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.leading, 2)

            ZStack {
                // Smoked titanium background aura
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#334155").opacity(0.25), Color(hex: "#1E293B").opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 12)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.78), Color.black.opacity(0.60)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.25), Color(hex: "#94A3B8").opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)

                VStack(spacing: 0) {
                    // Row 1: Ready status + Liquid Chrome Siri Orb
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("Siri AI is Ready on this Mac")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))

                            Text("Apple Foundation Models · On-Device · ~45ms")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.50))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 2)

                        // Liquid Chrome 3D Sphere (Smoked Titanium & Liquid Chrome)
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#334155"), Color(hex: "#1E293B"), Color(hex: "#0F172A")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.40), Color.white.opacity(0.10)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.4), radius: 3)

                            Image(systemName: "apple.logo")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.white, Color(hex: "#E2E8F0")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    // Row 2: Token Quota & Unlimited pill (Smoked Titanium, no emoji)
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("Token Quota & Execution")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))

                            Text("Unlimited Local Inference · Zero API Cost")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.50))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 2)

                        HStack(spacing: 3) {
                            Text("Unlimited")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#F1F5F9"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#27272A"), Color(hex: "#18181B")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(height: 86)
        }
    }

    private var siriIntegrationCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("System & Execution Integration")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.leading, 2)

            ZStack {
                // Smoked titanium background aura
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#334155").opacity(0.25), Color(hex: "#1E293B").opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 12)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.78), Color.black.opacity(0.60)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.25), Color(hex: "#94A3B8").opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)

                VStack(spacing: 0) {
                    // Row 1: Cua Driver Hands
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("Cua Driver Hands")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))

                            Text("56 Native Computer Use Tools")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.50))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 2)

                        HStack(spacing: 3) {
                            Text("56 Tools")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#F1F5F9"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#27272A"), Color(hex: "#18181B")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    // Row 2: Neural Engine & Accessibility
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("Neural Engine & Accessibility")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))

                            Text("Apple Silicon NPU · Background AX")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.50))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 2)

                        HStack(spacing: 3) {
                            Text("Active")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#F1F5F9"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#27272A"), Color(hex: "#18181B")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(height: 86)
        }
    }
    

    // MARK: - Gemini Models Section
    
    private var geminiSection: some View {
        let account = usageManager.activeAccount
        let geminiAvgUsage = (account.geminiWeeklyRemaining + account.geminiFiveHourRemaining) / 2.0
        
        return VStack(alignment: .leading, spacing: 5) {
            Text("Gemini Models")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.leading, 2)
            
            ZStack {
                AntigravityAmbianceView(usageLevel: geminiAvgUsage)
                
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.75), Color.black.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)
                
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("Weekly Limit Remaining")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))
                            
                            Text(account.geminiWeeklyRefreshText == "Ready" ? "Full Quota Available" : "Refreshes in \(account.geminiWeeklyRefreshText)")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.48))
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 2)
                        
                        HStack(spacing: 6) {
                            Text("\(Int(account.geminiWeeklyRemaining * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            
                            CircularRingView(
                                progress: account.geminiWeeklyRemaining,
                                size: 18,
                                strokeWidth: 2.4
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                    
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("Five Hour Limit Remaining")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))
                            
                            Text(account.geminiFiveHourRefreshText == "Ready" || account.geminiFiveHourRemaining >= 1.0 ? "Full Quota Available" : "Refreshes in \(account.geminiFiveHourRefreshText)")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.48))
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 2)
                        
                        HStack(spacing: 6) {
                            Text("\(Int(account.geminiFiveHourRemaining * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            
                            CircularRingView(
                                progress: account.geminiFiveHourRemaining,
                                size: 18,
                                strokeWidth: 2.4
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(height: 86)
        }
    }
    
    // MARK: - Claude and GPT Models Section
    
    private var claudeGptSection: some View {
        let account = usageManager.activeAccount
        let claudeAvgUsage = (account.claudeWeeklyRemaining + account.claudeFiveHourRemaining) / 2.0
        
        return VStack(alignment: .leading, spacing: 5) {
            Text("Claude and GPT models")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.leading, 2)
            
            ZStack {
                AntigravityAmbianceView(usageLevel: claudeAvgUsage)
                
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.75), Color.black.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)
                
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("Weekly Limit Remaining")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))
                            
                            Text(account.claudeWeeklyRefreshText == "Ready" || account.claudeWeeklyRemaining >= 1.0 ? "Full Quota Available" : "Refreshes in \(account.claudeWeeklyRefreshText)")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.48))
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 2)
                        
                        HStack(spacing: 6) {
                            Text("\(Int(account.claudeWeeklyRemaining * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            
                            CircularRingView(
                                progress: account.claudeWeeklyRemaining,
                                size: 18,
                                strokeWidth: 2.4
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                    
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("Five Hour Limit Remaining")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))
                            
                            Text(account.claudeFiveHourRemaining >= 1.0 ? "Full Quota Available" : "Refreshes in \(account.claudeFiveHourRefreshText)")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.48))
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 2)
                        
                        HStack(spacing: 6) {
                            Text("\(Int(account.claudeFiveHourRemaining * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            
                            CircularRingView(
                                progress: account.claudeFiveHourRemaining,
                                size: 18,
                                strokeWidth: 2.4
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(height: 86)
        }
    }
}
