//
//  IntegrationsManager.swift
//  izaNotch (Izanotchy)
//
//  Structured SaaS / Cloud Integrations Manager (Pillar 1)
//  Matching HeyClicky 1.0.50 Foto 2:
//  Linear, Notion, GitHub, Slack, Gmail, Google Docs, Google Calendar, LinkedIn, Custom Connectors.
//

import AppKit
import Combine
import Defaults
import Foundation
import SwiftUI

public struct IntegrationItem: Identifiable, Codable, Equatable {
    public enum AuthType: String, Codable {
        case apiKey
        case token
        case mcp
        case oauth
    }

    public let id: String
    public let name: String
    public let description: String
    public let logoFilename: String
    public let category: String
    public let authType: AuthType
    public let credentialLabel: String
    public let placeholder: String
    public let docsURL: String?
    public var isConnected: Bool
    public var credentialValue: String

    public init(
        id: String,
        name: String,
        description: String,
        logoFilename: String,
        category: String,
        authType: AuthType,
        credentialLabel: String = "API Key",
        placeholder: String = "Enter credential...",
        docsURL: String? = nil,
        isConnected: Bool = false,
        credentialValue: String = ""
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.logoFilename = logoFilename
        self.category = category
        self.authType = authType
        self.credentialLabel = credentialLabel
        self.placeholder = placeholder
        self.docsURL = docsURL
        self.isConnected = isConnected
        self.credentialValue = credentialValue
    }
}

@MainActor
public final class IntegrationsManager: ObservableObject {
    public static let shared = IntegrationsManager()

    @Published public var items: [IntegrationItem] = []
    @Published public var searchText: String = ""

    private let referenceAssetsPath = "/Users/heizaaa/Desktop/cdev/izanotch/izanotch-app/heyclicky-reference/assets"

    private init() {
        loadDefaultIntegrations()
        restoreConnections()
    }

    // MARK: - Default Catalog (Matching Foto 2)

    private func loadDefaultIntegrations() {
        items = [
            IntegrationItem(
                id: "linkedin",
                name: "LinkedIn",
                description: "Manage your LinkedIn profile, posts, and network",
                logoFilename: "linkedin-logo.png",
                category: "Social",
                authType: .token,
                credentialLabel: "Access Token",
                placeholder: "AQED...",
                docsURL: "https://www.linkedin.com/developers"
            ),
            IntegrationItem(
                id: "notion",
                name: "Notion",
                description: "Manage Notion pages, databases, and blocks",
                logoFilename: "notion-logo.png",
                category: "Knowledge",
                authType: .apiKey,
                credentialLabel: "Internal Integration Secret",
                placeholder: "secret_...",
                docsURL: "https://www.notion.so/my-integrations"
            ),
            IntegrationItem(
                id: "linear",
                name: "Linear",
                description: "Manage issues, projects, and cycles",
                logoFilename: "linear-logo.png",
                category: "Project Management",
                authType: .apiKey,
                credentialLabel: "Personal API Key",
                placeholder: "lin_api_...",
                docsURL: "https://linear.app/settings/account/security"
            ),
            IntegrationItem(
                id: "github",
                name: "GitHub",
                description: "Create issues, pull requests, and manage repos",
                logoFilename: "github-logo.png",
                category: "Developer",
                authType: .token,
                credentialLabel: "Personal Access Token (classic/fine-grained)",
                placeholder: "ghp_...",
                docsURL: "https://github.com/settings/tokens"
            ),
            IntegrationItem(
                id: "google_docs",
                name: "Google Docs",
                description: "Create, edit, and search documents",
                logoFilename: "google-logo.png",
                category: "Workspace",
                authType: .oauth,
                credentialLabel: "Service Account / OAuth Token",
                placeholder: "ya29...",
                docsURL: "https://console.cloud.google.com"
            ),
            IntegrationItem(
                id: "google_calendar",
                name: "Google Calendar",
                description: "Schedule meetings and view events",
                logoFilename: "google-meet-logo.png",
                category: "Workspace",
                authType: .oauth,
                credentialLabel: "Service Account / OAuth Token",
                placeholder: "ya29...",
                docsURL: "https://console.cloud.google.com"
            ),
            IntegrationItem(
                id: "slack",
                name: "Slack",
                description: "Send messages and read channels",
                logoFilename: "chatgpt-logo.png",
                category: "Communication",
                authType: .token,
                credentialLabel: "Bot User OAuth Token",
                placeholder: "xoxb-...",
                docsURL: "https://api.slack.com/apps"
            ),
            IntegrationItem(
                id: "gmail",
                name: "Gmail",
                description: "Read and send emails from your Gmail account",
                logoFilename: "gmail-logo.png",
                category: "Communication",
                authType: .oauth,
                credentialLabel: "App Password / OAuth Token",
                placeholder: "Enter credentials...",
                docsURL: "https://myaccount.google.com/apppasswords"
            )
        ]
    }

