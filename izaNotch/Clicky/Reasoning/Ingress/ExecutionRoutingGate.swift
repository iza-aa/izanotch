//
//  ExecutionRoutingGate.swift
//  izaNotch (Izanotchy)
//
//  Single Source of Truth for Autonomous Execution Tier Routing (TASK-046).
//  Deterministic Gate: "web" vs "native_cua".
//  Zero Hardcoding: Reads unified metadata directly from WebSiteAdapterRegistry.
//

import Foundation

public struct WebSurfaceDescriptor: Sendable {
    public let id: String
    public let supportedAppIdentifiers: Set<String>
    public let supportedIntentTypes: Set<String>
    public let description: String

    public init(
        id: String,
        supportedAppIdentifiers: Set<String>,
        supportedIntentTypes: Set<String>,
        description: String
    ) {
        self.id = id
        self.supportedAppIdentifiers = supportedAppIdentifiers
        self.supportedIntentTypes = supportedIntentTypes
        self.description = description
    }
}

public final class ExecutionRoutingGate: @unchecked Sendable {
    public static let shared = ExecutionRoutingGate()

    public init() {}

    /// Deterministically resolves executionTier ("web" | "native_cua") and reason.
    /// Reads directly from WebSiteAdapterRegistry (Unified Single Source of Truth).
    public func resolveExecutionTier(
        targetAppName: String,
        intentType: String,
        connectedApps: [String],
        isConversational: Bool
    ) -> (tier: String, reason: String, surfaceId: String?) {
        if isConversational {
            return ("native_cua", "Task is conversational without application operation", nil)
        }
        // Rule: companion without connected apps falls back to native_cua
        let cleanConnected = connectedApps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !cleanConnected.isEmpty else {
            return ("native_cua", "Companion has no connected apps configured; routing to native_cua fallback", nil)
        }
        let targetLower = targetAppName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let intentLower = intentType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Priority 1: Check ConnectorRegistry (Grok Bot protocol PRD §A5/§F5: "prefer a connector when available")
        let isEmailIntent = ["inspect", "read", "compose", "send", "search", "view"].contains(intentLower)
        let isEmailTarget = targetLower == "mail" || targetLower == "gmail" || cleanConnected.contains("mail") || cleanConnected.contains("gmail")
        if isEmailIntent && isEmailTarget && ConnectorRegistry.shared.isConnected(provider: .gmail) {
            let reason = "Connected Gmail account active via OAuth; routing to tier 'api_connector' (PRD §A5 priority)"
            ClickyLogger.info("[ROUTING]", "Resolved tier 'api_connector' surfaceId='gmail_api' for target '\(targetAppName)' and intent '\(intentType)': \(reason)")
            return ("api_connector", reason, "gmail_api")
        }

        // Priority 2: Match strictly against registered WebSiteAdapter capabilities
        for adapter in WebSiteAdapterRegistry.shared.adapters {
            let matchingConnected = cleanConnected.first { connected in
                adapter.supportedAppIdentifiers.contains(connected)
            }

            if let matchedApp = matchingConnected {
                let matchesTargetApp = targetLower.isEmpty || targetLower == "none" || adapter.supportedAppIdentifiers.contains(targetLower)
                let matchesIntent = adapter.supportedIntentTypes.contains(intentLower)

                if matchesTargetApp && matchesIntent {
                    return ("web", "Connected app '\(matchedApp)' supports web surface '\(adapter.id)' for target '\(targetAppName)' and intent '\(intentType)'", adapter.id)
                }
            }
        }

        return ("native_cua", "Connected apps [\(cleanConnected.joined(separator: ", "))] have no available web surface matching target '\(targetAppName)' and intent '\(intentType)'", nil)

    }
}
