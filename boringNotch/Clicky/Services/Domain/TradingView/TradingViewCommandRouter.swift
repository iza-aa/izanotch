//
//  TradingViewCommandRouter.swift
//  boringNotch
//
//  Command and Intent Parser for TradingView-specific workflows:
//  - /analisa, /chart, and chart analysis phrases
//  - Symbol extraction (BTC, ETH, SOL, tickers)
//  - Market analysis intents
//

import Foundation

public enum TradingViewCommandRouter {

    /// Attempts to parse a TradingView specific command (/analisa, /chart, or market analysis intent).
    /// Returns ClickyCommandCategory if matched, or nil if standard non-TradingView intent.
    public static func resolveTradingViewIntent(cleanSlash: String, rawTranscript: String) -> ClickyCommandCategory? {
        let isAnalisaCommand = (rawTranscript.hasPrefix("/") || rawTranscript.hasPrefix("!")) &&
                               (cleanSlash.hasPrefix("analisa") || cleanSlash.hasPrefix("chart"))
        let hasAnalisaPhrase = cleanSlash.contains("analisa chart") || cleanSlash.contains("analisis chart") ||
                               cleanSlash.contains("cek chart") || cleanSlash.contains("buka chart") ||
                               cleanSlash.contains("lihat chart") ||
                               cleanSlash.range(of: "\\b(analisa|analisis)\\s+([a-zA-Z0-9]{2,10})\\b", options: .regularExpression) != nil

        guard isAnalisaCommand || hasAnalisaPhrase else {
            return nil
        }

        // Exclude general explanation questions
        if cleanSlash.contains("apa itu") || cleanSlash.contains("jelaskan") || cleanSlash.contains("bagaimana") {
            return nil
        }

        let isMarketAnalysis = cleanSlash.contains("market") || cleanSlash.contains("pasar") || cleanSlash.contains("semua market") || cleanSlash.contains("all market")
        let noiseWords = [
            "analisa chart", "analisis chart", "cek chart", "buka chart", "lihat chart",
            "analisa", "analisis", "chart", "tradingview", "kripto", "crypto",
            "market", "pasar", "semua", "all",
            "bisa tolong", "tolong dong", "tolong", "please", "coba", "dan",
            "pair", "coin", "koin", "untuk", "pada", "di"
        ]

        var symbolCandidate = cleanSlash
        for word in noiseWords {
            symbolCandidate = symbolCandidate.replacingOccurrences(of: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b", with: " ", options: .regularExpression)
        }
        symbolCandidate = symbolCandidate.replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: " ", options: .regularExpression)
        symbolCandidate = symbolCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = symbolCandidate.split(separator: " ").map { String($0) }
        let validTokens = words.filter { token in
            let upper = token.uppercased()
            return token.count >= 2 && token.count <= 10 && !["USDT", "PERP", "SWAP", "COIN", "PAIR"].contains(upper)
        }.map { $0.uppercased() }

        if isMarketAnalysis {
            let customMarketsParam = validTokens.joined(separator: " ")
            return .aksi(actionType: "analisa_market", target: customMarketsParam)
        }

        let foundSymbol = validTokens.first ?? "BTCUSDT"
        return .aksi(actionType: "analisa", target: foundSymbol)
    }
}
