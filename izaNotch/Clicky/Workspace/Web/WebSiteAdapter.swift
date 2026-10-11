//
//  WebSiteAdapter.swift
//  izaNotch (Izanotchy)
//
//  Unified Single Source of Truth for Web Surfaces, Routing Metadata, and DOM Selectors (TASK-046).
//  Zero Hardcoding: Surfaces, routing metadata, domains, selectors, and dismissSelectors are all unified here.
//

import Foundation

public struct WebSiteSelectorMap: Codable, Sendable {
    public let toField: String
    public let subjectField: String
    public let bodyField: String
    public let composeButton: String
    public let sendButton: String
    public let listItems: String
    public let emailRow: String?
    public let inboxSelector: String
    public let loginMarkers: [String]
    public let dismissSelectors: [String]

    public init(
        toField: String,
        subjectField: String,
        bodyField: String,
        composeButton: String,
        sendButton: String,
        listItems: String,
        emailRow: String? = nil,
        inboxSelector: String,
        loginMarkers: [String],
        dismissSelectors: [String] = []
    ) {
        self.toField = toField
        self.subjectField = subjectField
        self.bodyField = bodyField
        self.composeButton = composeButton
        self.sendButton = sendButton
        self.listItems = listItems
        self.emailRow = emailRow
        self.inboxSelector = inboxSelector
        self.loginMarkers = loginMarkers
        self.dismissSelectors = dismissSelectors
    }
}

public struct WebSiteAdapter: Sendable {
    public let id: String
    public let name: String
    public let domains: [String]
    public let entryURL: URL
    public let supportedAppIdentifiers: Set<String>
    public let supportedIntentTypes: Set<String>
    public let selectors: WebSiteSelectorMap

    public init(
        id: String,
        name: String,
        domains: [String],
        entryURL: URL,
        supportedAppIdentifiers: Set<String> = [],
        supportedIntentTypes: Set<String> = [],
        selectors: WebSiteSelectorMap
    ) {
        self.id = id
        self.name = name
        self.domains = domains
        self.entryURL = entryURL
        self.supportedAppIdentifiers = supportedAppIdentifiers
        self.supportedIntentTypes = supportedIntentTypes
        self.selectors = selectors
    }
}

public final class WebSiteAdapterRegistry: @unchecked Sendable {
    public static let shared = WebSiteAdapterRegistry()
    public static let defaultAdapterId = "gmail"

    public var defaultAdapter: WebSiteAdapter {
        adapters.first(where: { $0.id == Self.defaultAdapterId }) ?? adapters[0]
    }

