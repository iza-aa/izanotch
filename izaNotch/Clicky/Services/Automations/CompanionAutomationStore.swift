//
//  CompanionAutomationStore.swift
//  izaNotch (Izanotchy)
//
//  Actor / Store for Persisting and Managing Companion Automations (TASK-046 Fase D).
//  Persists declarative JSON to ~/.izanotchy/automations.json.
//  Enforces Strict Retry & Graceful Parking Policy (Max 3 retries without state change).
//

import Foundation

public enum AutomationStoreError: Error, LocalizedError, Equatable {
    case limitExceeded(String)
    case invalidInterval(String)

    public var errorDescription: String? {
        switch self {
        case .limitExceeded(let msg): return msg
        case .invalidInterval(let msg): return msg
        }
    }
}

@MainActor
final class CompanionAutomationStore: ObservableObject {
    static let shared = CompanionAutomationStore()

    public static let maxRoutinesPerCompanion = 50
    public static let maxRunRecordsPerRoutine = 20
    public static let minIntervalSeconds = 300 // 5 minutes

    @Published private(set) var automations: [CompanionAutomation] = []

    private let fileURL: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let baseDir = home.appendingPathComponent(".izanotchy", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.fileURL = baseDir.appendingPathComponent("automations.json")

        loadAutomations()
        if automations.isEmpty {
            seedDefaultAutomations()
        }
    }

    // MARK: - Persistence

