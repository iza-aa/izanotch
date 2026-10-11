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
    public let isTestRun: Bool
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
        targetSurfaceId: String? = nil,
        isTestRun: Bool = false
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
        self.isTestRun = isTestRun
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
        self.isTestRun = try container.decodeIfPresent(Bool.self, forKey: .isTestRun) ?? false
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
// MARK: - Approval Contract (Schema C6)

public struct ApprovalRequest: Codable, Sendable, Identifiable, Equatable {
    public var id: String { actionId }
    public let actionId: String
    public let operation: String
    public let inputs: [String: String]
    public let options: [String] // ["allow_once", "always_allow", "deny"]
    public let source: String // "user" | "routine" | "bot_handoff"
    public let expiresAt: Date
    public var status: String // "pending" | "allowed_once" | "always_allowed" | "denied" | "expired"

    public var isExpired: Bool {
        return Date() > expiresAt
    }

    public init(
        actionId: String = UUID().uuidString,
        operation: String,
        inputs: [String: String] = [:],
        options: [String] = ["allow_once", "always_allow", "deny"],
        source: String = "routine",
        expiresAt: Date = Date().addingTimeInterval(600), // ~10 minutes per PRD §A12
        status: String = "pending"
    ) {
        self.actionId = actionId
        self.operation = operation
        self.inputs = inputs
        self.options = options
        self.source = source
        self.expiresAt = expiresAt
        self.status = status
    }
}

// MARK: - ApprovalManager (PRD §A12, MT-19: 10-Minute Expiry & Safe Retry Flow)

public final class ApprovalManager: @unchecked Sendable {
    public static let shared = ApprovalManager()

    private let lock = NSLock()
    private var requests: [String: ApprovalRequest] = [:]

    private init() {}

    /// Submits a new approval request with ~10-minute expiry
    @discardableResult
    public func requestApproval(
        operation: String,
        inputs: [String: String],
        source: String = "routine",
        expirySeconds: TimeInterval = 600
    ) -> ApprovalRequest {
        lock.lock()
        defer { lock.unlock() }

        let req = ApprovalRequest(
            actionId: UUID().uuidString,
            operation: operation,
            inputs: inputs,
            options: ["allow_once", "always_allow", "deny"],
            source: source,
            expiresAt: Date().addingTimeInterval(expirySeconds),
            status: "pending"
        )
        requests[req.actionId] = req
        ClickyLogger.info("[APPROVAL]", "Created approval request '\(req.actionId)' for '\(operation)' (expires in \(Int(expirySeconds))s)")
        return req
    }

    /// Evaluates status with automatic expiry enforcement
    public func evaluateStatus(actionId: String, at date: Date = Date()) -> String {
        lock.lock()
        defer { lock.unlock() }

        guard var req = requests[actionId] else { return "not_found" }
        if date > req.expiresAt && req.status == "pending" {
            req.status = "expired"
            requests[actionId] = req
            ClickyLogger.warning("[APPROVAL]", "Approval request '\(actionId)' has EXPIRED. Operation '\(req.operation)' halted.")
        }
        return req.status
    }

    /// Checks if action is permitted to execute. Returns false if expired, pending, or denied!
    public func canExecuteAction(actionId: String, at date: Date = Date()) -> Bool {
        let status = evaluateStatus(actionId: actionId, at: date)
        let allowed = (status == "allow_once" || status == "allowed_once" || status == "always_allow" || status == "always_allowed")
        if !allowed {
            ClickyLogger.warning("[APPROVAL]", "Action '\(actionId)' blocked by approval gate (status: '\(status)')")
        }
        return allowed
    }

    /// Resolves an approval (allow_once, always_allow, deny)
    public func resolveApproval(actionId: String, decision: String, at date: Date = Date()) -> (success: Bool, message: String) {
        lock.lock()
        defer { lock.unlock() }

        guard var req = requests[actionId] else {
            return (false, "Permintaan approval tidak ditemukan.")
        }
        if date > req.expiresAt {
            req.status = "expired"
            requests[actionId] = req
            return (false, "Approval telah kadaluarsa (~10 menit). Aksi dibatalkan secara aman.")
        }

        req.status = decision
        requests[actionId] = req
        ClickyLogger.info("[APPROVAL]", "Resolved approval '\(actionId)' -> '\(decision)'")
        return (true, "Approval berhasil diperbarui.")
    }

