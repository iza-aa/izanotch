//
//  AntigravityUsageManager.swift
//  izaNotch
//
//  Created by Antigravity on 30/08/2026.
//

import SwiftUI
import Combine
import Defaults
import AppKit

public struct AntigravityAccount: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var email: String
    public var plan: String
    public var avatarColorHex: String
    public var savedAtString: String = ""
    
    // Live Quota Metrics
    public var geminiWeeklyRemaining: Double = 1.00
    public var geminiWeeklyRefreshText: String = "Ready"
    public var geminiFiveHourRemaining: Double = 1.00
    public var geminiFiveHourRefreshText: String = "Ready"
    
    public var claudeWeeklyRemaining: Double = 1.00
    public var claudeWeeklyRefreshText: String = "Ready"
    public var claudeFiveHourRemaining: Double = 1.00
    public var claudeFiveHourRefreshText: String = "Ready"
    
    public var creditOveragesEnabled: Bool = false
    
    public var initials: String {
        let parts = name.split(separator: " ")
        if let first = parts.first?.first {
            if parts.count > 1, let second = parts.last?.first {
                return "\(first)\(second)".uppercased()
            }
            return String(first).uppercased()
        }
        return "A"
    }
}

// MARK: - Disk Profile Wrapper
public struct AntigravityProfileFile: Codable {
    public let email: String
    public let displayName: String?
    public let plan: String?
    public let savedAt: String?
    public let tokenPayload: String?
}

@MainActor
public final class AntigravityUsageManager: ObservableObject {
    public static let shared = AntigravityUsageManager()
    
    @Published public var accounts: [AntigravityAccount] = []
    @Published public var activeAccount: AntigravityAccount
    @Published public var activeAccountId: UUID = UUID()
    @Published public var isConnected: Bool = false
    @Published public var lastUpdatedDate: Date = Date()
    @Published public var isRefreshing: Bool = false
    @Published public var isSwitching: Bool = false
    @Published public var switchingTargetEmail: String = ""
    @Published public var statusMessage: String? = nil
    
    private let fileManager = FileManager.default
    private var statusResetTask: Task<Void, Never>?
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
    
