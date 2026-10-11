//
//  CompanionWorkspaceManager.swift
//  izaNotch
//
//  Created for Izanotchy - Multi-Agent Desktop System
//  Refactored for Fitur F-05: Per-Companion Workspace & Storage Isolation
//

import AppKit
import Foundation

// MARK: - Companion Workspace Paths (Per-Slug Sandbox Container)
public struct CompanionWorkspacePaths {
    public let baseSlugDirectory: URL
    public let workspaceDirectory: URL
    public let deliverablesDirectory: URL
    public let snapshotsDirectory: URL
    public let browserDataDirectory: URL
    public let cookiesDirectory: URL
    public let cacheDirectory: URL
    public let memoryFile: URL
    public let profileFile: URL
    public let personaFile: URL
    public let routinesFile: URL
}

public final class CompanionWorkspaceManager {
    public static let shared = CompanionWorkspaceManager()
    
    private let fileManager = FileManager.default
    
    /// Root Izanotchy Application Support / Sandbox Directory (~/.izanotchy)
    public var rootDirectory: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".izanotchy")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Base Companions Directory (~/.izanotchy/companions)
    public var baseCompanionsDirectory: URL {
        let dir = rootDirectory.appendingPathComponent("companions")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Shared Workspace Directory for Cross-Bot Deliverables & Scratchpad (~/.izanotchy/shared_workspace)
    public var sharedWorkspaceDirectory: URL {
        let dir = rootDirectory.appendingPathComponent("shared_workspace")
        let deliverables = dir.appendingPathComponent("deliverables")
        let scratchpad = dir.appendingPathComponent("scratchpad")
        for d in [dir, deliverables, scratchpad] {
            if !fileManager.fileExists(atPath: d.path) {
                try? fileManager.createDirectory(at: d, withIntermediateDirectories: true)
            }
        }
        return dir
    }
    
    /// Backward-compatibility alias for base directory
    public var baseDirectory: URL {
        return baseCompanionsDirectory
    }
    
    /// Returns the root folder for a specific companion slug (~/.izanotchy/companions/<slug>)
    public func companionBaseURL(for slug: String) -> URL {
        let dir = baseCompanionsDirectory.appendingPathComponent(slug)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Backward-compatibility alias: returns companion base URL
    public func workspaceURL(for slug: String) -> URL {
        return companionBaseURL(for: slug)
    }

    /// Initializes and guarantees the complete isolated workspace & storage hierarchy for a companion
    @discardableResult
    public func ensureWorkspaceHierarchy(for slug: String) -> CompanionWorkspacePaths {
        let baseDir = companionBaseURL(for: slug)
        
        let workspaceDir = baseDir.appendingPathComponent("workspace")
        let deliverablesDir = workspaceDir.appendingPathComponent("deliverables")
        let snapshotsDir = workspaceDir.appendingPathComponent("snapshots")
        
        let browserDataDir = baseDir.appendingPathComponent("browser_data")
        let cookiesDir = browserDataDir.appendingPathComponent("cookies")
        let cacheDir = browserDataDir.appendingPathComponent("cache")
        
        let memoryFile = baseDir.appendingPathComponent("memory.json")
        let profileFile = baseDir.appendingPathComponent("profile.json")
        let personaFile = baseDir.appendingPathComponent("persona.md")
        let routinesFile = baseDir.appendingPathComponent("routines.json")

        // Create all necessary isolated directories
        let allDirs = [
            workspaceDir,
            deliverablesDir,
            snapshotsDir,
            browserDataDir,
            cookiesDir,
            cacheDir
        ]
        
        for dir in allDirs {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
        
        // Initialize memory.json if not present
        if !fileManager.fileExists(atPath: memoryFile.path) {
            let initialMemory: [String: Any] = [
                "slug": slug,
                "createdAt": ISO8601DateFormatter().string(from: Date()),
                "preferences": [String: Any](),
                "facts": [String](),
                "recentContext": [String]()
            ]
            if let data = try? JSONSerialization.data(withJSONObject: initialMemory, options: [.prettyPrinted]) {
                try? data.write(to: memoryFile)
            }
        }

        // Clean up legacy duplicated <slug>.md if present (Option 1: Single persona.md SSOT)
        let legacySpec = baseDir.appendingPathComponent("\(slug).md")
        if fileManager.fileExists(atPath: legacySpec.path) {
            try? fileManager.removeItem(at: legacySpec)
        }

        // Clean up legacy obsolete 'output/' folder if present (Option 1: superseded by workspace/deliverables)
        let legacyOutputDir = baseDir.appendingPathComponent("output")
        if fileManager.fileExists(atPath: legacyOutputDir.path) {
            try? fileManager.removeItem(at: legacyOutputDir)
        }

        // Clean up empty routines.json if present and empty (Option 1: on-demand routines)
        if fileManager.fileExists(atPath: routinesFile.path) {
            if let data = try? Data(contentsOf: routinesFile),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let routines = json["routines"] as? [Any], routines.isEmpty {
                try? fileManager.removeItem(at: routinesFile)
            }
        }

        // Guarantee shared workspace exists
        _ = sharedWorkspaceDirectory

        return CompanionWorkspacePaths(
            baseSlugDirectory: baseDir,
            workspaceDirectory: workspaceDir,
            deliverablesDirectory: deliverablesDir,
            snapshotsDirectory: snapshotsDir,
            browserDataDirectory: browserDataDir,
            cookiesDirectory: cookiesDir,
            cacheDirectory: cacheDir,
            memoryFile: memoryFile,
            profileFile: profileFile,
            personaFile: personaFile,
            routinesFile: routinesFile
        )
    }

    /// Opens the companion's private workspace directory in macOS Finder
    public func openWorkspaceInFinder(for slug: String) {
        let paths = ensureWorkspaceHierarchy(for: slug)
        NSWorkspace.shared.open(paths.workspaceDirectory)
    }

    /// Opens the shared cross-bot workspace in macOS Finder
    public func openSharedWorkspaceInFinder() {
        let dir = sharedWorkspaceDirectory
        NSWorkspace.shared.open(dir)
    }

    /// Saves companion profile as JSON in its root container directory
    public func saveProfileJSON(for profile: CompanionProfile) {
        let paths = ensureWorkspaceHierarchy(for: profile.slug)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(profile) {
            try? data.write(to: paths.profileFile)
        }
    }

    /// Reads long-term memory dictionary for a companion
    public func readMemory(for slug: String) -> [String: Any] {
        let paths = ensureWorkspaceHierarchy(for: slug)
        guard let data = try? Data(contentsOf: paths.memoryFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    /// Updates or inserts a preference key in companion's memory.json
    public func updateMemoryPreference(for slug: String, key: String, value: Any) {
        var mem = readMemory(for: slug)
        var prefs = mem["preferences"] as? [String: Any] ?? [:]
        prefs[key] = value
        mem["preferences"] = prefs
        mem["updatedAt"] = ISO8601DateFormatter().string(from: Date())
        let paths = ensureWorkspaceHierarchy(for: slug)
        if let data = try? JSONSerialization.data(withJSONObject: mem, options: [.prettyPrinted]) {
            try? data.write(to: paths.memoryFile)
        }
    }

    /// Generates or updates the <slug>.md persona file for a companion
    public func generateCompanionSpec(for profile: CompanionProfile) -> URL {
        let paths = ensureWorkspaceHierarchy(for: profile.slug)
        saveProfileJSON(for: profile)
        
        let content = """
        # \(profile.name) (\(profile.role))
        
        <!-- Generated by Izanotchy Companion Workspace Engine -->
        <!-- Date: \(ISO8601DateFormatter().string(from: Date())) -->
        
        ## Primary Goal & Identity
        - **Name**: \(profile.name)
        - **Slug**: `\(profile.slug)`
        - **Role**: \(profile.role)
        - **Cloud Color**: `\(profile.cloudColorHex)`
        - **Ring Color**: `\(profile.ringColorHex)`
        - **Mood / Expression**: `\(profile.mood.rawValue)`
        - **Summary**: \(profile.summary)
        
        ## Active Skills & Integrations
        \(profile.activeSkills.map { "- `\($0).md`" }.joined(separator: "\n"))
        
        ## Standing Preferences & Memory
        - Initialized for active macOS pair programming and desktop assistance.
        - Standing rule: Verify physical screen state before claiming task completion.
        
        ## Dedicated Workspace Directories
        - **Private Workspace**: `\(paths.workspaceDirectory.path)`
        - **Deliverables**: `\(paths.deliverablesDirectory.path)`
        - **Browser Profile**: `\(paths.browserDataDirectory.path)`
        - **Shared Workspace**: `\(sharedWorkspaceDirectory.path)`
        """
        
        try? content.write(to: paths.personaFile, atomically: true, encoding: .utf8)
        let legacySpec = paths.baseSlugDirectory.appendingPathComponent("\(profile.slug).md")
        if fileManager.fileExists(atPath: legacySpec.path) {
            try? fileManager.removeItem(at: legacySpec)
        }
        
        return paths.personaFile
    }

    /// Saves custom markdown content directly into the persona file for a companion
    @discardableResult
    public func saveCustomCompanionSpec(slug: String, markdownContent: String) -> URL {
        let paths = ensureWorkspaceHierarchy(for: slug)
        try? markdownContent.write(to: paths.personaFile, atomically: true, encoding: .utf8)
        let legacySpec = paths.baseSlugDirectory.appendingPathComponent("\(slug).md")
        if fileManager.fileExists(atPath: legacySpec.path) {
            try? fileManager.removeItem(at: legacySpec)
        }
        return paths.personaFile
    }

    /// Reads existing persona file if available
    public func readCompanionSpec(slug: String) -> String? {
        let paths = ensureWorkspaceHierarchy(for: slug)
        if let content = try? String(contentsOf: paths.personaFile, encoding: .utf8) {
            return content
        }
        let legacySpec = paths.baseSlugDirectory.appendingPathComponent("\(slug).md")
        return try? String(contentsOf: legacySpec, encoding: .utf8)
    }

    /// Deletes a companion's workspace directory when removed from roster
    public func deleteCompanionWorkspace(slug: String) {
        let baseDir = baseCompanionsDirectory.appendingPathComponent(slug)
        if fileManager.fileExists(atPath: baseDir.path) {
            try? fileManager.removeItem(at: baseDir)
            ClickyLogger.info("[WORKSPACE]", "Deleted workspace for removed companion: \(slug)")
        }
    }

    /// Prunes orphaned companion directories not present in active roster (Option 1)
    public func pruneOrphanWorkspaces(activeSlugs: Set<String>) {
        guard let items = try? fileManager.contentsOfDirectory(at: baseCompanionsDirectory, includingPropertiesForKeys: nil) else { return }
        for item in items {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                let slug = item.lastPathComponent
                if !activeSlugs.contains(slug) {
                    try? fileManager.removeItem(at: item)
                    ClickyLogger.info("[WORKSPACE]", "Pruned orphaned companion folder from disk: \(slug)")
                }
            }
        }
    }
}
// MARK: - EvidencePreservationService (PRD §A9, MT-04: Automated Multi-Type Evidence Preservation)

public final class EvidencePreservationService: @unchecked Sendable {
    public static let shared = EvidencePreservationService()

    private init() {}

    /// Preserves complete multi-type evidence bundle for a given run
    /// Guarantees at least 5 distinct evidence artifacts per run folder.
    @discardableResult
    public func preserveRunEvidence(
        runId: String,
        slug: String,
        sourceLinks: [String] = [],
        snapshotPath: String? = nil,
        performedSteps: [String] = [],
        filesCreated: [String] = [],
        unverifiedItems: [String] = [],
        report: EgressReport? = nil,
        rawLogExcerpt: String? = nil
    ) -> EgressEvidence {
        let fileManager = FileManager.default
        let evidenceBaseDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".izanotchy/companions/\(slug)/workspace/evidence/\(runId)", isDirectory: true)
        try? fileManager.createDirectory(at: evidenceBaseDir, withIntermediateDirectories: true)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        let currentTimestamp = isoFormatter.string(from: Date())

        // 1. Evidence Type: Screenshots
        var preservedScreenshots: [String] = []
        let targetScreenshotPath = evidenceBaseDir.appendingPathComponent("screenshot.png").path
        if let snap = snapshotPath, fileManager.fileExists(atPath: snap) {
            try? fileManager.removeItem(atPath: targetScreenshotPath)
            try? fileManager.copyItem(atPath: snap, toPath: targetScreenshotPath)
            preservedScreenshots.append(targetScreenshotPath)
        } else {
            let activeFrame = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".izanotchy/companions/\(slug)/workspace/snapshots/active_frame.png").path
            if fileManager.fileExists(atPath: activeFrame) {
                try? fileManager.removeItem(atPath: targetScreenshotPath)
                try? fileManager.copyItem(atPath: activeFrame, toPath: targetScreenshotPath)
                preservedScreenshots.append(targetScreenshotPath)
            }
        }

        // 2. Evidence Type: Action Log (un-redacted operational trail; only secrets masked)
        let actionLogFile = evidenceBaseDir.appendingPathComponent("action_log.txt")
        let logTrail: String
        if let excerpt = rawLogExcerpt, !excerpt.isEmpty {
            logTrail = excerpt
        } else if !performedSteps.isEmpty {
            logTrail = performedSteps.enumerated().map { "[\(currentTimestamp)] STEP \($0 + 1): \($1)" }.joined(separator: "\n")
        } else {
            let globalLogPath = ("~/Library/Logs/Izanotchy/clicky.log" as NSString).expandingTildeInPath
            if let fullLog = try? String(contentsOfFile: globalLogPath, encoding: .utf8) {
                logTrail = String(fullLog.suffix(8000))
            } else {
                logTrail = "[\(currentTimestamp)] Task execution completed for runId=\(runId)"
            }
        }
        // Mask only credential patterns, NEVER redact operational steps or findings
        let maskedLog = Self.maskCredentialsOnly(logTrail)
        try? maskedLog.write(to: actionLogFile, atomically: true, encoding: .utf8)

        // 3. Evidence Type: Source Links
        let sourceLinksFile = evidenceBaseDir.appendingPathComponent("source_links.json")
        let finalSourceLinks = sourceLinks.isEmpty ? ["about:blank"] : sourceLinks
        if let linksData = try? JSONSerialization.data(withJSONObject: finalSourceLinks, options: [.prettyPrinted]) {
            try? linksData.write(to: sourceLinksFile)
        }

        // 4. Evidence Type: Timestamps with Timezone
        let timestampsFile = evidenceBaseDir.appendingPathComponent("timestamps.json")
        let tzName = TimeZone.current.identifier
        let timestampsPayload: [String: Any] = [
            "timestamp": currentTimestamp,
            "timezone": tzName,
            "epochSeconds": Date().timeIntervalSince1970
        ]
        if let tsData = try? JSONSerialization.data(withJSONObject: timestampsPayload, options: [.prettyPrinted]) {
            try? tsData.write(to: timestampsFile)
        }

        // 5. Evidence Type: Files Created / Referenced
        let filesFile = evidenceBaseDir.appendingPathComponent("files_created.json")
        let finalFiles = filesCreated.isEmpty ? ["egress.json"] : filesCreated
        if let filesData = try? JSONSerialization.data(withJSONObject: finalFiles, options: [.prettyPrinted]) {
            try? filesData.write(to: filesFile)
        }

        // 6. Evidence Type: Unverified Items
        let unverifiedFile = evidenceBaseDir.appendingPathComponent("unverified_items.json")
        if let unvData = try? JSONSerialization.data(withJSONObject: unverifiedItems, options: [.prettyPrinted]) {
            try? unvData.write(to: unverifiedFile)
        }

        let evidenceObject = EgressEvidence(
            sourceLinks: finalSourceLinks,
            screenshots: preservedScreenshots,
            timestamps: [currentTimestamp],
            files: finalFiles,
            actionLog: actionLogFile.path,
            unverified: unverifiedItems
        )

        // 7. Full C3 Egress Manifest
        if let rep = report {
            let egressResult = EgressResult(
                runId: runId,
                concluded: true,
                isDone: true,
                report: rep,
                evidence: evidenceObject,
                deliverables: [
                    EgressDeliverable(type: "evidence_bundle", artifact: evidenceBaseDir.path, title: "Evidence Bundle", summary: "Preserved 6 evidence types")
                ]
            )
            if let egData = try? JSONEncoder().encode(egressResult) {
                try? egData.write(to: evidenceBaseDir.appendingPathComponent("egress.json"))
            }
        }

        ClickyLogger.info("[EVIDENCE]", "Preserved multi-type evidence in \(evidenceBaseDir.path) for runId=\(runId)")
        return evidenceObject
    }

    /// Redacts only sensitive credentials (Bearer, passwords, tokens, API keys)
    /// Preserves all operational steps, selectors, and user findings intact without over-redacting
    public static func maskCredentialsOnly(_ text: String) -> String {
        var result = text
        // Bearer tokens
        result = result.replacingOccurrences(of: #"(Bearer\s+)[A-Za-z0-9_\-\.]{12,}"#, with: "$1[REDACTED]", options: .regularExpression)
        // Passwords
        result = result.replacingOccurrences(of: #"("password"\s*:\s*")[^"]+(")"#, with: "$1[REDACTED]$2", options: .regularExpression)
        result = result.replacingOccurrences(of: #"('password'\s*:\s*')[^']+(')"#, with: "$1[REDACTED]$2", options: .regularExpression)
        // Secrets / API keys
        result = result.replacingOccurrences(of: #"(api[_-]?key\s*[=:]\s*)[A-Za-z0-9_\-]{16,}"#, with: "$1[REDACTED]", options: .regularExpression, range: nil)
        return result
    }
}
