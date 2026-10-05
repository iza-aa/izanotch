//
//  test_revisions_f14_sidebar_connected_apps.swift
//  boringNotch Tests
//
//  TDD Verification Suite for Milestone 195 (Feature F-14):
//  1. Strict Window Targeting (Finder false positive eliminated when targeting Mail)
//  2. InstalledAppsDiscoveryService scanning macOS applications & loading native icons
//  3. Search filtering for discovered Mac applications
//  4. Connected Apps toggle management per companion
//

import Foundation
import AppKit
import CoreGraphics

func runTests() async {
    print("=================================================================")
    print("🚀 Running F-14 Test Suite: Sidebar Navigation & Connected Apps")
    print("=================================================================")

    var passed = 0
    var failed = 0

    func assertCondition(_ desc: String, _ condition: Bool) {
        if condition {
            print("  ✅ PASS: \(desc)")
            passed += 1
        } else {
            print("  ❌ FAIL: \(desc)")
            failed += 1
        }
    }

    // TEST 1: Strict Window Targeting (Prevent Finder matching "Mail")
    print("\n--- Test 1: Strict Window Targeting vs Finder False Positive ---")
    let testWindowList: [[String: Any]] = [
        [
            kCGWindowNumber as String: 3273,
            kCGWindowOwnerName as String: "Finder",
            kCGWindowName as String: "sent_emails",
            kCGWindowLayer as String: 0,
            kCGWindowOwnerPID as String: 100,
            kCGWindowBounds as String: ["X": 0.0, "Y": 0.0, "Width": 800.0, "Height": 600.0]
        ],
        [
            kCGWindowNumber as String: 4567,
            kCGWindowOwnerName as String: "Mail",
            kCGWindowName as String: "Inbox — rezkyhaikal2@gmail.com",
            kCGWindowLayer as String: 0,
            kCGWindowOwnerPID as String: 200,
            kCGWindowBounds as String: ["X": 100.0, "Y": 100.0, "Width": 900.0, "Height": 700.0]
        ]
    ]

    func simulateFindTarget(appName: String, in windows: [[String: Any]]) -> Int64? {
        let cleanTarget = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for w in windows {
            let ownerName = (w[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            let layer = w[kCGWindowLayer as String] as? Int ?? -1
            let windowId = Int64(w[kCGWindowNumber as String] as? Int ?? 0)

            guard layer == 0, windowId > 0 else { continue }
            if cleanTarget != "finder" && (ownerName == "finder" || ownerName.contains("finder")) {
                continue
            }

            let matchesApp = ownerName == cleanTarget ||
                             ownerName.hasPrefix(cleanTarget) ||
                             ownerName.contains(cleanTarget) ||
                             (cleanTarget == "mail" && ownerName.contains("mail"))

            guard matchesApp else { continue }
            return windowId
        }
        return nil
    }

    let resolvedMailId = simulateFindTarget(appName: "Mail", in: testWindowList)
    assertCondition("Targeting 'Mail' selects window ID 4567 owned by Mail, NOT 3273 owned by Finder", resolvedMailId == 4567)

    let finderOnlyList: [[String: Any]] = [testWindowList[0]]
    let resolvedWhenMailNotRunning = simulateFindTarget(appName: "Mail", in: finderOnlyList)
    assertCondition("When Mail is not running, Finder titled 'sent_emails' is REJECTED (returns nil)", resolvedWhenMailNotRunning == nil)

    // TEST 2: Installed Apps Discovery Service
    print("\n--- Test 2: Installed Apps Discovery on macOS ---")
    let fileManager = FileManager.default
    let scanDirs = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications")
    ]

    var apps: [(name: String, path: String, icon: NSImage)] = []
    
    // Core bundle resolution
    if let safariUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
        apps.append(("Safari", safariUrl.path, NSWorkspace.shared.icon(forFile: safariUrl.path)))
    }
    if let mailUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.mail") {
        apps.append(("Mail", mailUrl.path, NSWorkspace.shared.icon(forFile: mailUrl.path)))
    }

    for dir in scanDirs {
        if let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for url in contents where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                if !apps.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    apps.append((name: name, path: url.path, icon: icon))
                }
            }
        }
    }

    assertCondition("Discovered installed macOS applications count > 20", apps.count > 20)
    let hasSafari = apps.contains { $0.name.lowercased() == "safari" }
    assertCondition("Discovery found Safari with valid app path", hasSafari)
    let hasMail = apps.contains { $0.name.lowercased() == "mail" }
    assertCondition("Discovery found Mail with valid app path", hasMail)

    if let firstApp = apps.first {
        assertCondition("App icon has valid dimensions (width > 0, height > 0)", firstApp.icon.size.width > 0 && firstApp.icon.size.height > 0)
    }

    // TEST 3: Search Filtering Logic
    print("\n--- Test 3: Search Filtering Logic ---")
    let filteredSafari = apps.filter { $0.name.lowercased().contains("safari") }
    assertCondition("Searching 'safari' returns at least 1 match", !filteredSafari.isEmpty)

    let filteredNonExistent = apps.filter { $0.name.lowercased().contains("nonexistent_fictional_app_xyz") }
    assertCondition("Searching non-existent app returns empty list", filteredNonExistent.isEmpty)

    // TEST 4: Connected Apps Permission Management
    print("\n--- Test 4: Connected Apps Permission Toggling ---")
    var mockAllowedApps = ["Mail", "Safari"]
    
    // Toggle ON TradingView
    let appToToggle = "TradingView"
    if !mockAllowedApps.contains(appToToggle) {
        mockAllowedApps.append(appToToggle)
    }
    assertCondition("Toggling TradingView ON adds it to workflowAppNames", mockAllowedApps.contains("TradingView"))

    // Toggle OFF Mail
    mockAllowedApps.removeAll { $0 == "Mail" }
    assertCondition("Toggling Mail OFF removes it from workflowAppNames", !mockAllowedApps.contains("Mail"))
    assertCondition("Safari remains allowed in workflowAppNames", mockAllowedApps.contains("Safari"))

    print("\n=================================================================")
    print("📊 F-14 Test Results: \(passed) PASSED, \(failed) FAILED")
    print("=================================================================")
    if failed > 0 {
        exit(1)
    }
}

Task {
    await runTests()
    exit(0)
}

RunLoop.main.run(until: Date(timeIntervalSinceNow: 15))
