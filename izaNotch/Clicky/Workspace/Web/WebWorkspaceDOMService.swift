//
//  WebWorkspaceDOMService.swift
//  izaNotch (Izanotchy)
//
//  Deterministic DOM Observation and Action Execution Service (TASK-046 Fase C).
//  Zero AX calls — The DOM is the eye and the hand.
//

import Foundation
import WebKit
import SwiftUI
public final class WebWorkspaceDOMService: @unchecked Sendable {
    public static let shared = WebWorkspaceDOMService()

    private init() {}

    // MARK: - DOM Observation

    /// Extracts structured observation from DOM matching Clicky JSON schema.
    public func extractDOMObservation(
        webView: WKWebView,
        adapter: WebSiteAdapter
    ) async -> [String: Any] {
        let toSel = escapeJS(adapter.selectors.toField)
        let subSel = escapeJS(adapter.selectors.subjectField)
        let bodySel = escapeJS(adapter.selectors.bodyField)
        let compSel = escapeJS(adapter.selectors.composeButton)
        let sendSel = escapeJS(adapter.selectors.sendButton)
        let listSel = escapeJS(adapter.selectors.listItems)

        let js = """
        (function() {
            var getVal = function(sel) {
                var el = document.querySelector(sel);
                if (!el) return '';
                if ('value' in el && el.value !== undefined) return el.value.trim();
                return (el.innerText || el.textContent || '').trim();
            };

            var exists = function(sel) {
                return document.querySelector(sel) !== null;
            };

            var toVal = getVal('\(toSel)');
            var subVal = getVal('\(subSel)');
            var bodyVal = getVal('\(bodySel)');

            var isComposerActive = exists('\(subSel)') || exists('\(bodySel)') || exists('\(toSel)');
            var windowType = isComposerActive ? 'draft_composer' : 'list';
            var activeContainer = isComposerActive ? 'draft_composer' : 'inbox';

            var formFields = {};
            if (isComposerActive) {
                formFields['To'] = toVal.length > 0 ? toVal : '[empty]';
                formFields['Subject'] = subVal.length > 0 ? subVal : '[empty]';
                formFields['Body'] = bodyVal.length > 0 ? bodyVal : '[empty]';
            }

            var topBar = [];
            if (exists('\(compSel)')) topBar.push('New Message');
            if (exists('\(sendSel)')) topBar.push('Send');

            var navElements = ['All Inboxes', 'Sent', 'Drafts'];

            var listItems = [];
            var rows = document.querySelectorAll('\(listSel)');
            for (var i = 0; i < Math.min(rows.length, 15); i++) {
                var r = rows[i];
                var senderEl = r.querySelector('[email], .yP, .zF, span[name], [data-hovercard-id], strong, b');
                var subjEl = r.querySelector('.bog, .bqe, [role="heading"], .subject, .mail-subject');
                var sender = senderEl ? (senderEl.innerText || '').trim() : '';
                var subject = subjEl ? (subjEl.innerText || '').trim() : '';
                var text = (r.innerText || '').trim();
                if (text.length > 0) {
                    var rect = r.getBoundingClientRect();
                    listItems.push({
                        'index': i + 1,
                        'sender': sender,
                        'subject': subject,
                        'headline': text.substring(0, 100),
                        'x': rect.left + (rect.width / 2.0),
                        'y': rect.top + (rect.height / 2.0)
                    });
                }
            }

            return {
                'windowType': windowType,
                'activeContainer': activeContainer,
                'formFields': formFields,
                'topBar': topBar,
                'navigationElements': navElements,
                'listItems': listItems,
                'viewport': { 'isAtTop': window.scrollY === 0, 'scrollOffset': window.scrollY }
            };
        })();
        """

        do {
            if let result = try await webView.evaluateJavaScript(js) as? [String: Any] {
                return result
            }
        } catch {
            ClickyLogger.warning("[WEB_DOM]", "Error evaluating DOM observation: \(error.localizedDescription)")
        }

        return [
            "windowType": "web_workspace",
            "activeContainer": "web_workspace",
            "formFields": [:],
            "topBar": [],
            "navigationElements": [],
            "listItems": [],
            "viewport": ["isAtTop": true, "scrollOffset": 0.0]
        ]
    }