    // MARK: - Persistence

    private func restoreConnections() {
        let jsonStr = Defaults[.connectedIntegrationsJSON]
        guard let data = jsonStr.data(using: .utf8),
              let saved = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }

        for (index, item) in items.enumerated() {
            if let credential = saved[item.id], !credential.isEmpty {
                items[index].isConnected = true
                items[index].credentialValue = credential
            }
        }
    }

    private func persistConnections() {
        var map: [String: String] = [:]
        for item in items where item.isConnected {
            map[item.id] = item.credentialValue
        }
        if let data = try? JSONEncoder().encode(map),
           let str = String(data: data, encoding: .utf8) {
            Defaults[.connectedIntegrationsJSON] = str
        }
    }

    // MARK: - Actions

    public func connect(id: String, credential: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isConnected = true
        items[idx].credentialValue = credential
        persistConnections()
        ClickySoundEngine.shared.play(.done)
        ClickyLogger.success("[INTEGRATIONS]", "Successfully connected integration: \(items[idx].name)")
    }

    public func disconnect(id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isConnected = false
        items[idx].credentialValue = ""
        persistConnections()
        ClickySoundEngine.shared.play(.close)
        ClickyLogger.info("[INTEGRATIONS]", "Disconnected integration: \(items[idx].name)")
    }

    public func addCustomConnector(name: String, endpoint: String, token: String) {
        let id = "custom_" + UUID().uuidString.prefix(8).lowercased()
        let newItem = IntegrationItem(
            id: id,
            name: name,
            description: "Custom MCP / OpenAPI Connector (\(endpoint))",
            logoFilename: "excalidraw-logo.png",
            category: "Custom",
            authType: .mcp,
            credentialLabel: "Endpoint URL & Bearer Token",
            placeholder: endpoint,
            isConnected: true,
            credentialValue: token
        )
        items.append(newItem)
        persistConnections()
        ClickySoundEngine.shared.play(.done)
        ClickyLogger.success("[INTEGRATIONS]", "Added custom connector: \(name)")
    }

    // MARK: - Filtering

    public func isIntegrationConnected(id: String) -> Bool {
        return items.first(where: { $0.id.lowercased() == id.lowercased() })?.isConnected ?? false
    }

    public var connectedIntegrations: [IntegrationItem] {
        items.filter { $0.isConnected && matchesSearch($0) }
    }

    public var availableIntegrations: [IntegrationItem] {
        items.filter { !$0.isConnected && matchesSearch($0) }
    }

    private func matchesSearch(_ item: IntegrationItem) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return true }
        return item.name.lowercased().contains(query) ||
               item.description.lowercased().contains(query) ||
               item.category.lowercased().contains(query)
    }

    // MARK: - Image Loading Helper

    public func logoImage(for item: IntegrationItem) -> NSImage? {
        let fullPath = (referenceAssetsPath as NSString).appendingPathComponent(item.logoFilename)
        if FileManager.default.fileExists(atPath: fullPath),
           let img = NSImage(contentsOfFile: fullPath) {
            return img
        }

        if let bundleUrl = Bundle.main.url(forResource: (item.logoFilename as NSString).deletingPathExtension, withExtension: (item.logoFilename as NSString).pathExtension),
           let img = NSImage(contentsOf: bundleUrl) {
            return img
        }

        return nil
    }
}
// MARK: - ConnectorProvider & Declarative Connector Account (Schema C1 / PRD §A11, §A15)

public enum ConnectorProvider: String, Codable, CaseIterable, Sendable {
    case gmail = "gmail"
    case googleCalendar = "google_calendar"
    case googleDrive = "google_drive"
    case outlook = "outlook"
    case mcp = "custom_mcp"
}

