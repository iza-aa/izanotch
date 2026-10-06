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
    public var tokenPayload: String? = nil
    
    // Live Gemini Quota Metrics (Weekly & 5-Hour) fetched from CloudCode API
    public var geminiWeeklyRemaining: Double = 1.00
    public var geminiWeeklyRefreshText: String = "Ready"
    public var geminiFiveHourRemaining: Double = 1.00
    public var geminiFiveHourRefreshText: String = "Ready"
    
    public var score: Double {
        (geminiWeeklyRemaining * 0.5) + (geminiFiveHourRemaining * 0.5)
    }
    
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
    public let savedAt: String?
    public let tokenPayload: String?
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
    private var geminiHomeDir: URL {
        let username = NSUserName()
        let realHome = URL(fileURLWithPath: "/Users/\(username)")
        return realHome.appendingPathComponent(".gemini")
    }
    
    private var activeTokenFileURL: URL {
        geminiHomeDir.appendingPathComponent("jetski-standalone-oauth-token")
    }
    
    private var profilesDirURL: URL {
        geminiHomeDir.appendingPathComponent("profiles")
    }
    
    public var bestBackupAccount: DeepSeekAccount? {
        let backups = accounts.filter { $0.email.lowercased() != activeAccount.email.lowercased() }
        return backups.sorted(by: { $0.score > $1.score }).first
    }
    
    private init() {
        self.activeAccount = DeepSeekAccount(
            name: "Rezky Haikal",
            email: "rezkyhaikal2@gmail.com",
            plan: "Google AI Pro",
            avatarColorHex: "#4D6BFE"
        )
        
        ensureProfilesDirectoryExists()
        loadProfiles()
        fetchLiveUsage()
        
        // Refresh every 10 seconds
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchLiveUsage()
            }
        }
    }
    
    deinit {
        periodicTimer?.invalidate()
    }
    
    private func ensureProfilesDirectoryExists() {
        if !fileManager.fileExists(atPath: profilesDirURL.path) {
            try? fileManager.createDirectory(at: profilesDirURL, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Load Real Profiles from ~/.gemini/profiles/
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
                    let plan = (profile.plan?.isEmpty ?? true) ? "Google AI Pro" : profile.plan!
                    
                    var acc = DeepSeekAccount(
                        id: UUID(),
                        name: dName,
                        email: email,
                        plan: plan,
                        avatarColorHex: colorForEmail(email),
                        savedAtString: profile.savedAt ?? "",
                        tokenPayload: profile.tokenPayload
                    )
                    
                    // Retain existing live quota if already fetched
                    if let existing = self.accounts.first(where: { $0.email.lowercased() == email.lowercased() }) {
                        acc.geminiWeeklyRemaining = existing.geminiWeeklyRemaining
                        acc.geminiWeeklyRefreshText = existing.geminiWeeklyRefreshText
                        acc.geminiFiveHourRemaining = existing.geminiFiveHourRemaining
                        acc.geminiFiveHourRefreshText = existing.geminiFiveHourRefreshText
                    }
                    
                    loadedAccounts.append(acc)
                }
            }
        }
        
        self.accounts = loadedAccounts
    }
    
    // MARK: - Detect Active Email from Active System Token and ~/.dsh/active_account.json
    private func detectLiveActiveEmail() -> String? {
        // 1. Highest priority: ~/.dsh/active_account.json written by DeepSeek Harness / gemini-adapter
        let dshActiveFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".dsh/active_account.json")
        if let dshData = try? Data(contentsOf: dshActiveFile),
           let dshJson = try? JSONSerialization.jsonObject(with: dshData) as? [String: Any],
           let rawEmail = (dshJson["email"] as? String) ?? (dshJson["contact"] as? String) {
            let clean = rawEmail.lowercased().trimmingCharacters(in: .whitespaces)
            if clean.contains("@") && !clean.contains("*") {
                return clean
            }
            // If masked (rez******al3@gmail.com), resolve to real profile
            for f in (try? fileManager.contentsOfDirectory(at: profilesDirURL, includingPropertiesForKeys: nil)) ?? [] {
                let name = f.deletingPathExtension().lastPathComponent.lowercased()
                if name.hasPrefix(clean.prefix(3)) && name.hasSuffix(clean.suffix(12)) {
                    return name
                }
            }
        }

        // 2. Next: inspect active token file
        guard let tokenData = try? Data(contentsOf: activeTokenFileURL),
              let json = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any] else {
            return nil
        }
        
        let tokenObj = json["token"] as? [String: Any]
        let activeAccess = tokenObj?["access_token"] as? String
        let activeRefresh = tokenObj?["refresh_token"] as? String
        
        guard let files = try? fileManager.contentsOfDirectory(at: profilesDirURL, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        for f in files where f.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: f),
                  let profile = try? JSONDecoder().decode(DeepSeekProfileFile.self, from: data),
                  let payloadStr = profile.tokenPayload,
                  let pData = payloadStr.data(using: .utf8),
                  let pJson = try? JSONSerialization.jsonObject(with: pData) as? [String: Any] else {
                continue
            }
            
            let pToken = pJson["token"] as? [String: Any]
            let pAccess = (pToken?["access_token"] as? String) ?? (pJson["access_token"] as? String)
            let pRefresh = (pToken?["refresh_token"] as? String) ?? (pJson["refresh_token"] as? String)
            
            if (activeAccess != nil && pAccess == activeAccess) ||
               (activeRefresh != nil && pRefresh == activeRefresh) {
                return profile.email.lowercased().trimmingCharacters(in: .whitespaces)
            }
        }
        
        return nil
    }
    
    // MARK: - Fetch Real Live Quota for all accounts via Google CloudCode API
    public func fetchLiveUsage() {
        loadProfiles()
        
        if let detected = detectLiveActiveEmail(), !detected.isEmpty {
            self.activeAccount.email = detected
            Defaults[.activeAntigravityEmail] = detected
        }
        
        self.isConnected = true
        self.lastUpdatedDate = Date()
        
        // Fetch live quota for all accounts asynchronously
        Task.detached(priority: .userInitiated) {
            let currentAccounts = await MainActor.run { self.accounts }
            
            for acc in currentAccounts {
                guard let payloadStr = acc.tokenPayload, let pData = payloadStr.data(using: .utf8),
                      let pJson = try? JSONSerialization.jsonObject(with: pData) as? [String: Any] else {
                    continue
                }
                
                var tokenStr: String? = nil
                if let tObj = pJson["token"] as? [String: Any] {
                    tokenStr = tObj["access_token"] as? String
                } else if let direct = pJson["access_token"] as? String {
                    tokenStr = direct
                }
                
                guard let token = tokenStr, !token.isEmpty else { continue }
                
                guard let url = URL(string: "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota") else { continue }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.setValue("antigravity/2.11.0", forHTTPHeaderField: "User-Agent")
                req.httpBody = "{}".data(using: .utf8)
                
                guard let (respData, _) = try? await URLSession.shared.data(for: req),
                      let respJson = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                      let buckets = respJson["buckets"] as? [[String: Any]] else {
                    continue
                }
                
                var remFraction = 1.0
                var resetDateString: String? = nil
                for b in buckets {
                    let mId = (b["modelId"] as? String) ?? ""
                    if mId == "gemini-3.8-flash-high" || mId.contains("gemini-3.8-flash") {
                        remFraction = b["remainingFraction"] as? Double ?? 1.0
                        resetDateString = b["resetTime"] as? String
                        break
                    }
                }
                
                let refreshText = self.formatResetTime(resetDateString)
                
                await MainActor.run {
                    if let idx = self.accounts.firstIndex(where: { $0.email.lowercased() == acc.email.lowercased() }) {
                        self.accounts[idx].geminiWeeklyRemaining = remFraction
                        self.accounts[idx].geminiWeeklyRefreshText = refreshText
                        self.accounts[idx].geminiFiveHourRemaining = remFraction
                        self.accounts[idx].geminiFiveHourRefreshText = refreshText
                    }
                    
                    if self.activeAccount.email.lowercased() == acc.email.lowercased() {
                        self.activeAccount.name = acc.name
                        self.activeAccount.plan = acc.plan
                        self.activeAccount.geminiWeeklyRemaining = remFraction
                        self.activeAccount.geminiWeeklyRefreshText = refreshText
                        self.activeAccount.geminiFiveHourRemaining = remFraction
                        self.activeAccount.geminiFiveHourRefreshText = refreshText
                        if let match = self.accounts.first(where: { $0.email.lowercased() == acc.email.lowercased() }) {
                            self.activeAccountId = match.id
                        }
                    }
                }
            }
        }
    }
    
    private nonisolated func formatResetTime(_ rawDateStr: String?) -> String {
        guard let raw = rawDateStr, !raw.isEmpty else { return "Ready" }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var targetDate = formatter.date(from: raw)
        if targetDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            targetDate = formatter.date(from: raw)
        }
        
        guard let date = targetDate else { return "Reset soon" }
        let diff = date.timeIntervalSinceNow
        guard diff > 0 else { return "Ready" }
        
        let totalMinutes = Int(round(diff / 60.0))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    public func refresh() {
        self.isRefreshing = true
        fetchLiveUsage()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isRefreshing = false
        }
    }
    
    // MARK: - Save Current Live Profile
    public func saveLiveDetectedProfile() {
        let email = activeAccount.email
        guard !email.isEmpty else { return }
        
        ensureProfilesDirectoryExists()
        let currentTokenPayload = fetchLiveSystemToken()
        
        let profile = DeepSeekProfileFile(
            email: email,
            displayName: activeAccount.name,
            plan: activeAccount.plan,
            savedAt: ISO8601DateFormatter().string(from: Date()),
            tokenPayload: currentTokenPayload
        )
        
        let safeFilename = email.replacingOccurrences(of: "/", with: "_") + ".json"
        let destURL = profilesDirURL.appendingPathComponent(safeFilename)
        
        do {
            let encoded = try JSONEncoder().encode(profile)
            try encoded.write(to: destURL, options: .atomic)
            loadProfiles()
            showStatus("Profil tersimpan: \(email)")
        } catch {
            showStatus("Gagal menyimpan: \(error.localizedDescription)")
        }
    }
    
    public func currentProfileHasToken() -> Bool {
        let email = activeAccount.email
        guard !email.isEmpty else { return false }
        let safeFilename = email.replacingOccurrences(of: "/", with: "_") + ".json"
        let profileURL = profilesDirURL.appendingPathComponent(safeFilename)
        guard let data = try? Data(contentsOf: profileURL),
              let profile = try? JSONDecoder().decode(DeepSeekProfileFile.self, from: data) else {
            return false
        }
        return profile.tokenPayload != nil && !(profile.tokenPayload?.isEmpty ?? true)
    }
    
    // MARK: - Switch Account & Auto-Restart DeepSeek Harness
    public func switchAccount(to id: UUID, autoRestart: Bool = true) {
        guard let targetAccount = accounts.first(where: { $0.id == id }) else { return }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isSwitching = true
            switchingTargetEmail = targetAccount.email
            activeAccountId = id
            activeAccount.email = targetAccount.email
            activeAccount.name = targetAccount.name
            activeAccount.geminiWeeklyRemaining = targetAccount.geminiWeeklyRemaining
            activeAccount.geminiWeeklyRefreshText = targetAccount.geminiWeeklyRefreshText
            activeAccount.geminiFiveHourRemaining = targetAccount.geminiFiveHourRemaining
            activeAccount.geminiFiveHourRefreshText = targetAccount.geminiFiveHourRefreshText
            Defaults[.activeAntigravityEmail] = targetAccount.email
            lastUpdatedDate = Date()
        }
        
        let safeFilename = targetAccount.email.replacingOccurrences(of: "/", with: "_") + ".json"
        let profileURL = profilesDirURL.appendingPathComponent(safeFilename)
        var targetPayload: String? = nil
        if let data = try? Data(contentsOf: profileURL),
           let profile = try? JSONDecoder().decode(DeepSeekProfileFile.self, from: data) {
            targetPayload = profile.tokenPayload
        }
        
        showStatus("Switching ke \(targetAccount.email)...")
        
        Task.detached(priority: .userInitiated) {
            // 1. Write target OAuth token to macOS Keychain and fallback file
            if let payload = targetPayload, !payload.isEmpty {
                self.applyTokenToSystem(payload: payload)
            }

            // 2. Update ~/.dsh/active_account.json directly
            let dshActiveFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".dsh/active_account.json")
            let dshContent = """
            {
              "email": "\(targetAccount.email)",
              "name": "\(targetAccount.name)",
              "updatedAt": "\(ISO8601DateFormatter().string(from: Date()))"
            }
            """
            try? dshContent.write(to: dshActiveFile, atomically: true, encoding: .utf8)
            
            // 3. Also sync AntigravityUsageManager
            await MainActor.run {
                AntigravityUsageManager.shared.activeAccount.email = targetAccount.email
                AntigravityUsageManager.shared.activeAccount.name = targetAccount.name
            }
            
            // 4. Reliable Auto-restart of DeepSeek Harness via NSWorkspace and shell fallback
            if autoRestart {
                let killP = Process()
                killP.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
                killP.arguments = ["-9", "-f", "DeepSeek Harness"]
                try? killP.run()
                killP.waitUntilExit()
                
                try? await Task.sleep(for: .milliseconds(1500))
                
                await MainActor.run {
                    let appURL = URL(fileURLWithPath: "/Applications/DeepSeek Harness.app")
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    NSWorkspace.shared.openApplication(at: appURL, configuration: config, completionHandler: nil)
                }
            }
            
            try? await Task.sleep(for: .seconds(2.5))
            
            await MainActor.run {
                self.fetchLiveUsage()
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.isSwitching = false
                    self.showStatus("DeepSeek aktif: \(targetAccount.email)")
                }
            }
        }
    }
    
    // MARK: - Delete Profiles
    public func deleteProfile(email: String) {
        let safeFilename = email.replacingOccurrences(of: "/", with: "_") + ".json"
        let destURL = profilesDirURL.appendingPathComponent(safeFilename)
        try? fileManager.removeItem(at: destURL)
        loadProfiles()
        showStatus("Profil dihapus: \(email)")
    }
    
    public func deleteAllProfiles() {
        if let files = try? fileManager.contentsOfDirectory(at: profilesDirURL, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        loadProfiles()
        showStatus("Semua profil dihapus")
    }
    
    private nonisolated func fetchLiveSystemToken() -> String? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-a", "antigravity", "-s", "gemini", "-w"]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if out.hasPrefix("go-keyring-base64:") {
            let base64Part = String(out.dropFirst("go-keyring-base64:".count))
            if let decodedData = Data(base64Encoded: base64Part),
               let jsonString = String(data: decodedData, encoding: .utf8), !jsonString.isEmpty {
                return jsonString
            }
        }
        
        let username = NSUserName()
        let fileURL = URL(fileURLWithPath: "/Users/\(username)/.gemini/jetski-standalone-oauth-token")
        if let tokenData = try? Data(contentsOf: fileURL),
           let fileString = String(data: tokenData, encoding: .utf8), !fileString.isEmpty {
            return fileString
        }
        
        return nil
    }
    
    private nonisolated func applyTokenToSystem(payload: String) {
        let b64 = Data(payload.utf8).base64EncodedString()
        let keychainVal = "go-keyring-base64:\(b64)"
        
        let secProcess = Process()
        secProcess.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        secProcess.arguments = ["add-generic-password", "-a", "antigravity", "-s", "gemini", "-w", keychainVal, "-U"]
        try? secProcess.run()
        secProcess.waitUntilExit()
        
        let username = NSUserName()
        let fileURL = URL(fileURLWithPath: "/Users/\(username)/.gemini/jetski-standalone-oauth-token")
        try? payload.data(using: .utf8)?.write(to: fileURL, options: .atomic)
    }
    
    private func showStatus(_ msg: String) {
        self.statusMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.statusMessage == msg {
                self.statusMessage = nil
            }
        }
    }
    
    private func colorForEmail(_ email: String) -> String {
        let palette = ["#4D6BFE", "#00B4D8", "#7209B7", "#3A0CA3", "#4361EE", "#4CC9F0"]
        let hash = abs(email.hashValue)
        return palette[hash % palette.count]
    }
}
