//
//  CompanionProfile.swift
//  izaNotch
//
//  Created for Izanotchy - Multi-Agent Desktop System
//

import SwiftUI
import ClickyFoundation

public enum CompanionStatus: String, Codable, CaseIterable {
    case idle = "Idle"
    case working = "Working"
    case done = "Done"
    
    public var dotColor: Color {
        switch self {
        case .idle: return Color.gray.opacity(0.7)
        case .working: return Color.blue
        case .done: return Color.green
        }
    }
}

// MARK: - Harmonious Color Themes (12 Curated Presets)
public struct CompanionColorTheme: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let cloudColorHex: String
    public let ringColorHex: String

    public var cloudColor: Color { Color(hex: cloudColorHex) }
    public var ringColor: Color { Color(hex: ringColorHex) }

    public init(id: String, name: String, cloudColorHex: String, ringColorHex: String) {
        self.id = id
        self.name = name
        self.cloudColorHex = cloudColorHex
        self.ringColorHex = ringColorHex
    }
}

extension CompanionColorTheme {
    public static let allThemes: [CompanionColorTheme] = [
        CompanionColorTheme(id: "pure-gold", name: "Imperial Gold", cloudColorHex: "#FF9800", ringColorHex: "#FFE082"),
        CompanionColorTheme(id: "cyan-green", name: "Cyan Green", cloudColorHex: "#03BDA7", ringColorHex: "#A7F3D0"),
        CompanionColorTheme(id: "vibrant-purple", name: "Vibrant Purple", cloudColorHex: "#905AFD", ringColorHex: "#E9D5FF"),
        CompanionColorTheme(id: "crimson-red", name: "Crimson Red", cloudColorHex: "#FF233B", ringColorHex: "#FECDD3"),
        CompanionColorTheme(id: "sky-breeze", name: "Vivid Sky", cloudColorHex: "#0EA5E9", ringColorHex: "#BAE6FD"),
        CompanionColorTheme(id: "matcha-lime", name: "Vibrant Lime", cloudColorHex: "#84CC16", ringColorHex: "#D9F99D"),
        CompanionColorTheme(id: "electric-pink", name: "Electric Pink", cloudColorHex: "#EC4899", ringColorHex: "#FBCFE8"),
        CompanionColorTheme(id: "warm-tangerine", name: "Deep Tangerine", cloudColorHex: "#FF6F00", ringColorHex: "#FFCC80"),
        CompanionColorTheme(id: "cobalt-blue", name: "Cobalt Blue", cloudColorHex: "#3B82F6", ringColorHex: "#BFDBFE"),
        CompanionColorTheme(id: "neon-violet", name: "Neon Violet", cloudColorHex: "#A855F7", ringColorHex: "#F3E8FF"),
        CompanionColorTheme(id: "titanium-white", name: "Titanium White", cloudColorHex: "#FFFFFF", ringColorHex: "#E2E8F0"),
        CompanionColorTheme(id: "smoked-slate", name: "Smoked Slate", cloudColorHex: "#475569", ringColorHex: "#CBD5E1")
    ]

    public static func matchTheme(cloudHex: String, ringHex: String = "") -> CompanionColorTheme? {
        allThemes.first(where: {
            $0.cloudColorHex.caseInsensitiveCompare(cloudHex) == .orderedSame
        })
    }
}

public struct CompanionProfile: Identifiable, Codable, Equatable {
    public var id: UUID
    public var slug: String
    public var name: String
    public var role: String
    public var summary: String
    public var cloudColorHex: String
    public var ringColorHex: String
    public var status: CompanionStatus
    public var lastMessage: String
    public var activeSkills: [String]
    public var mdPath: String
    public var isPinnedToRail: Bool
    public var lastActiveAt: Date
    public var hasUnreadMessages: Bool
    public var messages: [HomeSpaceChatMessage]
    public var mood: AgentCloudFaceMood
    public var templateId: String
    public var animationKey: String?
    public var currentExpressionKey: String?
    public var executionDomain: MascotExecutionDomain
    public var workflowAppNames: [String]
    public var allowedSafariDomains: [String]
    public var safariTabAccessMode: String // "whitelist_only", "all_tabs", "active_tab_only"
    public var isSandboxedVM: Bool {
        return executionDomain == .virtualSandbox || !workflowAppNames.isEmpty
    }

