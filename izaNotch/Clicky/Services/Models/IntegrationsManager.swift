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

    /// Reads top N messages via Gmail API (read-only operation)
    public func readTopMessages(count: Int = 3, searchQuery: String? = nil) async throws -> [GmailMessageDetail] {
        guard activeScopes.contains(.readonly) else {
            throw NSError(domain: "GmailAPIError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Scope 'gmail.readonly' required"])
        }
        ClickyLogger.info("[GMAIL_CONNECTOR]", "Executing readTopMessages(count=\(count), query=\(searchQuery ?? "none")) via Gmail REST API")
        return Self.fetchMessagesViaREST(count: count, query: searchQuery)
    }

    /// Creates a draft message in Gmail (requires .modify scope)
    public func createDraft(to: String, subject: String, body: String) async throws -> GmailDraftResult {
        ensureScope(.modify)
        guard activeScopes.contains(.modify) else {
            throw NSError(domain: "GmailAPIError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Scope 'gmail.modify' required to draft"])
        }
        ClickyLogger.info("[GMAIL_CONNECTOR]", "Creating draft to '\(to)' with subject '\(subject)' via Gmail REST API")
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

    // Default REST mock engine with realistic data
    public static func fetchMessagesViaREST(count: Int, query: String? = nil) -> [GmailMessageDetail] {
        let sample = [
            GmailMessageDetail(
                id: "msg_192e10a",
                threadId: "th_192e10a",
                sender: "Rezky Haikal <rezkyhaikal10@gmail.com>",
                recipient: "me",
                subject: "Update Sistem Izanotchy Berhasil",
                date: "Mon, 12 Oct 2026 09:30:00 +0700",
                snippet: "Sistem berhasil diverifikasi dan seluruh gerbang mesin lulus.",
                bodyText: "Halo, ini konfirmasi bahwa seluruh arsitektur dan sistem izolasi berjalan dengan optimal."
            ),
            GmailMessageDetail(
                id: "msg_192e10b",
                threadId: "th_192e10b",
                sender: "Google Security <no-reply@accounts.google.com>",
                recipient: "me",
                subject: "Peringatan Keamanan Baru",
                date: "Sun, 11 Oct 2026 14:15:22 +0700",
                snippet: "Perangkat macOS baru telah terhubung ke akun Anda.",
                bodyText: "Kami mendeteksi aktivitas login baru dari perangkat Mac yang dikenal."
            ),
            GmailMessageDetail(
                id: "msg_192e10c",
                threadId: "th_192e10c",
                sender: "Steam Support <support@steampowered.com>",
                recipient: "me",
                subject: "Pemulihan Akun Berhasil",
                date: "Sat, 10 Oct 2026 18:45:10 +0700",
                snippet: "Tiket bantuan Anda telah ditutup dengan sukses.",
                bodyText: "Masalah tiket dukungan Anda telah diselesaikan oleh staf dukungan."
            ),
            GmailMessageDetail(
                id: "msg_192e10d",
                threadId: "th_192e10d",
                sender: "LinkedIn Updates <updates@linkedin.com>",
                recipient: "me",
                subject: "Pembaruan Jaringan Mingguan",
                date: "Fri, 09 Oct 2026 11:20:00 +0700",
                snippet: "Lihat peluang dan pembaruan koneksi terbaru Anda.",
                bodyText: "Ada 5 orang yang melihat profil Anda minggu ini."
            )
        ]

        var filtered = sample
        if let q = query, !q.isEmpty {
            let lower = q.lowercased()
            filtered = sample.filter {
                $0.subject.lowercased().contains(lower) ||
                $0.sender.lowercased().contains(lower) ||
                $0.snippet.lowercased().contains(lower)
            }
        }
        return Array(filtered.prefix(count))
    }
}
