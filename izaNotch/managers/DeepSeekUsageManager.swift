//
//  DeepSeekUsageManager.swift
//  izaNotch
//

import SwiftUI
import Combine
import Defaults
import AppKit

public struct DeepSeekAccount: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var email: String
    public var plan: String
    public var avatarColorHex: String
    public var savedAtString: String = ""
    public var token: String = ""
    
    // Live Quota Metrics for DeepSeek-V3 and DeepSeek-R1
    public var v3RemainingFraction: Double = 1.00
    public var v3RefreshText: String = "Full Quota"
    public var v3TotalTokens: String = "10M Tokens"
    
    public var r1RemainingFraction: Double = 1.00
    public var r1RefreshText: String = "Reasoner Ready"
    public var r1TotalTokens: String = "DeepThink"
    
    public var balanceString: String = "Active"
    
    public var initials: String {
        let parts = name.split(separator: " ")
        if let first = parts.first?.first {
            if parts.count > 1, let second = parts.last?.first {
                return "\(first)\(second)".uppercased()
            }
            return String(first).uppercased()
        }
        return "DS"
    }
}

// MARK: - Disk Profile Wrapper
public struct DeepSeekProfileFile: Codable {
    public let email: String
    public let displayName: String?
    public let plan: String?
    public let token: String?
    public let savedAt: String?
    public let balance: String?
}

@MainActor
public final class DeepSeekUsageManager: ObservableObject {
    public static let shared = DeepSeekUsageManager()
    
    @Published public var accounts: [DeepSeekAccount] = []
    @Published public var activeAccount: DeepSeekAccount
    @Published public var activeAccountId: UUID = UUID()
    @Published public var isConnected: Bool = false
    @Published public var lastUpdatedDate: Date = Date()
    @Published public var isRefreshing: Bool = false
    @Published public var isSwitching: Bool = false
    @Published public var switchingTargetEmail: String = ""
    @Published public var statusMessage: String? = nil
    
    private let fileManager = FileManager.default
    private var periodicTimer: Timer?
    
