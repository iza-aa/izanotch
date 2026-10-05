import Foundation

@main
struct TestAstronacciTimeCycles {
    static func main() {
        print("=================================================================")
        print("🧪 UJI TDD ASTRONACCI TIME CYCLES & FIBONACCI TIME PROJECTION")
        print("=================================================================")

        // Reference Date: 2026-09-27 12:00:00 UTC
        let formatter = ISO8601DateFormatter()
        let refDate = formatter.date(from: "2026-09-27T12:00:00Z")!

        // Test 1: In-Window Exact Match (Bar 8)
        print("\n[TEST 1: IN-WINDOW EXACT MATCH (BAR 8)]")
        let win8 = FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow(
            anchorIndex: 10,
            currentClosedIndex: 18, // 18 - 10 = 8 bars
            referenceDate: refDate
        )
        assert(win8.state == .inWindow, "Expected .inWindow, got \(win8.state)")
        assert(win8.currentBarCount == 8, "Expected count 8, got \(win8.currentBarCount)")
        assert(win8.currentTargetFib == 8, "Expected target 8")
        assert(win8.barsRemaining == 0, "Expected 0 bars remaining")
        assert(win8.estimatedTargetDate == refDate, "Expected target date to be refDate")
        print("  ✅ [PASS] Bar ke-8 pas berada di .inWindow (Target Fib 8, 0 bar tersisa)")

        // Test 2: Approaching Next Target (Bar 10 -> Target 13, 3 bars remaining)
        // 3 bars of M15 = 45 minutes -> 12:45 UTC
        print("\n[TEST 2: APPROACHING NEXT TARGET (BAR 10 -> FIB 13)]")
        let win10 = FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow(
            anchorIndex: 10,
            currentClosedIndex: 20, // 20 - 10 = 10 bars (Target: 13, remaining: 3)
            referenceDate: refDate
        )
        assert(win10.state == .approaching, "Expected .approaching, got \(win10.state)")
        assert(win10.currentBarCount == 10, "Expected count 10")
        assert(win10.currentTargetFib == 13, "Expected target 13")
        assert(win10.barsRemaining == 3, "Expected 3 bars remaining")
        let expectedEta = refDate.addingTimeInterval(3 * 900) // +45 min = 12:45 UTC
        assert(win10.estimatedTargetDate == expectedEta, "Expected ETA \(expectedEta), got \(String(describing: win10.estimatedTargetDate))")
        assert(win10.displayText.contains("12:45 UTC"), "Expected display text to include '12:45 UTC', got: \(win10.displayText)")
        assert(win10.displayText.contains("(proyeksi nominal kandel, bukan jadwal pasti)"), "Expected display text to include nominal projection caveat, got: \(win10.displayText)")
        print("  ✅ [PASS] Bar ke-10 menuju bar 13 terhitung eksak 3 bar tersisa (ETA: 12:45 UTC, Caveat Proyeksi Nominal terpasang)")

        // Test 3: Approaching Target 21 (Bar 15 -> Target 21, 6 bars remaining = +90 min -> 13:30 UTC)
        print("\n[TEST 3: APPROACHING NEXT TARGET (BAR 15 -> FIB 21)]")
        let win15 = FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow(
            anchorIndex: 10,
            currentClosedIndex: 25, // 25 - 10 = 15 bars
            referenceDate: refDate
        )
        assert(win15.state == .approaching, "Expected .approaching")
        assert(win15.currentTargetFib == 21, "Expected target 21")
        assert(win15.barsRemaining == 6, "Expected 6 bars remaining")
        let expectedEta21 = refDate.addingTimeInterval(6 * 900) // +90 min = 13:30 UTC
        assert(win15.estimatedTargetDate == expectedEta21, "Expected ETA \(expectedEta21)")
        assert(win15.displayText.contains("13:30 UTC"), "Expected display text to include '13:30 UTC'")
        print("  ✅ [PASS] Bar ke-15 menuju bar 21 terhitung eksak 6 bar tersisa (ETA: 13:30 UTC)")

        // Test 4: Window Passed (> 34 bars)
        print("\n[TEST 4: WINDOW PASSED (> 34 BARS)]")
        let win40 = FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow(
            anchorIndex: 10,
            currentClosedIndex: 50, // 50 - 10 = 40 bars > 34
            referenceDate: refDate
        )
        assert(win40.state == .windowPassed, "Expected .windowPassed, got \(win40.state)")
        assert(win40.barsRemaining == 0, "Expected 0 bars remaining")
        print("  ✅ [PASS] Bar ke-40 (> 34) terdeteksi .windowPassed secara deterministik")

        // Test 5: Nil Anchor Fail-Closed
        print("\n[TEST 5: NIL ANCHOR FAIL-CLOSED]")
        let winNil = FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow(
            anchorIndex: nil,
            currentClosedIndex: 50,
            referenceDate: refDate
        )
        assert(winNil.state == .noAnchor, "Expected .noAnchor, got \(winNil.state)")
        assert(winNil.estimatedTargetDate == nil, "Expected nil target date")
        print("  ✅ [PASS] Nil anchor fail-closed ke .noAnchor")

        print("\n=================================================================")
        print("🏁 SELURUH UJI TDD ASTRONACCI TIME CYCLES LOLOS 100%!")
        print("=================================================================")
    }
}
