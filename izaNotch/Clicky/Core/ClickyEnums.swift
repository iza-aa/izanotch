//
//  ClickyEnums.swift
//  izaNotch
//
//  Common enums and notification definitions for Clicky companion.
//

import Foundation

extension Notification.Name {
    static let clickyDismissPanel = Notification.Name("clickyDismissPanel")
    /// Plan sinkron-teks S2/S3: flight mulai (bubble ditegakkan) & TTS mulai (hold bubble).
    static let clickyFlightStarted = Notification.Name("clickyFlightStarted")
    static let clickyTTSStarted = Notification.Name("clickyTTSStarted")
}

// MARK: - Computer Card Models (F-07 1:1 Foto 1)

public enum ComputerCardStatus: String, Codable, Equatable, Sendable {
    case working = "Working"
    case done = "Done"
    case takeoverNeeded = "Takeover Needed"
    case failed = "Failed"
}

public struct ComputerCardQueueItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let statusBadge: String
    public let isChecked: Bool

    public init(name: String, statusBadge: String = "Draft", isChecked: Bool = false) {
        self.name = name
        self.statusBadge = statusBadge
        self.isChecked = isChecked
    }
}

public struct ComputerCardPayload: Codable, Equatable, Sendable {
    public var cardTitle: String
    public var status: ComputerCardStatus
    public var instructionText: String
    public var snapshotImagePath: String?
    public var targetWindowId: Int64?
    public var targetAppName: String?
    public var activeWorkflowApp: String?
    public var takeoverReason: String?
    public var queueSummary: String?
    public var queueItems: [ComputerCardQueueItem]?
    public var targetCoordinateX: Double?
    public var targetCoordinateY: Double?
    public var currentActionLabel: String?
    public var deliverableSummary: String?
    public var responseToUser: String?
    public var updatedAt: Date
    public var egressResult: EgressResult?

    public init(
        cardTitle: String = "Computer",
        status: ComputerCardStatus = .working,
        instructionText: String,
        snapshotImagePath: String? = nil,
        targetWindowId: Int64? = nil,
        targetAppName: String? = nil,
        activeWorkflowApp: String? = nil,
        takeoverReason: String? = nil,
        queueSummary: String? = nil,
        queueItems: [ComputerCardQueueItem]? = nil,
        targetCoordinateX: Double? = nil,
        targetCoordinateY: Double? = nil,
        currentActionLabel: String? = nil,
        deliverableSummary: String? = nil,
        responseToUser: String? = nil,
        updatedAt: Date = Date(),
        egressResult: EgressResult? = nil
    ) {
        self.cardTitle = cardTitle
        self.status = status
        self.instructionText = instructionText
        self.snapshotImagePath = snapshotImagePath
        self.targetWindowId = targetWindowId
        self.targetAppName = targetAppName
        self.activeWorkflowApp = activeWorkflowApp
        self.takeoverReason = takeoverReason
        self.queueSummary = queueSummary
        self.queueItems = queueItems
        self.targetCoordinateX = targetCoordinateX
        self.targetCoordinateY = targetCoordinateY
        self.currentActionLabel = currentActionLabel
        self.deliverableSummary = deliverableSummary
        self.responseToUser = responseToUser
        self.updatedAt = updatedAt
        self.egressResult = egressResult
    }
}

public struct ChatAttachment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let fileName: String
    public let fileURLString: String
    public let fileSize: Int64
    public let mimeType: String
    public let isVideo: Bool

    public init(
        id: UUID = UUID(),
        fileName: String,
        fileURLString: String,
        fileSize: Int64,
        mimeType: String,
        isVideo: Bool = false
    ) {
        self.id = id
        self.fileName = fileName
        self.fileURLString = fileURLString
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.isVideo = isVideo
    }
}

public struct AttachmentValidator: Sendable {
    public static let maxAttachments = 6
    public static let maxStandardSizeBytes: Int64 = 25 * 1024 * 1024 // 25MB
    public static let maxVideoSizeBytes: Int64 = 200 * 1024 * 1024 // 200MB

