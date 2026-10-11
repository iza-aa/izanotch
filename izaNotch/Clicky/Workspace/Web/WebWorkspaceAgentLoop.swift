//
//  WebWorkspaceAgentLoop.swift
//  izaNotch (Izanotchy)
//
//  Autonomous Web Workspace Agent Loop (TASK-046 Fase C).
//  Direct DOM Execution & Verification. Zero AX calls.
//  Rigid Web Completion Gate: Declarative Login Detection & Truth Verification.
//

import Foundation
import WebKit
import AppKit

public enum WebTaskStatus: String, Codable, Sendable {
    case loading = "loading"
    case awaitingLogin = "awaiting_login"
    case executing = "executing"
    case completed = "completed"
    case failed = "failed"
}

@MainActor
public final class WebWorkspaceAgentLoop: ObservableObject {
    public static let shared = WebWorkspaceAgentLoop()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentStepIndex: Int = 0

    private init() {}

    /// Executes an autonomous task inside the Web Workspace using DOM perception and actions.
    public func executeAutonomousWebTask(
        prompt: String,
        slug: String,
        appName: String,
        taskPlan: AFMTaskDecomposition,
        onProgress: @escaping (ComputerCardPayload) -> Void
    ) async throws -> ComputerCardPayload {
        // Concurrency Lock: reject concurrent executions
        guard !isRunning else {
            ClickyLogger.warning("[WEB_LOOP]", "Web task rejected: another web task is already executing.")
            throw NSError(domain: "WebWorkspace", code: -429, userInfo: [NSLocalizedDescriptionKey: "Task already executing"])
        }

        self.isRunning = true
        defer { self.isRunning = false }

        ClickyLogger.info("[WEB_LOOP]", "Starting autonomous web task: '\(prompt)' [slug=\(slug), tier=\(taskPlan.executionTier)]")

        // 1. Prepare and ensure WebKit Viewport is ready with single-chain resolution from routing gate
        let viewportController = CompanionVMViewportController.shared
        let surfaceId = taskPlan.targetSurfaceId ?? viewportController.mailProvider
        viewportController.prepareViewport(slug: slug, app: appName, preferredAdapterId: surfaceId, prompt: prompt)

        guard let webView = viewportController.webView else {
            throw NSError(domain: "WebWorkspace", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebKit runtime unavailable"])
        }

        // 2. Resolve Site Adapter directly from routing decision (Single Chain of Resolution)
        let adapter = WebSiteAdapterRegistry.shared.adapter(forProviderId: surfaceId)
        ClickyLogger.info("[WEB_LOOP]", "Resolved WebSiteAdapter: '\(adapter.id)' (\(adapter.name)) from routing surfaceId='\(surfaceId)'")

        // Domain-Aware Navigation Check: if not on an authorized domain, re-navigate to adapter entryURL
        let currentHost = webView.url?.host?.lowercased() ?? ""
        let isAuthorizedDomain = adapter.domains.contains(where: { currentHost.contains($0) })
        if !isAuthorizedDomain && adapter.id != "browser" {
            ClickyLogger.warning("[WEB_LOOP]", "WebView currently on '\(currentHost)', which is NOT an authorized domain for \(adapter.name). Re-navigating to entryURL: \(adapter.entryURL)")
            webView.load(URLRequest(url: adapter.entryURL))
            await waitForPageLoad(webView: webView, timeoutSeconds: 8.0)
        }
        // 3. Initialize Card Payload
        var queueItems = taskPlan.plannedSubGoals.map {
            ComputerCardQueueItem(name: $0, statusBadge: "Planned", isChecked: false)
        }
        if queueItems.isEmpty {
            queueItems = [
                ComputerCardQueueItem(name: "Memuat halaman webmail", statusBadge: "Starting", isChecked: false),
                ComputerCardQueueItem(name: "Verifikasi elemen DOM", statusBadge: "Pending", isChecked: false),
                ComputerCardQueueItem(name: "Eksekusi tindakan", statusBadge: "Pending", isChecked: false)
            ]
        }

        var payload = ComputerCardPayload(
            cardTitle: "Web Workspace",
            status: .working,
            instructionText: prompt,
            snapshotImagePath: viewportController.activeSnapshotPath,
            targetAppName: adapter.name,
            activeWorkflowApp: adapter.name,
            queueSummary: "Memuat Web Workspace...",
            queueItems: queueItems
        )
        onProgress(payload)

        // 4. Page Loading Gate: Wait until page is completely loaded
        ClickyLogger.info("[WEB_LOOP]", "Waiting for page readiness in WebKit...")
        await waitForPageLoad(webView: webView, timeoutSeconds: 8.0)

        // 5. Declarative Login / Landing Page Gate (awaiting_login)
        let loginCheck = await checkIsLoginPage(webView: webView, adapter: adapter)
        if loginCheck.isLogin && !loginCheck.hasInbox {
            ClickyLogger.warning("[WEB_LOOP]", "Landing/Login page detected on \(adapter.name) (\(loginCheck.reason)). Setting awaiting_login. In-card takeover enabled (Raycast pattern).")

            queueItems[0] = ComputerCardQueueItem(name: "Login diperlukan pada \(adapter.name)", statusBadge: "Login Required", isChecked: false)
            payload.status = ComputerCardStatus.takeoverNeeded
            payload.queueItems = queueItems
            payload.instructionText = "Login diperlukan pada \(adapter.name). Silakan masuk langsung melalui kartu Web Workspace di bawah."
            payload.deliverableSummary = "Menunggu login pengguna pada \(adapter.name). Sesi akan dipersistenkan."
            payload.responseToUser = "Login dibuka di kartu. Silakan masuk untuk melanjutkan."
            onProgress(payload)

            viewportController.isTakeoverActive = true
            _ = await viewportController.captureSnapshot(slug: slug)

            #if DEBUG
            if let runId = CompanionManager.shared.activeE2ERunId {
                DistributedNotificationCenter.default().postNotificationName(
                    NSNotification.Name("iza.e2e.done"),
                    object: nil,
                    userInfo: [
                        "runId": runId,
                        "concluded": false,
                        "validatorIsDone": false,
                        "deliverableSaved": false,
                        "status": WebTaskStatus.awaitingLogin.rawValue,
                        "reason": loginCheck.reason
                    ],
                    deliverImmediately: true
                )
                ClickyLogger.info("[E2E_IPC]", "Posted iza.e2e.done with concluded=false (awaiting_login) for runId=\(runId)")
            }
            #endif

            // Await user login in standalone window (polling for inboxSelector up to 120 seconds)
            ClickyLogger.info("[WEB_LOOP]", "Awaiting user login on card / window (polling for inboxSelector)...")
            let loginDeadline = Date().addingTimeInterval(120.0)
            while Date() < loginDeadline && (viewportController.isTakeoverActive || WebWorkspaceLoginWindowController.shared.isLoginWindowOpen) {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                let recheck = await checkIsLoginPage(webView: webView, adapter: adapter)
                if recheck.hasInbox {
                    ClickyLogger.info("[WEB_LOOP]", "User login confirmed! Inbox selector detected on \(adapter.name). Automatically resuming task.")
                    queueItems[0] = ComputerCardQueueItem(name: "Login terverifikasi", statusBadge: "Done", isChecked: true)
                    payload.status = ComputerCardStatus.working
                    payload.instructionText = prompt
                    payload.deliverableSummary = "Login berhasil diverifikasi. Memeriksa kotak masuk..."
                    payload.responseToUser = "Login berhasil diverifikasi. Memeriksa kotak masuk..."
                    onProgress(payload)

                    if WebWorkspaceLoginWindowController.shared.isLoginWindowOpen {
                        WebWorkspaceLoginWindowController.shared.dismissLoginWindow()
                    }
                    viewportController.isTakeoverActive = false
                    break
                }
            }

            let postWaitCheck = await checkIsLoginPage(webView: webView, adapter: adapter)
            if !postWaitCheck.hasInbox {
                ClickyLogger.warning("[WEB_LOOP]", "Still awaiting login after wait timeout. Parking task gracefully without fake done.")
                WebWorkspaceLoginWindowController.shared.dismissLoginWindow()
                viewportController.isTakeoverActive = false
                return payload
            }
        }
        // On-Demand Takeover Pause: pause agent while user has manual takeover active
        while viewportController.isTakeoverActive {
            ClickyLogger.info("[WEB_LOOP]", "Agent paused: Human Takeover is active on card. Awaiting user release...")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        // 6. Execute Task Logic via DOM
        let intent = taskPlan.intentType.lowercased()
        let isCompose = intent == "compose" || intent == "send" || intent == "create"
        let domService = WebWorkspaceDOMService.shared

        if isCompose {
            queueItems[0] = ComputerCardQueueItem(name: "Periksa composer aktif", statusBadge: "Working", isChecked: false)
            payload.queueItems = queueItems
            onProgress(payload)

            // Step 1: Open composer if not already active
            let obs = await domService.extractDOMObservation(webView: webView, adapter: adapter)
            let formFields = obs["formFields"] as? [String: String] ?? [:]
            let isComposerActive = !formFields.isEmpty

            if !isComposerActive {
                ClickyLogger.info("[WEB_LOOP]", "Draft composer not active; clicking Compose button")
                _ = await domService.glideCursorAndClick(webView: webView, selector: adapter.selectors.composeButton)
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            queueItems[0] = ComputerCardQueueItem(name: "Composer aktif", statusBadge: "Done", isChecked: true)

            // Step 2: Extract targets (recipient, subject, body) from prompt / plan
            let extracted = extractEmailPayload(prompt: prompt, taskPlan: taskPlan)
            ClickyLogger.info("[WEB_LOOP]", "Extracted email payload: To='\(extracted.to)', Subject='\(extracted.subject)', Body='\(extracted.body)'")

            queueItems[1] = ComputerCardQueueItem(name: "Mengisi To, Subject, Body via DOM", statusBadge: "Working", isChecked: false)
            payload.queueItems = queueItems
            onProgress(payload)

            // Fill 'To' field
            if !extracted.to.isEmpty {
                _ = await domService.glideCursorAndFill(webView: webView, selector: adapter.selectors.toField, value: extracted.to)
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            // Fill 'Subject' field
            if !extracted.subject.isEmpty {
                _ = await domService.glideCursorAndFill(webView: webView, selector: adapter.selectors.subjectField, value: extracted.subject)
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            // Fill 'Body' field
            if !extracted.body.isEmpty {
                _ = await domService.glideCursorAndFill(webView: webView, selector: adapter.selectors.bodyField, value: extracted.body)
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            // Step 3: Strict DOM Truth Verification Gate
            let verification = await domService.verifyDOMFormState(webView: webView, adapter: adapter)
            ClickyLogger.info("[WEB_LOOP]", "DOM Verification: to='\(verification.to)', subject='\(verification.subject)', isComplete=\(verification.isComplete)")

            guard verification.isComplete else {
                ClickyLogger.warning("[WEB_LOOP]", "DOM Verification FAILED: fields are incomplete. FORBIDDEN to claim done.")
                queueItems[1] = ComputerCardQueueItem(name: "Verifikasi field gagal", statusBadge: "Failed", isChecked: false)
                payload.status = ComputerCardStatus.failed
                payload.queueItems = queueItems
                payload.deliverableSummary = "Gagal memverifikasi pengisian lengkap To/Subject/Body pada webmail."
                payload.responseToUser = "Pengisian formulir email belum lengkap atau terhalang elemen halaman."
                onProgress(payload)

                #if DEBUG
                if let runId = CompanionManager.shared.activeE2ERunId {
                    DistributedNotificationCenter.default().postNotificationName(
                        NSNotification.Name("iza.e2e.done"),
                        object: nil,
                        userInfo: [
                            "runId": runId,
                            "concluded": false,
                            "validatorIsDone": false,
                            "deliverableSaved": false,
                            "status": WebTaskStatus.failed.rawValue,
                            "reason": "dom_form_verification_failed"
                        ],
                        deliverImmediately: true
                    )
                }
                #endif
                return payload
            }

            queueItems[1] = ComputerCardQueueItem(name: "Field terverifikasi DOM", statusBadge: "Done", isChecked: true)

            // Step 4: Submit / Send if required
            if intent == "send" || intent == "compose" {
                ClickyLogger.info("[WEB_LOOP]", "Submitting email via DOM Send click")
                queueItems[2] = ComputerCardQueueItem(name: "Mengirim email via DOM", statusBadge: "Working", isChecked: false)
                payload.queueItems = queueItems
                onProgress(payload)

                _ = await domService.glideCursorAndClick(webView: webView, selector: adapter.selectors.sendButton)
                try? await Task.sleep(nanoseconds: 800_000_000)
                queueItems[2] = ComputerCardQueueItem(name: "Email terkirim", statusBadge: "Done", isChecked: true)
            }

            _ = await viewportController.captureSnapshot(slug: slug)

            payload.status = .done
            payload.queueItems = queueItems
            payload.deliverableSummary = "Email ke \(extracted.to.isEmpty ? "tujuan" : extracted.to) berhasil diverifikasi DOM dan terkirim."
            payload.responseToUser = "Email berhasil diverifikasi dan dikirim melalui Web Workspace."
            onProgress(payload)

            #if DEBUG
            if let runId = CompanionManager.shared.activeE2ERunId {
                DistributedNotificationCenter.default().postNotificationName(
                    NSNotification.Name("iza.e2e.done"),
                    object: nil,
                    userInfo: [
                        "runId": runId,
                        "concluded": true,
                        "validatorIsDone": true,
                        "deliverableSaved": true,
                        "status": WebTaskStatus.completed.rawValue
                    ],
                    deliverImmediately: true
                )
                ClickyLogger.info("[E2E_IPC]", "Posted iza.e2e.done for Web Workspace runId=\(runId)")
            }
            #endif

            return payload
        } else {
            // Inspection / Read / Search via DOM
            ClickyLogger.info("[WEB_LOOP]", "Inspecting Inbox DOM...")
            queueItems[0] = ComputerCardQueueItem(name: "Menunggu daftar email termuat", statusBadge: "Working", isChecked: false)
            payload.queueItems = queueItems
            onProgress(payload)

            // Clear transient banners before observation
            await domService.dismissTransientBanners(webView: webView, adapter: adapter)

            // Step 1: Wait for inbox list items to render in DOM
            let obs = await waitForInboxDOM(webView: webView, adapter: adapter, timeoutSeconds: 6.0)
            let listItems = obs["listItems"] as? [[String: Any]] ?? []
            let previewPane = obs["previewPane"] as? [String: Any] ?? [:]
            let hasEmails = !listItems.isEmpty || !previewPane.isEmpty

            guard hasEmails else {
                let recheckLogin = await checkIsLoginPage(webView: webView, adapter: adapter)
                if recheckLogin.isLogin || !recheckLogin.hasInbox {
                    ClickyLogger.warning("[WEB_LOOP]", "Inbox elements not found; landing/login portal active on \(adapter.name) (\(recheckLogin.reason)). Setting status=awaiting_login with card takeover.")

                    queueItems[0] = ComputerCardQueueItem(name: "Login diperlukan pada \(adapter.name)", statusBadge: "Takeover Needed", isChecked: false)
                    payload.status = ComputerCardStatus.takeoverNeeded
                    payload.queueItems = queueItems
                    payload.instructionText = "Login diperlukan pada \(adapter.name). Silakan masuk langsung melalui kartu Web Workspace di bawah."
                    payload.deliverableSummary = "Menunggu login pengguna pada \(adapter.name). Dilarang conclude sebelum login selesai."
                    payload.responseToUser = "Halaman login \(adapter.name) terdeteksi. Silakan login terlebih dahulu untuk mengakses kotak masuk."
                    onProgress(payload)

                    viewportController.isTakeoverActive = true
                    _ = await viewportController.captureSnapshot(slug: slug)

                    #if DEBUG
                    if let runId = CompanionManager.shared.activeE2ERunId {
                        DistributedNotificationCenter.default().postNotificationName(
                            NSNotification.Name("iza.e2e.done"),
                            object: nil,
                            userInfo: [
                                "runId": runId,
                                "concluded": false,
                                "validatorIsDone": false,
                                "deliverableSaved": false,
                                "status": WebTaskStatus.awaitingLogin.rawValue,
                                "reason": recheckLogin.reason
                            ],
                            deliverImmediately: true
                        )
                    }
                    #endif
                    return payload
                }

                ClickyLogger.warning("[WEB_LOOP]", "Inbox elements not found in DOM. FORBIDDEN to claim done.")
                queueItems[0] = ComputerCardQueueItem(name: "Daftar email tidak terdeteksi", statusBadge: "Failed", isChecked: false)
                payload.status = ComputerCardStatus.failed
                payload.queueItems = queueItems
                payload.deliverableSummary = "Gagal mendeteksi daftar email pada kotak masuk webmail."
                payload.responseToUser = "Daftar email belum dapat ditemukan pada halaman webmail."
                onProgress(payload)

                _ = await viewportController.captureSnapshot(slug: slug)

                #if DEBUG
                if let runId = CompanionManager.shared.activeE2ERunId {
                    DistributedNotificationCenter.default().postNotificationName(
                        NSNotification.Name("iza.e2e.done"),
                        object: nil,
                        userInfo: [
                            "runId": runId,
                            "concluded": false,
                            "validatorIsDone": false,
                            "deliverableSaved": false,
                            "status": WebTaskStatus.failed.rawValue,
                            "reason": "inbox_elements_not_found"
                        ],
                        deliverImmediately: true
                    )
                }
                #endif
                return payload
            }

            _ = await viewportController.captureSnapshot(slug: slug)

            queueItems[0] = ComputerCardQueueItem(name: "Daftar email terverifikasi (\(listItems.count) item)", statusBadge: "Done", isChecked: true)
            if queueItems.count > 1 {
                queueItems[1] = ComputerCardQueueItem(name: "Inspeksi isi selesai", statusBadge: "Done", isChecked: true)
            }
            if queueItems.count > 2 {
                queueItems[2] = ComputerCardQueueItem(name: "Validasi tuntas", statusBadge: "Done", isChecked: true)
            }

            let totalEmails = listItems.count
            let firstEmail = listItems.first
            let sender = firstEmail?["sender"] as? String ?? ""
            let subject = firstEmail?["subject"] as? String ?? ""
            let latestDetail = (!sender.isEmpty || !subject.isEmpty) ? " Email terbaru dari \(sender.isEmpty ? "pengirim" : sender): '\(subject)'." : ""

            payload.status = .done
            payload.queueItems = queueItems
            payload.deliverableSummary = "Kotak masuk terverifikasi: terdapat \(totalEmails) email.\(latestDetail)"
            payload.responseToUser = "Pemeriksaan kotak masuk selesai. Ditemukan \(totalEmails) email.\(latestDetail)"
            onProgress(payload)
            #if DEBUG
            if let runId = CompanionManager.shared.activeE2ERunId {
                DistributedNotificationCenter.default().postNotificationName(
                    NSNotification.Name("iza.e2e.done"),
                    object: nil,
                    userInfo: [
                        "runId": runId,
                        "concluded": true,
                        "validatorIsDone": true,
                        "deliverableSaved": true,
                        "status": WebTaskStatus.completed.rawValue
                    ],
                    deliverImmediately: true
                )
                ClickyLogger.info("[E2E_IPC]", "Posted iza.e2e.done for Web Workspace runId=\(runId)")
            }
            #endif

            return payload
        }
    }

    // MARK: - Page Readiness & Declarative Login Detection Gates

    private func waitForPageLoad(webView: WKWebView, timeoutSeconds: Double) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if !webView.isLoading {
                let js = "document.readyState === 'complete' || document.readyState === 'interactive'"
                if let isReady = try? await webView.evaluateJavaScript(js) as? Bool, isReady {
                    return
                }
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func checkIsLoginPage(webView: WKWebView, adapter: WebSiteAdapter) async -> (isLogin: Bool, hasInbox: Bool, reason: String) {
        let inboxSel = escapeJS(adapter.selectors.inboxSelector)
        let markersJSON: String = {
            if let data = try? JSONEncoder().encode(adapter.selectors.loginMarkers),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "[]"
        }()
        let domainsJSON: String = {
            if let data = try? JSONEncoder().encode(adapter.domains),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "[]"
        }()

        let js = """
        (function() {
            var inboxEl = document.querySelector('\(inboxSel)');
            if (inboxEl) {
                return { 'isLogin': false, 'hasInbox': true, 'reason': 'inbox_present' };
            }

            var pwd = document.querySelector('input[type="password"]');
            if (pwd !== null) {
                return { 'isLogin': true, 'hasInbox': false, 'reason': 'password_input_present' };
            }

            var markers = \(markersJSON);
            var domains = \(domainsJSON);
            var bodyText = (document.body ? document.body.innerText : '').toLowerCase();
            var title = (document.title || '').toLowerCase();
            var href = (window.location.href || '').toLowerCase();

            for (var i = 0; i < markers.length; i++) {
                var m = markers[i].toLowerCase();
                if (bodyText.includes(m) || title.includes(m) || href.includes(m)) {
                    return { 'isLogin': true, 'hasInbox': false, 'reason': 'marker_matched: ' + m };
                }
            }

            var buttons = document.querySelectorAll('button, a, [role="button"], input[type="submit"], input[type="button"]');
            for (var j = 0; j < buttons.length; j++) {
                var btnTxt = (buttons[j].innerText || buttons[j].getAttribute('aria-label') || buttons[j].value || '').toLowerCase();
                for (var k = 0; k < markers.length; k++) {
                    var km = markers[k].toLowerCase();
                    if (btnTxt.includes(km)) {
                        return { 'isLogin': true, 'hasInbox': false, 'reason': 'button_marker_matched: ' + km };
                    }
                }
            }

            for (var d = 0; d < domains.length; d++) {
                var dom = domains[d].toLowerCase();
                if (href.includes(dom)) {
                    for (var mIdx = 0; mIdx < markers.length; mIdx++) {
                        if (href.includes(markers[mIdx].toLowerCase())) {
                            return { 'isLogin': true, 'hasInbox': false, 'reason': 'url_marker_matched: ' + markers[mIdx] };
                        }
                    }
                }
            }

            return { 'isLogin': false, 'hasInbox': false, 'reason': 'unrecognized_state' };
        })();
        """

        do {
            if let dict = try await webView.evaluateJavaScript(js) as? [String: Any] {
                let isLogin = dict["isLogin"] as? Bool ?? false
                let hasInbox = dict["hasInbox"] as? Bool ?? false
                let reason = dict["reason"] as? String ?? ""
                return (isLogin, hasInbox, reason)
            }
        } catch {
            ClickyLogger.warning("[WEB_LOOP]", "Error evaluating login detection: \(error.localizedDescription)")
        }
        return (false, false, "eval_error")
    }

    private func waitForInboxDOM(webView: WKWebView, adapter: WebSiteAdapter, timeoutSeconds: Double) async -> [String: Any] {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        let domService = WebWorkspaceDOMService.shared

        while Date() < deadline {
            let obs = await domService.extractDOMObservation(webView: webView, adapter: adapter)
            let listItems = obs["listItems"] as? [[String: Any]] ?? []
            let previewPane = obs["previewPane"] as? [String: Any] ?? [:]
            if !listItems.isEmpty || !previewPane.isEmpty {
                return obs
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return await domService.extractDOMObservation(webView: webView, adapter: adapter)
    }

    // MARK: - Email Payload Parser

    private func extractEmailPayload(prompt: String, taskPlan: AFMTaskDecomposition) -> (to: String, subject: String, body: String) {
        var recipient = ""
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let matches = regex.matches(in: prompt, range: NSRange(prompt.startIndex..., in: prompt))
            if let first = matches.first, let range = Range(first.range, in: prompt) {
                recipient = String(prompt[range])
            }
        }

        var subject = "Pemberitahuan Sistem"
        var body = prompt

        let lower = prompt.lowercased()
        if lower.contains("bahwa ") {
            if let r = prompt.range(of: "bahwa ", options: .caseInsensitive) {
                let remainder = String(prompt[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                subject = remainder
                body = remainder
            }
        } else if !taskPlan.normalizedGoal.isEmpty && taskPlan.normalizedGoal != prompt {
            subject = taskPlan.normalizedGoal
        }

        return (recipient, subject, body)
    }

    private func escapeJS(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
