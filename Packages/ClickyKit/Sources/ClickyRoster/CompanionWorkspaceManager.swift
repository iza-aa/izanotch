//
//  CompanionWorkspaceManager.swift
//  boringNotch
//
//  Created for Izanotchy - Multi-Agent Desktop System
//  Refactored for Fitur F-05: Per-Companion Workspace & Storage Isolation
//

import AppKit
import Foundation
import ClickyFoundation

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
        
        ## 🎯 Primary Goal & Identity
        - **Name**: \(profile.name)
        - **Slug**: `\(profile.slug)`
        - **Role**: \(profile.role)
        - **Cloud Color**: `\(profile.cloudColorHex)`
        - **Ring Color**: `\(profile.ringColorHex)`
        - **Mood / Expression**: `\(profile.mood.rawValue)`
        - **Summary**: \(profile.summary)
        
        ## ⚡ Active Skills & Integrations
        \(profile.activeSkills.map { "- `\($0).md`" }.joined(separator: "\n"))
        
        ## 🧠 Standing Preferences & Memory
        - Initialized for active macOS pair programming and desktop assistance.
        - Standing rule: Verify physical screen state before claiming task completion.
        
        ## 📁 Dedicated Workspace Directories
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