    public static let supportedExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "bmp",
        "mp4", "mov", "m4v", "webm", "mkv", "avi",
        "mp3", "m4a", "wav", "aac", "flac", "ogg",
        "pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "txt", "rtf", "pages", "numbers", "key",
        "csv", "tsv", "json", "yaml", "yml", "xml",
        "swift", "py", "js", "ts", "html", "css", "sh", "c", "cpp", "h", "go", "rs", "rb", "php", "ipynb", "md",
        "eml", "msg"
    ]

    public static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "webm", "mkv", "avi"
    ]

    public static func validate(url: URL, currentCount: Int) -> (isValid: Bool, error: String?, attachment: ChatAttachment?) {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        if currentCount >= maxAttachments {
            return (false, "Maksimal \(maxAttachments) lampiran per pesan.", nil)
        }

        if !supportedExtensions.contains(ext) {
            return (false, "Tipe berkas '.\(ext)' tidak didukung.", nil)
        }

        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let size = (attrs[.size] as? Int64) ?? 0
        let isVideo = videoExtensions.contains(ext)

        let limit = isVideo ? maxVideoSizeBytes : maxStandardSizeBytes
        if size > limit {
            let formattedSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            let limitStr = isVideo ? "200MB" : "25MB"
            let msg = isVideo
                ? "Ukuran video '\(name)' melebihi batas \(limitStr) (\(formattedSize))."
                : "Ukuran berkas '\(name)' melebihi batas \(limitStr) (\(formattedSize))."
            return (false, msg, nil)
        }

        let att = ChatAttachment(
            fileName: name,
            fileURLString: url.path,
            fileSize: size,
            mimeType: ext,
            isVideo: isVideo
        )
        return (true, nil, att)
    }
}
public struct VoiceMemoData: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let audioFileURLString: String?
    public let durationSeconds: Double
    public let transcriptText: String
    public let recordedAt: Date

    public init(
        id: UUID = UUID(),
        audioFileURLString: String? = nil,
        durationSeconds: Double = 0.0,
        transcriptText: String,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.audioFileURLString = audioFileURLString
        self.durationSeconds = durationSeconds
        self.transcriptText = transcriptText
        self.recordedAt = recordedAt
    }
}
public struct LiveVoiceChatSessionData: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let companionSlug: String
    public let durationSeconds: Double
    public let startedAt: Date
    public let endedAt: Date
    public let summary: String
    public let fullTranscriptLines: [String]

    public init(
        id: UUID = UUID(),
        companionSlug: String,
        durationSeconds: Double = 0.0,
        startedAt: Date = Date(),
        endedAt: Date = Date(),
        summary: String,
        fullTranscriptLines: [String] = []
    ) {
        self.id = id
        self.companionSlug = companionSlug
        self.durationSeconds = durationSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.summary = summary
        self.fullTranscriptLines = fullTranscriptLines
    }
}

public struct MessageReactionItem: Codable, Sendable, Identifiable, Equatable {
    public var id: String { "\(symbol):\(authorSlug)" }
    public let symbol: String // e.g. "thumbs_up", "heart", "eyes", "rocket"
    public let authorSlug: String
    public let timestamp: Date

    public init(symbol: String, authorSlug: String, timestamp: Date = Date()) {
        self.symbol = symbol
        self.authorSlug = authorSlug
        self.timestamp = timestamp
    }
}

public struct HomeSpaceChatMessage: Identifiable, Codable, Equatable {
    public let id: UUID
    public let isUser: Bool
    public var text: String
    public let timestamp: Date
    public var computerPayload: ComputerCardPayload?
    public var egressResult: EgressResult?
    public var attachments: [ChatAttachment]
    public var voiceMemo: VoiceMemoData?
    public var liveVoiceChat: LiveVoiceChatSessionData?
    public var senderCompanionSlug: String?
    public var replyToMessageId: UUID?
    public var threadId: UUID?
    public var threadMessages: [HomeSpaceChatMessage]
    public var reactions: [MessageReactionItem]

