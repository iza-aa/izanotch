//
//  CanonicalTaskContract.swift
//  izaNotch (Izanotchy)
//
//  Single Source of Truth for Autonomous CUA Inter-Model Contracts.
//  Zero Linguistic Prompt Injections — Canonical English JSON Protocol.
//

import AppKit
import Foundation

// MARK: - Task Decomposition Contract (Ingress Output)
public struct AFMTaskDecomposition: Codable, Sendable {
    public let userIntent: String
    public let targetAppName: String
    public let actionScope: String
    public let intentType: String
    public let targetEntity: String
    public let targetContainer: String?
    public let targetSection: String?
    public let targetIndex: Int?
    public let searchQuery: String?
    public let normalizedGoal: String
    public let userLanguage: String
    public let plannedSubGoals: [String]
    public let requiresCUA: Bool
    public let requiresTakeoverOnCompletion: Bool
    public let executionTier: String // "web" | "native_cua"
    public let routingReason: String?
    public let targetSurfaceId: String?

    public var isConversational: Bool {
        return !requiresCUA || targetAppName.lowercased() == "none" || intentType.lowercased() == "conversational"
    }

    public init(
        userIntent: String,
        targetAppName: String,
        actionScope: String,
        plannedSubGoals: [String] = [],
        requiresCUA: Bool = true,
        intentType: String = "inspect",
        targetEntity: String = "main_window",
        targetContainer: String? = nil,
        targetSection: String? = nil,
        targetIndex: Int? = nil,
        searchQuery: String? = nil,
        normalizedGoal: String = "",
        userLanguage: String = "id",
        requiresTakeoverOnCompletion: Bool = false,
        executionTier: String = "native_cua",
        routingReason: String? = nil,
        targetSurfaceId: String? = nil
    ) {
        self.userIntent = userIntent
        self.targetAppName = targetAppName
        self.actionScope = actionScope
        self.plannedSubGoals = plannedSubGoals
        self.requiresCUA = requiresCUA
        self.intentType = intentType
        self.targetEntity = targetEntity
        self.targetContainer = targetContainer
        self.targetSection = targetSection
        self.targetIndex = targetIndex
        self.searchQuery = searchQuery
        self.normalizedGoal = normalizedGoal.isEmpty ? userIntent : normalizedGoal
        self.userLanguage = userLanguage
        self.requiresTakeoverOnCompletion = requiresTakeoverOnCompletion
        self.executionTier = executionTier
        self.routingReason = routingReason
        self.targetSurfaceId = targetSurfaceId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userIntent = try container.decodeIfPresent(String.self, forKey: .userIntent) ?? ""
        self.targetAppName = try container.decodeIfPresent(String.self, forKey: .targetAppName) ?? "None"
        self.actionScope = try container.decodeIfPresent(String.self, forKey: .actionScope) ?? ""
        self.plannedSubGoals = try container.decodeIfPresent([String].self, forKey: .plannedSubGoals) ?? []
        let rawRequiresCUA = try container.decodeIfPresent(Bool.self, forKey: .requiresCUA)
        self.requiresCUA = rawRequiresCUA ?? (!targetAppName.isEmpty && targetAppName.lowercased() != "none")
        self.intentType = try container.decodeIfPresent(String.self, forKey: .intentType) ?? "inspect"
        self.targetEntity = try container.decodeIfPresent(String.self, forKey: .targetEntity) ?? "main_window"
        self.targetContainer = try container.decodeIfPresent(String.self, forKey: .targetContainer)
        self.targetSection = try container.decodeIfPresent(String.self, forKey: .targetSection)
        self.targetIndex = try container.decodeIfPresent(Int.self, forKey: .targetIndex)
        self.searchQuery = try container.decodeIfPresent(String.self, forKey: .searchQuery)
        let norm = try container.decodeIfPresent(String.self, forKey: .normalizedGoal) ?? ""
        self.normalizedGoal = norm.isEmpty ? self.userIntent : norm
        self.userLanguage = try container.decodeIfPresent(String.self, forKey: .userLanguage) ?? "id"
        self.requiresTakeoverOnCompletion = try container.decodeIfPresent(Bool.self, forKey: .requiresTakeoverOnCompletion) ?? false
        self.executionTier = try container.decodeIfPresent(String.self, forKey: .executionTier) ?? "native_cua"
        self.routingReason = try container.decodeIfPresent(String.self, forKey: .routingReason)
        self.targetSurfaceId = try container.decodeIfPresent(String.self, forKey: .targetSurfaceId)
    }
}

