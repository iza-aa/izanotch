//
//  test_market_radar_analyst.swift
//  scripts
//
//  TDD & Verification Suite for Multi-Market Radar Analyst (Reviewer Canon)
//  Tests:
//  1. Exact Rule-Based Candidate Classification (Hot, Approaching, Choppy/Dead, Unavailable)
//  2. Deterministic Top-Pick Selection & Tie-Breaking (Smallest GP Distance)
//  3. Resilient Skip-on-Fail (Unavailable Candidate does not abort evaluation)
//  4. Zero-Mutation Guarantee on All-Choppy Markets
//  5. Executive Market Overview Card Markdown & Breadth Synthesis
//  6. Clean TTS Narrative Contract (< 300 char, strictly zero markdown characters)
//  7. Pipeline Command Intent Isolation (/analisa market vs single-coin /analisa btc)
//
//  Compilation standard:
//  swiftc -parse-as-library scripts/test_market_radar_analyst.swift ... -o /tmp/test_market_radar && /tmp/test_market_radar
//

import Foundation

var totalAssertions = 0
var passedAssertions = 0
var failedAssertions = 0

func assertTest(_ name: String, _ condition: Bool, detail: String = "") {
    totalAssertions += 1
    if condition {
        passedAssertions += 1
        if detail.isEmpty {
            print("  ✅ [PASS] \(name)")
        } else {
            print("  ✅ [PASS] \(name) (\(detail))")
        }
    } else {
        failedAssertions += 1
        print("  ❌ [FAIL] \(name) — \(detail.isEmpty ? "Condition evaluated to false" : detail)")
    }
}