    public init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        timestamp: Date = Date(),
        computerPayload: ComputerCardPayload? = nil,
        egressResult: EgressResult? = nil,
        attachments: [ChatAttachment] = [],
        voiceMemo: VoiceMemoData? = nil,
        liveVoiceChat: LiveVoiceChatSessionData? = nil,
        senderCompanionSlug: String? = nil,
        replyToMessageId: UUID? = nil,
        threadId: UUID? = nil,
        threadMessages: [HomeSpaceChatMessage] = [],
        reactions: [MessageReactionItem] = []
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
        self.computerPayload = computerPayload
        self.egressResult = egressResult
        self.attachments = attachments
        self.voiceMemo = voiceMemo
        self.liveVoiceChat = liveVoiceChat
        self.senderCompanionSlug = senderCompanionSlug
        self.replyToMessageId = replyToMessageId
        self.threadId = threadId
        self.threadMessages = threadMessages
        self.reactions = reactions
    }
}

// MARK: - MessageThreadAndReactionManager (PRD §A7, MT-32: Threads & Reaction Acknowledgment)

public final class MessageThreadAndReactionManager: @unchecked Sendable {
    public static let shared = MessageThreadAndReactionManager()

    private let lock = NSLock()
    private var threads: [UUID: [HomeSpaceChatMessage]] = [:]

    private init() {}

    /// Adds an acknowledgment reaction. Invariant (PRD §A7): Reactions NEVER carry new instructions!
    public func evaluateReactionImpact(symbol: String, authorSlug: String) -> (isInstruction: Bool, acknowledgmentNotice: String) {
        ClickyLogger.info("[REACTION]", "Received reaction '\(symbol)' from '\(authorSlug)' (strictly acknowledgment only; no new instructions dispatched).")
        return (false, "Reaction '\(symbol)' diterima sebagai acknowledgement saja.")
    }

    /// Appends a reply to a message thread (feedback on specific deliverable or turn)
    public func addThreadReply(parentMessageId: UUID, reply: HomeSpaceChatMessage) {
        lock.lock()
        var list = threads[parentMessageId] ?? []
        list.append(reply)
        threads[parentMessageId] = list
        lock.unlock()
        ClickyLogger.info("[THREAD]", "Appended thread reply to message '\(parentMessageId)' (total thread replies: \(list.count))")
    }

    /// Gets all replies in a message thread
    public func getThreadReplies(parentMessageId: UUID) -> [HomeSpaceChatMessage] {
        lock.lock()
        defer { lock.unlock() }
        return threads[parentMessageId] ?? []
    }
}

// MARK: - GroupChatSession & GroupChatCoordinator (PRD §A7, MT-31: Group Chat 2-6 Companions)

public struct GroupChatParticipant: Codable, Sendable, Identifiable, Equatable {
    public var id: String { slug }
    public let slug: String
    public let name: String
    public let role: String

    public init(slug: String, name: String, role: String) {
        self.slug = slug
        self.name = name
        self.role = role
    }
}

public struct GroupChatSession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var sharedOutcomeGoal: String
    public var participantSlugs: [String] // 2-6 companions per PRD §A7
    public var messages: [HomeSpaceChatMessage]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        sharedOutcomeGoal: String,
        participantSlugs: [String],
        messages: [HomeSpaceChatMessage] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sharedOutcomeGoal = sharedOutcomeGoal
        // Enforce 2-6 bots limit per PRD §A7
        self.participantSlugs = Array(participantSlugs.prefix(6))
        self.messages = messages
        self.createdAt = createdAt
    }
}

public final class GroupChatCoordinator: @unchecked Sendable {
    public static let shared = GroupChatCoordinator()

    private let lock = NSLock()
    private var sessions: [UUID: GroupChatSession] = [:]

    private init() {}

    /// Creates a group chat enforcing the 2 to 6 bot limit (PRD §A7)
    public func createGroupChat(name: String, outcome: String, participants: [String]) throws -> GroupChatSession {
        lock.lock()
        defer { lock.unlock() }

        guard participants.count >= 2 else {
            throw NSError(domain: "GroupChat", code: 400, userInfo: [NSLocalizedDescriptionKey: "Group chat memerlukan minimal 2 companion."])
        }
        let clamped = Array(participants.prefix(6))
        let session = GroupChatSession(name: name, sharedOutcomeGoal: outcome, participantSlugs: clamped)
        sessions[session.id] = session
        ClickyLogger.info("[GROUP_CHAT]", "Created group chat '\(name)' with \(clamped.count) participants (shared outcome: '\(outcome)')")
        return session
    }