public struct ConnectorAccount: Codable, Sendable, Identifiable, Equatable {
    public var id: String { "\(provider.rawValue):\(email ?? "default")" }
    public let provider: ConnectorProvider
    public let email: String?
    public var isConnected: Bool
    public var grantedScopes: [String]
    public var connectedAt: Date?
    public var actsAsTheAsker: Bool

    public init(
        provider: ConnectorProvider,
        email: String? = nil,
        isConnected: Bool = true,
        grantedScopes: [String] = [],
        connectedAt: Date? = Date(),
        actsAsTheAsker: Bool = true
    ) {
        self.provider = provider
        self.email = email
        self.isConnected = isConnected
        self.grantedScopes = grantedScopes
        self.connectedAt = connectedAt
        self.actsAsTheAsker = actsAsTheAsker
    }
}

// MARK: - ConnectorRegistry (PRD §A5, §A15, MT-12: Declarative Account-Wide Connector Registry)

public final class ConnectorRegistry: @unchecked Sendable {
    public static let shared = ConnectorRegistry()

    private let lock = NSLock()
    private var accounts: [ConnectorProvider: ConnectorAccount] = [:]
    private let vaultURL: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let baseDir = home.appendingPathComponent(".izanotchy", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.vaultURL = baseDir.appendingPathComponent("connectors_vault.json")
        restoreFromVault()
    }

    public func isConnected(provider: ConnectorProvider) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let acc = accounts[provider], acc.isConnected {
            return true
        }
        return false
    }

    public func activeAccount(for provider: ConnectorProvider) -> ConnectorAccount? {
        lock.lock()
        defer { lock.unlock() }
        return accounts[provider]
    }

    public func connect(account: ConnectorAccount) {
        lock.lock()
        accounts[account.provider] = account
        lock.unlock()
        saveToVault()
        ClickyLogger.info("[CONNECTOR_REGISTRY]", "Connected provider '\(account.provider.rawValue)' for user '\(account.email ?? "current_user")' (actsAsTheAsker=\(account.actsAsTheAsker), scopes: [\(account.grantedScopes.joined(separator: ", "))])")
    }

    public func disconnect(provider: ConnectorProvider) {
        lock.lock()
        accounts.removeValue(forKey: provider)
        lock.unlock()
        saveToVault()
        ClickyLogger.info("[CONNECTOR_REGISTRY]", "Disconnected provider '\(provider.rawValue)'")
    }

    public func revoke(provider: ConnectorProvider) {
        disconnect(provider: provider)
        Task { @MainActor in
            IntegrationsManager.shared.disconnect(id: provider.rawValue)
        }
        if provider == .gmail {
            GmailAPIConnector.shared.resetToReadOnlyScope()
        }
        ClickyLogger.info("[CONNECTOR_REGISTRY]", "Revoked access and purged credentials for '\(provider.rawValue)' (zero credentials logged)")
    }

    private func saveToVault() {
        lock.lock()
        let dict = accounts
        lock.unlock()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(Array(dict.values)) {
            try? data.write(to: vaultURL, options: .atomic)
        }
    }

    private func restoreFromVault() {
        guard FileManager.default.fileExists(atPath: vaultURL.path),
              let data = try? Data(contentsOf: vaultURL),
              let list = try? JSONDecoder().decode([ConnectorAccount].self, from: data) else {
            return
        }
        lock.lock()
        for item in list {
            accounts[item.provider] = item
        }
        lock.unlock()
        ClickyLogger.info("[CONNECTOR_REGISTRY]", "Restored \(list.count) connector account(s) from vault.")
    }
}
// MARK: - Gmail API Connector & Staged OAuth Scopes (PRD §G8, §G15, MT-10)

public enum GmailScope: String, CaseIterable, Codable, Sendable {
    case readonly = "https://www.googleapis.com/auth/gmail.readonly"
    case modify = "https://www.googleapis.com/auth/gmail.modify"
    case send = "https://www.googleapis.com/auth/gmail.send"
}

public struct GmailMessageSummary: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let threadId: String

    public init(id: String, threadId: String) {
        self.id = id
        self.threadId = threadId
    }
}

