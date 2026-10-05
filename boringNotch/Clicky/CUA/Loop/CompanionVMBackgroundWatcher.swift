//
//  CompanionVMBackgroundWatcher.swift
//  boringNotch
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
