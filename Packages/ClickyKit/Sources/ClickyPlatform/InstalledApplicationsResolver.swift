//
//  InstalledApplicationsResolver.swift
//  izaNotch (Izanotchy)
//
//  Dynamic application discovery and fuzzy name matching.
//

import ClickyFoundation
import AppKit
import Foundation

public struct InstalledApplication: Sendable {
    public let displayName: String
    public let bundleURL: URL
    public let bundleIdentifier: String?
}

public typealias DynamicAppResolver = InstalledApplicationsResolver

public final class InstalledApplicationsResolver: @unchecked Sendable {
    public static let shared = InstalledApplicationsResolver()

    public private(set) var cachedApps: [InstalledApplication] = []
    private var lastScanTime: Date = .distantPast
    private let lock = NSLock()

    private init() {
        refreshCache()
    }

    public func refreshCache() {
        lock.lock()
        defer { lock.unlock() }

        var results: [InstalledApplication] = []
        var seenURLs = Set<URL>()

        let directories = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Cryptexes/App/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        let fm = FileManager.default
        for dir in directories {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items {
                if item.hasSuffix(".app") {
                    let fullPath = dir + "/" + item
                    let url = URL(fileURLWithPath: fullPath)
                    if seenURLs.insert(url).inserted {
                        let name = url.deletingPathExtension().lastPathComponent
                        let bundle = Bundle(url: url)
                        let bundleId = bundle?.bundleIdentifier
                        let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                            ?? name
                        results.append(InstalledApplication(
                            displayName: displayName,
                            bundleURL: url,
                            bundleIdentifier: bundleId
                        ))
                    }
                } else if !item.hasPrefix(".") {
                    // Check 1 level of subdirectories (e.g. DaVinci Resolve, Python, etc.)
                    let sub = dir + "/" + item
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: sub, isDirectory: &isDir), isDir.boolValue {
                        if let subItems = try? fm.contentsOfDirectory(atPath: sub) {
                            for s in subItems where s.hasSuffix(".app") {
                                let fullPath = sub + "/" + s
                                let url = URL(fileURLWithPath: fullPath)
                                if seenURLs.insert(url).inserted {
                                    let name = url.deletingPathExtension().lastPathComponent
                                    let bundle = Bundle(url: url)
                                    let bundleId = bundle?.bundleIdentifier
                                    let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                                        ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                                        ?? name
                                    results.append(InstalledApplication(
                                        displayName: displayName,
                                        bundleURL: url,
                                        bundleIdentifier: bundleId
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }

        self.cachedApps = results
        self.lastScanTime = Date()
        ClickyLogger.info("[APP_RESOLVER]", "Scanned and cached \(results.count) installed applications dynamically")
    }

    /// Resolves a user query (e.g. "trading view", "safari", "google chrome") to a matching installed application
    public func resolveApplication(query: String) -> InstalledApplication? {
        lock.lock()
        // Refresh every 5 minutes or if empty
        if Date().timeIntervalSince(lastScanTime) > 300 || cachedApps.isEmpty {
            lock.unlock()
            refreshCache()
            lock.lock()
        }
        let apps = cachedApps
        lock.unlock()

        let rawQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedQuery = rawQuery.replacingOccurrences(of: "\\b(?:aplikasi|app)\\b", with: " ", options: [.regularExpression, .caseInsensitive])
        let normalizedQuery = cleanedQuery.filter { $0.isLetter || $0.isNumber }
        if normalizedQuery.isEmpty { return nil }

        // Pass 1: Exact match on normalized alphanumeric string
        for app in apps {
            let normName = app.displayName.lowercased().filter { $0.isLetter || $0.isNumber }
            if normName == normalizedQuery { return app }
            let normLastPath = app.bundleURL.deletingPathExtension().lastPathComponent.lowercased().filter { $0.isLetter || $0.isNumber }
            if normLastPath == normalizedQuery { return app }
        }

        // Pass 2: Prefix match on normalized string
        for app in apps {
            let normName = app.displayName.lowercased().filter { $0.isLetter || $0.isNumber }
            if normName.hasPrefix(normalizedQuery) || normalizedQuery.hasPrefix(normName) { return app }
        }

        // Pass 3: Substring match on query
        for app in apps {
            let normName = app.displayName.lowercased().filter { $0.isLetter || $0.isNumber }
            if normName.contains(normalizedQuery) || normalizedQuery.contains(normName) { return app }
        }

        // Pass 4: Common aliases dictionary
        let aliases: [String: String] = [
            "chrome": "googlechrome",
            "vscode": "visualstudiocode",
            "code": "visualstudiocode",
            "settings": "systemsettings",
            "pengaturan": "systemsettings",
            "terminal": "terminal",
            "pesan": "messages",
            "catatan": "notes",
            "kalkulator": "calculator"
        ]
        if let targetAlias = aliases[normalizedQuery] {
            for app in apps {
                let normName = app.displayName.lowercased().filter { $0.isLetter || $0.isNumber }
                if normName == targetAlias || normName.contains(targetAlias) { return app }
            }
        }

        return nil
    }
}