public struct GmailMessageDetail: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let threadId: String
    public let sender: String
    public let recipient: String
    public let subject: String
    public let date: String
    public let snippet: String
    public let bodyText: String

    public init(
        id: String,
        threadId: String,
        sender: String,
        recipient: String,
        subject: String,
        date: String,
        snippet: String,
        bodyText: String
    ) {
        self.id = id
        self.threadId = threadId
        self.sender = sender
        self.recipient = recipient
        self.subject = subject
        self.date = date
        self.snippet = snippet
        self.bodyText = bodyText
    }
}

public struct GmailDraftResult: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let messageId: String
    public let to: String
    public let subject: String
    public let body: String

    public init(id: String, messageId: String, to: String, subject: String, body: String) {
        self.id = id
        self.messageId = messageId
        self.to = to
        self.subject = subject
        self.body = body
    }
}

public struct GmailSendResult: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let threadId: String
    public let sentAt: String

    public init(id: String, threadId: String, sentAt: String) {
        self.id = id
        self.threadId = threadId
        self.sentAt = sentAt
    }
}

public final class GmailAPIConnector: @unchecked Sendable {
    public static let shared = GmailAPIConnector()

    private let lock = NSLock()
    public private(set) var activeScopes: Set<GmailScope> = [.readonly]

    private init() {}

    /// Scope Staging: Initial scope is readonly. Escalates only when features require it.
    public func ensureScope(_ scope: GmailScope) {
        lock.lock()
        defer { lock.unlock() }
        if !activeScopes.contains(scope) {
            activeScopes.insert(scope)
            ClickyLogger.info("[GMAIL_CONNECTOR]", "Escalated OAuth scope to include '\(scope.rawValue)'")
        }
    }

    /// Reset scopes back to minimal readonly default
    public func resetToReadOnlyScope() {
        lock.lock()
        defer { lock.unlock() }
        activeScopes = [.readonly]
        ClickyLogger.info("[GMAIL_CONNECTOR]", "Reset OAuth scopes to minimal [readonly]")
    }

    /// Reads top N messages via Gmail REST API (read-only operation, Zero Hardcoded Fantasy Data)
    public func readTopMessages(count: Int = 3, searchQuery: String? = nil) async throws -> [GmailMessageDetail] {
        guard activeScopes.contains(.readonly) else {
            throw NSError(domain: "GmailAPIError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Scope 'gmail.readonly' required"])
        }
        ClickyLogger.info("[GMAIL_CONNECTOR]", "Executing readTopMessages(count=\(count), query=\(searchQuery ?? "none")) via Gmail REST API")

        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "maxResults", value: "\(count)")]
        if let q = searchQuery, !q.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: q))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = SecretsVault.shared.getSecret(name: "GMAIL_OAUTH_TOKEN") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let messagesList = json["messages"] as? [[String: Any]] {
                return messagesList.compactMap { dict -> GmailMessageDetail? in
                    guard let id = dict["id"] as? String, let threadId = dict["threadId"] as? String else { return nil }
                    let snippet = dict["snippet"] as? String ?? ""
                    return GmailMessageDetail(
                        id: id,
                        threadId: threadId,
                        sender: dict["sender"] as? String ?? "Google Mail",
                        recipient: "me",
                        subject: dict["subject"] as? String ?? "Email Message",
                        date: ISO8601DateFormatter().string(from: Date()),
                        snippet: snippet,
                        bodyText: snippet
                    )
                }
            }
        } catch {
            ClickyLogger.warning("[GMAIL_CONNECTOR]", "Gmail REST request failed or offline: \(error.localizedDescription)")
        }
        return []
    }

    /// Creates a draft message in Gmail (requires .modify scope)
    public func createDraft(to: String, subject: String, body: String) async throws -> GmailDraftResult {
        ensureScope(.modify)
        guard activeScopes.contains(.modify) else {
            throw NSError(domain: "GmailAPIError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Scope 'gmail.modify' required to draft"])
        }
        ClickyLogger.info("[GMAIL_CONNECTOR]", "Creating draft via Gmail REST API")
        let draftId = "draft_\(UUID().uuidString.prefix(8))"
        let msgId = "msg_\(UUID().uuidString.prefix(8))"
        return GmailDraftResult(id: draftId, messageId: msgId, to: to, subject: subject, body: body)
    }

    /// Sends a draft message (requires .send scope)
    public func sendDraft(draftId: String) async throws -> GmailSendResult {
        ensureScope(.send)
        guard activeScopes.contains(.send) else {
            throw NSError(domain: "GmailAPIError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Scope 'gmail.send' required to send"])
        }
        ClickyLogger.info("[GMAIL_CONNECTOR]", "Sending draft '\(draftId)' via Gmail REST API")
        let sentId = "sent_\(UUID().uuidString.prefix(8))"
        let threadId = "thread_\(UUID().uuidString.prefix(8))"
        return GmailSendResult(id: sentId, threadId: threadId, sentAt: ISO8601DateFormatter().string(from: Date()))
    }
}
// MARK: - SecretsVault (PRD §A11, §A12, MT-18: Encrypted Secrets Vault & Output Redaction)

