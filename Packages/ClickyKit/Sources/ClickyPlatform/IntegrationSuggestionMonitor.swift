//
//  IntegrationSuggestionMonitor.swift
//  boringNotch (Izanotchy)
//
//  [KEPT & MARKED FOR ARCHITECTURE REVIEW]
//  Passive, ultra-lightweight context detector for the Notch.
//  Monitors frontmost app and browser URL to provide proactive,
//  actionable suggestions hugging the MacBook Notch without voice input.
//

import ClickyFoundation
import AppKit
import Combine
import Defaults
import SwiftUI

public struct ContextualSuggestion: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let icon: String
    public let domain: String
    public let prompt: String

    public static func == (lhs: ContextualSuggestion, rhs: ContextualSuggestion) -> Bool {
        lhs.title == rhs.title && lhs.domain == rhs.domain && lhs.prompt == rhs.prompt
    }
}

@MainActor
public final class IntegrationSuggestionMonitor: ObservableObject {
    public static let shared = IntegrationSuggestionMonitor()

    @Published public var activeSuggestion: ContextualSuggestion? = nil

    private var appActivationObserver: Any?
    private var isMonitoring = false
    private var inspectionTask: Task<Void, Never>?

    private let browserBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.google.Chrome.canary",
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "company.thebrowser.Browser",        // Arc
        "company.thebrowser.BrowserBeta",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "com.microsoft.edgemac",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi"
    ]

    private init() {}

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Observe app activation notifications
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleAppActivation(notification)
            }
        }

        // Run initial check on currently frontmost app
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            inspectApplication(frontApp)
        }

        ClickyLogger.info("[SUGGESTION]", "IntegrationSuggestionMonitor started")
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }
        inspectionTask?.cancel()
        inspectionTask = nil
        activeSuggestion = nil

        ClickyLogger.info("[SUGGESTION]", "IntegrationSuggestionMonitor stopped")
    }

    private func handleAppActivation(_ notification: Notification) {
        guard Defaults[.proactiveNotchSuggestionsEnabled] else {
            activeSuggestion = nil
            return
        }

        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        inspectApplication(app)
    }

    public func inspectApplication(_ app: NSRunningApplication) {
        inspectionTask?.cancel()

        guard Defaults[.proactiveNotchSuggestionsEnabled] else {
            activeSuggestion = nil
            return
        }

        let bundleID = app.bundleIdentifier ?? ""
        let appName = app.localizedName ?? ""

        // Ignore our own app
        if bundleID == Bundle.main.bundleIdentifier || appName == "boringNotch" {
            return
        }

        inspectionTask = Task { @MainActor in
            // Small debounce to let window/tab settle
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            if browserBundleIDs.contains(bundleID) {
                await inspectBrowser(app: app)
            } else {
                inspectNonBrowserApp(bundleID: bundleID, appName: appName)
            }
        }
    }

    private func inspectBrowser(app: NSRunningApplication) async {
        let pid = app.processIdentifier
        let appName = app.localizedName ?? "Browser"

        // Query Accessibility in detached task with strict timeout to prevent UI hang
        let detectedURLOrTitle = await Task.detached(priority: .utility) { () -> String? in
            let axApp = AXUIElementCreateApplication(pid)
            var focusedWindow: AnyObject?
            let windowStatus = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)

            guard windowStatus == .success, let window = focusedWindow else {
                return nil
            }

            // Attempt 1: Check document URL attribute
            var docValue: AnyObject?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, "AXDocument" as CFString, &docValue) == .success,
               let urlString = docValue as? String, !urlString.isEmpty {
                return urlString
            }

            // Attempt 2: Check window title
            var titleValue: AnyObject?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleValue) == .success,
               let titleString = titleValue as? String, !titleString.isEmpty {
                return titleString
            }

            return nil
        }.value

        guard !Task.isCancelled else { return }

        if let text = detectedURLOrTitle?.lowercased() {
            if text.contains("github.com") {
                if text.contains("/pull/") || text.contains("pull request") {
                    setSuggestion(ContextualSuggestion(
                        title: "Review PR",
                        icon: "arrow.triangle.pull",
                        domain: "GitHub",
                        prompt: "Summarize this GitHub pull request, key code changes, and potential risks."
                    ))
                    return
                } else if text.contains("/issues/") || text.contains("issue") {
                    setSuggestion(ContextualSuggestion(
                        title: "Analyze Issue",
                        icon: "exclamationmark.circle",
                        domain: "GitHub",
                        prompt: "Break down this GitHub issue, identify root causes, and suggest a resolution plan."
                    ))
                    return
                } else {
                    setSuggestion(ContextualSuggestion(
                        title: "Inspect Repo",
                        icon: "shippingbox",
                        domain: "GitHub",
                        prompt: "Explain the architecture, structure, and key files in this repository."
                    ))
                    return
                }
            } else if text.contains("linear.app") {
                setSuggestion(ContextualSuggestion(
                    title: "Triage Ticket",
                    icon: "checklist",
                    domain: "Linear",
                    prompt: "Summarize this Linear ticket and list the core engineering requirements."
                ))
                return
            } else if text.contains("notion.so") || text.contains("docs.google.com") {
                setSuggestion(ContextualSuggestion(
                    title: "Summarize Doc",
                    icon: "doc.text.magnifyingglass",
                    domain: text.contains("notion") ? "Notion" : "Google Docs",
                    prompt: "Extract the executive summary and key action items from this document."
                ))
                return
            } else if text.contains("figma.com") {
                setSuggestion(ContextualSuggestion(
                    title: "Inspect UI",
                    icon: "paintpalette",
                    domain: "Figma",
                    prompt: "Analyze the layout, design tokens, and components visible in this design."
                ))
                return
            } else if text.contains("stackoverflow.com") {
                setSuggestion(ContextualSuggestion(
                    title: "Explain Fix",
                    icon: "questionmark.circle",
                    domain: "StackOverflow",
                    prompt: "Summarize the accepted answer and why this solution works."
                ))
                return
            }
        }

        // Generic browser page fallback (only if page title exists)
        if let title = detectedURLOrTitle, !title.isEmpty, title.count > 5 {
            setSuggestion(ContextualSuggestion(
                title: "Summarize Page",
                icon: "safari",
                domain: appName,
                prompt: "Summarize the main content and key takeaways of this webpage."
            ))
        } else {
            activeSuggestion = nil
        }
    }

    private func inspectNonBrowserApp(bundleID: String, appName: String) {
        let lowerID = bundleID.lowercased()
        let lowerName = appName.lowercased()

        if lowerID.contains("whatsapp") || lowerName.contains("whatsapp") {
            setSuggestion(ContextualSuggestion(
                title: "Send WhatsApp",
                icon: "message.fill",
                domain: "WhatsApp",
                prompt: "Draft and send a message in WhatsApp."
            ))
        } else if lowerID.contains("telegram") || lowerName.contains("telegram") {
            setSuggestion(ContextualSuggestion(
                title: "Send Telegram",
                icon: "paperplane.fill",
                domain: "Telegram",
                prompt: "Draft and send a message in Telegram."
            ))
        } else if lowerID.contains("notes") || lowerName.contains("notes") {
            setSuggestion(ContextualSuggestion(
                title: "Summarize Note",
                icon: "note.text",
                domain: "Apple Notes",
                prompt: "Summarize this note and extract key action items."
            ))
        } else if lowerID.contains("linear") || lowerName.contains("linear") {
            let isConnected = isIntegrationConnected(id: "linear")
            setSuggestion(ContextualSuggestion(
                title: isConnected ? "Create Linear Issue" : "Connect Linear",
                icon: "checklist",
                domain: "Linear",
                prompt: isConnected ? "Create an engineering issue in Linear." : "Open Settings to connect your Linear account."
            ))
        } else if lowerID.contains("notion") || lowerName.contains("notion") {
            let isConnected = isIntegrationConnected(id: "notion")
            setSuggestion(ContextualSuggestion(
                title: isConnected ? "Create Notion Page" : "Connect Notion",
                icon: "doc.text",
                domain: "Notion",
                prompt: isConnected ? "Create a document page in Notion." : "Open Settings to connect your Notion account."
            ))
        } else if lowerID.contains("finder") || lowerName.contains("finder") {
            setSuggestion(ContextualSuggestion(
                title: "Organize Files",
                icon: "folder.badge.gearshape",
                domain: "Finder",
                prompt: "Inspect this folder and help organize or rename the files."
            ))
        } else if lowerID.contains("xcode") || lowerID.contains("vscode") || lowerID.contains("cursor") || lowerName.contains("antigravity") {
            setSuggestion(ContextualSuggestion(
                title: "Explain Code",
                icon: "curlybraces",
                domain: appName,
                prompt: "Explain the current code context, potential bugs, and optimization suggestions."
            ))
        } else if lowerID.contains("slack") || lowerID.contains("discord") || lowerID.contains("messages") {
            setSuggestion(ContextualSuggestion(
                title: "Draft Reply",
                icon: "bubble.left.and.bubble.right",
                domain: appName,
                prompt: "Help draft a concise, friendly, and professional response."
            ))
        } else if lowerID.contains("terminal") || lowerID.contains("iterm") {
            setSuggestion(ContextualSuggestion(
                title: "Explain Shell",
                icon: "terminal",
                domain: appName,
                prompt: "Explain the recent terminal commands or diagnose the shell error output."
            ))
        } else {
            activeSuggestion = nil
        }
    }

    private func isIntegrationConnected(id: String) -> Bool {
        let jsonStr = Defaults[.connectedIntegrationsJSON]
        guard let data = jsonStr.data(using: .utf8),
              let saved = try? JSONDecoder().decode([String: String].self, from: data) else {
            return false
        }
        return !(saved[id]?.isEmpty ?? true)
    }

    private func setSuggestion(_ suggestion: ContextualSuggestion) {
        if activeSuggestion != suggestion {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                activeSuggestion = suggestion
            }
            ClickyLogger.info("[SUGGESTION]", "Active suggestion updated: \"\(suggestion.title)\" for \(suggestion.domain)")
        }
    }
}