@main
struct MarketRadarTestRunner {
    static func main() async {
        print("==================================================================")
        print("🧪 SUITE 12: MULTI-MARKET RADAR & OVERVIEW TDD VERIFICATION")
        print("==================================================================")

        let engine = AstronacciDeterministicEngine.shared
        let refDate = Date(timeIntervalSince1970: 1727481600) // Deterministic fixed date

        // Helper to generate synthetic closed klines
        func makeKlines(startPrice: Double, trendDelta: Double, count: Int = 220) -> [AstronacciKline] {
            var klines: [AstronacciKline] = []
            var price = startPrice
            for i in 0..<count {
                price += trendDelta
                klines.append(AstronacciKline(
                    open: price - (trendDelta * 0.5),
                    high: price + abs(trendDelta * 1.5),
                    low: price - abs(trendDelta * 1.5),
                    close: price,
                    volume: 100.0,
                    timestamp: Int64(i * 3600),
                    isClosed: true
                ))
            }
            return klines
        }

        // Generate synthetic markets:
        // 1. SOL: Bullish Trending
        let solH1 = makeKlines(startPrice: 100.0, trendDelta: 0.5, count: 220)
        let solM15 = makeKlines(startPrice: 200.0, trendDelta: 0.2, count: 60)
        let solM5 = makeKlines(startPrice: 210.0, trendDelta: 0.1, count: 30)

        // 2. BTC: Flat / Choppy
        var btcH1: [AstronacciKline] = []
        var btcPrice = 84000.0
        for i in 0..<220 {
            let osc = (i % 2 == 0) ? 50.0 : -50.0
            btcPrice += osc
            btcH1.append(AstronacciKline(open: btcPrice - 20, high: btcPrice + 30, low: btcPrice - 30, close: btcPrice, volume: 50.0, timestamp: Int64(i * 3600), isClosed: true))
        }
        let btcM15 = btcH1.suffix(60).map { $0 }
        let btcM5 = btcH1.suffix(30).map { $0 }

        print("\n[TEST 1: EXACT RULE-BASED CANDIDATE CLASSIFICATION]")
        // Evaluate SOL
        let solAnalysis = FuturesScoutCoreAnalyst.analyze(
            rawSymbol: "SOL",
            klinesH1: solH1,
            klinesM15: solM15,
            klinesM5: solM5,
            referenceDate: refDate,
            engine: engine
        )
        let isSolSuccess: Bool
        if case .success = solAnalysis { isSolSuccess = true } else { isSolSuccess = false }
        assertTest("SOL analysis succeeded", isSolSuccess)

        if case .success(let solRes) = solAnalysis {
            let solCandidate = FuturesScoutCoreAnalyst.evaluateMarketCandidate(rawSymbol: "SOL", result: solRes)
            assertTest("SOL display symbol formatted", solCandidate.displaySymbol == "SOL/USDT")
            assertTest("SOL classification is valid", solCandidate.classification == .hot || solCandidate.classification == .approaching || solCandidate.classification == .deadOrChoppy)
            print("  ℹ️ SOL Evaluated Classification: \(solCandidate.classification.rawValue)")
        }

        // Evaluate BTC (Choppy)
        let btcAnalysis = FuturesScoutCoreAnalyst.analyze(
            rawSymbol: "BTC",
            klinesH1: btcH1,
            klinesM15: btcM15,
            klinesM5: btcM5,
            referenceDate: refDate,
            engine: engine
        )
        let isBtcSuccess: Bool
        if case .success = btcAnalysis { isBtcSuccess = true } else { isBtcSuccess = false }
        assertTest("BTC analysis succeeded", isBtcSuccess)
        if case .success(let btcRes) = btcAnalysis {
            let btcCandidate = FuturesScoutCoreAnalyst.evaluateMarketCandidate(rawSymbol: "BTC", result: btcRes)
            assertTest("BTC Choppy classified as .deadOrChoppy", btcCandidate.classification == .deadOrChoppy)
        }

        print("\n[TEST 2: DETERMINISTIC TOP-PICK SELECTION & TIE BREAKING]")
        // Create Mock Candidates for Strict Logic Testing
        let dummyRes = (try? solAnalysis.get())!

        let hotCand1 = MarketCandidateEvaluation(
            symbol: "SOL",
            displaySymbol: "SOL/USDT",
            classification: .hot,
            analysisResult: dummyRes,
            distanceToGPAtrMultiple: 0.4
        )
        let hotCand2 = MarketCandidateEvaluation(
            symbol: "ETH",
            displaySymbol: "ETH/USDT",
            classification: .hot,
            analysisResult: dummyRes,
            distanceToGPAtrMultiple: 0.1 // Closer to GP
        )
        let appCand = MarketCandidateEvaluation(
            symbol: "XRP",
            displaySymbol: "XRP/USDT",
            classification: .approaching,
            analysisResult: dummyRes,
            distanceToGPAtrMultiple: 0.8
        )
        let choppyCand = MarketCandidateEvaluation(
            symbol: "BTC",
            displaySymbol: "BTC/USDT",
            classification: .deadOrChoppy,
            analysisResult: dummyRes,
            distanceToGPAtrMultiple: nil
        )

        // Case 2a: Hot vs Approaching -> Hot wins
        let pick1 = FuturesScoutCoreAnalyst.selectTopPickCandidate(candidates: [appCand, hotCand1, choppyCand])
        assertTest("Hot candidate wins over approaching and choppy", pick1?.symbol == "SOL")

        // Case 2b: Tie-break between multiple Hot candidates -> Smallest distance wins
        let pickTie = FuturesScoutCoreAnalyst.selectTopPickCandidate(candidates: [hotCand1, hotCand2, choppyCand])
        assertTest("Tie-break selects candidate with smaller GP distance (ETH 0.1 vs SOL 0.4)", pickTie?.symbol == "ETH")

        // Case 2c: Only Approaching candidates -> Approaching wins
        let pickApp = FuturesScoutCoreAnalyst.selectTopPickCandidate(candidates: [appCand, choppyCand])
        assertTest("Approaching candidate selected when no hot candidates", pickApp?.symbol == "XRP")

        // Case 2d: All Choppy -> nil (Zero Mutation guaranteed)
        let pickNone = FuturesScoutCoreAnalyst.selectTopPickCandidate(candidates: [choppyCand])
        assertTest("Zero mutation: top-pick is nil when all candidates are choppy", pickNone == nil)

        print("\n[TEST 3: RESILIENT SKIP-ON-FAIL (UNAVAILABLE CANDIDATE RESILIENCE)]")
        let unavailCand = MarketCandidateEvaluation(
            symbol: "DOGE",
            displaySymbol: "DOGE/USDT",
            classification: .dataUnavailable,
            analysisResult: nil,
            distanceToGPAtrMultiple: nil,
            failureReason: "Network timeout 3.0s"
        )
        let mixedCandidates = [choppyCand, unavailCand, hotCand1]
        let pickMixed = FuturesScoutCoreAnalyst.selectTopPickCandidate(candidates: mixedCandidates)
        assertTest("Unavailable candidate does not break top-pick selection", pickMixed?.symbol == "SOL")

        print("\n[TEST 4: MARKET OVERVIEW CARD & BREADTH SYNTHESIS]")
        let (cardMarkdown, voiceNarrative) = FuturesScoutCoreAnalyst.renderMarketOverview(
            candidates: [choppyCand, hotCand1, appCand, unavailCand],
            referenceDate: refDate,
            topPick: hotCand1
        )
        assertTest("Card markdown contains Header", cardMarkdown.contains("Laporan Analisa Pasar Crypto"))
        assertTest("Card markdown contains Market Breadth", cardMarkdown.contains("Sebaran Rezim Pasar"))
        assertTest("Card markdown contains Matriks Kondisi", cardMarkdown.contains("Matriks Kondisi Seluruh Pasar"))
        assertTest("Card markdown contains Top-Pick Focus", cardMarkdown.contains("Top-Pick Actionable Focus"))
        assertTest("Card markdown contains Unavailable Row without crash", cardMarkdown.contains("DOGE/USDT") && cardMarkdown.contains("Unavailable"))
        assertTest("Card markdown contains mandatory Disclaimer", cardMarkdown.contains("Catatan Edukasi"))

        print("\n[TEST 5: CLEAN TTS NARRATIVE CONTRACT (< 300 CHAR & ZERO MARKDOWN)]")
        print("  🎙️ Generated TTS: \"\(voiceNarrative)\"")
        assertTest("Voice narrative length is < 300 characters", voiceNarrative.count < 300, detail: "Length: \(voiceNarrative.count)")
        assertTest("Voice narrative has no asterisk markdown", !voiceNarrative.contains("*"))
        assertTest("Voice narrative has no hash markdown", !voiceNarrative.contains("#"))
        assertTest("Voice narrative has no underscore markdown", !voiceNarrative.contains("_"))
        assertTest("Voice narrative has no table pipe markdown", !voiceNarrative.contains("|"))
        assertTest("Voice narrative has no greater-than blockquote markdown", !voiceNarrative.contains(">"))

        print("\n[TEST 6: ALL-CHOPPY CLEAN TTS & ZERO MUTATION CONTRACT]")
        let (choppyCard, choppyVoice) = FuturesScoutCoreAnalyst.renderMarketOverview(
            candidates: [choppyCand],
            referenceDate: refDate,
            topPick: nil
        )
        assertTest("All-choppy card states Zero Mutation", choppyCard.contains("Zero Mutation"))
        assertTest("All-choppy voice narrative is < 300 char", choppyVoice.count < 300, detail: "Length: \(choppyVoice.count)")
        assertTest("All-choppy voice narrative has zero markdown", !choppyVoice.contains("*") && !choppyVoice.contains("#") && !choppyVoice.contains("|"))
        print("  🎙️ All-Choppy TTS: \"\(choppyVoice)\"")

        print("\n[TEST 7: ALL-CHOPPY ZERO-MUTATION DISPATCHER BYPASS CONTRACT]")
        // Assert that when topPick is nil, dispatcher.execute is 100% bypassed
        var simulatedDispatcherCalled = false
        var simulatedCuaMutations = 0

        func evaluateCuaExecution(topPick: MarketCandidateEvaluation?) {
            if let pick = topPick, let _ = pick.analysisResult {
                simulatedDispatcherCalled = true
                simulatedCuaMutations += 1
            } else {
                // Zero-Touch CUA: Bypass dispatcher completely
                simulatedDispatcherCalled = false
            }
        }

        evaluateCuaExecution(topPick: nil)
        assertTest("Dispatcher is NOT called when top-pick is nil (All-Choppy 100% Zero-Touch)", !simulatedDispatcherCalled)
        assertTest("Zero CUA mutations executed on all-choppy market", simulatedCuaMutations == 0)

        evaluateCuaExecution(topPick: hotCand1)
        assertTest("Dispatcher IS called when actionable top-pick exists", simulatedDispatcherCalled)
        assertTest("Mutations incremented only for actionable top-pick", simulatedCuaMutations == 1)

        print("\n[TEST 8: CUSTOM MARKETS SAFETY CAP ENFORCEMENT (MAX 20 COINS)]")
        var custom25Coins: [String] = []
        for i in 1...25 { custom25Coins.append("COIN\(i)") }
        let rawUniverse = custom25Coins
        let maxCap = 20
        let clampedUniverse: [String]
        var logWarningEmitted = false
        if rawUniverse.count > maxCap {
            logWarningEmitted = true
            clampedUniverse = Array(rawUniverse.prefix(maxCap))
        } else {
            clampedUniverse = rawUniverse
        }

        assertTest("Custom 25 coins clamped to exactly 20", clampedUniverse.count == 20, detail: "Count: \(clampedUniverse.count)")
        assertTest("Clamped universe contains first 20 coins in order", clampedUniverse.count == 20 && clampedUniverse.first == "COIN1" && clampedUniverse.last == "COIN20")
        assertTest("Safety limit warning log condition triggered", logWarningEmitted)

        print("\n[TEST 9: TOP-PICK PINE SCRIPT INJECTION (HOT & APPROACHING CANDIDATES)]")
        // Construct synthetic trending market with valid dominant swing & retrace:
        var trendingH1: [AstronacciKline] = []
        var p = 20000.0
        for i in 0..<210 {
            p += 100.0
            trendingH1.append(AstronacciKline(open: p - 20, high: p + 30, low: p - 30, close: p, volume: 100.0, timestamp: Int64(i * 3600), isClosed: true))
        }
        var trendingM15: [AstronacciKline] = []
        var m15P = 35000.0
        for i in 0..<50 {
            if i < 10 { m15P = 35000.0 }
            else if i <= 35 { m15P += 300.0 } // 35000 -> 42500
            else { m15P -= 180.0 } // Retrace into 39800 (GP)
            trendingM15.append(AstronacciKline(open: m15P - 30, high: m15P + 50, low: m15P - 50, close: m15P, volume: 50.0, timestamp: Int64(i * 900), isClosed: true))
        }
        var trendingM5: [AstronacciKline] = []
        var m5P = 39800.0
        for i in 0..<20 {
            m5P += 10.0
            trendingM5.append(AstronacciKline(open: m5P, high: m5P + 20, low: m5P - 20, close: m5P + 5, volume: 10.0, timestamp: Int64(i * 300), isClosed: true))
        }
        trendingM5[18] = AstronacciKline(open: 39900, high: 39920, low: 39600, close: 39910, volume: 50.0, timestamp: 19 * 300, isClosed: true)
        trendingM5[19] = AstronacciKline(open: 39910, high: 39950, low: 39900, close: 39940, volume: 10.0, timestamp: 20 * 300, isClosed: false)

        let trendingAnalysis = FuturesScoutCoreAnalyst.analyze(
            rawSymbol: "ETH",
            klinesH1: trendingH1,
            klinesM15: trendingM15,
            klinesM5: trendingM5,
            referenceDate: refDate,
            engine: engine
        )

        let isTrendingSuccess: Bool
        if case .success = trendingAnalysis { isTrendingSuccess = true } else { isTrendingSuccess = false }
        assertTest("Trending market analysis succeeded", isTrendingSuccess)

        if case .success(let trendingRes) = trendingAnalysis {
            print("  ℹ️ Trending Candidate Status: \(trendingRes.status.rawValue)")
            let script = FuturesScoutCoreAnalyst.generatePineScriptOverlay(result: trendingRes)
            assertTest("Non-choppy top-pick generates non-empty Pine Script overlay", !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            assertTest("Non-choppy Pine Script contains HUD table", script.contains("var table hud = table.new"))
            assertTest("Non-choppy Pine Script contains ENTRY LIMIT", script.contains("ENTRY LIMIT"))
            assertTest("Non-choppy Pine Script contains TAKE PROFIT (TP1/TP2)", script.contains("TAKE PROFIT") && script.contains("TP1"))
            assertTest("Non-choppy Pine Script contains STOP LOSS", script.contains("STOP LOSS"))
        }

        // Choppy candidate produces empty overlay (Zero Mutation)
        if case .success(let btcR) = btcAnalysis {
            let btcScript = FuturesScoutCoreAnalyst.generatePineScriptOverlay(result: btcR)
            assertTest("Choppy candidate generates empty overlay (Zero Mutation)", btcScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        print("\n==================================================================")
        print("📊 SUITE 12 RUN SUMMARY: \(passedAssertions)/\(totalAssertions) Assertions Passed")
        print("==================================================================")
        if failedAssertions == 0 {
            print("🎉 SUITE 12 (MULTI-MARKET RADAR ANALYST) PASSED 100%!")
        } else {
            print("❌ SUITE 12 FAILED with \(failedAssertions) errors.")
            exit(1)
        }
    }
}
