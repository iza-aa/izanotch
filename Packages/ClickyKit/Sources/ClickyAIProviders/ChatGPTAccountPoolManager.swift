import ClickyFoundation
//
//  ChatGPTAccountPoolManager.swift
//  boringNotch
//
//  Multi-Account Session Pool & Hot Failover Manager for ChatGPT Codex
//  Enables instant account switching (<50ms) on rate-limits via isolated CODEX_HOME
//  Zero app restart required.
//

import Foundation
import Combine

public enum GPTAccountStatus: Codable, Equatable {
    case active
    case ready
    case cooldown(resetAt: Date)
    case invalid(reason: String)
    
    private enum CodingKeys: String, CodingKey {
        case type, resetAt, reason
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "active":
            self = .active
        case "ready":
            self = .ready
        case "cooldown":
            let resetAt = try container.decode(Date.self, forKey: .resetAt)
            self = .cooldown(resetAt: resetAt)
        case "invalid":
            let reason = try container.decode(String.self, forKey: .reason)
            self = .invalid(reason: reason)
        default:
            self = .ready
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .active:
            try container.encode("active", forKey: .type)
        case .ready:
            try container.encode("ready", forKey: .type)
        case .cooldown(let resetAt):
            try container.encode("cooldown", forKey: .type)
            try container.encode(resetAt, forKey: .resetAt)
        case .invalid(let reason):
            try container.encode("invalid", forKey: .type)
            try container.encode(reason, forKey: .reason)
        }
    }
}

public struct GPTAccount: Identifiable, Codable, Equatable {
    public let id: UUID
    public var label: String
    public var email: String?
    public var homeDirectoryPath: String
    public var status: GPTAccountStatus
    public var requestCount: Int
    public var lastUsed: Date
    
    public init(
        id: UUID = UUID(),
        label: String,
        email: String? = nil,
        homeDirectoryPath: String,
        status: GPTAccountStatus = .ready,
        requestCount: Int = 0,
        lastUsed: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.email = email
        self.homeDirectoryPath = homeDirectoryPath
        self.status = status
        self.requestCount = requestCount
        self.lastUsed = lastUsed
    }
}

@MainActor
public final class ChatGPTAccountPoolManager: ObservableObject {
    public static let shared = ChatGPTAccountPoolManager()
    
    @Published public private(set) var accounts: [GPTAccount] = []
    @Published public private(set) var activeAccountId: UUID?
    
    private var cooldownTimer: AnyCancellable?
    
    public var activeAccount: GPTAccount? {
        guard let activeAccountId = activeAccountId else {
            return accounts.first(where: { $0.status == .active })
        }
        return accounts.first(where: { $0.id == activeAccountId })
    }
    
