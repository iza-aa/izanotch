//
//  FuturesScoutMarketDataService.swift
//  izaNotch
//
//  Lightweight, keyless real-time market data service for On-Demand Chart Analysis.
//  Fetches public perpetual futures klines with native macOS TLS.
//

import Foundation

public final class FuturesScoutMarketDataService: Sendable {
    public static let shared = FuturesScoutMarketDataService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: config)
    }

    /// Normalizes user-input symbol strings (e.g. "BTC", "BTCUSDT", "ETH") into canonical BingX format "BTC-USDT"
    public static func normalizeSymbolForExchange(_ rawSymbol: String) -> String {
        var clean = rawSymbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("BINANCE:") || clean.hasPrefix("BINGX:") || clean.hasPrefix("BYBIT:") {
            if let colonIdx = clean.firstIndex(of: ":") {
                clean = String(clean[clean.index(after: colonIdx)...])
            }
        }
        clean = clean.replacingOccurrences(of: "/", with: "")
        if clean.contains("-") {
            return clean
        }
        if clean.hasSuffix("USDT") {
            let base = clean.dropLast(4)
            return "\(base)-USDT"
        }
        if clean.hasSuffix("USD") {
            let base = clean.dropLast(3)
            return "\(base)-USDT"
        }
        // Bare coin symbol (e.g. "BTC", "ETH", "SOL")
        return "\(clean)-USDT"
    }

    /// Normalizes symbol for TradingView search adhering strictly to doc 05 canon (e.g. "BINGX:BTCUSDT.P")
    public static func normalizeSymbolForTradingView(_ rawSymbol: String) -> String {
        var clean = rawSymbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("BINANCE:") || clean.hasPrefix("BYBIT:") {
            if let colonIdx = clean.firstIndex(of: ":") {
                clean = String(clean[clean.index(after: colonIdx)...])
            }
        }
        if clean.hasPrefix("BINGX:") {
            if !clean.hasSuffix(".P") && clean.contains("USDT") {
                return clean + ".P"
            }
            return clean
        }
        clean = clean.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "/", with: "")
        let baseOnly: String = {
            if clean.hasSuffix(".P") {
                let noP = String(clean.dropLast(2))
                return noP.hasSuffix("USDT") ? String(noP.dropLast(4)) : noP
            }
            return clean.hasSuffix("USDT") ? String(clean.dropLast(4)) : (clean.hasSuffix("USD") ? String(clean.dropLast(3)) : clean)
        }()
        return "BINGX:\(baseOnly)USDT.P"
    }

    /// Fetches historical and live klines from public exchange quote API
    public func fetchKlines(
        symbol: String,
        interval: String,
        limit: Int = 100
    ) async throws -> [AstronacciKline] {
        let normSym = Self.normalizeSymbolForExchange(symbol)
        guard let url = URL(string: "https://open-api.bingx.com/openApi/swap/v2/quote/klines?symbol=\(normSym)&interval=\(interval)&limit=\(limit)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        struct BingXResponse: Decodable {
            let code: Int
            let msg: String?
            let data: [BingXItem]?
        }

        struct BingXItem: Decodable {
            let open: String
            let close: String
            let high: String
            let low: String
            let volume: String
            let time: Double
        }

        let decoded = try JSONDecoder().decode(BingXResponse.self, from: data)
        guard decoded.code == 0, let items = decoded.data else {
            ClickyLogger.warning("[MARKET_DATA]", "Failed BingX response code \(decoded.code): \(decoded.msg ?? "unknown")")
            return []
        }

        var klines: [AstronacciKline] = []
        for item in items {
            guard let o = Double(item.open),
                  let c = Double(item.close),
                  let h = Double(item.high),
                  let l = Double(item.low),
                  let v = Double(item.volume) else {
                continue
            }
            let ts = Int64(item.time)
            let k = AstronacciKline(open: o, high: h, low: l, close: c, volume: v, timestamp: ts, isClosed: true)
            if k.isValid {
                klines.append(k)
            }
        }

        klines.sort(by: { (a: AstronacciKline, b: AstronacciKline) -> Bool in
            a.timestamp < b.timestamp
        })

        // Anti-Repaint Canon: The last candle in live quote API is the currently forming walking candle.
        // Mark it as isClosed = false so downstream logic never treats an unclosed bar as closed.
        if !klines.isEmpty {
            let lastIdx = klines.count - 1
            let lastK = klines[lastIdx]
            klines[lastIdx] = AstronacciKline(
                open: lastK.open,
                high: lastK.high,
                low: lastK.low,
                close: lastK.close,
                volume: lastK.volume,
                timestamp: lastK.timestamp,
                isClosed: false
            )
        }

        return klines
    }
}
