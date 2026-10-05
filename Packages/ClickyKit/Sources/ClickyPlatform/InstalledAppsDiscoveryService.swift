//
//  InstalledAppsDiscoveryService.swift
//  izaNotch
//
//  Discovers installed applications on macOS and loads their native system icons.
//  Powers the Connected Apps permission manager per companion.
//

import ClickyFoundation
import Foundation
import AppKit

public struct MacInstalledApp: Identifiable, Hashable, @unchecked Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let bundleId: String?
    public let icon: NSImage
    public var isRunning: Bool

    public init(
        id: String,
        name: String,
        path: String,
        bundleId: String?,
        icon: NSImage,
        isRunning: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.bundleId = bundleId
        self.icon = icon
        self.isRunning = isRunning
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: MacInstalledApp, rhs: MacInstalledApp) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
public final class InstalledAppsDiscoveryService: ObservableObject {
    public static let shared = InstalledAppsDiscoveryService()

    @Published public private(set) var installedApps: [MacInstalledApp] = []
    @Published public private(set) var isLoading: Bool = false

    private var hasScanned: Bool = false

    private init() {
        scanInstalledApplications()
    }

    /// Memindai aplikasi terpasang di Mac secara asynchronous agar tidak memblokir antarmuka pengguna
    public func scanInstalledApplications(forceReload: Bool = false) {
        if hasScanned && !forceReload && !installedApps.isEmpty {
            return
        }

        self.isLoading = true

        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let scanDirs = [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                URL(fileURLWithPath: "/System/Applications/Utilities")
            ]

            let runningApps = await MainActor.run {
                NSWorkspace.shared.runningApplications
            }
            let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })
            let runningNames = Set(runningApps.compactMap { $0.localizedName?.lowercased() })

            var discovered: [MacInstalledApp] = []
            var seenBundleIds: Set<String> = []
            var seenNames: Set<String> = []

            // Common priority apps to prioritize near the top
            let priorityNames = ["Mail", "Safari", "Terminal", "Finder", "TradingView", "Telegram", "Discord", "ChatGPT", "Chrome", "Google Chrome", "Spotify", "Notes", "Calendar"]

            // 1. Resolve well-known core apps via NSWorkspace bundle URLs (guarantees system apps like Safari/Mail are always found)
            let coreAppBundles = [
                ("Safari", "com.apple.Safari"),
                ("Mail", "com.apple.mail"),
                ("Terminal", "com.apple.Terminal"),
                ("Finder", "com.apple.finder"),
                ("TradingView", "com.tradingview.tradingviewapp.desktop"),
                ("Notes", "com.apple.Notes"),
                ("Calendar", "com.apple.iCal")
            ]

            for (name, bundleId) in coreAppBundles {
                if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    let icon = NSWorkspace.shared.icon(forFile: appUrl.path)
                    icon.size = NSSize(width: 32, height: 32)
                    let isRunning = runningBundleIds.contains(bundleId) || runningNames.contains(name.lowercased())
                    discovered.append(MacInstalledApp(
                        id: bundleId,
                        name: name,
                        path: appUrl.path,
                        bundleId: bundleId,
                        icon: icon,
                        isRunning: isRunning
                    ))
                    seenBundleIds.insert(bundleId)
                    seenNames.insert(name.lowercased())
                }
            }

            for dir in scanDirs {
                guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                    continue
                }

                for url in contents where url.pathExtension == "app" {
                    let name = url.deletingPathExtension().lastPathComponent
                    let bundle = Bundle(url: url)
                    let bundleId = bundle?.bundleIdentifier

                    // Skip internal helper / uninstallers
                    let lowerName = name.lowercased()
                    if lowerName.contains("uninstaller") || lowerName.contains("helper") || lowerName.contains("crashlytics") {
                        continue
                    }

                    let uniqueKey = bundleId ?? url.path
                    if seenBundleIds.contains(uniqueKey) || seenNames.contains(lowerName) {
                        continue
                    }
                    seenBundleIds.insert(uniqueKey)
                    seenNames.insert(lowerName)

                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    icon.size = NSSize(width: 32, height: 32)

                    let isRunning = (bundleId != nil && runningBundleIds.contains(bundleId!)) ||
                                    runningNames.contains(lowerName)

                    discovered.append(MacInstalledApp(
                        id: uniqueKey,
                        name: name,
                        path: url.path,
                        bundleId: bundleId,
                        icon: icon,
                        isRunning: isRunning
                    ))
                }
            }

            // Sort: Priority apps first, then running apps, then alphabetical
            discovered.sort { a, b in
                let aPriority = priorityNames.firstIndex(where: { $0.lowercased() == a.name.lowercased() }) ?? 999
                let bPriority = priorityNames.firstIndex(where: { $0.lowercased() == b.name.lowercased() }) ?? 999
                if aPriority != bPriority {
                    return aPriority < bPriority
                }
                if a.isRunning != b.isRunning {
                    return a.isRunning && !b.isRunning
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

            let result = discovered
            await MainActor.run {
                self.installedApps = result
                self.isLoading = false
                self.hasScanned = true
                ClickyLogger.info("[APPS_DISCOVERY]", "Discovered \(result.count) macOS applications with native system icons.")
            }
        }
    }

    /// Mengambil daftar aplikasi yang telah difilter berdasarkan kata kunci pencarian
    public func filteredApps(query: String) -> [MacInstalledApp] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanQuery.isEmpty else { return installedApps }
        return installedApps.filter { app in
            app.name.lowercased().contains(cleanQuery) ||
            (app.bundleId?.lowercased().contains(cleanQuery) ?? false)
        }
    }

    /// Mencari URL aplikasi yang terpasang secara dinamis berdasarkan nama
    public func findAppURL(appName: String) -> URL? {
        let clean = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = installedApps.first(where: {
            $0.name.lowercased() == clean ||
            $0.name.lowercased().contains(clean) ||
            ($0.bundleId?.lowercased().contains(clean) ?? false)
        }) {
            return URL(fileURLWithPath: match.path)
        }
        return nil
    }
}