    public init(
        id: UUID = UUID(),
        slug: String,
        name: String,
        role: String,
        summary: String,
        cloudColorHex: String,
        ringColorHex: String,
        status: CompanionStatus = .idle,
        lastMessage: String = "",
        activeSkills: [String] = [],
        mdPath: String = "",
        isPinnedToRail: Bool = true,
        lastActiveAt: Date = Date(),
        hasUnreadMessages: Bool = false,
        messages: [HomeSpaceChatMessage] = [],
        mood: AgentCloudFaceMood = .happy,
        templateId: String = "strobi",
        animationKey: String? = nil,
        currentExpressionKey: String? = nil,
        executionDomain: MascotExecutionDomain = .virtualSandbox,
        workflowAppNames: [String] = ["Mail", "Safari"],
        allowedSafariDomains: [String] = ["google.com", "github.com"],
        safariTabAccessMode: String = "whitelist_only"
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.role = role
        self.summary = summary
        self.cloudColorHex = cloudColorHex
        self.ringColorHex = ringColorHex
        self.status = status
        self.lastMessage = lastMessage
        self.activeSkills = activeSkills
        self.mdPath = mdPath
        self.isPinnedToRail = isPinnedToRail
        self.lastActiveAt = lastActiveAt
        self.hasUnreadMessages = hasUnreadMessages
        self.messages = messages
        self.mood = mood
        self.templateId = templateId
        self.animationKey = animationKey
        self.currentExpressionKey = currentExpressionKey
        self.executionDomain = executionDomain
        self.workflowAppNames = workflowAppNames
        self.allowedSafariDomains = allowedSafariDomains
        self.safariTabAccessMode = safariTabAccessMode
    }

    private enum CodingKeys: String, CodingKey {
        case id, slug, name, role, summary, cloudColorHex, ringColorHex
        case status, lastMessage, activeSkills, mdPath, isPinnedToRail
        case lastActiveAt, hasUnreadMessages, messages, mood, templateId
        case animationKey, currentExpressionKey, executionDomain
        case workflowAppNames, allowedSafariDomains, safariTabAccessMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        slug = try container.decode(String.self, forKey: .slug)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(String.self, forKey: .role)
        summary = try container.decode(String.self, forKey: .summary)
        cloudColorHex = try container.decode(String.self, forKey: .cloudColorHex)
        ringColorHex = try container.decode(String.self, forKey: .ringColorHex)
        status = try container.decode(CompanionStatus.self, forKey: .status)
        lastMessage = try container.decodeIfPresent(String.self, forKey: .lastMessage) ?? ""
        activeSkills = try container.decodeIfPresent([String].self, forKey: .activeSkills) ?? []
        mdPath = try container.decodeIfPresent(String.self, forKey: .mdPath) ?? ""
        isPinnedToRail = try container.decodeIfPresent(Bool.self, forKey: .isPinnedToRail) ?? true
        lastActiveAt = try container.decodeIfPresent(Date.self, forKey: .lastActiveAt) ?? Date()
        hasUnreadMessages = try container.decodeIfPresent(Bool.self, forKey: .hasUnreadMessages) ?? false
        messages = try container.decodeIfPresent([HomeSpaceChatMessage].self, forKey: .messages) ?? []
        mood = try container.decodeIfPresent(AgentCloudFaceMood.self, forKey: .mood) ?? .happy
        templateId = try container.decodeIfPresent(String.self, forKey: .templateId) ?? "strobi"
        animationKey = try container.decodeIfPresent(String.self, forKey: .animationKey)
        currentExpressionKey = try container.decodeIfPresent(String.self, forKey: .currentExpressionKey)
        executionDomain = try container.decodeIfPresent(MascotExecutionDomain.self, forKey: .executionDomain) ?? .virtualSandbox
        workflowAppNames = try container.decodeIfPresent([String].self, forKey: .workflowAppNames) ?? ["Mail", "Safari"]
        allowedSafariDomains = try container.decodeIfPresent([String].self, forKey: .allowedSafariDomains) ?? ["google.com", "github.com"]
        safariTabAccessMode = try container.decodeIfPresent(String.self, forKey: .safariTabAccessMode) ?? "whitelist_only"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(slug, forKey: .slug)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(summary, forKey: .summary)
        try container.encode(cloudColorHex, forKey: .cloudColorHex)
        try container.encode(ringColorHex, forKey: .ringColorHex)
        try container.encode(status, forKey: .status)
        try container.encode(lastMessage, forKey: .lastMessage)
        try container.encode(activeSkills, forKey: .activeSkills)
        try container.encode(mdPath, forKey: .mdPath)
        try container.encode(isPinnedToRail, forKey: .isPinnedToRail)
        try container.encode(lastActiveAt, forKey: .lastActiveAt)
        try container.encode(hasUnreadMessages, forKey: .hasUnreadMessages)
        try container.encode(messages, forKey: .messages)
        try container.encode(mood, forKey: .mood)
        try container.encode(templateId, forKey: .templateId)
        try container.encode(executionDomain, forKey: .executionDomain)
        try container.encode(workflowAppNames, forKey: .workflowAppNames)
        try container.encode(allowedSafariDomains, forKey: .allowedSafariDomains)
        try container.encode(safariTabAccessMode, forKey: .safariTabAccessMode)
        try container.encodeIfPresent(animationKey, forKey: .animationKey)
        try container.encodeIfPresent(currentExpressionKey, forKey: .currentExpressionKey)
    }
    
