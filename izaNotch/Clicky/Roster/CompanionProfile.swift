//
//  CompanionProfile.swift
//  izaNotch
//
//  Created for Izanotchy - Multi-Agent Desktop System
//

import SwiftUI

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
        isPinnedToRail: false,
        workflowAppNames: []
    )
    
    public static let defaultStarters: [CompanionProfile] = [
        defaultResearchBuddy,
        defaultShippy,
        defaultClicky
    ]
}
// MARK: - CompanionSkill (Schema C4: 6-Field Standard Skill Contract)
public struct CompanionSkill: Identifiable, Codable, Equatable, Sendable {
    public var id: String { name.lowercased().replacingOccurrences(of: " ", with: "-") }
    public var name: String
    public var whenToUse: String
    public var requiredInputs: [String]
    public var access: [String]
    public var steps: [String]
    public var validation: String
    public var output: String
    public var approvalBoundary: [String]
    public var origin: String // "manual" | "teach-mode"
    public var draft: Bool

    public init(
        name: String,
        whenToUse: String,
        requiredInputs: [String] = [],
        access: [String] = [],
        steps: [String] = [],
        validation: String = "",
        output: String = "",
        approvalBoundary: [String] = [],
        origin: String = "manual",
        draft: Bool = false
    ) {
        self.name = name
        self.whenToUse = whenToUse
        self.requiredInputs = requiredInputs
        self.access = access
        self.steps = steps
        self.validation = validation
        self.output = output
        self.approvalBoundary = approvalBoundary
        self.origin = origin
        self.draft = draft
    }
}

// MARK: - CompanionSkillLibrary (Shared Cross-Bot Skill Storage & Slash Resolver)
public final class CompanionSkillLibrary: @unchecked Sendable {
    public static let shared = CompanionSkillLibrary()

    private let fileManager = FileManager.default

    private var sharedSkillsDirectory: URL {
        let dir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".izanotchy/shared_workspace/skills", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {
        seedBuiltinSkillsIfEmpty()
    }

    /// Saves or updates a skill in the shared library or companion-specific directory
    @discardableResult
    public func saveSkill(_ skill: CompanionSkill, for companionSlug: String? = nil) -> URL? {
        let targetDir: URL
        if let slug = companionSlug, !slug.isEmpty {
            targetDir = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".izanotchy/companions/\(slug)/workspace/skills", isDirectory: true)
        } else {
            targetDir = sharedSkillsDirectory
        }
        try? fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let fileURL = targetDir.appendingPathComponent("\(skill.id).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(skill) else { return nil }
        try? data.write(to: fileURL)
        ClickyLogger.info("[SKILLS]", "Saved skill '\(skill.name)' to \(fileURL.path) (origin=\(skill.origin), draft=\(skill.draft))")
        return fileURL
    }

    /// Retrieves a skill by name or slug from companion scope or shared library
    public func getSkill(named name: String, for companionSlug: String? = nil) -> CompanionSkill? {
        let targetId = name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "/", with: "")

        // 1. Check companion-specific directory if slug provided
        if let slug = companionSlug, !slug.isEmpty {
            let compDir = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".izanotchy/companions/\(slug)/workspace/skills", isDirectory: true)
            let compFile = compDir.appendingPathComponent("\(targetId).json")
            if let data = try? Data(contentsOf: compFile),
               let skill = try? JSONDecoder().decode(CompanionSkill.self, from: data) {
                return skill
            }
        }

        // 2. Check shared library
        let sharedFile = sharedSkillsDirectory.appendingPathComponent("\(targetId).json")
        if let data = try? Data(contentsOf: sharedFile),
           let skill = try? JSONDecoder().decode(CompanionSkill.self, from: data) {
            return skill
        }

