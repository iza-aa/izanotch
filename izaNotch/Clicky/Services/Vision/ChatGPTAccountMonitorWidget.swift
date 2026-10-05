//
//  ChatGPTAccountMonitorWidget.swift
//  izaNotch
//
//  Dynamic Island Notch AI Widget: ChatGPT Multi-Account Pool & Usage Monitor
//  Monitors active account, 6 Luna Medium model, cooldown timers, and hot failover pool.
//

import SwiftUI
import AppKit

public struct ChatGPTAccountMonitorWidget: View {
    @ObservedObject private var poolManager = ChatGPTAccountPoolManager.shared
    @State private var showingAddAccountSheet: Bool = false
    @State private var newAccountLabel: String = ""
    @State private var newAccountAuthJSON: String = ""
    @State private var errorMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 16) {
            // Left Card: Active Account & 6 Luna Model Status
            activeAccountCard
            
            // Right Card: Pool Roster & Failover Standby
            poolRosterCard
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingAddAccountSheet) {
            addAccountModal
        }
    }
    
    // MARK: - Active Account Card
    
    private var activeAccountCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Text("ChatGPT Vision VM")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("gpt-6-luna")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#10A37F"))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color(hex: "#10A37F").opacity(0.18))
                    .clipShape(Capsule())
            }
            .padding(.leading, 2)
            
            ZStack {
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
                                    colors: [Color.white.opacity(0.20), Color(hex: "#10A37F").opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)
                
                VStack(spacing: 0) {
                    // Row 1: Active Account Details
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let active = poolManager.activeAccount {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color(hex: "#10A37F"))
                                        .frame(width: 6, height: 6)
                                    
                                    Text(active.label)
                                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.95))
                                        .lineLimit(1)
                                }
                                
                                Text(active.email ?? "Session Active")
                                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.50))
                                    .lineLimit(1)
                            } else {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6, height: 6)
                                    
                                    Text("No Active Account")
                                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.95))
                                }
                                
                                Text("Register or import an account below")
                                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.50))
                            }
                        }
                        
                        Spacer(minLength: 2)
                        
                        // OpenAI / ChatGPT Icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#10A37F").opacity(0.22))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#10A37F"))
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                    
                    // Row 2: In-Flight Rotation Status
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text("Hot-Failover Guard")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                            
                            Text("Automatic fallback on 429 limit · Zero restart")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        
                        Spacer()
                        
                        Text("<50ms")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#38BDF8"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#38BDF8").opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Pool Roster Card
    
    private var poolRosterCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Account Pool (\(poolManager.accounts.count))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.leading, 2)
                
                Spacer()
                
                Button(action: {
                    newAccountLabel = "Account \(poolManager.accounts.count + 1)"
                    newAccountAuthJSON = ""
                    errorMessage = nil
                    showingAddAccountSheet = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("Add Account")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            ZStack {
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
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)
                
                if poolManager.accounts.isEmpty {
                    VStack(spacing: 4) {
                        Text("No accounts in pool")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        Text("Click Add Account to register")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(poolManager.accounts) { acc in
                                accountRow(acc)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Account Row
    
    @ViewBuilder
    private func accountRow(_ acc: GPTAccount) -> some View {
        HStack(spacing: 6) {
            // Status Dot
            switch acc.status {
            case .active:
                Circle()
                    .fill(Color(hex: "#10A37F"))
                    .frame(width: 5, height: 5)
            case .ready:
                Circle()
                    .fill(Color.blue)
                    .frame(width: 5, height: 5)
            case .cooldown:
                Circle()
                    .fill(Color.orange)
                    .frame(width: 5, height: 5)
            case .invalid:
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(acc.label)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(acc.status == .active ? .white : .white.opacity(0.8))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    switch acc.status {
                    case .active:
                        Text("Active Now")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Color(hex: "#10A37F"))
                    case .ready:
                        Text("Ready Standby")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Color.blue.opacity(0.8))
                    case .cooldown(let resetAt):
                        let remaining = max(0, Int(resetAt.timeIntervalSince(Date()) / 60))
                        Text("Cooldown (\(remaining)m)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Color.orange)
                    case .invalid(let reason):
                        Text("Invalid: \(reason)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Color.red)
                    }
                    
                    Text("• \(acc.requestCount) calls")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            
            Spacer()
            
            // Actions
            if acc.status != .active {
                Button(action: {
                    poolManager.setAccountActive(id: acc.id)
                }) {
                    Text("Use")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Button(action: {
                poolManager.deleteAccount(id: acc.id)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(acc.status == .active ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
        )
    }
    
    // MARK: - Add Account Modal Sheet
    
    private var addAccountModal: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Register ChatGPT Account Session")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showingAddAccountSheet = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Account Label")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("e.g. Personal Free / Secondary Work", text: $newAccountLabel)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Session Auth JSON (~/.codex/auth.json)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Button(action: {
                        importFromCurrentCodexAuth()
                    }) {
                        Text("Auto-fill from ~/.codex/auth.json")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(Color(hex: "#38BDF8"))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                TextEditor(text: $newAccountAuthJSON)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(height: 100)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.red)
            }
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    showingAddAccountSheet = false
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.white.opacity(0.7))
                
                Button("Save to Pool") {
                    saveNewAccount()
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .tint(Color(hex: "#10A37F"))
                .disabled(newAccountLabel.isEmpty || newAccountAuthJSON.isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 440)
        .background(Color(hex: "#1A1A1A"))
    }
    
    private func importFromCurrentCodexAuth() {
        let authURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        if let data = try? Data(contentsOf: authURL),
           let string = String(data: data, encoding: .utf8) {
            newAccountAuthJSON = string
        } else {
            errorMessage = "Could not find ~/.codex/auth.json"
        }
    }
    
    private func saveNewAccount() {
        do {
            try poolManager.registerAccount(label: newAccountLabel, authJsonString: newAccountAuthJSON)
            showingAddAccountSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