    public var cloudColor: Color {
        Color(hex: cloudColorHex)
    }
    
    public var ringColor: Color {
        Color(hex: ringColorHex)
    }
}

// MARK: - Built-in Starter Profiles
extension CompanionProfile {
    public static let defaultResearchBuddy = CompanionProfile(
        slug: "research-buddy",
        name: "Research Buddy",
        role: "Market & Competitor Researcher",
        summary: "Spesialis riset perusahaan, tren pasar, dan intelijen kompetitor.",
        cloudColorHex: "#4ADE80", // Pastel Green
        ringColorHex: "#FBCFE8",  // Soft Pink Ring
        status: .done,
        lastMessage: "Research Buddy siap membantu riset perusahaan, pasar, atau kompetitor.",
        activeSkills: ["google-workspace", "notion", "ocr-and-documents"],
        mdPath: "ResearchBuddy.md",
        isPinnedToRail: true
    )
    
    public static let defaultShippy = CompanionProfile(
        slug: "shippy",
        name: "Shippy",
        role: "Web & macOS App Builder",
        summary: "Spesialis merapikan kode, membangun web, dan automasi Mac.",
        cloudColorHex: "#818CF8", // Indigo / Lavender
        ringColorHex: "#FEF08A",  // Soft Pastel Gold / Warm Yellow
        status: .working,
        lastMessage: "Halo Ruski, aku Shippy—siap bantu bikin atau merapikan web apa pun di Mac ini.",
        activeSkills: ["github-issues", "github-pr-workflow", "linear"],
        mdPath: "Shippy.md",
        isPinnedToRail: true
    )
    
    public static let defaultClicky = CompanionProfile(
        slug: "clicky",
        name: "Clicky",
        role: "Spatial AI Companion",
        summary: "Navigasi kursor spasial, Computer Use, dan automasi desktop.",
        cloudColorHex: "#38BDF8", // Vibrant Sky Blue
        ringColorHex: "#BAE6FD",  // Soft Pastel Sky Blue
        status: .idle,
        lastMessage: "Hey! Aku Clicky. Ada tombol atau tugas yang perlu aku arahkan di layar?",
        activeSkills: ["claude-code", "excalidraw"],
        mdPath: "Clicky.md",
        isPinnedToRail: false
    )
    
    public static let defaultStarters: [CompanionProfile] = [
        defaultResearchBuddy,
        defaultShippy,
        defaultClicky
    ]
}
