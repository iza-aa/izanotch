//
//  CompanionVMBackgroundWatcher.swift
//  izaNotch
//
//  Continuous Background Watcher for Companion VMs (1:1 Grok Bot).
//  Periodically monitors the companion's virtual workspace and proactively
//  notifies the user via floating rail badges and chat messages when important items arrive.
//

import Foundation
import SwiftUI

@MainActor
public final class CompanionVMBackgroundWatcher: ObservableObject {
    public static let shared = CompanionVMBackgroundWatcher()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var lastCheckTime: Date? = nil

    private var watcherTask: Task<Void, Never>? = nil
    private let checkIntervalSeconds: UInt64 = 60
    private var alertedItemIds: Set<String> = []

    private init() {}

    // MARK: - Lifecycle Control

    /// Starts the continuous background VM watcher loop
    public func start() {
        guard !isRunning else {
            ClickyLogger.info("[VM_WATCHER]", "Companion VM background watcher is already running.")
            return
        }

        isRunning = true
        ClickyLogger.info("[VM_WATCHER]", "Starting continuous Companion VM background watcher (interval: \(checkIntervalSeconds)s)...")

        watcherTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                await self.pollCycle()
                try? await Task.sleep(nanoseconds: self.checkIntervalSeconds * 1_000_000_000)
            }
        }
    }

    /// Stops the continuous background VM watcher loop
    public func stop() {
        ClickyLogger.info("[VM_WATCHER]", "Stopping Companion VM background watcher.")
        watcherTask?.cancel()
        watcherTask = nil
        isRunning = false
    }

    // MARK: - Polling Cycle

    /// Executes one inspection cycle across all active companions in virtual sandbox
    public func pollCycle() async {
        lastCheckTime = Date()
        let companions = CompanionRosterStore.shared.allCompanions
        let sandboxCompanions = companions.filter { $0.executionDomain == .virtualSandbox }

        for companion in sandboxCompanions {
            await inspectSandboxForImportantItems(companion: companion)
        }

        // TASK-046 Fase D: Evaluate and trigger scheduled automations
        await evaluateAutomations()
    }

    private func inspectSandboxForImportantItems(companion: CompanionProfile) async {
        let slug = companion.slug
        let workspaceDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".izanotchy/companions/\(slug)/workspace", isDirectory: true)

        // Check if there is an incoming queue or deliverable folder with urgent items
        let incomingQueueDir = workspaceDir.appendingPathComponent("incoming", isDirectory: true)
        if !FileManager.default.fileExists(atPath: incomingQueueDir.path) {
            try? FileManager.default.createDirectory(at: incomingQueueDir, withIntermediateDirectories: true)
        }

        // Check for simulated or queued urgent items
        if let files = try? FileManager.default.contentsOfDirectory(atPath: incomingQueueDir.path) {
            for file in files where file.hasSuffix(".json") && !alertedItemIds.contains(file) {
                let fileURL = incomingQueueDir.appendingPathComponent(file)
                if let data = try? Data(contentsOf: fileURL),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let subject = json["subject"] as? String ?? "Pesan Penting"
                    let sender = json["sender"] as? String ?? "Sistem"
                    let preview = json["preview"] as? String ?? ""

                    alertedItemIds.insert(file)
                    triggerProactiveAlert(companionSlug: slug, subject: subject, sender: sender, preview: preview)
                }
            }
        }
    }
    // MARK: - Automation Trigger Evaluation (TASK-046 Fase D)

    /// Evaluates due automations from the store and dispatches them autonomously with a unique runId.
    public func evaluateAutomations() async {
        let isTakeover = await MainActor.run { CompanionVMViewportController.shared.isTakeoverActive }
        guard !WebWorkspaceLoginWindowController.shared.isLoginWindowOpen && !isTakeover else {
            ClickyLogger.info("[VM_WATCHER]", "[AUTOMATION_PARKED] Skipping automation evaluation: Web Workspace is currently awaiting login or active human takeover.")
            return
        }
        let store = CompanionAutomationStore.shared
        let due = store.dueAutomations(at: Date())
        for auto in due {
            let runId = "auto-" + UUID().uuidString.prefix(8)
            ClickyLogger.info(
                "[VM_WATCHER]",
                "[AUTOMATION] Firing scheduled automation '\(auto.name)' (runId=\(runId)) for companion '\(auto.targetBuddySlug)': prompt='\(auto.prompt)'"
            )

            store.recordExecution(id: auto.id, at: Date())

            // Set active E2E runId directly on companion manager
            #if DEBUG
            CompanionManager.shared.activeE2ERunId = String(runId)
            #endif

            // Production internal dispatch to HomeSpace prompt entrypoint (Single Source of Truth)
            NotificationCenter.default.post(
                name: Notification.Name("HomeSpaceSubmitPrompt"),
                object: auto.prompt,
                userInfo: [
                    "runId": String(runId),
                    "companionSlug": auto.targetBuddySlug,
                    "isAutomation": true
                ]
            )
        }
    }

    // MARK: - Proactive Alert Notification (1:1 Grok Bot)

    /// Triggers a proactive notification message from the mascot and presents it on the floating rail
    public func triggerProactiveAlert(
        companionSlug: String,
        subject: String,
        sender: String,
        preview: String
    ) {
        guard let companion = CompanionRosterStore.shared.allCompanions.first(where: { $0.slug == companionSlug }) else {
            ClickyLogger.warning("[VM_WATCHER]", "Cannot dispatch proactive alert: companion \(companionSlug) not found in roster.")
            return
        }

        Task { @MainActor in
            let detectedLang = TaskIngressGateway.resolveLanguage(prompt: "\(subject) \(sender) \(preview)")
            let alertText = await TaskEgressValidator.shared.synthesizeNotice(
                noticeSummary: "Important new message in Inbox: \"\(subject)\" from \(sender). Offer to read contents or draft reply.",
                appName: "Mail",
                userGoal: "Proactive Inbox Alert",
                userLanguage: detectedLang
            )
            let assistantMessage = HomeSpaceChatMessage(
                isUser: false,
                text: alertText,
                timestamp: Date()
            )

            ClickyLogger.info("[VM_WATCHER]", "Proactive alert dispatched for [\(companion.name)]: \"\(subject)\" from \(sender)")

            // Append to companion conversation
            CompanionRosterStore.shared.appendMessage(assistantMessage, forCompanionId: companion.id)

            // Present companion on the floating rail with unread badge (1:1 Grok Bot)
            CompanionRosterStore.shared.presentCompanionOnRail(id: companion.id)
            ClickySoundEngine.shared.play(.receive)
        }
    }
}
