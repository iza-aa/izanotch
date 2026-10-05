import ClickyFoundation
//
//  PCCGroundingEscalation.swift
//  boringNotch (Izanotchy)
//
//  PCC (Private Cloud Compute) escalation path for heavy grounding turns.
//  Status (verified 2026-09-21 on this Mac): on-device ctx 8192, PCC ctx
//  32768, isAvailable == true, quota belowLimit — but respond() fails at
//  runtime with ModelManagerError 1046 (system-side, same for text and image).
//  So this client is a capability probe + opt-in scaffold: it never fires by
//  default, and every call fails closed (returns nil) when PCC is unusable.
//  Re-verify with /tmp/pcctext + /tmp/pccimg probes before enabling.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 27.0, *)
@MainActor
enum PCCGroundingEscalation {

    /// Cached probe outcome so we don't hammer ModelManager per turn.
    private static var probeCache: (at: Date, usable: Bool)?

    static var isUsableCached: Bool {
        if let c = probeCache, Date().timeIntervalSince(c.at) < 300 { return c.usable }
        let usable = probeUsable()
        probeCache = (Date(), usable)
        return usable
    }

    private static func probeUsable() -> Bool {
        guard PrivateCloudComputeLanguageModel().isAvailable else { return false }
        guard case .available = PrivateCloudComputeLanguageModel().availability else { return false }
        return true
    }

    /// Opt-in heavy-grounding escalation: candidate-select over the SoM legend
    /// via PCC's 32k context (room for full legend + history that on-device
    /// 8k can't fit). Returns the selected candidate id, or nil (fail closed).
    /// NOTE: currently expected to fail with ModelManagerError 1046 until
    /// Apple fixes the system side — caller must always have a fallback.
    static func selectCandidate(
        transcript: String,
        legendLines: [String],
        timeoutSeconds: Double = 20
    ) async -> String? {
        guard isUsableCached, !legendLines.isEmpty else { return nil }
        do {
            return try await withThrowingTaskGroup(of: String?.self) { group in
                group.addTask {
                    let session = LanguageModelSession(
                        model: PrivateCloudComputeLanguageModel(),
                        instructions: "You pick UI element candidates. Reply with ONLY the candidate id.")
                    let prompt = "User wants: \(transcript)\nCandidates:\n"
                        + legendLines.joined(separator: "\n")
                        + "\nReply with ONLY the id (e.g. dock-whatsapp)."
                    let resp = try await session.respond(to: prompt)
                    let id = resp.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    ClickyLogger.info("[PCC]", "Escalation selected: \(id)")
                    return id.isEmpty ? nil : id
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                    return nil
                }
                let first = try await group.next() ?? nil
                group.cancelAll()
                return first
            }
        } catch {
            ClickyLogger.warning("[PCC]", "Escalation failed (fail closed): \(error.localizedDescription)")
            probeCache = (Date(), false)
            return nil
        }
    }
}
#else

@MainActor
enum PCCGroundingEscalation {
    static var isUsableCached: Bool { false }
    static func selectCandidate(transcript _: String, legendLines _: [String], timeoutSeconds _: Double = 20) async -> String? { nil }
}
#endif