        return nil
    }

    /// Lists all skills available in the shared library plus companion scope
    public func allSkills(for companionSlug: String? = nil) -> [CompanionSkill] {
        var results: [String: CompanionSkill] = [:]

        // Read shared library
        if let items = try? fileManager.contentsOfDirectory(at: sharedSkillsDirectory, includingPropertiesForKeys: nil) {
            for item in items where item.pathExtension.lowercased() == "json" {
                if let data = try? Data(contentsOf: item),
                   let skill = try? JSONDecoder().decode(CompanionSkill.self, from: data) {
                    results[skill.id] = skill
                }
            }
        }

        // Read companion scope (overrides or adds)
        if let slug = companionSlug, !slug.isEmpty {
            let compDir = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".izanotchy/companions/\(slug)/workspace/skills", isDirectory: true)
            if let items = try? fileManager.contentsOfDirectory(at: compDir, includingPropertiesForKeys: nil) {
                for item in items where item.pathExtension.lowercased() == "json" {
                    if let data = try? Data(contentsOf: item),
                       let skill = try? JSONDecoder().decode(CompanionSkill.self, from: data) {
                        results[skill.id] = skill
                    }
                }
            }
        }

        return Array(results.values).sorted(by: { $0.name < $1.name })
    }

    /// Resolves slash command reference from prompt (e.g. "/check-inbox" or "/compose")
    public func resolveSlashReference(from prompt: String, for companionSlug: String? = nil) -> (skill: CompanionSkill?, remainderPrompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return (nil, prompt) }

        let components = trimmed.dropFirst().components(separatedBy: .whitespaces)
        guard let commandName = components.first, !commandName.isEmpty else { return (nil, prompt) }

        let remainder = components.dropFirst().joined(separator: " ")
        if let skill = getSkill(named: commandName, for: companionSlug) {
            ClickyLogger.info("[SKILLS]", "Resolved slash command '/\(commandName)' -> Skill '\(skill.name)'")
            return (skill, remainder)
        }

        return (nil, prompt)
    }

    /// Formats skill into System 2 prompt guidance so planner adheres to its steps and boundaries
    public func formatForSystemPrompt(_ skill: CompanionSkill) -> String {
        return """
        [ACTIVE_SKILL: \(skill.name)]
        - When to use: \(skill.whenToUse)
        - Required Inputs: \(skill.requiredInputs.joined(separator: ", "))
        - Access: \(skill.access.joined(separator: ", "))
        - Steps:
        \(skill.steps.enumerated().map { "  \($0 + 1). \($1)" }.joined(separator: "\n"))
        - Validation: \(skill.validation)
        - Expected Output: \(skill.output)
        - Approval Boundary: \(skill.approvalBoundary.joined(separator: ", "))
        """
    }

    private func seedBuiltinSkillsIfEmpty() {
        let existing = allSkills()
        if existing.isEmpty {
            let checkInbox = CompanionSkill(
                name: "check-inbox",
                whenToUse: "Digunakan saat pengguna meminta memeriksa kotak masuk, membaca email terbaru, atau memeriksa folder surel.",
                requiredInputs: ["folderName (opsional, default: Inbox)", "targetIndex (opsional, default: 1)"],
                access: ["Webmail DOM", "Mail App"],
                steps: [
                    "Buka antarmuka email pada isolated workspace.",
                    "Periksa daftar pesan pada folder target.",
                    "Ekstrak pengirim, subjek, dan pratinjau isi pesan tanpa mengubah status read/unread jika tidak diminta.",
                    "Sintesiskan laporan temuan faktual 5-bagian."
                ],
                validation: "Daftar email memuat minimal 1 item terverifikasi pada DOM atau AX.",
                output: "Laporan faktual pengirim, subjek, dan jumlah pesan.",
                approvalBoundary: [],
                origin: "manual",
                draft: false
            )

            let composeDraft = CompanionSkill(
                name: "compose-draft",
                whenToUse: "Digunakan saat pengguna meminta membuat draf email baru atau membalas pesan.",
                requiredInputs: ["to", "subject", "body"],
                access: ["Webmail DOM Compose", "Mail Composer"],
                steps: [
                    "Buka jendela komposisi pesan baru.",
                    "Isi bidang penerima, subjek, dan badan email.",
                    "Verifikasi teks yang diketik pada form fields.",
                    "Simpan sebagai draf (DILARANG mengirim tanpa approval eksplisit)."
                ],
                validation: "Form fields diverifikasi berisi alamat penerima dan subjek yang tepat.",
                output: "Status draf tersimpan dan pratinjau konten pesan.",
                approvalBoundary: ["Pengiriman email aktual (Send) wajib meminta izin pengguna"],
                origin: "manual",
                draft: false
            )

            saveSkill(checkInbox)
            saveSkill(composeDraft)
        }
    }
}
// MARK: - CompanionTeachModeEngine (PRD §A8, MT-06: Teach-by-Demonstration Engine)

public final class CompanionTeachModeEngine: ObservableObject, @unchecked Sendable {
    public static let shared = CompanionTeachModeEngine()

    @Published public var isRecording: Bool = false
    @Published public var taskName: String = ""
    @Published public var recordedSteps: [String] = []
    @Published public var activeDraftSkill: CompanionSkill? = nil
    @Published public var recordingStartTime: Date? = nil

    private init() {}

