//
//  CompanionAutomationStore.swift
//  izaNotch (Izanotchy)
//
//  Actor / Store for Persisting and Managing Companion Automations (TASK-046 Fase D).
//  Persists declarative JSON to ~/.izanotchy/automations.json.
//  Enforces Strict Retry & Graceful Parking Policy (Max 3 retries without state change).
//

import Foundation

@MainActor
final class CompanionAutomationStore: ObservableObject {
    static let shared = CompanionAutomationStore()

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

    /// Returns list of automations that are due for execution at the given timestamp.
    /// Excludes disabled and parked automations (Zero infinite retry loops).
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

            case .timeOfDay:
                guard let scheduled = automation.trigger.scheduledTime else { return false }
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                let currentStr = formatter.string(from: date)
                if currentStr == scheduled {
                    if let last = automation.lastRunAt {
                        return !Calendar.current.isDate(last, inSameDayAs: date)
                    }
                    return true
                }
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

    /// Records the execution outcome to enforce max 3 retries without state change.
    func recordOutcome(id: String, success: Bool, reason: String? = nil) {
        guard let idx = automations.firstIndex(where: { $0.id == id }) else { return }

        if success {
            automations[idx].consecutiveFailures = 0
            automations[idx].isParked = false
            automations[idx].parkedReason = nil
            saveAutomations()
            ClickyLogger.info("[AUTOMATION_STORE]", "Automation '\(automations[idx].name)' succeeded; reset consecutiveFailures=0.")
        } else {
            automations[idx].consecutiveFailures += 1
            let fails = automations[idx].consecutiveFailures
            ClickyLogger.warning("[AUTOMATION_STORE]", "Automation '\(automations[idx].name)' failed attempt \(fails)/3: \(reason ?? "unknown").")
            if fails >= 3 {
                automations[idx].isParked = true
                automations[idx].parkedReason = reason ?? "Awaiting login / action required"
                saveAutomations()

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
                saveAutomations()
            }
        }
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