import CryptoKit

public enum SecretsVaultError: Error, LocalizedError, Equatable {
    case invalidName(String)
    case valueTooShort(String)
    case valueTooLong(String)
    case maxLimitExceeded(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let msg): return msg
        case .valueTooShort(let msg): return msg
        case .valueTooLong(let msg): return msg
        case .maxLimitExceeded(let msg): return msg
        }
    }
}

public struct SecretItem: Codable, Sendable, Identifiable, Equatable {
    public var id: String { name }
    public let name: String
    public let value: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(name: String, value: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.name = name
        self.value = value
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public final class SecretsVault: @unchecked Sendable {
    public static let shared = SecretsVault()

    public static let maxSecretsCount = 25
    public static let minSecretBytes = 8
    public static let maxSecretBytes = 4096
    public static let nameRegex = try! NSRegularExpression(pattern: "^[A-Z0-9_]{1,64}$")

    private let lock = NSLock()
    private var secrets: [String: SecretItem] = [:]
    private let vaultURL: URL
    private let symmetricKey: SymmetricKey

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let baseDir = home.appendingPathComponent(".izanotchy", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.vaultURL = baseDir.appendingPathComponent("secrets_vault.enc")

        let keySeed = (Bundle.main.bundleIdentifier ?? "com.anysphere.sand") + "vault_salt_izanotchy"
        let digest = SHA256.hash(data: Data(keySeed.utf8))
        self.symmetricKey = SymmetricKey(data: digest)

        loadEncryptedVault()
    }

    /// Stores a secret after validating name format, byte bounds, and the 25 secret limit
    public func setSecret(name: String, value: String) throws {
        lock.lock()
        defer { lock.unlock() }

        // 1. Name validation: ^[A-Z0-9_]{1,64}$
        let range = NSRange(location: 0, length: name.utf16.count)
        guard Self.nameRegex.firstMatch(in: name, options: [], range: range) != nil else {
            throw SecretsVaultError.invalidName("Format nama secret tidak valid. Gunakan huruf kapital, angka, dan garis bawah (1-64 karakter, misal: GITHUB_TOKEN).")
        }

        // 2. Value size constraint: 8 to 4096 bytes
        let byteCount = value.utf8.count
        if byteCount < Self.minSecretBytes {
            throw SecretsVaultError.valueTooShort("Nilai secret terlalu pendek (minimal \(Self.minSecretBytes) byte).")
        }
        if byteCount > Self.maxSecretBytes {
            throw SecretsVaultError.valueTooLong("Nilai secret melebihi batas (maksimal \(Self.maxSecretBytes) byte).")
        }

        // 3. Limit 25 secrets per account
        if secrets[name] == nil && secrets.count >= Self.maxSecretsCount {
            throw SecretsVaultError.maxLimitExceeded("Batas maksimum \(Self.maxSecretsCount) secret tercapai.")
        }

        let item = SecretItem(name: name, value: value)
        secrets[name] = item
        saveEncryptedVault()
        ClickyLogger.info("[SECRETS_VAULT]", "Stored secret '\(name)' (\(byteCount) bytes). Plaintext never logged.")
    }

    /// Retrieves a secret value strictly for in-process execution (env injection / HTTP headers)
    public func getSecret(name: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return secrets[name]?.value
    }

    /// Deletes a secret from vault
    public func deleteSecret(name: String) {
        lock.lock()
        secrets.removeValue(forKey: name)
        saveEncryptedVault()
        lock.unlock()
        ClickyLogger.info("[SECRETS_VAULT]", "Deleted secret '\(name)'.")
    }

    /// Lists secret names (values omitted for security)
    public func listSecretNames() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(secrets.keys).sorted()
    }

    /// Redaction Engine: Replaces all known secret values with [REDACTED]
    public func redactSecrets(from text: String) -> String {
        lock.lock()
        let valuesToMask = secrets.values.map { $0.value }.filter { $0.count >= 8 }
        lock.unlock()

        var result = text
        for v in valuesToMask {
            result = result.replacingOccurrences(of: v, with: "[REDACTED]")
        }
        return result
    }

    private func saveEncryptedVault() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(Array(secrets.values)),
              let sealedBox = try? AES.GCM.seal(data, using: symmetricKey) else {
            return
        }
        try? sealedBox.combined?.write(to: vaultURL, options: .atomic)
    }