    public func startTeaching(name: String) {
        taskName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Tugas Terbimbing" : name
        recordedSteps = []
        isRecording = true
        recordingStartTime = Date()
        activeDraftSkill = nil
        ClickyLogger.info("[TEACH_MODE]", "Started Teach Mode session for '\(taskName)'")
    }

    public func recordAction(description: String) {
        guard isRecording else { return }
        let clean = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        recordedSteps.append(clean)
        ClickyLogger.info("[TEACH_MODE]", "Recorded step #\(recordedSteps.count): \(clean)")
    }

    @discardableResult
    public func finishTeaching(outputGoal: String = "") -> CompanionSkill {
        isRecording = false
        let safeName = taskName.isEmpty ? "skill-\(UUID().uuidString.prefix(6))" : taskName
        let cleanSteps = recordedSteps.isEmpty ? ["Jalankan tugas sesuai panduan alur kerja."] : recordedSteps

        let draftSkill = CompanionSkill(
            name: safeName,
            whenToUse: "Digunakan saat pengguna meminta menjalankan tugas '\(safeName)'.",
            requiredInputs: [],
            access: ["Desktop Workspace", "Target App"],
            steps: cleanSteps,
            validation: "Setiap langkah eksekusi selesai tanpa kegagalan tidak tertangani.",
            output: outputGoal.isEmpty ? "Hasil penyelesaian alur tugas \(safeName)." : outputGoal,
            approvalBoundary: [],
            origin: "teach-mode",
            draft: true
        )

        activeDraftSkill = draftSkill
        CompanionSkillLibrary.shared.saveSkill(draftSkill)
        ClickyLogger.info("[TEACH_MODE]", "Finished Teach Mode. Compiled draft skill '\(safeName)' with \(cleanSteps.count) steps.")
        return draftSkill
    }

    @discardableResult
    public func finalizeDraftSkill(_ skill: CompanionSkill) -> CompanionSkill {
        var finalized = skill
        finalized.draft = false
        CompanionSkillLibrary.shared.saveSkill(finalized)
        activeDraftSkill = nil
        isRecording = false
        ClickyLogger.info("[TEACH_MODE]", "Finalized draft skill '\(finalized.name)' (draft=false). Saved to library.")
        return finalized
    }

    public func cancelTeaching() {
        isRecording = false
        taskName = ""
        recordedSteps = []
        activeDraftSkill = nil
        recordingStartTime = nil
        ClickyLogger.info("[TEACH_MODE]", "Cancelled Teach Mode session.")
    }
}
// MARK: - SkillMarketplaceService (PRD §A8, MT-27: Marketplace & Packaged Skills)

public struct PackagedSkillItem: Identifiable, Codable, Sendable, Equatable {
    public var id: String { skill.id }
    public let skill: CompanionSkill
    public let category: String
    public let author: String
    public let downloadsCount: Int
    public var isInstalled: Bool

    public init(
        skill: CompanionSkill,
        category: String,
        author: String = "Izanotchy Catalog",
        downloadsCount: Int = 100,
        isInstalled: Bool = false
    ) {
        self.skill = skill
        self.category = category
        self.author = author
        self.downloadsCount = downloadsCount
        self.isInstalled = isInstalled
    }
}

public final class SkillMarketplaceService: @unchecked Sendable {
    public static let shared = SkillMarketplaceService()

    private let lock = NSLock()
    private var catalog: [PackagedSkillItem] = []

    private init() {
        seedCatalog()
    }