    /// Validates safety rule: DILARANG approval berisiko atau secrets di dalam grup!
    public func validateGroupMessageContent(text: String) -> (isValid: Bool, warning: String?) {
        let lower = text.lowercased()
        let hasSecretAttempt = lower.contains("token") || lower.contains("api_key") || lower.contains("password") || lower.contains("secret")
        let hasApprovalAttempt = lower.contains("approve send") || lower.contains("approve delete") || lower.contains("approve purchase")

        if hasSecretAttempt || hasApprovalAttempt {
            return (false, "Peringatan Keamanan (PRD §A7): Approval berisiko dan secrets dilarang di dalam group chat. Silakan gunakan chat privat 1:1.")
        }
        return (true, nil)
    }

    /// Resolves target companion turn from @mentions or reply reference
    public func resolveTargetCompanion(from text: String, availableSlugs: [String]) -> (targetSlug: String?, hasOverheard: Bool) {
        let words = text.components(separatedBy: .whitespaces)
        for w in words where w.hasPrefix("@") {
            let cleanTag = String(w.dropFirst()).lowercased()
            if let match = availableSlugs.first(where: { $0.lowercased() == cleanTag || $0.lowercased().contains(cleanTag) }) {
                return (match, true)
            }
        }
        // Default: broadcast to first participant, other participants overhear
        return (availableSlugs.first, true)
    }
}


public enum MascotExecutionDomain: String, Codable {
    case macHost            // Direct on user's Mac desktop (no VM card, no virtual viewport)
    case virtualSandbox     // Isolated bot device/VM (e.g. email mobile/headless sandbox)
}

// MARK: - BuddySession (Multi-Buddy Sesi 1:1 Foto 4)
public struct BuddySession: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var roleDescription: String
    public var avatarColorHex: String
    public var ringColorHex: String
    public var mood: AgentCloudFaceMood
    public var timestampString: String
    public var lastSnippet: String
    public var messages: [HomeSpaceChatMessage]
    public var isUnread: Bool
    public var templateId: String
    public var animationKey: String?
    public var currentExpressionKey: String?
    public var workflowAppNames: [String]
    public var executionDomain: MascotExecutionDomain
    public var allowedSafariDomains: [String]
    public var safariTabAccessMode: String // "whitelist_only", "all_tabs", "active_tab_only"
    public var isSandboxedVM: Bool {
        return executionDomain == .virtualSandbox || !workflowAppNames.isEmpty
    }

    public init(
        id: UUID = UUID(),
        name: String,
        roleDescription: String,
        avatarColorHex: String,
        ringColorHex: String = "#BAE6FD",
        mood: AgentCloudFaceMood = .happy,
        timestampString: String = "Just now",
        lastSnippet: String = "",
        messages: [HomeSpaceChatMessage] = [],
        isUnread: Bool = false,
        templateId: String = "strobi",
        animationKey: String? = nil,
        currentExpressionKey: String? = nil,
        workflowAppNames: [String]? = nil,
        executionDomain: MascotExecutionDomain? = nil,
        allowedSafariDomains: [String]? = nil,
        safariTabAccessMode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.roleDescription = roleDescription
        self.avatarColorHex = avatarColorHex
        self.ringColorHex = ringColorHex
        self.mood = mood
        self.timestampString = timestampString
        self.lastSnippet = lastSnippet
        self.messages = messages
        self.isUnread = isUnread
        self.templateId = templateId
        self.animationKey = animationKey
        self.currentExpressionKey = currentExpressionKey

        let lower = name.lowercased()
        if let customDomain = executionDomain {
            self.executionDomain = customDomain
        } else if lower.contains("inbox") || lower.contains("mail") || lower.contains("futures") {
            self.executionDomain = .virtualSandbox
        } else {
            self.executionDomain = .macHost
        }

        if let customApps = workflowAppNames, !customApps.isEmpty {
            self.workflowAppNames = customApps
        } else if lower.contains("inbox") || lower.contains("mail") || lower.contains("sales") {
            self.workflowAppNames = ["Safari", "Mail"]
        } else if lower.contains("futures") || lower.contains("trade") || lower.contains("market") {
            self.workflowAppNames = ["TradingView", "Safari"]
        } else if lower.contains("shippy") || lower.contains("dev") || lower.contains("code") {
            self.workflowAppNames = ["Terminal", "Xcode"]
        } else {
            self.workflowAppNames = ["Safari", "Mail"]
        }

        if let customDomains = allowedSafariDomains {
            self.allowedSafariDomains = customDomains
        } else if lower.contains("futures") || lower.contains("trade") {
            self.allowedSafariDomains = ["tradingview.com", "binance.com", "coinglass.com"]
        } else if lower.contains("inbox") || lower.contains("mail") {
            self.allowedSafariDomains = WebSiteAdapterRegistry.shared.defaultAdapter.domains
        } else {
            self.allowedSafariDomains = ["google.com", "github.com"]
        }

        self.safariTabAccessMode = safariTabAccessMode ?? "whitelist_only"
    }

    public var slug: String {
        let sanitized = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return sanitized.isEmpty ? "companion" : sanitized
    }
}