    /// Retries an expired approval by issuing a fresh 10-minute request
    public func retryExpiredApproval(actionId: String) -> ApprovalRequest? {
        lock.lock()
        let oldReq = requests[actionId]
        lock.unlock()

        guard let old = oldReq else { return nil }
        return requestApproval(operation: old.operation, inputs: old.inputs, source: old.source)
    }

    public func getRequest(actionId: String) -> ApprovalRequest? {
        lock.lock()
        defer { lock.unlock() }
        return requests[actionId]
    }
}
// MARK: - TrustDesignEngine (PRD §A8, §A12, MT-08: Trust Design & Test Run Gate)

final class ManagedAtomicSet: @unchecked Sendable {
    private let lock = NSLock()
    private var set: Set<String> = []

    func contains(_ item: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return set.contains(item)
    }

    func insert(_ item: String) {
        lock.lock()
        defer { lock.unlock() }
        set.insert(item)
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        set.removeAll()
    }
}

public final class TrustDesignEngine: Sendable {
    public static let shared = TrustDesignEngine()

    private init() {}

    /// Sensitive operations that strictly require explicit user approval
    public static let sensitiveOperations: Set<String> = [
        "send", "purchase", "delete", "publish", "modify_production",
        "transfer", "overwrite", "send_email", "execute_order"
    ]

    /// Evaluates if an operation requires approval boundary gating
    public func requiresApproval(operation: String, isTestRun: Bool = false) -> Bool {
        let op = operation.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if isTestRun {
            // In Test Run mode, ANY external mutation or sensitive operation requires approval!
            return Self.sensitiveOperations.contains(op) || op.contains("send") || op.contains("delete") || op.contains("buy") || op.contains("sell")
        }
        return Self.sensitiveOperations.contains(op)
    }

    /// Creates a standard Schema C6 Approval Request for a pending sensitive action
    public func createApprovalRequest(
        operation: String,
        inputs: [String: String],
        source: String = "routine"
    ) -> ApprovalRequest {
        return ApprovalRequest(
            actionId: UUID().uuidString,
            operation: operation,
            inputs: inputs,
            options: ["allow_once", "always_allow", "deny"],
            source: source,
            expiresAt: Date().addingTimeInterval(600), // ~10 minutes per PRD §A12
            status: "pending"
        )
    }

    /// Evaluates No-Data / Stale-Data policy without fabricating dummy data
    public func handleNoData(
        policy: String, // "pause_and_notify" | "skip"
        companionSlug: String,
        taskName: String
    ) -> (shouldHalt: Bool, resolutionMessage: String) {
        if policy == "skip" {
            ClickyLogger.info("[TRUST_DESIGN]", "No data found for '\(taskName)'. Gracefully skipping per policy.")
            return (false, "Data tidak ditemukan pada sumber. Tugas dilewati secara anggun.")
        } else {
            // Default: pause_and_notify
            ClickyLogger.warning("[TRUST_DESIGN]", "No data found for '\(taskName)'. Parking task per pause_and_notify policy.")
            return (true, "Data tidak ditemukan pada sumber. Tugas diparkir dan menunggu arahan pengguna.")
        }
    }

    /// Evaluates Idempotency Key to prevent duplicate external mutations on retry
    private static let executedIdempotencyKeys = ManagedAtomicSet()

    public func shouldExecuteIdempotent(key: String) -> Bool {
        guard !key.isEmpty else { return true }
        if Self.executedIdempotencyKeys.contains(key) {
            ClickyLogger.warning("[TRUST_DESIGN]", "Idempotent retry detected for key '\(key)'. Suppressed duplicate mutation.")
            return false
        }
        Self.executedIdempotencyKeys.insert(key)
        return true
    }

    /// Real Work warning for Test Run mode
    public static let testRunWarning = "Peringatan: Test run menyentuh aplikasi nyata dengan input aman (read-only/draft). Aksi eksternal yang berdampak permanen dicegah oleh approval boundary."
}
// MARK: - AutoReviewRuleEngine (PRD §A12, MT-17: Auto-Review Rule Engine & Invariant Resolution)

public enum AutoReviewRuleType: String, Codable, Sendable {
    case askFirst = "ask_first"
    case allowAutomatically = "allow_automatically"
}

public enum AutoReviewDecision: String, Codable, Sendable {
    case askFirst = "ask_first"
    case allowAutomatically = "allow_automatically"
}