// MARK: - Atomic Step Decision Contract (Planner Output)
public struct AFMStepDecision: Codable, Sendable {
    public let thought: String
    public let subGoal: String
    public let targetElement: String
    public let actionType: String // "read", "click", "type", "scroll", "done"
    public let textToType: String?
    public let isFinished: Bool

    public init(
        thought: String = "",
        subGoal: String,
        targetElement: String,
        actionType: String = "click",
        textToType: String? = nil,
        isFinished: Bool = false
    ) {
        self.thought = thought
        self.subGoal = subGoal
        self.targetElement = targetElement
        self.actionType = actionType
        self.textToType = textToType
        self.isFinished = isFinished
    }
}

// MARK: - Validation & Response Contract (Egress Output — Schema C3)

public struct EgressReport: Codable, Sendable, Equatable {
    public var facts: [String]
    public var assumptions: [String]
    public var completedActions: [String]
    public var awaitingApproval: [String]
    public var openQuestions: [String]

    public init(
        facts: [String] = [],
        assumptions: [String] = [],
        completedActions: [String] = [],
        awaitingApproval: [String] = [],
        openQuestions: [String] = []
    ) {
        self.facts = facts
        self.assumptions = assumptions
        self.completedActions = completedActions
        self.awaitingApproval = awaitingApproval
        self.openQuestions = openQuestions
    }
}

public struct EgressEvidence: Codable, Sendable, Equatable {
    public var sourceLinks: [String]
    public var screenshots: [String]
    public var timestamps: [String]
    public var files: [String]
    public var actionLog: String
    public var unverified: [String]

    public init(
        sourceLinks: [String] = [],
        screenshots: [String] = [],
        timestamps: [String] = [],
        files: [String] = [],
        actionLog: String = "",
        unverified: [String] = []
    ) {
        self.sourceLinks = sourceLinks
        self.screenshots = screenshots
        self.timestamps = timestamps
        self.files = files
        self.actionLog = actionLog
        self.unverified = unverified
    }
}

public struct EgressDeliverable: Codable, Sendable, Equatable, Identifiable {
    public var id: String { artifact.isEmpty ? type : artifact }
    public var type: String
    public var artifact: String
    public var title: String?
    public var summary: String?
    public var version: Int

    public init(
        type: String,
        artifact: String,
        title: String? = nil,
        summary: String? = nil,
        version: Int = 1
    ) {
        self.type = type
        self.artifact = artifact
        self.title = title
        self.summary = summary
        self.version = version
    }
}

public struct EgressResult: Codable, Sendable, Equatable {
    public var runId: String
    public var concluded: Bool
    public var isDone: Bool
    public var report: EgressReport
    public var evidence: EgressEvidence
    public var deliverables: [EgressDeliverable]

    public init(
        runId: String,
        concluded: Bool = true,
        isDone: Bool = true,
        report: EgressReport = EgressReport(),
        evidence: EgressEvidence = EgressEvidence(),
        deliverables: [EgressDeliverable] = []
    ) {
        self.runId = runId
        self.concluded = concluded
        self.isDone = isDone
        self.report = report
        self.evidence = evidence
        self.deliverables = deliverables
    }
}

public struct AFMValidationResult: Codable, Sendable {
    public let isDone: Bool
    public let systemState: String
    public let extractedData: String
    public let responseToUser: String
    public let requiresTakeover: Bool
    public let egressResult: EgressResult?

    public init(
        isDone: Bool,
        systemState: String,
        extractedData: String = "none",
        responseToUser: String,
        requiresTakeover: Bool = false,
        egressResult: EgressResult? = nil
    ) {
        self.isDone = isDone
        self.systemState = systemState
        self.extractedData = extractedData
        self.responseToUser = responseToUser
        self.requiresTakeover = requiresTakeover
        self.egressResult = egressResult
    }
}

// MARK: - Vision & Element Perception Result
public struct LunaPerceptionResult: Sendable {
    public let targetElement: String
    public let coordinate: CGPoint
    public let confidence: Double
    public let sourceMethod: String

    public init(
        targetElement: String,
        coordinate: CGPoint,
        confidence: Double,
        sourceMethod: String
    ) {
        self.targetElement = targetElement
        self.coordinate = coordinate
        self.confidence = confidence
        self.sourceMethod = sourceMethod
    }
}
