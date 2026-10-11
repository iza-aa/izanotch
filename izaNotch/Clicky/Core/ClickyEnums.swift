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

    public init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        timestamp: Date = Date(),
        computerPayload: ComputerCardPayload? = nil,
        egressResult: EgressResult? = nil,
        attachments: [ChatAttachment] = [],
        voiceMemo: VoiceMemoData? = nil,
        liveVoiceChat: LiveVoiceChatSessionData? = nil
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
