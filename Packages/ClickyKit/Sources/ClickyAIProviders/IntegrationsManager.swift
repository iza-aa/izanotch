import ClickyFoundation
//
//  IntegrationsManager.swift
//  boringNotch (Izanotchy)
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
    public static var soundEffectHandler: ((_ effect: String) -> Void)?

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
        Self.soundEffectHandler?("done")
        ClickyLogger.success("[INTEGRATIONS]", "Successfully connected integration: \(items[idx].name)")
    }

    public func disconnect(id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isConnected = false
        items[idx].credentialValue = ""
        persistConnections()
        Self.soundEffectHandler?("close")
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
        Self.soundEffectHandler?("done")
        ClickyLogger.success("[INTEGRATIONS]", "Added custom connector: \(name)")
    }

    // MARK: - Filtering

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