    // MARK: - Transient Web Banners & Overlays Dismissal

    /// Clears cookie dialogs, promotional toasts, and temporary banners via declarative selectors
    public func dismissTransientBanners(webView: WKWebView, adapter: WebSiteAdapter) async {
        guard !adapter.selectors.dismissSelectors.isEmpty else { return }
        let selJSON = (try? String(data: JSONEncoder().encode(adapter.selectors.dismissSelectors), encoding: .utf8)) ?? "[]"
        let js = """
        (function() {
            var selectors = \(selJSON);
            var dismissed = 0;
            for (var i = 0; i < selectors.length; i++) {
                var el = document.querySelector(selectors[i]);
                if (el) {
                    if (typeof el.click === 'function') {
                        el.click();
                        dismissed++;
                    }
                }
            }
            return dismissed;
        })();
        """
        if let count = try? await webView.evaluateJavaScript(js) as? Int, count > 0 {
            ClickyLogger.info("[WEB_DOM]", "Dismissed \(count) transient web banner(s) using declarative dismissSelectors.")
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }
    // MARK: - Virtual Agent Cursor Motion (Grok Bot Pillar 2)

    /// Retrieves the center point of an element in WebKit viewport coordinates
    public func getElementCenter(webView: WKWebView, selector: String) async -> CGPoint? {
        let selEsc = escapeJS(selector)
        let js = """
        (function() {
            var el = document.querySelector('\(selEsc)');
            if (!el) {
                var buttons = document.querySelectorAll('button, [role="button"], a');
                for (var i = 0; i < buttons.length; i++) {
                    var txt = (buttons[i].innerText || buttons[i].getAttribute('aria-label') || '').toLowerCase();
                    if (txt.includes('compose') || txt.includes('tulis') || txt.includes('new') || txt.includes('send') || txt.includes('kirim')) {
                        el = buttons[i];
                        break;
                    }
                }
            }
            if (el) {
                var rect = el.getBoundingClientRect();
                return {
                    'x': rect.left + (rect.width / 2.0),
                    'y': rect.top + (rect.height / 2.0)
                };
            }
            return null;
        })();
        """

        if let dict = try? await webView.evaluateJavaScript(js) as? [String: Any],
           let rawX = dict["x"] as? Double, let rawY = dict["y"] as? Double {
            let zoom = await MainActor.run { webView.pageZoom }
            let scale = (zoom > 0) ? zoom : 1.0
            return CGPoint(x: rawX * scale, y: rawY * scale)
        }
        return nil
    }

    /// Glides virtual agent cursor smoothly to the element, pulses click, then executes DOM click
    public func glideCursorAndClick(webView: WKWebView, selector: String) async -> Bool {
        if let targetPt = await getElementCenter(webView: webView, selector: selector) {
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    CompanionVMViewportController.shared.vmCursorPosition = targetPt
                }
            }
            ClickyLogger.info("[WEB_CURSOR]", "Glided virtual agent cursor to element at (\(Int(targetPt.x)), \(Int(targetPt.y))) for selector: \(selector)")
            try? await Task.sleep(nanoseconds: 180_000_000)

            await MainActor.run {
                CompanionVMViewportController.shared.isClicking = true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                CompanionVMViewportController.shared.isClicking = false
            }
        }
        return await executeDOMClick(webView: webView, selector: selector)
    }

    /// Glides virtual agent cursor smoothly to the input element before filling it
    public func glideCursorAndFill(webView: WKWebView, selector: String, value: String) async -> Bool {
        if let targetPt = await getElementCenter(webView: webView, selector: selector) {
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    CompanionVMViewportController.shared.vmCursorPosition = targetPt
                }
            }
            ClickyLogger.info("[WEB_CURSOR]", "Glided virtual agent cursor to input field at (\(Int(targetPt.x)), \(Int(targetPt.y))) for selector: \(selector)")
            try? await Task.sleep(nanoseconds: 180_000_000)

            await MainActor.run {
                CompanionVMViewportController.shared.isClicking = true
            }
            try? await Task.sleep(nanoseconds: 80_000_000)
            await MainActor.run {
                CompanionVMViewportController.shared.isClicking = false
            }
        }
        return await executeDOMFill(webView: webView, selector: selector, value: value)
    }

    // MARK: - DOM Actions

    /// Injects a click event into an element matching the given CSS selector.
    public func executeDOMClick(
        webView: WKWebView,
        selector: String
    ) async -> Bool {
        let escaped = escapeJS(selector)
        let js = """
        (function() {
            var el = document.querySelector('\(escaped)');
            if (!el) {
                // Try button text fallback
                var buttons = document.querySelectorAll('button, [role="button"], a');
                for (var i = 0; i < buttons.length; i++) {
                    var txt = (buttons[i].innerText || buttons[i].getAttribute('aria-label') || '').toLowerCase();
                    if (txt.includes('compose') || txt.includes('tulis') || txt.includes('new') || txt.includes('send') || txt.includes('kirim')) {
                        el = buttons[i];
                        break;
                    }
                }
            }
            if (el) {
                if (typeof el.scrollIntoViewIfNeeded === 'function') {
                    el.scrollIntoViewIfNeeded();
                }
                el.focus();
                el.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, view: window }));
                el.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true, view: window }));
                el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                if (typeof el.click === 'function') {
                    el.click();
                }
                return true;
            }
            return false;
        })();
        """

        do {
            if let success = try await webView.evaluateJavaScript(js) as? Bool {
                return success
            }
        } catch {
            ClickyLogger.warning("[WEB_DOM]", "Error executing DOM click for '\(selector)': \(error.localizedDescription)")
        }
        return false
    }

    /// Fills input or contenteditable element with text and triggers change/input events.
    public func executeDOMFill(
        webView: WKWebView,
        selector: String,
        value: String
    ) async -> Bool {
        let selEsc = escapeJS(selector)
        let valEsc = escapeJS(value)
        let js = """
        (function() {
            var el = document.querySelector('\(selEsc)');
            if (el) {
                el.focus();
                if ('value' in el) {
                    el.value = '\(valEsc)';
                } else if (el.isContentEditable || el.getAttribute('contenteditable') === 'true' || el.getAttribute('role') === 'textbox') {
                    el.innerText = '\(valEsc)';
                } else {
                    el.textContent = '\(valEsc)';
                }
                el.dispatchEvent(new Event('focus', { bubbles: true }));
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            }
            return false;
        })();
        """

        do {
            if let success = try await webView.evaluateJavaScript(js) as? Bool {
                return success
            }
        } catch {
            ClickyLogger.warning("[WEB_DOM]", "Error executing DOM fill for '\(selector)': \(error.localizedDescription)")
        }
        return false
    }

    /// Verifies DOM form fields directly from live page elements.
    public func verifyDOMFormState(
        webView: WKWebView,
        adapter: WebSiteAdapter
    ) async -> (to: String, subject: String, body: String, isComplete: Bool) {
        let toSel = escapeJS(adapter.selectors.toField)
        let subSel = escapeJS(adapter.selectors.subjectField)
        let bodySel = escapeJS(adapter.selectors.bodyField)

        let js = """
        (function() {
            var getVal = function(sel) {
                var el = document.querySelector(sel);
                if (!el) return '';
                if ('value' in el && el.value !== undefined) return el.value.trim();
                return (el.innerText || el.textContent || '').trim();
            };
            return {
                'to': getVal('\(toSel)'),
                'subject': getVal('\(subSel)'),
                'body': getVal('\(bodySel)')
            };
        })();
        """

        do {
            if let dict = try await webView.evaluateJavaScript(js) as? [String: String] {
                let to = dict["to"] ?? ""
                let subject = dict["subject"] ?? ""
                let body = dict["body"] ?? ""
                let isComplete = !to.isEmpty && !subject.isEmpty && !body.isEmpty
                return (to, subject, body, isComplete)
            }
        } catch {
            ClickyLogger.warning("[WEB_DOM]", "Error verifying DOM form state: \(error.localizedDescription)")
        }

        return ("", "", "", false)
    }

    // MARK: - Helpers

    private func escapeJS(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
