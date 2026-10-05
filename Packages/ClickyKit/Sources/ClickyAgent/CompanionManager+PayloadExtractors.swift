//
//  CompanionManager+PayloadExtractors.swift
//  izaNotch (Izanotchy)
//
//  Decomposed extension for CompanionManager.
//

import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Defaults
import Foundation
import ClickyFoundation
import ClickyPlatform
import ClickyAIProviders
import ClickySpeech
import ClickyCUA
import ClickyReasoning
import ClickyAstronacci
import ClickyTradingView
import ClickyFuturesScout
import ClickyRoster
import ClickyDesignSystem

extension CompanionManager {
    // MARK: - Crypto Symbol Extractor Helper (Universal Dynamic Coin Detection)

    public static func extractTradingSymbol(from text: String, activeWorkSurface: ActiveWorkSurface? = nil) -> String {
        let lower = text.lowercased()

        // 1. Explicit user prompt priority (common base coins)
        let commonCoins = [
            "btc", "eth", "sol", "doge", "xrp", "ada", "pepe", "bnb", "avax", "link",
            "sui", "near", "apt", "fet", "wif", "shib", "render", "ondo", "kas", "tao",
            "inj", "sei", "arb", "op", "tia", "bonk", "floki", "ton", "dot", "ltc", "bch"
        ]
        for coin in commonCoins {
            if lower.range(of: "\\b\(coin)\\b", options: .regularExpression) != nil ||
               lower.contains("\(coin)usdt") ||
               lower.contains("\(coin)-usdt") {
                return "\(coin.uppercased())-USDT"
            }
        }

        // Strict regex for custom coin ticker explicitly paired with USDT/USD/PERP (e.g. "INJUSDT", "TAO-USDT", "ETH.P")
        let promptPattern = #"\b([A-Za-z0-9]{2,10})[-/:](?:USDT|USD|PERP)(?:\.P)?\b|\b([A-Za-z0-9]{2,10})(?:USDT|USD)(?:\.P)?\b"#
        if let regex = try? NSRegularExpression(pattern: promptPattern, options: .caseInsensitive) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            let stopWords: Set<String> = ["CHART", "ANALISA", "ANALISIS", "SETUP", "TRADE", "TRADING", "TIME", "FRAME", "LONG", "SHORT", "WAIT", "BINGX", "SWAP", "PERP", "CEK", "TOLONG", "COBA"]
            for match in matches {
                let range = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
                if range.location != NSNotFound {
                    let matchedStr = nsText.substring(with: range).uppercased()
                    if !stopWords.contains(matchedStr) && matchedStr.count >= 2 && matchedStr.count <= 10 && !matchedStr.allSatisfy({ $0.isNumber }) {
                        return "\(matchedStr)-USDT"
                    }
                }
            }
        }