    private func seedCatalog() {
        catalog = [
            PackagedSkillItem(
                skill: CompanionSkill(
                    name: "gmail-digest",
                    whenToUse: "Digunakan untuk membaca dan membuat ringkasan surel harian.",
                    requiredInputs: ["newerThan (opsional)"],
                    access: ["Gmail API", "Mail"],
                    steps: [
                        "Panggil API surel untuk membaca 5 pesan terbaru.",
                        "Ekstrak poin penting dan urgensi per pesan.",
                        "Sintesiskan ringkasan 5-bagian."
                    ],
                    validation: "Surel terverifikasi terbaca.",
                    output: "Ringkasan surel harian berbutir.",
                    approvalBoundary: [],
                    origin: "marketplace",
                    draft: false
                ),
                category: "Communication",
                author: "Google Workspace Team",
                downloadsCount: 1420
            ),
            PackagedSkillItem(
                skill: CompanionSkill(
                    name: "pr-code-review",
                    whenToUse: "Digunakan saat meninjau pull request atau git diff.",
                    requiredInputs: ["diffContent"],
                    access: ["Terminal", "Git CLI"],
                    steps: [
                        "Periksa berkas yang berubah.",
                        "Identifikasi regresi tipe dan celah keamanan.",
                        "Buat daftar saran perbaikan spesifik."
                    ],
                    validation: "Seluruh berkas diff selesai dianalisis.",
                    output: "Laporan checklist code review.",
                    approvalBoundary: [],
                    origin: "marketplace",
                    draft: false
                ),
                category: "Developer",
                author: "Shippy Dev Fleet",
                downloadsCount: 980
            ),
            PackagedSkillItem(
                skill: CompanionSkill(
                    name: "market-crypto-scan",
                    whenToUse: "Digunakan untuk memindai pasar kripto dan indikator teknikal.",
                    requiredInputs: ["universe (opsional)"],
                    access: ["TradingView", "Market Data API"],
                    steps: [
                        "Ambil kandel harga 1 jam.",
                        "Hitung level Fibonacci dan divergensi RSI.",
                        "Petakan level entry dan invalidasi."
                    ],
                    validation: "Kandel harga terverifikasi.",
                    output: "Laporan sinyal radar pasar.",
                    approvalBoundary: ["Dilarang mengeksekusi order riil"],
                    origin: "marketplace",
                    draft: false
                ),
                category: "Finance",
                author: "Futures Scout",
                downloadsCount: 2150
            ),
            PackagedSkillItem(
                skill: CompanionSkill(
                    name: "meeting-notes-summary",
                    whenToUse: "Digunakan untuk menyusun notula rapat dan tindak lanjut.",
                    requiredInputs: ["notesText"],
                    access: ["Notes", "Calendar"],
                    steps: [
                        "Analisis poin keputusan rapat.",
                        "Ekstrak item aksi dan penanggung jawab.",
                        "Buat dokumen ringkasan terstruktur."
                    ],
                    validation: "Item aksi terverifikasi.",
                    output: "Dokumen notula rapat terstruktur.",
                    approvalBoundary: [],
                    origin: "marketplace",
                    draft: false
                ),
                category: "Productivity",
                author: "Chief of Staff",
                downloadsCount: 870
            )
        ]
    }

    /// Lists catalog items, marking installed status based on companion scope
    public func listCatalog(category: String? = nil, companionSlug: String? = nil) -> [PackagedSkillItem] {
        lock.lock()
        defer { lock.unlock() }

        let installedSkills: Set<String> = {
            if let slug = companionSlug {
                return Set(CompanionSkillLibrary.shared.allSkills(for: slug).map { $0.id })
            } else {
                return Set(CompanionSkillLibrary.shared.allSkills().map { $0.id })
            }
        }()

        var result = catalog.map { item -> PackagedSkillItem in
            var copy = item
            copy.isInstalled = installedSkills.contains(item.skill.id)
            return copy
        }

        if let cat = category, !cat.isEmpty {
            result = result.filter { $0.category.lowercased() == cat.lowercased() }
        }

        return result
    }

    /// Installs a packaged skill into the shared library and activates it for companion
    @discardableResult
    public func installSkill(skillId: String, for companionSlug: String? = nil) -> Bool {
        lock.lock()
        let item = catalog.first(where: { $0.skill.id == skillId })
        lock.unlock()

        guard let target = item else { return false }

        // 1. Save skill into library
        CompanionSkillLibrary.shared.saveSkill(target.skill, for: companionSlug)

        // 2. Activate in companion's activeSkills
        if let slug = companionSlug {
            Task { @MainActor in
                if let idx = CompanionRosterStore.shared.allCompanions.firstIndex(where: { $0.slug == slug }) {
                    if !CompanionRosterStore.shared.allCompanions[idx].activeSkills.contains(skillId) {
                        CompanionRosterStore.shared.allCompanions[idx].activeSkills.append(skillId)
                        CompanionRosterStore.shared.persist()
                    }
                }
            }
        }

        ClickyLogger.info("[MARKETPLACE]", "Installed packaged skill '\(skillId)' for companion '\(companionSlug ?? "shared")'.")
        return true
    }

    /// Uninstalls / deactivates a skill
    @discardableResult
    public func uninstallSkill(skillId: String, from companionSlug: String? = nil) -> Bool {
        if let slug = companionSlug {
            Task { @MainActor in
                if let idx = CompanionRosterStore.shared.allCompanions.firstIndex(where: { $0.slug == slug }) {
                    CompanionRosterStore.shared.allCompanions[idx].activeSkills.removeAll(where: { $0 == skillId })
                    CompanionRosterStore.shared.persist()
                }
            }
        }
        ClickyLogger.info("[MARKETPLACE]", "Uninstalled skill '\(skillId)' from companion '\(companionSlug ?? "shared")'.")
        return true
    }
}