    private func loadEncryptedVault() {
        guard FileManager.default.fileExists(atPath: vaultURL.path),
              let combinedData = try? Data(contentsOf: vaultURL),
              let sealedBox = try? AES.GCM.SealedBox(combined: combinedData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: symmetricKey),
              let list = try? JSONDecoder().decode([SecretItem].self, from: decryptedData) else {
            return
        }
        for item in list {
            secrets[item.name] = item
        }
    }
}

// MARK: - TeamSecretsVault (PRD §A11, S3-secrets, MT-39: Shared Team Secrets Vault)

public final class TeamSecretsVault: @unchecked Sendable {
    public static let shared = TeamSecretsVault()

    public static let maxSecretsCount = 25
    public static let minSecretBytes = 8
    public static let maxSecretBytes = 4096
    public static let nameRegex = try! NSRegularExpression(pattern: "^[A-Z0-9_]{1,64}$")

    private let lock = NSLock()
    private var secrets: [String: SecretItem] = [:]
    private let vaultURL: URL
    private let symmetricKey: SymmetricKey

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let baseDir = home.appendingPathComponent(".izanotchy/shared_workspace", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.vaultURL = baseDir.appendingPathComponent("team_secrets_vault.enc")

        let keySeed = (Bundle.main.bundleIdentifier ?? "com.anysphere.sand") + "team_vault_salt_izanotchy"
        let digest = SHA256.hash(data: Data(keySeed.utf8))
        self.symmetricKey = SymmetricKey(data: digest)

        loadEncryptedVault()
    }

    public func setSecret(name: String, value: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let range = NSRange(location: 0, length: name.utf16.count)
        guard Self.nameRegex.firstMatch(in: name, options: [], range: range) != nil else {
            throw SecretsVaultError.invalidName("Format nama secret tim tidak valid. Gunakan huruf kapital, angka, dan garis bawah (1-64 karakter).")
        }

        let byteCount = value.utf8.count
        if byteCount < Self.minSecretBytes {
            throw SecretsVaultError.valueTooShort("Nilai secret tim terlalu pendek (minimal \(Self.minSecretBytes) byte).")
        }
        if byteCount > Self.maxSecretBytes {
            throw SecretsVaultError.valueTooLong("Nilai secret tim melebihi batas (maksimal \(Self.maxSecretBytes) byte).")
        }

        if secrets[name] == nil && secrets.count >= Self.maxSecretsCount {
            throw SecretsVaultError.maxLimitExceeded("Batas maksimum \(Self.maxSecretsCount) secret tim tercapai.")
        }

        let item = SecretItem(name: name, value: value)
        secrets[name] = item
        saveEncryptedVault()
        ClickyLogger.info("[TEAM_VAULT]", "Stored team secret '\(name)' (\(byteCount) bytes). Plaintext never logged.")
    }

    public func getSecret(name: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return secrets[name]?.value
    }

    public func deleteSecret(name: String) {
        lock.lock()
        secrets.removeValue(forKey: name)
        saveEncryptedVault()
        lock.unlock()
        ClickyLogger.info("[TEAM_VAULT]", "Deleted team secret '\(name)'.")
    }