    func loadAutomations() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            self.automations = try JSONDecoder().decode([CompanionAutomation].self, from: data)
            ClickyLogger.info("[AUTOMATION_STORE]", "Loaded \(automations.count) automations from disk.")
        } catch {
            ClickyLogger.warning("[AUTOMATION_STORE]", "Error loading automations: \(error.localizedDescription)")
        }
    }

    func saveAutomations() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(automations)
            try data.write(to: fileURL, options: .atomic)
            ClickyLogger.info("[AUTOMATION_STORE]", "Saved \(automations.count) automations to disk.")
        } catch {
            ClickyLogger.warning("[AUTOMATION_STORE]", "Error saving automations: \(error.localizedDescription)")
        }
    }

    // MARK: - Scheduling & Trigger Evaluation

    /// Adds a new routine enforcing the 50 routine limit per companion and minimum 5-minute interval
    public func addAutomation(_ automation: CompanionAutomation) throws {
        let companionCount = automations.filter { $0.owningCompanion == automation.owningCompanion }.count
        if companionCount >= Self.maxRoutinesPerCompanion {
            throw AutomationStoreError.limitExceeded("Batas maksimum 50 routine per companion tercapai. Hapus routine yang tidak aktif untuk menambah baru.")
        }
        if let interval = automation.trigger.intervalSeconds, interval < Self.minIntervalSeconds {
            throw AutomationStoreError.invalidInterval("Interval minimum antar jadwal adalah 5 menit (300 detik).")
        }
        automations.append(automation)
        saveAutomations()
        ClickyLogger.info("[AUTOMATION_STORE]", "Added routine '\(automation.name)' for \(automation.owningCompanion) (total: \(companionCount + 1)/50)")
    }

    /// Returns list of automations that are due for execution at the given timestamp.
    /// Evaluates companion timezone and excludes disabled/parked automations.
    func dueAutomations(at date: Date = Date()) -> [CompanionAutomation] {
        guard !WebWorkspaceLoginWindowController.shared.isLoginWindowOpen else { return [] }
        return automations.filter { automation in
            guard automation.isEnabled, !automation.isParked else { return false }

            switch automation.trigger.type {
            case .interval:
                guard let interval = automation.trigger.intervalSeconds, interval > 0 else { return false }
                if let last = automation.lastRunAt {
                    return date.timeIntervalSince(last) >= Double(interval)
                }
                return true

            case .scheduled, .timeOfDay:
                guard let scheduled = automation.trigger.scheduledTime else { return false }
                let tz = TimeZone(identifier: automation.trigger.timezone) ?? TimeZone.current
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                formatter.timeZone = tz
                let currentStr = formatter.string(from: date)
                if currentStr == scheduled {
                    var cal = Calendar.current
                    cal.timeZone = tz
                    if let last = automation.lastRunAt {
                        return !cal.isDate(last, inSameDayAs: date)
                    }
                    return true
                }
                return false

            case .event:
                return false
            }
        }
    }

    /// Records an execution timestamp for the given automation.
    func recordExecution(id: String, at date: Date = Date()) {
        if let idx = automations.firstIndex(where: { $0.id == id }) {
            automations[idx].lastRunAt = date
            if let interval = automations[idx].trigger.intervalSeconds {
                automations[idx].nextRunAt = date.addingTimeInterval(Double(interval))
            }
            saveAutomations()
        }
    }

    /// Records the execution outcome to enforce max 3 retries without state change and caps history at 20.
    func recordOutcome(id: String, success: Bool, runId: String = UUID().uuidString, reason: String? = nil) {
        guard let idx = automations.firstIndex(where: { $0.id == id }) else { return }

        let currentIso = ISO8601DateFormatter().string(from: Date())
        let statusString: String

        if success {
            automations[idx].consecutiveFailures = 0
            automations[idx].isParked = false
            automations[idx].parkedReason = nil
            statusString = "success"
            ClickyLogger.info("[AUTOMATION_STORE]", "Automation '\(automations[idx].name)' succeeded; reset consecutiveFailures=0.")
        } else {
            automations[idx].consecutiveFailures += 1
            let fails = automations[idx].consecutiveFailures
            ClickyLogger.warning("[AUTOMATION_STORE]", "Automation '\(automations[idx].name)' failed attempt \(fails)/3: \(reason ?? "unknown").")
            if fails >= 3 {
                automations[idx].isParked = true
                automations[idx].parkedReason = reason ?? "Awaiting login / action required"
                statusString = "parked"

                ClickyLogger.warning("[AUTOMATION_STORE]", "Automation '\(automations[idx].name)' reached 3 consecutive failures. Parking task to prevent infinite retry loops.")

                NotificationCenter.default.post(
                    name: Notification.Name("CompanionProactiveNotice"),
                    object: nil,
                    userInfo: [
                        "slug": automations[idx].targetBuddySlug,
                        "subject": "Login Diperlukan",
                        "sender": "Automasi",
                        "preview": "Automasi '\(automations[idx].name)' diparkir sementara karena login diperlukan. Silakan login di Web Workspace untuk melanjutkan."
                    ]
                )
            } else {
                statusString = "failed"
            }
        }

        // Append to run history (capped at max 20)
        let record = RoutineRunRecord(runId: runId, at: currentIso, status: statusString, summary: reason)
        var history = automations[idx].runHistory
        history.append(record)
        if history.count > Self.maxRunRecordsPerRoutine {
            history = Array(history.suffix(Self.maxRunRecordsPerRoutine))
        }
        automations[idx].runHistory = history
        saveAutomations()
    }

    /// Unparks an automation when user completes login or manually triggers it.
    func unparkAutomation(id: String) {
        if let idx = automations.firstIndex(where: { $0.id == id }) {
            automations[idx].isParked = false
            automations[idx].consecutiveFailures = 0
            automations[idx].parkedReason = nil
            saveAutomations()
            ClickyLogger.info("[AUTOMATION_STORE]", "Automation '\(automations[idx].name)' unparked.")
        }
    }

    // MARK: - Default Seed

    private func seedDefaultAutomations() {
        let checkEmail = CompanionAutomation(
            id: "auto-check-email-60s",
            name: "Periodic Email Check",
            prompt: "check email saya",
            targetBuddySlug: "inbox-buddy",
            trigger: CompanionAutomationTrigger(intervalSeconds: 60),
            isEnabled: false, // Default is disabled (Opt-In only) to prevent unprompted spam
            lastRunAt: nil,
            nextRunAt: nil,
            consecutiveFailures: 0,
            isParked: false,
            parkedReason: nil
        )
        self.automations = [checkEmail]
        saveAutomations()
    }
}