    public static var baseStorageDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".izanotchy/credentials/gpt_accounts", isDirectory: true)
    }
    
    private var poolManifestURL: URL {
        Self.baseStorageDirectory.appendingPathComponent("pool.json")
    }
    
    private init() {
        ensureStorageDirectories()
        loadPool()
        startCooldownWatchdog()
    }
    
    // MARK: - Directory & Storage Setup
    
    private func ensureStorageDirectories() {
        let dir = Self.baseStorageDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
        }
    }
    
    private func loadPool() {
        if FileManager.default.fileExists(atPath: poolManifestURL.path),
           let data = try? Data(contentsOf: poolManifestURL),
           let loadedAccounts = try? JSONDecoder().decode([GPTAccount].self, from: data) {
            self.accounts = loadedAccounts
            if let active = loadedAccounts.first(where: { $0.status == .active }) {
                self.activeAccountId = active.id
            } else if let firstReady = loadedAccounts.first(where: { $0.status == .ready }) {
                setAccountActive(id: firstReady.id)
            }
        } else {
            // Auto-import default ChatGPT session if ~/.codex/auth.json exists
            autoImportDefaultCodexSession()
        }
    }
    
    private func savePool() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        try? data.write(to: poolManifestURL, options: .atomic)
    }
    
    public func syncDefaultCodexSession() {
        let defaultAuthURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        guard FileManager.default.fileExists(atPath: defaultAuthURL.path),
              let authData = try? Data(contentsOf: defaultAuthURL),
              let authString = String(data: authData, encoding: .utf8) else {
            return
        }
        
        if let active = activeAccount {
            let activeAuthURL = URL(fileURLWithPath: active.homeDirectoryPath).appendingPathComponent("auth.json")
            try? authData.write(to: activeAuthURL, options: .atomic)
            ClickyLogger.info("[ACCOUNT_POOL]", "Synchronized credentials from ~/.codex/auth.json to active account: \(active.label)")
        } else if accounts.isEmpty {
            autoImportDefaultCodexSession()
        }
    }

    private func autoImportDefaultCodexSession() {
        let defaultAuthURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        guard FileManager.default.fileExists(atPath: defaultAuthURL.path),
              let authData = try? Data(contentsOf: defaultAuthURL),
              let authString = String(data: authData, encoding: .utf8) else {
            return
        }
        
        do {
            _ = try registerAccount(label: "Account 1 (Primary)", authJsonString: authString)
        } catch {
            print("[ChatGPTAccountPoolManager] Failed to auto-import default codex session: \(error)")
        }
    }
    
    // MARK: - Public API
    
    /// Returns the active account's home directory to be injected as `CODEX_HOME`
    public func getActiveCodexHome() -> String? {
        syncDefaultCodexSession()
        if let active = activeAccount {
            let authPath = (active.homeDirectoryPath as NSString).appendingPathComponent("auth.json")
            if FileManager.default.fileExists(atPath: authPath) {
                return active.homeDirectoryPath
            }
        }
        return nil
    }
    
    /// Registers a new ChatGPT account session into the pool
    @discardableResult
    public func registerAccount(label: String, authJsonString: String) throws -> GPTAccount {
        let accountId = UUID()
        let accountDir = Self.baseStorageDirectory.appendingPathComponent("account_\(accountId.uuidString)", isDirectory: true)
        
        try FileManager.default.createDirectory(at: accountDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o700
        ])
        
        let authFileURL = accountDir.appendingPathComponent("auth.json")
        guard let authData = authJsonString.data(using: .utf8) else {
            throw NSError(domain: "ChatGPTAccountPoolManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid auth JSON string"])
        }
        try authData.write(to: authFileURL, options: .atomic)
        
        // Extract email if present
        var extractedEmail: String? = nil
        if let jsonObj = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
           let tokens = jsonObj["tokens"] as? [String: Any],
           let accountIdVal = tokens["account_id"] as? String {
            extractedEmail = accountIdVal
        }
        
        let isFirstAccount = accounts.isEmpty
        let newAccount = GPTAccount(
            id: accountId,
            label: label,
            email: extractedEmail,
            homeDirectoryPath: accountDir.path,
            status: isFirstAccount ? .active : .ready
        )
        
        accounts.append(newAccount)
        if isFirstAccount {
            activeAccountId = accountId
        }
        savePool()
        return newAccount
    }
    
    /// Switches to the next available `.ready` account instantly (<50ms)
    @discardableResult
    public func switchToNextReadyAccount() -> Bool {
        guard let nextIndex = accounts.firstIndex(where: { $0.status == .ready && $0.id != activeAccountId }) else {
            return false
        }
        
        // Downgrade old active if it was active
        if let currentActiveIndex = accounts.firstIndex(where: { $0.id == activeAccountId }) {
            if accounts[currentActiveIndex].status == .active {
                accounts[currentActiveIndex].status = .ready
            }
        }
        
        accounts[nextIndex].status = .active
        accounts[nextIndex].lastUsed = Date()
        activeAccountId = accounts[nextIndex].id
        savePool()
        return true
    }
    
    /// Marks the currently active account as in cooldown (rate limited) and hot-fails over
    public func markActiveAccountCooldown(durationSeconds: TimeInterval = 1800) {
        guard let activeIndex = accounts.firstIndex(where: { $0.id == activeAccountId }) else { return }
        let resetDate = Date().addingTimeInterval(durationSeconds)
        accounts[activeIndex].status = .cooldown(resetAt: resetDate)
        
        // Hot-failover to next available account
        if !switchToNextReadyAccount() {
            // No ready accounts remaining
            activeAccountId = nil
            savePool()
        }
    }
    
    /// Manually sets a specific account as active
    public func setAccountActive(id: UUID) {
        for i in accounts.indices {
            if accounts[i].id == id {
                accounts[i].status = .active
                accounts[i].lastUsed = Date()
                activeAccountId = id
            } else if accounts[i].status == .active {
                accounts[i].status = .ready
            }
        }
        savePool()
    }
    
    /// Removes an account from the pool and purges its stored credentials
    public func deleteAccount(id: UUID) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        let dirPath = accounts[index].homeDirectoryPath
        try? FileManager.default.removeItem(atPath: dirPath)
        
        accounts.remove(at: index)
        if activeAccountId == id {
            activeAccountId = nil
            switchToNextReadyAccount()
        }
        savePool()
    }
    
    /// Increments request count for the currently active account
    public func recordRequestSuccess() {
        guard let activeIndex = accounts.firstIndex(where: { $0.id == activeAccountId }) else { return }
        accounts[activeIndex].requestCount += 1
        accounts[activeIndex].lastUsed = Date()
        savePool()
    }
    
    // MARK: - Cooldown Watchdog
    
    private func startCooldownWatchdog() {
        cooldownTimer = Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateCooldownRecovery()
            }
    }
    
    private func evaluateCooldownRecovery() {
        let now = Date()
        var changed = false
        
        for i in accounts.indices {
            if case .cooldown(let resetAt) = accounts[i].status {
                if now >= resetAt {
                    accounts[i].status = .ready
                    changed = true
                }
            }
        }
        
        if changed {
            if activeAccountId == nil {
                switchToNextReadyAccount()
            }
            savePool()
        }
    }
}