    private init() {
        self.activeAccount = AntigravityAccount(
            name: "Antigravity User",
            email: "",
            plan: "Google AI Pro",
            avatarColorHex: "#00897B"
        )
        
        ensureProfilesDirectoryExists()
        loadProfiles()
        fetchLiveUsage()
        
        // Refresh live usage every 5 seconds
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
        if !fileManager.fileExists(atPath: profilesDirURL.path) {
            try? fileManager.createDirectory(at: profilesDirURL, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Load Real Profiles from ~/.gemini/profiles/
    public func loadProfiles() {
        ensureProfilesDirectoryExists()
        
        var loadedAccounts: [AntigravityAccount] = []
        
        if let files = try? fileManager.contentsOfDirectory(at: profilesDirURL, includingPropertiesForKeys: nil) {
            let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
            for file in jsonFiles {
                if let data = try? Data(contentsOf: file),
                   let profile = try? JSONDecoder().decode(AntigravityProfileFile.self, from: data) {
                    
                    let email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !email.isEmpty else { continue }
                    
                    let dName = (profile.displayName?.isEmpty ?? true) ? email : profile.displayName!
                    let plan = (profile.plan?.isEmpty ?? true) ? "Google AI Pro" : profile.plan!
                    
                    loadedAccounts.append(
                        AntigravityAccount(
                            id: UUID(),
                            name: dName,
                            email: email,
                            plan: plan,
                            avatarColorHex: colorForEmail(email),
                            savedAtString: profile.savedAt ?? ""
                        )
                    )
                }
            }
        }
        
        self.accounts = loadedAccounts
    }
    
    // MARK: - Fetch Real Live Usage & Active Email from Antigravity Language Server
    public func fetchLiveUsage() {
        Task.detached(priority: .userInitiated) {
            guard let (csrf, baseURL) = await self.detectLanguageServerEndpoint() else {
                await MainActor.run {
                    self.isConnected = false
                }
                return
            }
            
            let session = URLSession(configuration: .ephemeral, delegate: InsecureCertDelegate(), delegateQueue: nil)
            
            // 1. Query Active User Email & Status
            var detectedEmail: String? = nil
            var detectedName: String? = nil
            var detectedPlan: String? = nil
            
            if let userStatusURL = URL(string: "\(baseURL)/exa.language_server_pb.LanguageServerService/GetUserStatus") {
                var req = URLRequest(url: userStatusURL)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
                req.setValue(csrf, forHTTPHeaderField: "x-codeium-csrf-token")
                req.httpBody = "{}".data(using: .utf8)
                
                if let (data, _) = try? await session.data(for: req),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let userStatus = json["userStatus"] as? [String: Any] {
                    detectedEmail = userStatus["email"] as? String
                    detectedName = userStatus["name"] as? String
                    if let planStatus = userStatus["planStatus"] as? [String: Any],
                       let planInfo = planStatus["planInfo"] as? [String: Any] {
                        detectedPlan = planInfo["planName"] as? String
                    }
                }
            }
            
            // 2. Query Quota Limits
            var gWeekly = 1.0
            var gWeeklyText = "Ready"
            var g5h = 1.0
            var g5hText = "Full Quota Available"
            
            var cWeekly = 1.0
            var cWeeklyText = "Ready"
            var c5h = 1.0
            var c5hText = "Full Quota Available"
            
            if let quotaURL = URL(string: "\(baseURL)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary") {
                var req = URLRequest(url: quotaURL)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
                req.setValue(csrf, forHTTPHeaderField: "x-codeium-csrf-token")
                req.httpBody = "{}".data(using: .utf8)
                
                if let (data, _) = try? await session.data(for: req),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resp = json["response"] as? [String: Any],
                   let groups = resp["groups"] as? [[String: Any]] {
                    
                    for group in groups {
                        let name = (group["displayName"] as? String)?.lowercased() ?? ""
                        let buckets = group["buckets"] as? [[String: Any]] ?? []
                        
                        for bucket in buckets {
                            let window = bucket["window"] as? String ?? ""
                            let frac = bucket["remainingFraction"] as? Double ?? 1.0
                            let desc = bucket["description"] as? String ?? ""
                            let refreshText = self.extractRefreshText(from: desc)
                            
                            if name.contains("gemini") {
                                if window == "weekly" {
                                    gWeekly = frac
                                    gWeeklyText = refreshText
                                } else {
                                    g5h = frac
                                    g5hText = refreshText
                                }
                            } else {
                                if window == "weekly" {
                                    cWeekly = frac
                                    cWeeklyText = refreshText
                                } else {
                                    c5h = frac
                                    c5hText = refreshText
                                }
                            }
                        }
                    }
                }
            }
            
            await MainActor.run {
                guard let email = detectedEmail, !email.isEmpty else {
                    self.isConnected = false
                    return
                }
                
                self.isConnected = true
                self.activeAccount.email = email
                Defaults[.activeAntigravityEmail] = email
                
                if let name = detectedName, !name.isEmpty {
                    self.activeAccount.name = name
                }
                if let plan = detectedPlan, !plan.isEmpty {
                    self.activeAccount.plan = plan
                }
                
                self.activeAccount.geminiWeeklyRemaining = gWeekly
                self.activeAccount.geminiWeeklyRefreshText = gWeeklyText
                self.activeAccount.geminiFiveHourRemaining = g5h
                self.activeAccount.geminiFiveHourRefreshText = g5hText
                
                self.activeAccount.claudeWeeklyRemaining = cWeekly
                self.activeAccount.claudeWeeklyRefreshText = cWeeklyText
                self.activeAccount.claudeFiveHourRemaining = c5h
                self.activeAccount.claudeFiveHourRefreshText = c5hText
                
                self.lastUpdatedDate = Date()
            }
        }
    }
    
    private nonisolated func extractRefreshText(from desc: String) -> String {
        if let range = desc.range(of: "fully refresh in ") {
            var sub = String(desc[range.upperBound...])
            if sub.hasSuffix(".") { sub.removeLast() }
            return sub
        }
        return "Ready"
    }
    
    private nonisolated func detectLanguageServerEndpoint() async -> (String, String)? {
        // Step 1: Detect language_server PID and CSRF token safely via ps
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "ps -eo pid,command | grep '[l]anguage_server'"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        
        // CRITICAL: Read data BEFORE waitUntilExit to prevent macOS kernel pipe buffer deadlock
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        
        let out = String(data: data, encoding: .utf8) ?? ""
        guard let line = out.components(separatedBy: .newlines).first(where: { $0.contains("language_server") }),
              !line.isEmpty else {
            return nil
        }
        
        // Extract PID
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let pidStr = trimmed.components(separatedBy: .whitespaces).first,
              let pid = Int(pidStr) else {
            return nil
        }
        
        // Extract CSRF Token
        var csrfToken: String? = nil
        if let range = line.range(of: "--csrf_token") {
            let sub = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            csrfToken = sub.components(separatedBy: .whitespaces).first
        }
        guard let csrf = csrfToken, !csrf.isEmpty else { return nil }
        
        // Step 2: Extract Listening Ports via lsof
        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/bin/zsh")
        lsof.arguments = ["-c", "/usr/sbin/lsof -Pan -p \(pid) -iTCP -sTCP:LISTEN | awk -F: '/LISTEN/ {print $2}' | awk '{print $1}'"]
        let lpipe = Pipe()
        lsof.standardOutput = lpipe
        try? lsof.run()
        
        let ldata = lpipe.fileHandleForReading.readDataToEndOfFile()
        lsof.waitUntilExit()
        
        let lout = String(data: ldata, encoding: .utf8) ?? ""
        var candidatePorts: [Int] = []
        for portLine in lout.components(separatedBy: .newlines) {
            let pStr = portLine.trimmingCharacters(in: .whitespaces)
            if let p = Int(pStr), !candidatePorts.contains(p) {
                candidatePorts.append(p)
            }
        }
        
        guard !candidatePorts.isEmpty else { return nil }
        
        let session = URLSession(configuration: .ephemeral, delegate: InsecureCertDelegate(), delegateQueue: nil)
        
        // Step 3: Actively probe candidate ports across http and https
        for port in candidatePorts {
            for scheme in ["http", "https"] {
                guard let testURL = URL(string: "\(scheme)://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/GetUserStatus") else { continue }
                var req = URLRequest(url: testURL)
                req.httpMethod = "POST"
                req.timeoutInterval = 1.2
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
                req.setValue(csrf, forHTTPHeaderField: "x-codeium-csrf-token")
                req.httpBody = "{}".data(using: .utf8)
                
                if let (data, resp) = try? await session.data(for: req),
                   let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["userStatus"] != nil {
                    return (csrf, "\(scheme)://127.0.0.1:\(port)")
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Token Bridge (macOS Keychain + Fallback File)
    
    /// Reads the active OAuth token from macOS Keychain (service: "gemini", account: "antigravity") or fallback file
    private func fetchLiveSystemToken() -> String? {
        // 1. Try macOS Keychain
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "gemini", "-a", "antigravity", "-w"]
        let pipe = Pipe()
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
        
        // 2. Fallback to ~/.gemini/jetski-standalone-oauth-token
        if let tokenData = try? Data(contentsOf: activeTokenFileURL),
           let fileString = String(data: tokenData, encoding: .utf8), !fileString.isEmpty {
            return fileString
        }
        
        return nil
    }
    
    /// Writes the target OAuth token to macOS Keychain and backup file
    private nonisolated func applyTokenToSystem(payload: String) {
        // 1. Write to macOS Keychain with go-keyring-base64 format
        let b64 = Data(payload.utf8).base64EncodedString()
        let keychainVal = "go-keyring-base64:\(b64)"
        
        let secProcess = Process()
        secProcess.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        secProcess.arguments = ["add-generic-password", "-a", "antigravity", "-s", "gemini", "-w", keychainVal, "-U"]
        try? secProcess.run()
        secProcess.waitUntilExit()
        
        // 2. Write to fallback file ~/.gemini/jetski-standalone-oauth-token
        let username = NSUserName()
        let fileURL = URL(fileURLWithPath: "/Users/\(username)/.gemini/jetski-standalone-oauth-token")
        try? payload.data(using: .utf8)?.write(to: fileURL, options: .atomic)
    }
    
    // MARK: - Save Current Live Profile to Vault (~/.gemini/profiles/)
    public func saveLiveDetectedProfile() {
        let email = activeAccount.email
        guard !email.isEmpty else { return }
        
        ensureProfilesDirectoryExists()
        
        // Read the LIVE token from Keychain / file
        let currentTokenPayload = fetchLiveSystemToken()
        
        let profile = AntigravityProfileFile(
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
            showStatus("Gagal menyimpan profil: \(error.localizedDescription)")
        }
    }
    
    /// Returns true if the currently-connected account's vault profile already contains a tokenPayload
    public func currentProfileHasToken() -> Bool {
        let email = activeAccount.email
        guard !email.isEmpty else { return false }
        let safeFilename = email.replacingOccurrences(of: "/", with: "_") + ".json"
        let profileURL = profilesDirURL.appendingPathComponent(safeFilename)
        guard let data = try? Data(contentsOf: profileURL),
              let profile = try? JSONDecoder().decode(AntigravityProfileFile.self, from: data) else {
            return false
        }
        return profile.tokenPayload != nil && !(profile.tokenPayload?.isEmpty ?? true)
    }
    
    // MARK: - Delete Profile from Vault
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
    
    // MARK: - Switch Account
    public func switchAccount(to id: UUID, autoRestart: Bool = true) {
        guard let targetAccount = accounts.first(where: { $0.id == id }) else { return }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isSwitching = true
            switchingTargetEmail = targetAccount.email
            activeAccountId = id
            activeAccount.email = targetAccount.email
            activeAccount.name = targetAccount.name
            Defaults[.activeAntigravityEmail] = targetAccount.email
            lastUpdatedDate = Date()
        }
        
        let safeFilename = targetAccount.email.replacingOccurrences(of: "/", with: "_") + ".json"
        let profileURL = profilesDirURL.appendingPathComponent(safeFilename)
        var targetPayload: String? = nil
        if let data = try? Data(contentsOf: profileURL),
           let profile = try? JSONDecoder().decode(AntigravityProfileFile.self, from: data) {
            targetPayload = profile.tokenPayload
        }
        
        showStatus("Switching to \(targetAccount.email)...")
        
        Task.detached(priority: .userInitiated) {
            if autoRestart {
                // 1. Tell Antigravity to quit
                let quitProcess = Process()
                quitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                quitProcess.arguments = ["-e", "tell application \"Antigravity\" to quit"]
                try? quitProcess.run()
                quitProcess.waitUntilExit()
                
                // Wait for process to fully exit
                try? await Task.sleep(for: .milliseconds(1200))
                
                // 2. Write new token payload to Keychain and disk
                if let payload = targetPayload, !payload.isEmpty {
                    self.applyTokenToSystem(payload: payload)
                }
                
                // 3. Launch Antigravity again
                let openProcess = Process()
                openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                openProcess.arguments = ["-e", "tell application \"Antigravity\" to activate"]
                try? openProcess.run()
                openProcess.waitUntilExit()
                
                // 4. Wait for language server to initialize
                try? await Task.sleep(for: .seconds(3.5))
                await MainActor.run {
                    self.fetchLiveUsage()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        self.isSwitching = false
                    }
                }
            } else {
                if let payload = targetPayload, !payload.isEmpty {
                    self.applyTokenToSystem(payload: payload)
                }
                await MainActor.run {
                    self.fetchLiveUsage()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        self.isSwitching = false
                    }
                }
            }
        }
    }
    
    // MARK: - Restart Antigravity Language Server (Soft Reload)
    public func restartLanguageServer() {
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            process.arguments = ["-f", "language_server.*antigravity"]
            try? process.run()
        }
    }
    
    // MARK: - Full App Relaunch (osascript quit & activate)
    public func restartFullAntigravityApp() {
        Task.detached(priority: .userInitiated) {
            let script = """
            tell application "Antigravity" to quit
            delay 1.5
            tell application "Antigravity" to activate
            """
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            try? p.run()
            p.waitUntilExit()
            
            // Wait for new language server to initialize before polling
            try? await Task.sleep(for: .seconds(3.0))
            await MainActor.run {
                self.fetchLiveUsage()
            }
        }
        showStatus("Restarting Antigravity...")
    }
    
    private func showStatus(_ msg: String) {
        statusResetTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            self.statusMessage = msg
        }
        statusResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.0))
            withAnimation(.easeInOut(duration: 0.3)) {
                self.statusMessage = nil
            }
        }
    }
    
    public func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        Task { @MainActor in
            loadProfiles()
            fetchLiveUsage()
            self.lastUpdatedDate = Date()
            try? await Task.sleep(for: .milliseconds(500))
            self.isRefreshing = false
        }
    }
    
    private func colorForEmail(_ email: String) -> String {
        let hash = abs(email.hashValue)
        let colors = ["#D81B60", "#00897B", "#1E88E5", "#7B1FA2", "#F4511E", "#43A047"]
        return colors[hash % colors.count]
    }
}

// MARK: - Insecure Certificate Delegate for Localhost Self-Signed HTTPS
private final class InsecureCertDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            return (.useCredential, URLCredential(trust: trust))
        }
        return (.performDefaultHandling, nil)
    }
}
