//
//  CompanionAutomation.swift
//  izaNotch (Izanotchy)
//
//  Declarative Data Contract for Companion Automations (TASK-046 Fase D).
//  Supports Interval and Time-of-Day Triggers with Strict Retry & Parking Policy.
//

import Foundation

public struct RoutineRunRecord: Codable, Sendable, Identifiable, Equatable {
    public var id: String { runId }
    public let runId: String
    public let at: String
    public let status: String // "success" | "failed" | "parked"
    public let summary: String?

    public init(
        runId: String = UUID().uuidString,
        at: String = ISO8601DateFormatter().string(from: Date()),
        status: String,
        summary: String? = nil
    ) {
        self.runId = runId
        self.at = at
        self.status = status
        self.summary = summary
    }
}

public struct CompanionAutomationTrigger: Codable, Sendable, Equatable {
    public enum TriggerType: String, Codable, Sendable {
        case interval
        case scheduled
        case timeOfDay
        case event
    }

    public let type: TriggerType
    public let intervalSeconds: Int?
    public let scheduledTime: String? // "HH:mm"
    public let eventName: String?
    public let timezone: String

    public init(intervalSeconds: Int, timezone: String = TimeZone.current.identifier) {
        self.type = .interval
        // PRD §A8 & MT-07 limit: minimum 5 menit (300 detik) antar jadwal
        self.intervalSeconds = max(300, intervalSeconds)
        self.scheduledTime = nil
        self.eventName = nil
        self.timezone = timezone
    }

    public init(scheduledTime: String, timezone: String = TimeZone.current.identifier) {
        self.type = .scheduled
        self.intervalSeconds = nil
        self.scheduledTime = scheduledTime
        self.eventName = nil
        self.timezone = timezone
    }

    public init(eventName: String, timezone: String = TimeZone.current.identifier) {
        self.type = .event
        self.intervalSeconds = nil
        self.scheduledTime = nil
        self.eventName = eventName
        self.timezone = timezone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(TriggerType.self, forKey: .type)
        let rawInterval = try container.decodeIfPresent(Int.self, forKey: .intervalSeconds)
        self.intervalSeconds = rawInterval != nil ? max(300, rawInterval!) : nil
        self.scheduledTime = try container.decodeIfPresent(String.self, forKey: .scheduledTime)
        self.eventName = try container.decodeIfPresent(String.self, forKey: .eventName)
        self.timezone = try container.decodeIfPresent(String.self, forKey: .timezone) ?? TimeZone.current.identifier
    }
}

public struct CompanionAutomation: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var prompt: String
    public var owningCompanion: String
    public var targetBuddySlug: String { owningCompanion }
    public var skillOrPrompt: String { prompt }
    public var trigger: CompanionAutomationTrigger
    public var isEnabled: Bool
    public var approvalBoundary: [String]
    public var noDataPolicy: String
    public var maxRuns: Int?
    public var lastRunAt: Date?
    public var nextRunAt: Date?
    public var consecutiveFailures: Int
    public var isParked: Bool
    public var parkedReason: String?
    public var runHistory: [RoutineRunRecord]

    public init(
        id: String = UUID().uuidString,
        name: String,
        prompt: String,
        targetBuddySlug: String,
        trigger: CompanionAutomationTrigger,
        isEnabled: Bool = true,
        approvalBoundary: [String] = [],
        noDataPolicy: String = "pause_and_notify",
        maxRuns: Int? = nil,
        lastRunAt: Date? = nil,
        nextRunAt: Date? = nil,
        consecutiveFailures: Int = 0,
        isParked: Bool = false,
        parkedReason: String? = nil,
        runHistory: [RoutineRunRecord] = []
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.owningCompanion = targetBuddySlug
        self.trigger = trigger
        self.isEnabled = isEnabled
        self.approvalBoundary = approvalBoundary
        self.noDataPolicy = noDataPolicy
        self.maxRuns = maxRuns
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt
        self.consecutiveFailures = consecutiveFailures
        self.isParked = isParked
        self.parkedReason = parkedReason
        // Cap run history at max 20 records
        self.runHistory = runHistory.count > 20 ? Array(runHistory.suffix(20)) : runHistory
    }

    enum CodingKeys: String, CodingKey {
        case id, name, prompt, skillOrPrompt, targetBuddySlug, owningCompanion
        case trigger, isEnabled, approvalBoundary, noDataPolicy, maxRuns
        case lastRunAt, nextRunAt, consecutiveFailures, isParked, parkedReason, runHistory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        let decodedPrompt = try container.decodeIfPresent(String.self, forKey: .prompt)
            ?? container.decodeIfPresent(String.self, forKey: .skillOrPrompt)
            ?? ""
        self.prompt = decodedPrompt
        let decodedSlug = try container.decodeIfPresent(String.self, forKey: .owningCompanion)
            ?? container.decodeIfPresent(String.self, forKey: .targetBuddySlug)
            ?? "inbox-buddy"
        self.owningCompanion = decodedSlug
        self.trigger = try container.decode(CompanionAutomationTrigger.self, forKey: .trigger)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.approvalBoundary = try container.decodeIfPresent([String].self, forKey: .approvalBoundary) ?? []
        self.noDataPolicy = try container.decodeIfPresent(String.self, forKey: .noDataPolicy) ?? "pause_and_notify"
        self.maxRuns = try container.decodeIfPresent(Int.self, forKey: .maxRuns)
        self.lastRunAt = try container.decodeIfPresent(Date.self, forKey: .lastRunAt)
        self.nextRunAt = try container.decodeIfPresent(Date.self, forKey: .nextRunAt)
        self.consecutiveFailures = try container.decodeIfPresent(Int.self, forKey: .consecutiveFailures) ?? 0
        self.isParked = try container.decodeIfPresent(Bool.self, forKey: .isParked) ?? false
        self.parkedReason = try container.decodeIfPresent(String.self, forKey: .parkedReason)
        let rawHistory = try container.decodeIfPresent([RoutineRunRecord].self, forKey: .runHistory) ?? []
        self.runHistory = rawHistory.count > 20 ? Array(rawHistory.suffix(20)) : rawHistory
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(prompt, forKey: .skillOrPrompt)
        try container.encode(owningCompanion, forKey: .owningCompanion)
        try container.encode(owningCompanion, forKey: .targetBuddySlug)
        try container.encode(trigger, forKey: .trigger)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(approvalBoundary, forKey: .approvalBoundary)
        try container.encode(noDataPolicy, forKey: .noDataPolicy)
        try container.encodeIfPresent(maxRuns, forKey: .maxRuns)
        try container.encodeIfPresent(lastRunAt, forKey: .lastRunAt)
        try container.encodeIfPresent(nextRunAt, forKey: .nextRunAt)
        try container.encode(consecutiveFailures, forKey: .consecutiveFailures)
        try container.encode(isParked, forKey: .isParked)
        try container.encodeIfPresent(parkedReason, forKey: .parkedReason)
        try container.encode(runHistory, forKey: .runHistory)
    }
}
