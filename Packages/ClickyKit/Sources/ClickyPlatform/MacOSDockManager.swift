//
//  MacOSDockManager.swift
//  izaNotch (Izanotchy)
//
//  Dock location discovery and accessibility positioning.
//

import ClickyFoundation
import AppKit
import ApplicationServices
import Foundation

struct DockItemLocation {
    let name: String
    let bundleIdentifier: String?
    let screenPoint: CGPoint
    let size: CGSize
    let screenBounds: CGRect
}

@MainActor
enum MacOSDockManager {
    /// Retrieves all visible items in the macOS Dock dynamically
    static func getAllDockItems() -> [DockItemLocation] {
        let axItems = queryDockItemsViaAccessibility()
        if !axItems.isEmpty {
            return axItems
        }
        return queryDockItemsViaPreferencesFallback()
    }

    /// Finds a specific Dock item by app name (fuzzy case-insensitive match)
    static func getDockItem(named query: String) -> DockItemLocation? {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanQuery.isEmpty else { return nil }

        let all = getAllDockItems()
        // 1. Exact match
        if let exact = all.first(where: { $0.name.lowercased() == cleanQuery }) {
            return exact
        }
        // 2. Query contains item name or item name contains query
        if let match = all.first(where: {
            let itemLower = $0.name.lowercased()
            return cleanQuery.contains(itemLower) || itemLower.contains(cleanQuery)
        }) {
            return match
        }
        // 3. Bundle identifier match
        if let match = all.first(where: {
            if let bundle = $0.bundleIdentifier?.lowercased() {
                return bundle.contains(cleanQuery) || cleanQuery.contains(bundle)
            }
            return false
        }) {
            return match
        }
        return nil
    }

    private static func queryDockItemsViaAccessibility() -> [DockItemLocation] {
        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
            return []
        }

        let appElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        var listValue: AnyObject?
        let err = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &listValue)
        guard err == .success, let children = listValue as? [AXUIElement] else {
            return []
        }

        var results: [DockItemLocation] = []
        for child in children {
            var subValue: AnyObject?
            if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subValue) == .success,
               let items = subValue as? [AXUIElement] {
                for item in items {
                    var titleVal: AnyObject?
                    var posVal: AnyObject?
                    var sizeVal: AnyObject?
                    _ = AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleVal)
                    _ = AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &posVal)
                    _ = AXUIElementCopyAttributeValue(item, kAXSizeAttribute as CFString, &sizeVal)

                    var pos = CGPoint.zero
                    var size = CGSize.zero
                    if let p = posVal as! AXValue? { AXValueGetValue(p, .cgPoint, &pos) }
                    if let s = sizeVal as! AXValue? { AXValueGetValue(s, .cgSize, &size) }

                    let title = (titleVal as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !title.isEmpty && size.width > 0 && size.height > 0 {
                        // Hotfix #12 (docktrace3 22 Sep, BUKTI FINAL): semua ikon
                        // (badge/tidak) pos.y=907 IDENTIK -> teori badge RUNTUH.
                        // AX Dock = CG top-left (dari atas): center (257,942) cocok
                        // 100% dengan visual crop (942/982 dari atas). Tapi Overlay
                        // render seolah AppKit (dari bawah) -> mendarat di atas.
                        // Konversi BENAR: AppKit = (x, primaryH - y) = (257,40) ->
                        // SwiftUI y = 982-40 = 942 = Dock bawah. BENAR.
                        let primaryH = NSScreen.screens.first?.frame.height ?? 982
                        let centerCG = CGPoint(x: pos.x + size.width / 2.0, y: pos.y + size.height / 2.0)
                        let center = CGPoint(x: centerCG.x, y: primaryH - centerCG.y)
                        results.append(DockItemLocation(
                            name: title,
                            bundleIdentifier: nil,
                            screenPoint: center,
                            size: size,
                            screenBounds: CGRect(origin: pos, size: size)
                        ))
                    }
                }
            }
        }
        return results
    }

    private static func queryDockItemsViaPreferencesFallback() -> [DockItemLocation] {
        guard let screen = NSScreen.main else { return [] }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        let dockHeight = visibleFrame.origin.y > 0 ? visibleFrame.origin.y : 76.0
        let dockCenterY = screenFrame.height - (dockHeight / 2.0)

        guard let dict = UserDefaults(suiteName: "com.apple.dock")?.dictionaryRepresentation(),
              let persistentApps = dict["persistent-apps"] as? [[String: Any]] else {
            return []
        }

        var appNames: [(name: String, bundle: String?)] = []
        appNames.append((name: "Finder", bundle: "com.apple.finder"))

        for item in persistentApps {
            if let tileData = item["tile-data"] as? [String: Any],
               let label = tileData["file-label"] as? String {
                let bundle = tileData["bundle-identifier"] as? String
                appNames.append((name: label, bundle: bundle))
            }
        }

        let tilesize = CGFloat(dict["tilesize"] as? Int ?? 50)
        let spacing: CGFloat = max(6.0, tilesize * 0.18)
        let totalItemsWidth = CGFloat(appNames.count) * tilesize + CGFloat(appNames.count - 1) * spacing
        let startX = (screenFrame.width - totalItemsWidth) / 2.0

        var results: [DockItemLocation] = []
        for (index, app) in appNames.enumerated() {
            let itemX = startX + CGFloat(index) * (tilesize + spacing)
            let itemCenter = CGPoint(x: itemX + tilesize / 2.0, y: dockCenterY)
            let itemRect = CGRect(x: itemX, y: dockCenterY - tilesize / 2.0, width: tilesize, height: tilesize)
            results.append(DockItemLocation(
                name: app.name,
                bundleIdentifier: app.bundle,
                screenPoint: itemCenter,
                size: CGSize(width: tilesize, height: tilesize),
                screenBounds: itemRect
            ))
        }

        return results
    }
}