// MARK: - ComputerUseActionPayload & Request
public struct ComputerUseActionPayload: Equatable {
    public enum ActionType: String, Equatable {
        case click
        case rightClick
        case doubleClick
        case typeText
        case keyCombo
        case launchApp
        case scroll
        case tradingViewAction
    }

    public var type: ActionType
    public var targetCoordinate: CGPoint?
    public var textToType: String?
    public var targetApp: String?
    public var keyCombo: String?
    public var tradingViewPayload: TradingViewActionPayload?
    public var rawDetails: String

    public init(
        type: ActionType = .click,
        targetCoordinate: CGPoint? = nil,
        textToType: String? = nil,
        targetApp: String? = nil,
        keyCombo: String? = nil,
        tradingViewPayload: TradingViewActionPayload? = nil,
        rawDetails: String = ""
    ) {
        self.type = type
        self.targetCoordinate = targetCoordinate
        self.textToType = textToType
        self.targetApp = targetApp
        self.keyCombo = keyCombo
        self.tradingViewPayload = tradingViewPayload
        self.rawDetails = rawDetails
    }
}

public struct ComputerUseRequest: Identifiable, Equatable {
    public let id: UUID
    public var companionId: UUID?
    public var companionName: String
    public var companionMood: AgentCloudFaceMood
    public var cloudColorHex: String
    public var ringColorHex: String
    public var heading: String
    public var bodyText: String
    public var payload: ComputerUseActionPayload

    public init(
        id: UUID = UUID(),
        companionId: UUID? = nil,
        companionName: String,
        companionMood: AgentCloudFaceMood = .happy,
        cloudColorHex: String = "#38BDF8",
        ringColorHex: String = "#BAE6FD",
        heading: String = "Wants to use your Mac",
        bodyText: String,
        payload: ComputerUseActionPayload
    ) {
        self.id = id
        self.companionId = companionId
        self.companionName = companionName
        self.companionMood = companionMood
        self.cloudColorHex = cloudColorHex
        self.ringColorHex = ringColorHex
        self.heading = heading
        self.bodyText = bodyText
        self.payload = payload
    }
}

// MARK: - Command Category (L0 Foundation Contract)

public enum ClickyCommandCategory: Equatable, Sendable {
    case tunjuk(target: String)
    case aksi(actionType: String, target: String)
    case tanya(query: String)
}
// MARK: - AuditLogService (PRD §A11, §A16, S4-security, MT-41)

public struct AuditEventItem: Identifiable, Codable, Sendable, Equatable {
    public var id: String { eventId }
    public let eventId: String
    public let timestamp: Date
    public let eventType: String
    public let actorSlug: String
    public let actionDescription: String
    public let metadata: [String: String]