    public private(set) var adapters: [WebSiteAdapter] = [
        WebSiteAdapter(
            id: "gmail",
            name: "Google Gmail",
            domains: ["mail.google.com", "accounts.google.com"],
            entryURL: URL(string: "https://mail.google.com")!,
            supportedAppIdentifiers: ["mail", "webmail", "gmail"],
            supportedIntentTypes: ["compose", "send", "inspect", "read", "search", "interact"],
            selectors: WebSiteSelectorMap(
                toField: "input[aria-label*='To'], input[peoplekit-id], textarea[name='to'], [name='to'], input[aria-label*='Kepada'], [role='combobox'][aria-label*='To']",
                subjectField: "input[name='subjectbox'], [aria-label*='Subject'], [aria-label*='Subjek']",
                bodyField: "[role='textbox'][aria-label*='Message Body'], [role='textbox'][aria-label*='Isi Pesan'], [g_editable='true'], .Am.Al.editable",
                composeButton: "[role='button'][gh='cm'], .T-I.T-I-KE.L3, [aria-label*='Compose'], [aria-label*='Tulis']",
                sendButton: "[role='button'][data-tooltip*='Send'], [role='button'][aria-label*='Send'], [role='button'][aria-label*='Kirim'], .T-I.J-J5-Ji.aoO.v7.T-I-atl.L3",
                listItems: "tr.zA, [role='row']",
                emailRow: "tr.zA",
                inboxSelector: "tr.zA, [role='main'] [role='row'], [gh='cm'], [aria-label*='Inbox'], [aria-label*='Kotak Masuk'], .UI tr",
                loginMarkers: ["sign in", "choose an account", "pilih akun", "masuk ke akun", "login", "create account", "identifierid", "input[type='email']", "input[type='password']"],
                dismissSelectors: ["button[aria-label*='Dismiss']", "button[aria-label*='Tutup']", ".bBe", "[role='alertdialog'] button", "[aria-label*='Tidak, terima kasih']", "[aria-label*='No thanks']", ".gb_Vd button", ".gb_Wd", "#gb a[role='button']"]
            )
        ),
        WebSiteAdapter(
            id: "outlook",
            name: "Microsoft Outlook",
            domains: ["outlook.live.com", "outlook.office.com", "outlook.office365.com", "login.live.com"],
            entryURL: URL(string: "https://outlook.live.com/mail/")!,
            supportedAppIdentifiers: ["mail", "webmail", "outlook"],
            supportedIntentTypes: ["compose", "send", "inspect", "read", "search", "interact"],
            selectors: WebSiteSelectorMap(
                toField: "[role='combobox'][aria-label*='To'], [aria-label*='Kepada'], input[id*='to'], [data-testid='to-picker']",
                subjectField: "input[aria-label*='Add a subject'], input[placeholder*='Add a subject'], [aria-label*='Subjek'], input[id*='subject']",
                bodyField: "[role='textbox'][aria-label*='Message body'], [aria-label*='Isi pesan'], [contenteditable='true'], [data-testid='editor-body']",
                composeButton: "button[aria-label*='New mail'], button[aria-label*='Pesan baru'], [data-icon-name='ComposeRegular']",
                sendButton: "button[aria-label*='Send'], button[title*='Send'], [aria-label*='Kirim'], [data-testid='send-button']",
                listItems: "[role='listbox'] [role='option'], [data-convid]",
                emailRow: "[data-convid]",
                inboxSelector: "[role='listbox'] [role='option'], [data-convid], [aria-label*='Inbox'], [aria-label*='Kotak Masuk']",
                loginMarkers: ["sign in", "masuk", "i0116", "i0118", "login", "input[type='password']"],
                dismissSelectors: ["button[aria-label*='Close']", "button[aria-label*='Tutup']", "#close-button", "[data-icon-name='Cancel']"]
            )
        ),
        WebSiteAdapter(
            id: "icloud",
            name: "Apple iCloud Mail",
            domains: ["icloud.com", "www.icloud.com", "idmsa.apple.com"],
            entryURL: URL(string: "https://www.icloud.com/mail")!,
            supportedAppIdentifiers: ["mail", "webmail", "icloud"],
            supportedIntentTypes: ["compose", "send", "inspect", "read", "search", "interact"],
            selectors: WebSiteSelectorMap(
                toField: "input[type='email'], input[name='to'], [aria-label*='To']",
                subjectField: "input[name='subject'], [aria-label*='Subject']",
                bodyField: "textarea, [contenteditable='true'], [role='textbox']",
                composeButton: "button[aria-label*='New Message'], [role='button'][aria-label*='Compose']",
                sendButton: "button[aria-label*='Send'], [role='button'][aria-label*='Send']",
                listItems: "[role='listitem'], .mail-list-item",
                emailRow: "[role='listitem']",
                inboxSelector: "[role='listbox'], [role='listitem'], .mail-list-item, [data-test-id*='mailbox'], [aria-label*='Mailboxes']",
                loginMarkers: ["private, secure and personal", "sign in", "sign in with apple", "apple id", "masuk", "use a different apple id", "password-input"],
                dismissSelectors: ["button[aria-label*='Dismiss']", ".banner-dismiss", "button.close-btn"]
            )
        ),
        WebSiteAdapter(
            id: "browser",
            name: "Web Browser",
            domains: ["google.com", "bing.com", "duckduckgo.com"],
            entryURL: URL(string: "https://www.google.com")!,
            supportedAppIdentifiers: ["safari", "chrome", "edge", "browser", "web"],
            supportedIntentTypes: ["browse", "search"],
            selectors: WebSiteSelectorMap(
                toField: "input[type='text'], input[type='search'], textarea",
                subjectField: "input[type='text'], input[type='search']",
                bodyField: "textarea, [contenteditable='true']",
                composeButton: "button[type='submit']",
                sendButton: "button[type='submit']",
                listItems: "[role='article'], h3, a",
                emailRow: "a",
                inboxSelector: "",
                loginMarkers: ["sign in", "log in", "masuk"],
                dismissSelectors: [".cookie-banner button", "[aria-label*='dismiss']", "[aria-label*='close']", ".modal-close"]
            )
        ),
        WebSiteAdapter(
            id: "generic_webmail",
            name: "Generic Webmail",
            domains: [],
            entryURL: URL(string: "about:blank")!,
            supportedAppIdentifiers: ["mail", "webmail"],
            supportedIntentTypes: ["compose", "send", "inspect", "read", "search", "interact"],
            selectors: WebSiteSelectorMap(
                toField: "input[type='email'], input[name*='to'], input[placeholder*='To'], [aria-label*='To'], [aria-label*='Kepada']",
                subjectField: "input[name*='subject'], input[placeholder*='Subject'], [aria-label*='Subject'], [aria-label*='Subjek']",
                bodyField: "[role='textbox'], [contenteditable='true'], textarea, [name*='body'], [name*='message']",
                composeButton: "button[aria-label*='New'], button[aria-label*='Compose'], [role='button'][aria-label*='New'], [role='button'][aria-label*='Compose']",
                sendButton: "button[type='submit'], button[aria-label*='Send'], [role='button'][aria-label*='Send'], input[type='submit']",
                listItems: "table tbody tr, ul li, [role='listitem']",
                emailRow: "tr",
                inboxSelector: "table tbody tr, ul li, [role='listitem'], [role='row']",
                loginMarkers: ["sign in", "log in", "masuk", "password", "username"],
                dismissSelectors: [".cookie-banner button", "[aria-label*='dismiss']", "[aria-label*='close']", ".modal-close"]
            )
        )
    ]

    private init() {}

    public func adapter(for url: URL?) -> WebSiteAdapter {
        guard let url = url, let host = url.host?.lowercased() else {
            return defaultAdapter
        }
        for adapter in adapters {
            if adapter.domains.contains(where: { host.contains($0) }) {
                return adapter
            }
        }
        return defaultAdapter
    }

    public func adapter(forProviderId providerId: String) -> WebSiteAdapter {
        let clean = providerId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return adapters.first(where: { $0.id == clean }) ?? defaultAdapter
    }
    /// Single Source of Truth for provider resolution from email host or domain
    public func adapter(forEmailHost host: String) -> WebSiteAdapter {
        return adapter(forEmailOrDomain: host)
    }

    /// Single Source of Truth for provider resolution from email addresses, domains, or prompt text
    public func adapter(forEmailOrDomain query: String) -> WebSiteAdapter {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for adapter in adapters {
            if clean.contains("@" + adapter.id) || clean.contains(adapter.id) {
                return adapter
            }
            for d in adapter.domains {
                if clean.contains(d) {
                    return adapter
                }
            }
        }
        return defaultAdapter
    }

    public func registerAdapter(_ adapter: WebSiteAdapter) {
        adapters.removeAll { $0.id == adapter.id }
        adapters.append(adapter)
    }
}
