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
        requiresTakeoverOnCompletion: Bool = false
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

// MARK: - Validation & Response Contract (Egress Output)
public struct AFMValidationResult: Codable, Sendable {
    public let isDone: Bool
    public let systemState: String
    public let extractedData: String
    public let responseToUser: String
    public let requiresTakeover: Bool

    public init(
        isDone: Bool,
        systemState: String,
        extractedData: String = "none",
        responseToUser: String,
        requiresTakeover: Bool = false
    ) {
        self.isDone = isDone
        self.systemState = systemState
        self.extractedData = extractedData
        self.responseToUser = responseToUser
        self.requiresTakeover = requiresTakeover
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