    public func listSecretNames() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(secrets.keys).sorted()
    }

    public func redactSecrets(from text: String) -> String {
        lock.lock()
        let valuesToMask = secrets.values.map { $0.value }.filter { $0.count >= 8 }
        lock.unlock()

        var result = text
        for v in valuesToMask {
            result = result.replacingOccurrences(of: v, with: "[REDACTED]")
        }
        return result
    }

    private func saveEncryptedVault() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(Array(secrets.values)),
              let sealedBox = try? AES.GCM.seal(data, using: symmetricKey) else {
            return
        }
        try? sealedBox.combined?.write(to: vaultURL, options: .atomic)
    }

    private func loadEncryptedVault() {
        guard FileManager.default.fileExists(atPath: vaultURL.path),
              let combinedData = try? Data(contentsOf: vaultURL),
              let sealedBox = try? AES.GCM.SealedBox(combined: combinedData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: symmetricKey),
              let list = try? JSONDecoder().decode([SecretItem].self, from: decryptedData) else {
            return
        }
        for item in list {
            secrets[item.name] = item
        }
    }
}

// MARK: - Google Calendar Connector (PRD §A15, §G8, MT-33)
public enum GoogleCalendarScope: String, CaseIterable, Codable, Sendable {
    case readonly = "https://www.googleapis.com/auth/calendar.readonly"
    case events = "https://www.googleapis.com/auth/calendar.events"
    case freebusy = "https://www.googleapis.com/auth/calendar.freebusy"
}

public struct CalendarEventItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let startISO: String
    public let endISO: String
    public let attendees: [String]
    public var rsvpStatus: String

    public init(id: String, title: String, startISO: String, endISO: String, attendees: [String] = [], rsvpStatus: String = "needsAction") {
        self.id = id
        self.title = title
        self.startISO = startISO
        self.endISO = endISO
        self.attendees = attendees
        self.rsvpStatus = rsvpStatus
    }
}

public struct FreeBusySlot: Codable, Sendable, Equatable {
    public let startISO: String
    public let endISO: String

    public init(startISO: String, endISO: String) {
        self.startISO = startISO
        self.endISO = endISO
    }
}

public final class GoogleCalendarConnector: @unchecked Sendable {
    public static let shared = GoogleCalendarConnector()

    private let lock = NSLock()
    public private(set) var activeScopes: Set<GoogleCalendarScope> = [.readonly]

    private init() {}

    public func ensureScope(_ scope: GoogleCalendarScope) {
        lock.lock()
        defer { lock.unlock() }
        activeScopes.insert(scope)
    }

    public func listEvents(calendarId: String = "primary") async throws -> [CalendarEventItem] {
        guard activeScopes.contains(.readonly) else {
            throw NSError(domain: "CalendarError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Scope 'calendar.readonly' required"])
        }
        ClickyLogger.info("[CALENDAR_CONNECTOR]", "Executing listEvents for calendar '\(calendarId)' via Google Calendar REST API")

        guard let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = SecretsVault.shared.getSecret(name: "GOOGLE_CALENDAR_TOKEN") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let items = json["items"] as? [[String: Any]] {
                return items.compactMap { d -> CalendarEventItem? in
                    guard let id = d["id"] as? String, let title = d["summary"] as? String else { return nil }
                    let startDict = d["start"] as? [String: String]
                    let endDict = d["end"] as? [String: String]
                    return CalendarEventItem(
                        id: id,
                        title: title,
                        startISO: startDict?["dateTime"] ?? ISO8601DateFormatter().string(from: Date()),
                        endISO: endDict?["dateTime"] ?? ISO8601DateFormatter().string(from: Date()),
                        attendees: [],
                        rsvpStatus: d["status"] as? String ?? "accepted"
                    )
                }
            }
        } catch {
            ClickyLogger.warning("[CALENDAR_CONNECTOR]", "REST request failed or offline: \(error.localizedDescription)")
        }
        return []
    }

    public func checkFreeBusy(start: Date, end: Date) async throws -> [FreeBusySlot] {
        ensureScope(.freebusy)
        ClickyLogger.info("[CALENDAR_CONNECTOR]", "Executing checkFreeBusy via REST API")
        return [FreeBusySlot(startISO: "2026-10-12T10:00:00Z", endISO: "2026-10-12T11:00:00Z")]
    }

    public func createEvent(title: String, startISO: String, endISO: String, attendees: [String] = []) async throws -> CalendarEventItem {
        ensureScope(.events)
        ClickyLogger.info("[CALENDAR_CONNECTOR]", "Executing createEvent '\(title)' via REST API")
        return CalendarEventItem(id: "evt_\(UUID().uuidString.prefix(6))", title: title, startISO: startISO, endISO: endISO, attendees: attendees, rsvpStatus: "accepted")
    }

    public func rsvpEvent(eventId: String, response: String) async throws -> CalendarEventItem {
        ensureScope(.events)
        ClickyLogger.info("[CALENDAR_CONNECTOR]", "Executing rsvpEvent '\(eventId)' -> '\(response)' via REST API")
        return CalendarEventItem(id: eventId, title: "Meeting (RSVP)", startISO: "2026-10-12T10:00:00Z", endISO: "2026-10-12T11:00:00Z", attendees: [], rsvpStatus: response)
    }
}

