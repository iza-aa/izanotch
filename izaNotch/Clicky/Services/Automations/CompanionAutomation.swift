//
//  CompanionAutomation.swift
//  izaNotch (Izanotchy)
//
//  Declarative Data Contract for Companion Automations (TASK-046 Fase D).
//  Supports Interval and Time-of-Day Triggers with Strict Retry & Parking Policy.
//

import Foundation

struct CompanionAutomationTrigger: Codable, Sendable, Equatable {
    enum TriggerType: String, Codable, Sendable {
        case interval
        case timeOfDay
    }

    let type: TriggerType
    let intervalSeconds: Int?
    let scheduledTime: String? // "HH:mm"

    init(intervalSeconds: Int) {
        self.type = .interval
        self.intervalSeconds = intervalSeconds
        self.scheduledTime = nil
    }

    init(scheduledTime: String) {
        self.type = .timeOfDay
        self.intervalSeconds = nil
        self.scheduledTime = scheduledTime
    }
}

struct CompanionAutomation: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let prompt: String
    let targetBuddySlug: String
    let trigger: CompanionAutomationTrigger
    var isEnabled: Bool
    var lastRunAt: Date?
    var nextRunAt: Date?
    var consecutiveFailures: Int
    var isParked: Bool
    var parkedReason: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        prompt: String,
        targetBuddySlug: String,
        trigger: CompanionAutomationTrigger,
        isEnabled: Bool = true,
        lastRunAt: Date? = nil,
        nextRunAt: Date? = nil,
        consecutiveFailures: Int = 0,
        isParked: Bool = false,
        parkedReason: String? = nil
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.targetBuddySlug = targetBuddySlug
        self.trigger = trigger
        self.isEnabled = isEnabled
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt
        self.consecutiveFailures = consecutiveFailures
        self.isParked = isParked
        self.parkedReason = parkedReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.prompt = try container.decode(String.self, forKey: .prompt)
        self.targetBuddySlug = try container.decode(String.self, forKey: .targetBuddySlug)
        self.trigger = try container.decode(CompanionAutomationTrigger.self, forKey: .trigger)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.lastRunAt = try container.decodeIfPresent(Date.self, forKey: .lastRunAt)
        self.nextRunAt = try container.decodeIfPresent(Date.self, forKey: .nextRunAt)
        self.consecutiveFailures = try container.decodeIfPresent(Int.self, forKey: .consecutiveFailures) ?? 0
        self.isParked = try container.decodeIfPresent(Bool.self, forKey: .isParked) ?? false
        self.parkedReason = try container.decodeIfPresent(String.self, forKey: .parkedReason)
    }
}