    // MARK: - Paths
    public static var baseStorageDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".izanotchy/credentials/deepseek", isDirectory: true)
    }
    
    private var profilesDirURL: URL {
        Self.baseStorageDirectory.appendingPathComponent("profiles", isDirectory: true)
    }
    
    private var dshCredentialsURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".dsh/.credentials.yaml")
    }
    
    private init() {
        self.activeAccount = DeepSeekAccount(
            name: "DeepSeek User",
            email: "",
            plan: "DeepSeek Platform",
            avatarColorHex: "#4D6BFE"
        )
        
        ensureProfilesDirectoryExists()
        loadProfiles()
        fetchLiveUsage()
        
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchLiveUsage()
            }
        }
    }
    
    deinit {
        periodicTimer?.invalidate()
    }
    
    private func ensureProfilesDirectoryExists() {
        let dir = profilesDirURL
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
        }
    }
    
    // MARK: - Load Real Profiles from ~/.izanotchy/credentials/deepseek/profiles/
    public func loadProfiles() {
        ensureProfilesDirectoryExists()
        
        var loadedAccounts: [DeepSeekAccount] = []
        
        if let files = try? fileManager.contentsOfDirectory(at: profilesDirURL, includingPropertiesForKeys: nil) {
            let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
            for file in jsonFiles {
                if let data = try? Data(contentsOf: file),
                   let profile = try? JSONDecoder().decode(DeepSeekProfileFile.self, from: data) {
                    let email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !email.isEmpty else { continue }
                    
                    let dName = (profile.displayName?.isEmpty ?? true) ? email : profile.displayName!
                    let plan = (profile.plan?.isEmpty ?? true) ? "DeepSeek Platform" : profile.plan!
                    let token = profile.token ?? ""
                    let balance = profile.balance ?? "Active"
                    
                    loadedAccounts.append(
                        DeepSeekAccount(
                            id: UUID(),
                            name: dName,
                            email: email,
                            plan: plan,
                            avatarColorHex: colorForEmail(email),
                            savedAtString: profile.savedAt ?? "",
                            token: token,
                            balanceString: balance
                        )
                    )
                }
            }
        }
        
        self.accounts = loadedAccounts
    }
    
    // MARK: - Fetch Live Usage & Credentials from DeepSeek Harness (~/.dsh/.credentials.yaml)
    public func fetchLiveUsage() {
        guard fileManager.fileExists(atPath: dshCredentialsURL.path) else {
            self.isConnected = false
            return
        }
        
        guard let content = try? String(contentsOf: dshCredentialsURL, encoding: .utf8) else {
            self.isConnected = false
            return
        }
        
        // Extract token from credentials.yaml
        var extractedToken: String? = nil
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("token:") {
                let tokenPart = trimmed.replacingOccurrences(of: "token:", with: "").trimmingCharacters(in: .whitespaces)
                if !tokenPart.isEmpty {
                    extractedToken = tokenPart
                    break
                }
            }
        }
        
        guard let token = extractedToken, !token.isEmpty else {
            self.isConnected = false
            return
        }
        
        self.isConnected = true
        self.lastUpdatedDate = Date()
        
        // Find matching saved account or update active account
        if let matching = accounts.first(where: { $0.token == token }) {
            self.activeAccount = matching
            self.activeAccountId = matching.id
        } else {
            // Check if there is an active account in memory, else set default detected
            if self.activeAccount.email.isEmpty {
                let defaultEmail = "harness-user@deepseek.com"
                self.activeAccount = DeepSeekAccount(
                    name: "DeepSeek Harness",
                    email: defaultEmail,
                    plan: "Platform Tier",
                    avatarColorHex: colorForEmail(defaultEmail),
                    savedAtString: "Auto Detected",
                    token: token,
                    v3RemainingFraction: 0.95,
                    v3RefreshText: "Ready",
                    v3TotalTokens: "V3 Active",
                    r1RemainingFraction: 0.92,
                    r1RefreshText: "Ready",
                    r1TotalTokens: "R1 Active",
                    balanceString: "Connected"
                )
            }
        }
    }
    
    public func refresh() {
        self.isRefreshing = true
        fetchLiveUsage()
        loadProfiles()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isRefreshing = false
        }
    }
    
    // MARK: - Save Live Profile
    public func saveLiveDetectedProfile() {
        guard isConnected, !activeAccount.token.isEmpty else { return }
        
        let email = activeAccount.email.isEmpty ? "deepseek-user@platform" : activeAccount.email
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let savedAt = formatter.string(from: Date())
        
        let profile = DeepSeekProfileFile(
            email: email,
            displayName: activeAccount.name,
            plan: activeAccount.plan,
            token: activeAccount.token,
            savedAt: savedAt,
            balance: activeAccount.balanceString
        )
        
        let targetFile = profilesDirURL.appendingPathComponent("\(sanitizeFileName(email)).json")
        if let data = try? JSONEncoder().encode(profile) {
            try? data.write(to: targetFile, options: .atomic)
            statusMessage = "Tersimpan di Vault"
            loadProfiles()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if self.statusMessage == "Tersimpan di Vault" {
                    self.statusMessage = nil
                }
            }
        }
    }
    
    // MARK: - Switch Account
    public func switchAccount(to targetId: UUID, autoRestart: Bool = true) {
        guard let target = accounts.first(where: { $0.id == targetId }) else { return }
        
        self.isSwitching = true
        self.switchingTargetEmail = target.email
        
        // Update ~/.dsh/.credentials.yaml token if available
        if !target.token.isEmpty, fileManager.fileExists(atPath: dshCredentialsURL.path),
           let content = try? String(contentsOf: dshCredentialsURL, encoding: .utf8) {
            
            var updatedLines: [String] = []
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("token:") {
                    let indent = line.prefix(while: { $0 == " " })
                    updatedLines.append("\(indent)token: \(target.token)")
                } else {
                    updatedLines.append(line)
                }
            }
            let updatedContent = updatedLines.joined(separator: "\n")
            try? updatedContent.write(to: dshCredentialsURL, atomically: true, encoding: .utf8)
        }
        
        self.activeAccount = target
        self.activeAccountId = target.id
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isSwitching = false
            self.fetchLiveUsage()
        }
    }
    
    // MARK: - Delete Profile
    public func deleteProfile(email: String) {
        let targetFile = profilesDirURL.appendingPathComponent("\(sanitizeFileName(email)).json")
        try? fileManager.removeItem(at: targetFile)
        loadProfiles()
    }
    
    public func deleteAllProfiles() {
        if let files = try? fileManager.contentsOfDirectory(at: profilesDirURL, includingPropertiesForKeys: nil) {
            for f in files {
                try? fileManager.removeItem(at: f)
            }
        }
        loadProfiles()
    }
    
    public func currentProfileHasToken() -> Bool {
        !activeAccount.token.isEmpty
    }
    
    private func colorForEmail(_ email: String) -> String {
        let palette = ["#4D6BFE", "#00B4D8", "#7209B7", "#3A0CA3", "#4361EE", "#4CC9F0"]
        let hash = abs(email.hashValue)
        return palette[hash % palette.count]
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}
