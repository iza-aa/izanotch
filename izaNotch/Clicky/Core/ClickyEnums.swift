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

public struct HomeSpaceChatMessage: Identifiable, Codable, Equatable {
    public let id: UUID
    public let isUser: Bool
    public var text: String
    public let timestamp: Date
    public var computerPayload: ComputerCardPayload?
    public var egressResult: EgressResult?

    public init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        timestamp: Date = Date(),
        computerPayload: ComputerCardPayload? = nil,
        egressResult: EgressResult? = nil
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
        self.computerPayload = computerPayload
        self.egressResult = egressResult
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
            self.allowedSafariDomains = ["google.com", "mail.google.com", "salesforce.com"]
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