        // 2. Active Window Title Auto-Detection (ONLY for TradingView Desktop)
        let isTVActive = activeWorkSurface?.appName.localizedCaseInsensitiveContains("TradingView") == true
        let windowTitle: String = {
            if isTVActive, let title = activeWorkSurface?.windowTitle, !title.isEmpty, title != "TradingView" {
                return title
            }
            let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
            if let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
                for info in infoList {
                    let owner = info[kCGWindowOwnerName as String] as? String ?? ""
                    let layer = info[kCGWindowLayer as String] as? Int ?? -1
                    if layer == 0 && owner.contains("TradingView") {
                        let name = info[kCGWindowName as String] as? String ?? ""
                        if !name.isEmpty && name != "TradingView" {
                            return name
                        }
                    }
                }
            }
            return ""
        }()

        if !windowTitle.isEmpty {
            ClickyLogger.info("[COMPANION]", "Inspecting TradingView window title for active ticker: '\(windowTitle)'")
            // Match pattern like "BTCUSDT.P / Unnamed" or "SOLUSDT / Unnamed" or "ETHUSDT"
            let titlePattern = #"([A-Za-z0-9]{2,10})(?:USDT|USD)(?:\.P)?"#
            if let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
               let match = titleRegex.firstMatch(in: windowTitle, options: [], range: NSRange(location: 0, length: (windowTitle as NSString).length)) {
                let coin = (windowTitle as NSString).substring(with: match.range(at: 1)).uppercased()
                let nonCoin: Set<String> = ["TRADINGVIEW", "UNNAMED", "CHART", "LAYOUT"]
                if !nonCoin.contains(coin) && coin.count >= 2 && !coin.allSatisfy({ $0.isNumber }) {
                    ClickyLogger.success("[COMPANION]", "Auto-detected active coin from TradingView window title: '\(coin)-USDT'")
                    return "\(coin)-USDT"
                }
            }
        }

        // 3. Graceful Fallback
        return "BTC-USDT"
    }

    // MARK: - Companion Proactive Feature Request Protocol

    public struct CompanionFeatureRequest: Codable {
        public let id: String
        public let timestamp: String
        public let companion: String
        public let goal: String
        public let feature: String
        public let reason: String
    }

    static func extractFeatureRequest(from text: String) -> (featureName: String, reason: String)? {
        let pattern = #"(?i)\[REQUEST_FEATURE:([^:\]]+):([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let nameRange = Range(match.range(at: 1), in: text),
              let reasonRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        let featureName = String(text[nameRange]).trimmingCharacters(in: .whitespaces)
        let reason = String(text[reasonRange]).trimmingCharacters(in: .whitespaces)
        return (featureName, reason)
    }

    func saveFeatureRequest(featureName: String, reason: String, goal: String) {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let folder = homeDir.appendingPathComponent(".izanotchy")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("feature_requests.json")

        let newItem = CompanionFeatureRequest(
            id: UUID().uuidString,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            companion: self.activeBuddy.name,
            goal: goal,
            feature: featureName,
            reason: reason
        )

        var existingItems: [CompanionFeatureRequest] = []
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([CompanionFeatureRequest].self, from: data) {
            existingItems = decoded
        }
        existingItems.append(newItem)
        if let encoded = try? JSONEncoder().encode(existingItems) {
            try? encoded.write(to: fileURL)
            ClickyLogger.success("[FEATURE_REQUEST]", "Saved companion feature request to \(fileURL.path)")
        }
    }

    // MARK: - TradingView Payload Extractor Helper

    static func parseSingleTradingViewMatch(_ match: NSTextCheckingResult, in text: String) -> TradingViewActionPayload? {
        guard let subTypeRange = Range(match.range(at: 1), in: text) else { return nil }
        let subType = String(text[subTypeRange]).lowercased()
        let param1: String = (match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound) ? String(text[Range(match.range(at: 2), in: text)!]).trimmingCharacters(in: .whitespaces) : ""
        let param2: String? = (match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound) ? String(text[Range(match.range(at: 3), in: text)!]).trimmingCharacters(in: .whitespaces) : nil

        switch subType {
        case "setup_workspace", "prepare_workspace", "init_workspace":
            let fullSymbol = (param2 != nil && !param2!.isEmpty) ? "\(param1):\(param2!)" : param1
            return TradingViewActionPayload(
                actionType: .setupWorkspace,
                parameter: fullSymbol.isEmpty ? nil : fullSymbol,
                rawDetails: "Workspace Hygiene & Symbol Alignment"
            )

        case "close_modal", "dismiss", "dismiss_modal":
            return TradingViewActionPayload(
                actionType: .closeModal,
                rawDetails: "Dismiss active modal or popup"
            )

        case "toggle_sidebar", "close_sidebar", "sidebar":
            return TradingViewActionPayload(
                actionType: .toggleSidebar,
                rawDetails: "Toggle/Close Watchlist Sidebar"
            )

        case "maximize", "fullscreen":
            return TradingViewActionPayload(
                actionType: .maximize,
                rawDetails: "Maximize TradingView window"
            )

        case "reset_scale", "autoscale", "scale":
            return TradingViewActionPayload(
                actionType: .resetScale,
                rawDetails: "Auto-Fit and Reset Chart Scale (⌥+R)"
            )

        case "tool":
            var pts: [CGPoint] = []
            if let pointsStr = param2 {
                pts = pointsStr.split(separator: "|").compactMap { pair in
                    let coords = pair.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    if coords.count >= 2 { return CGPoint(x: coords[0], y: coords[1]) }
                    return nil
                }
            }
            return TradingViewActionPayload(
                actionType: .drawWithTool,
                toolName: param1,
                points: pts.isEmpty ? nil : pts,
                rawDetails: "Draw \(param1) on TradingView"
            )

        case "timeframe":
            return TradingViewActionPayload(
                actionType: .timeframe,
                parameter: param1,
                rawDetails: "Switch timeframe to \(param1)"
            )

        case "symbol":
            let fullSymbol = (param2 != nil && !param2!.isEmpty) ? "\(param1):\(param2!)" : param1
            return TradingViewActionPayload(
                actionType: .symbol,
                parameter: fullSymbol,
                rawDetails: "Switch symbol to \(fullSymbol)"
            )

        case "indicator":
            return TradingViewActionPayload(
                actionType: .addIndicator,
                parameter: param1,
                rawDetails: "Add indicator \(param1)"
            )

        case "pine":
            let code = param2 != nil ? "\(param1):\(param2!)" : param1
            return TradingViewActionPayload(
                actionType: .injectPineScript,
                pineScript: code,
                rawDetails: "Inject Pine Script"
            )

        case "clear", "cleardrawings", "clear_drawings":
            return TradingViewActionPayload(
                actionType: .clearDrawings,
                rawDetails: "Clear drawings on chart"
            )

        default:
            return TradingViewActionPayload(
                actionType: .timeframe,
                parameter: param1,
                rawDetails: "TradingView action: \(param1)"
            )
        }
    }

    static func extractTradingViewPayload(from text: String) -> TradingViewActionPayload? {
        // Special robust extraction for Pine Script (Tier 4) which can contain colons, brackets, or newlines
        if let pineStartRange = text.range(of: #"(?i)\[ACTION:tv_pine:"#, options: .regularExpression) {
            let remainder = text[pineStartRange.upperBound...]
            var depth = 1
            var scriptEnd: String.Index? = nil
            for idx in remainder.indices {
                if remainder[idx] == "[" {
                    depth += 1
                } else if remainder[idx] == "]" {
                    depth -= 1
                    if depth == 0 {
                        scriptEnd = idx
                        break
                    }
                }
            }
            if let endIdx = scriptEnd {
                let script = String(remainder[..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                return TradingViewActionPayload(
                    actionType: .injectPineScript,
                    pineScript: script,
                    rawDetails: "Inject Dynamic Pine Script v5"
                )
            }
        }

        let tvPattern = #"(?i)\[ACTION:tv_([a-z_]+)(?::([^:\]]+))?(?::([^\]]+))?\]"#
        guard let tvRegex = try? NSRegularExpression(pattern: tvPattern, options: []) else { return nil }
        let matches = tvRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return nil }

        let payloads = matches.compactMap { parseSingleTradingViewMatch($0, in: text) }
        guard !payloads.isEmpty else { return nil }

        if payloads.count == 1 {
            return payloads[0]
        } else {
            // Multi-action chained sequence
            let titles = payloads.map { $0.rawDetails }.joined(separator: " ➔ ")
            return TradingViewActionPayload(
                actionType: .chain,
                subActions: payloads,
                rawDetails: "Multi-action sequence: \(titles)"
            )
        }
    }

    static func parseProposedAction(from responseText: String) -> (cleanedText: String, action: ComputerUseProposedAction?) {
        // Robust extraction for tv_pine with bracket depth counting
        if let pineStartRange = responseText.range(of: #"(?i)\[ACTION:tv_pine:"#, options: .regularExpression) {
            let remainder = responseText[pineStartRange.upperBound...]
            var depth = 1
            var scriptEnd: String.Index? = nil
            for idx in remainder.indices {
                if remainder[idx] == "[" {
                    depth += 1
                } else if remainder[idx] == "]" {
                    depth -= 1
                    if depth == 0 {
                        scriptEnd = idx
                        break
                    }
                }
            }
            if let endIdx = scriptEnd {
                let fullTagRange = pineStartRange.lowerBound...endIdx
                let cleaned = responseText.replacingCharacters(in: fullTagRange, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if let tvPayload = extractTradingViewPayload(from: responseText) {
                    let action = ComputerUseProposedAction(
                        category: "TradingView",
                        appName: "TradingView",
                        appIcon: "chart.line.uptrend.xyaxis",
                        title: tvPayload.rawDetails,
                        details: "TradingView automation: \(tvPayload.rawDetails). Izanotchy will execute this action upon your confirmation.",
                        targetCoordinate: nil,
                        actionType: .runScript
                    )
                    return (cleaned, action)
                }
            }
        }

        let tvPattern = #"(?i)\[ACTION:tv_([a-z_]+)(?::([^:\]]+))?(?::([^\]]+))?\]"#
        if let tvRegex = try? NSRegularExpression(pattern: tvPattern, options: []),
           let match = tvRegex.firstMatch(in: responseText, range: NSRange(responseText.startIndex..., in: responseText)) {
            let cleaned = tvRegex.stringByReplacingMatches(
                in: responseText,
                options: [],
                range: NSRange(responseText.startIndex..., in: responseText),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            if let tvPayload = extractTradingViewPayload(from: responseText) {
                let action = ComputerUseProposedAction(
                    category: "TradingView",
                    appName: "TradingView",
                    appIcon: "chart.line.uptrend.xyaxis",
                    title: tvPayload.rawDetails,
                    details: "TradingView automation: \(tvPayload.rawDetails). Izanotchy will execute this action upon your confirmation.",
                    targetCoordinate: nil,
                    actionType: .runScript
                )
                return (cleaned, action)
            }
        }

        let actionPattern = #"(?i)\[ACTION:([a-z_]+):([^:\]]+):([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: actionPattern, options: []),
              let match = regex.firstMatch(in: responseText, range: NSRange(responseText.startIndex..., in: responseText)) else {
            return (responseText, nil)
        }

        let cleaned = regex.stringByReplacingMatches(
            in: responseText,
            options: [],
            range: NSRange(responseText.startIndex..., in: responseText),
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard match.numberOfRanges >= 4,
              let typeRange = Range(match.range(at: 1), in: responseText),
              let targetRange = Range(match.range(at: 2), in: responseText),
              let descRange = Range(match.range(at: 3), in: responseText) else {
            return (cleaned, nil)
        }

        let actionTypeStr = String(responseText[typeRange]).lowercased()
        let targetStr = String(responseText[targetRange]).trimmingCharacters(in: .whitespaces)
        let descStr = String(responseText[descRange]).trimmingCharacters(in: .whitespaces)

        let actionType: ComputerUseProposedAction.ActionType
        switch actionTypeStr {
        case "click": actionType = .click
        case "key_combo", "shortcut": actionType = .keyCombo
        case "launch", "launch_app", "open_app": actionType = .launchApp
        default: actionType = .click
        }

        var parsedCoordinate: CGPoint? = nil
        let parts = targetStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count >= 2 {
            parsedCoordinate = CGPoint(x: parts[0], y: parts[1])
        }

        // Robust target app resolution:
        var resolvedAppName = "Active App"
        if actionType == .launchApp {
            resolvedAppName = targetStr
        } else if parsedCoordinate == nil && !targetStr.isEmpty && targetStr.lowercased() != "current" && targetStr.lowercased() != "active app" {
            resolvedAppName = targetStr
        } else if let detected = ComputerUsePhysicalExecutor.resolveTargetAppName(appName: nil, details: "\(descStr) \(responseText)") {
            resolvedAppName = detected
        }

        let action = ComputerUseProposedAction(
            category: actionType == .launchApp ? "Application" : "System Action",
            appName: resolvedAppName,
            appIcon: actionType == .click ? "cursorarrow.click.2" : (actionType == .keyCombo ? "keyboard" : "macwindow"),
            title: descStr.isEmpty ? "Action on \(resolvedAppName)" : descStr,
            details: "Target: \(resolvedAppName). Izanotchy will safely perform this action upon your confirmation.",
            targetCoordinate: parsedCoordinate,
            actionType: actionType
        )
        return (cleaned, action)
    }

    static func parseComputerUseRequest(from responseText: String, activeBuddy: BuddySession?) -> (cleanedText: String, request: ComputerUseRequest?) {
        // 1. Check for <COMPUTER_USE_REQUEST>...</COMPUTER_USE_REQUEST>
        let requestPattern = #"(?s)<COMPUTER_USE_REQUEST>(.*?)</COMPUTER_USE_REQUEST>"#
        guard let requestRegex = try? NSRegularExpression(pattern: requestPattern, options: []),
              let requestMatch = requestRegex.firstMatch(in: responseText, range: NSRange(responseText.startIndex..., in: responseText)),
              let bodyRange = Range(requestMatch.range(at: 1), in: responseText) else {
            // Check if there is a raw [ACTION:...] without the wrapper tags
            let (cleanedRaw, rawAction) = parseProposedAction(from: responseText)
            if let action = rawAction {
                let tvPayload = extractTradingViewPayload(from: responseText)
                let payload = ComputerUseActionPayload(
                    type: tvPayload != nil ? .tradingViewAction : (action.actionType == .keyCombo ? .keyCombo : (action.actionType == .launchApp ? .launchApp : .click)),
                    targetCoordinate: action.targetCoordinate,
                    targetApp: action.appName,
                    tradingViewPayload: tvPayload,
                    rawDetails: action.title
                )
                let req = ComputerUseRequest(
                    companionId: activeBuddy?.id,
                    companionName: activeBuddy?.name ?? "Shippy",
                    companionMood: activeBuddy?.mood ?? .happy,
                    cloudColorHex: activeBuddy?.avatarColorHex ?? "#38BDF8",
                    ringColorHex: activeBuddy?.ringColorHex ?? "#BAE6FD",
                    heading: tvPayload != nil ? "TradingView Chart Action" : "Wants to use your Mac",
                    bodyText: action.details.isEmpty ? action.title : action.details,
                    payload: payload
                )
                return (cleanedRaw, req)
            }
            return (responseText, nil)
        }

        let innerContent = String(responseText[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        var actionPayload = ComputerUseActionPayload(type: .click, rawDetails: innerContent)
        var cleanedInner = innerContent

        // 2a. Check for TradingView actions [ACTION:tv_...]
        if let tvPayload = extractTradingViewPayload(from: innerContent) {
            actionPayload = ComputerUseActionPayload(
                type: .tradingViewAction,
                targetApp: "TradingView",
                tradingViewPayload: tvPayload,
                rawDetails: tvPayload.rawDetails
            )
            let tvPattern = #"(?i)\[ACTION:tv_([a-z_]+):([^:\]]+)(?::([^\]]+))?\]"#
            if let tvRegex = try? NSRegularExpression(pattern: tvPattern, options: []) {
                cleanedInner = tvRegex.stringByReplacingMatches(
                    in: innerContent,
                    options: [],
                    range: NSRange(innerContent.startIndex..., in: innerContent),
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            // 2b. Standard [ACTION:type:target:details]
            let actionPattern = #"(?i)\[ACTION:([a-z_]+):([^:\]]+):([^\]]+)\]"#
            if let actionRegex = try? NSRegularExpression(pattern: actionPattern, options: []),
               let actionMatch = actionRegex.firstMatch(in: innerContent, range: NSRange(innerContent.startIndex..., in: innerContent)) {
                if let typeRange = Range(actionMatch.range(at: 1), in: innerContent),
                   let targetRange = Range(actionMatch.range(at: 2), in: innerContent),
                   let detailsRange = Range(actionMatch.range(at: 3), in: innerContent) {
                    let typeStr = String(innerContent[typeRange]).lowercased()
                    let targetStr = String(innerContent[targetRange]).trimmingCharacters(in: .whitespaces)
                    let detailsStr = String(innerContent[detailsRange]).trimmingCharacters(in: .whitespaces)

                    let actType: ComputerUseActionPayload.ActionType
                    switch typeStr {
                    case "click": actType = .click
                    case "right_click", "rightclick": actType = .rightClick
                    case "double_click", "doubleclick": actType = .doubleClick
                    case "type", "type_text", "typetext": actType = .typeText
                    case "shortcut", "key_combo", "keycombo": actType = .keyCombo
                    case "launch", "open_app", "launch_app": actType = .launchApp
                    case "scroll": actType = .scroll
                    default: actType = .click
                    }

                    var targetCoord: CGPoint? = nil
                    if actType == .click || actType == .rightClick || actType == .doubleClick {
                        let parts = targetStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                        if parts.count >= 2 {
                            targetCoord = CGPoint(x: parts[0], y: parts[1])
                        }
                    }

                    var targetAppName: String? = targetStr.isEmpty ? nil : targetStr
                    if targetAppName == nil || targetAppName?.lowercased() == "current" || targetAppName?.lowercased() == "active app" {
                        if let detected = ComputerUsePhysicalExecutor.resolveTargetAppName(appName: targetAppName, details: "\(detailsStr) \(innerContent) \(responseText)") {
                            targetAppName = detected
                        }
                    }

                    actionPayload = ComputerUseActionPayload(
                        type: actType,
                        targetCoordinate: targetCoord,
                        textToType: actType == .typeText ? detailsStr : nil,
                        targetApp: targetAppName,
                        keyCombo: actType == .keyCombo ? (detailsStr.isEmpty ? targetStr : detailsStr) : nil,
                        rawDetails: detailsStr.isEmpty ? targetStr : detailsStr
                    )

                    cleanedInner = actionRegex.stringByReplacingMatches(
                        in: innerContent,
                        options: [],
                        range: NSRange(innerContent.startIndex..., in: innerContent),
                        withTemplate: ""
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        let cleanedText = requestRegex.stringByReplacingMatches(
            in: responseText,
            options: [],
            range: NSRange(responseText.startIndex..., in: responseText),
            withTemplate: cleanedInner
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let heading = actionPayload.type == .tradingViewAction ? "TradingView Chart Action" : "Wants to use your Mac"
        let fallbackBody = actionPayload.type == .tradingViewAction ? "Aku ingin menganalisis dan menggambarkan level teknikal di TradingView. Boleh aku lakukan sekarang?" : "Aku perlu mengambil alih layar sebentar untuk melakukan aksi ini. Boleh aku lakukan sekarang?"

        let request = ComputerUseRequest(
            companionId: activeBuddy?.id,
            companionName: activeBuddy?.name ?? "Shippy",
            companionMood: activeBuddy?.mood ?? .happy,
            cloudColorHex: activeBuddy?.avatarColorHex ?? "#38BDF8",
            ringColorHex: activeBuddy?.ringColorHex ?? "#BAE6FD",
            heading: heading,
            bodyText: cleanedInner.isEmpty ? fallbackBody : cleanedInner,
            payload: actionPayload
        )

        return (cleanedText, request)
    }
}

// MARK: - CompanionReportPresenter Conformance

extension CompanionManager: CompanionReportPresenter {}