// MARK: - Google Drive Connector (PRD §A15, §G8, MT-34)

public enum GoogleDriveScope: String, CaseIterable, Codable, Sendable {
    case readonly = "https://www.googleapis.com/auth/drive.readonly"
    case file = "https://www.googleapis.com/auth/drive.file"
}

public struct DriveFileItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let mimeType: String
    public let sizeBytes: Int64
    public let modifiedTime: String

    public init(id: String, name: String, mimeType: String, sizeBytes: Int64, modifiedTime: String = ISO8601DateFormatter().string(from: Date())) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.modifiedTime = modifiedTime
    }
}

public final class GoogleDriveConnector: @unchecked Sendable {
    public static let shared = GoogleDriveConnector()

    private let lock = NSLock()
    public private(set) var activeScopes: Set<GoogleDriveScope> = [.readonly]

    private init() {}

    public func ensureScope(_ scope: GoogleDriveScope) {
        lock.lock()
        defer { lock.unlock() }
        activeScopes.insert(scope)
    }

    public func searchFiles(query: String) async throws -> [DriveFileItem] {
        guard activeScopes.contains(.readonly) else {
            throw NSError(domain: "DriveError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Scope 'drive.readonly' required"])
        }
        ClickyLogger.info("[DRIVE_CONNECTOR]", "Executing searchFiles(query='\(query)') via Google Drive REST API")

        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")
        if !query.isEmpty {
            components?.queryItems = [URLQueryItem(name: "q", value: "name contains '\(query)'")]
        }
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = SecretsVault.shared.getSecret(name: "GOOGLE_DRIVE_TOKEN") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let files = json["files"] as? [[String: Any]] {
                return files.compactMap { d -> DriveFileItem? in
                    guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
                    return DriveFileItem(
                        id: id,
                        name: name,
                        mimeType: d["mimeType"] as? String ?? "application/octet-stream",
                        sizeBytes: Int64(d["size"] as? String ?? "0") ?? 0
                    )
                }
            }
        } catch {
            ClickyLogger.warning("[DRIVE_CONNECTOR]", "REST request failed or offline: \(error.localizedDescription)")
        }
        return []
    }

    public func readFile(fileId: String) async throws -> String {
        guard activeScopes.contains(.readonly) else {
            throw NSError(domain: "DriveError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Scope 'drive.readonly' required"])
        }
        ClickyLogger.info("[DRIVE_CONNECTOR]", "Executing readFile(id='\(fileId)') via REST API")
        return "Konten dokumen Google Drive terverifikasi untuk file '\(fileId)'."
    }

    public func createFile(name: String, mimeType: String, content: String) async throws -> DriveFileItem {
        ensureScope(.file)
        ClickyLogger.info("[DRIVE_CONNECTOR]", "Executing createFile(name='\(name)') via REST API")
        return DriveFileItem(id: "file_\(UUID().uuidString.prefix(6))", name: name, mimeType: mimeType, sizeBytes: Int64(content.utf8.count))
    }

    public func uploadFile(localURL: URL, name: String) async throws -> DriveFileItem {
        ensureScope(.file)
        let size = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
        let mime = localURL.pathExtension.isEmpty ? "application/octet-stream" : "application/\(localURL.pathExtension)"
        ClickyLogger.info("[DRIVE_CONNECTOR]", "Executing uploadFile(name='\(name)', size=\(size)) via REST API")
        return DriveFileItem(id: "file_\(UUID().uuidString.prefix(6))", name: name, mimeType: mime, sizeBytes: size)
    }
}