    public init(
        eventId: String = UUID().uuidString,
        timestamp: Date = Date(),
        eventType: String,
        actorSlug: String,
        actionDescription: String,
        metadata: [String: String] = [:]
    ) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.eventType = eventType
        self.actorSlug = actorSlug
        self.actionDescription = actionDescription
        self.metadata = metadata
    }
}

public final class AuditLogService: @unchecked Sendable {
    public static let shared = AuditLogService()

    private let lock = NSLock()
    private var events: [AuditEventItem] = []
    private let logFileURL: URL
    public static let maxAuditRetention = 1000

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let baseDir = home.appendingPathComponent(".izanotchy", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.logFileURL = baseDir.appendingPathComponent("audit_logs.json")
        loadLogs()
    }

    /// Records a control-plane event with strict redaction of PEM keys, tokens, and passwords
    @discardableResult
    public func recordEvent(
        type: String,
        actor: String,
        description: String,
        metadata: [String: String] = [:]
    ) -> AuditEventItem {
        lock.lock()
        defer { lock.unlock() }

        // Apply strict redaction to description and metadata values
        let cleanDescription = Self.maskSensitiveContent(description)
        var cleanMetadata: [String: String] = [:]
        for (k, v) in metadata {
            cleanMetadata[k] = Self.maskSensitiveContent(v)
        }

        let item = AuditEventItem(
            eventType: type,
            actorSlug: actor,
            actionDescription: cleanDescription,
            metadata: cleanMetadata
        )

        events.append(item)
        if events.count > Self.maxAuditRetention {
            events = Array(events.suffix(Self.maxAuditRetention))
        }

        saveLogs()
        ClickyLogger.info("[AUDIT_LOG]", "Recorded control-plane event '\(type)' by '\(actor)': \(cleanDescription)")
        return item
    }

    /// Exports audit log to disk as a JSON artifact
    public func exportAuditLog() -> URL? {
        lock.lock()
        let items = events
        lock.unlock()

        let home = FileManager.default.homeDirectoryForCurrentUser
        let exportDir = home.appendingPathComponent(".izanotchy/shared_workspace/audit_exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestampStr = formatter.string(from: Date())
        let exportURL = exportDir.appendingPathComponent("audit_export_\(timestampStr).json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(items) else { return nil }
        try? data.write(to: exportURL, options: .atomic)
        ClickyLogger.info("[AUDIT_LOG]", "Exported \(items.count) audit events to \(exportURL.path)")
        return exportURL
    }

    /// Strict Redaction Filter: masks PEM blocks, Bearer tokens, passwords, and sensitive keys
    public static func maskSensitiveContent(_ text: String) -> String {
        var result = text
        // 1. PEM Key blocks
        let pemPattern = #"-----BEGIN[A-Z0-9\s_-]+KEY-----[\s\S]*?-----END[A-Z0-9\s_-]+KEY-----"#
        result = result.replacingOccurrences(of: pemPattern, with: "[REDACTED_PEM_KEY]", options: .regularExpression)
        // 2. Bearer tokens
        result = result.replacingOccurrences(of: #"(Bearer\s+)[A-Za-z0-9_\-\.]{10,}"#, with: "$1[REDACTED]", options: .regularExpression)
        // 3. Passwords & Secrets in JSON/text
        result = result.replacingOccurrences(of: #"("password"\s*:\s*")[^"]+(")"#, with: "$1[REDACTED]$2", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(api[_-]?key\s*[=:]\s*)[A-Za-z0-9_\-]{12,}"#, with: "$1[REDACTED]", options: .regularExpression)
        return result
    }

    private func saveLogs() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(events) {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }

    private func loadLogs() {
        guard FileManager.default.fileExists(atPath: logFileURL.path),
              let data = try? Data(contentsOf: logFileURL),
              let list = try? JSONDecoder().decode([AuditEventItem].self, from: data) else {
            return
        }
        self.events = list.count > Self.maxAuditRetention ? Array(list.suffix(Self.maxAuditRetention)) : list
    }
}