public struct AutoReviewRule: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let type: AutoReviewRuleType
    public let operationPattern: String
    public let isSystemRule: Bool
    public let description: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: AutoReviewRuleType,
        operationPattern: String,
        isSystemRule: Bool = false,
        description: String = ""
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.operationPattern = operationPattern
        self.isSystemRule = isSystemRule
        self.description = description
    }

    public func matches(operation: String) -> Bool {
        let op = operation.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let pat = operationPattern.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if pat == "*" || pat == op { return true }
        if pat.hasSuffix("*") {
            let prefix = String(pat.dropLast())
            return op.hasPrefix(prefix)
        }
        if pat.hasPrefix("*") {
            let suffix = String(pat.dropFirst())
            return op.hasSuffix(suffix)
        }
        return op.contains(pat)
    }
}

public final class AutoReviewRuleEngine: @unchecked Sendable {
    public static let shared = AutoReviewRuleEngine()

    private let lock = NSLock()
    private var systemRules: [AutoReviewRule] = []
    private var personalRules: [AutoReviewRule] = []

    private init() {
        seedDefaultRules()
    }

    private func seedDefaultRules() {
        // System Rules (Cannot be loosened by personal rules)
        systemRules = [
            AutoReviewRule(
                name: "Require Approval For External Email Send",
                type: .askFirst,
                operationPattern: "send*",
                isSystemRule: true,
                description: "System rule: All external email sends require explicit human confirmation"
            ),
            AutoReviewRule(
                name: "Require Approval For File Deletion",
                type: .askFirst,
                operationPattern: "delete*",
                isSystemRule: true,
                description: "System rule: File deletion requires explicit human confirmation"
            ),
            AutoReviewRule(
                name: "Allow Automatic Local Inspection",
                type: .allowAutomatically,
                operationPattern: "inspect*",
                isSystemRule: true,
                description: "System rule: Read-only inspection operates automatically"
            )
        ]
    }

    /// Adds a personal rule. Invariant: Personal rules can only tighten (Ask first), never bypass system rules!
    public func addPersonalRule(_ rule: AutoReviewRule) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // Reject if personal rule attempts to loosen a system askFirst rule
        if rule.type == .allowAutomatically {
            let conflictsWithSystem = systemRules.contains { sys in
                sys.type == .askFirst && (sys.operationPattern == rule.operationPattern || rule.matches(operation: sys.operationPattern))
            }
            if conflictsWithSystem {
                ClickyLogger.warning("[AUTO_REVIEW]", "Rejected personal rule '\(rule.name)': Personal rules cannot loosen system Ask First rules.")
                return false
            }
        }

        personalRules.append(rule)
        ClickyLogger.info("[AUTO_REVIEW]", "Added personal rule '\(rule.name)' (\(rule.type.rawValue))")
        return true
    }

    /// Evaluates an operation against active rules.
    /// Invariant: "Ask first MENANG" (Ask first wins conflicts)!
    public func evaluate(operation: String) -> (decision: AutoReviewDecision, matchedRule: AutoReviewRule?, reason: String) {
        lock.lock()
        let allRules = systemRules + personalRules
        lock.unlock()

        // 1. Check if ANY rule (system or personal) matches with askFirst
        let askFirstMatches = allRules.filter { $0.type == .askFirst && $0.matches(operation: operation) }
        if let primaryAsk = askFirstMatches.first {
            let reason = "Rule '\(primaryAsk.name)' matched with Ask First. Invariant: Ask First wins conflicts."
            ClickyLogger.info("[AUTO_REVIEW]", "Evaluation for '\(operation)' -> ASK FIRST: \(reason)")
            return (.askFirst, primaryAsk, reason)
        }

        // 2. Check if a rule matches with allowAutomatically
        let allowMatches = allRules.filter { $0.type == .allowAutomatically && $0.matches(operation: operation) }
        if let primaryAllow = allowMatches.first {
            let reason = "Rule '\(primaryAllow.name)' matched with Allow Automatically (no Ask First conflicts)."
            ClickyLogger.info("[AUTO_REVIEW]", "Evaluation for '\(operation)' -> ALLOW AUTOMATICALLY: \(reason)")
            return (.allowAutomatically, primaryAllow, reason)
        }

        // 3. Fallback: Sensitive operations ask first, read-only operations allow
        let isSensitive = TrustDesignEngine.sensitiveOperations.contains(operation.lowercased())
        if isSensitive {
            let reason = "Operation '\(operation)' is classified as sensitive; default policy requires Ask First."
            return (.askFirst, nil, reason)
        } else {
            let reason = "Operation '\(operation)' is read-only/safe; default policy permits automatic execution."
            return (.allowAutomatically, nil, reason)
        }
    }
}
