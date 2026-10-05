//
//  test_astronacci_economic_calendar.swift
//  scripts
//
//  TDD & Verification Suite for High-Impact Economic News Buffer (SOP Bab 7)
//  Verifies:
//  - Buffer rule <= 45 minutes before/after FOMC, CPI, NFP
//  - DST resilience (America/New_York EST vs EDT automatic shift)
//  - Approaching window (within 4 hours)
//  - Quiet market days
//  - Expired calendar detection past validUntil (2026-12-31)
//

import Foundation

@main
struct TestAstronacciEconomicCalendarMain {
    static func main() {
        print("=================================================================")
        print("🧪 UJI TDD HIGH-IMPACT ECONOMIC NEWS CALENDAR (BUFFER 45 MENIT)")
        print("=================================================================")

        let engine = AstronacciEconomicCalendarEngine()
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(secondsFromGMT: 0)

        // -------------------------------------------------------------
        // TEST 1: 30 minutes before FOMC (2025-01-29 18:30 UTC / 13:30 EST)
        // FOMC is at 14:00 EST / 19:00 UTC
        // -------------------------------------------------------------
        print("\n[TEST 1: 30 MENIT SEBELUM FOMC RATE DECISION]")
        let dateBeforeFOMC = iso.date(from: "2025-01-29T18:30:00Z")!
        let resFOMC = engine.evaluateBuffer(currentDate: dateBeforeFOMC)

        assert(resFOMC.isInsideBuffer == true, "Expected isInsideBuffer == true, got \(resFOMC.isInsideBuffer)")
        assert(resFOMC.activeEvent?.name == "FOMC Rate Decision", "Expected FOMC Rate Decision, got \(String(describing: resFOMC.activeEvent?.name))")
        assert(resFOMC.minutesDelta == 30, "Expected 30 minutes remaining, got \(resFOMC.minutesDelta)")
        assert(resFOMC.alertBadge?.contains("BUFFER BERITA TINGGI") == true, "Expected buffer badge alert")
        assert(resFOMC.advisoryText.contains("STAND ASIDE"), "Expected STAND ASIDE advice")
        print("  ✅ [PASS] 30 menit sebelum FOMC terdeteksi di dalam buffer (STAND ASIDE aktif)")

        // -------------------------------------------------------------
        // TEST 2: 15 minutes after CPI release (2025-02-12 13:45 UTC / 08:45 EST)
        // CPI is at 08:30 EST / 13:30 UTC
        // -------------------------------------------------------------
        print("\n[TEST 2: 15 MENIT PASCA-RILIS CPI INFLASI]")
        let dateAfterCPI = iso.date(from: "2025-02-12T13:45:00Z")!
        let resCPI = engine.evaluateBuffer(currentDate: dateAfterCPI)

        assert(resCPI.isInsideBuffer == true, "Expected isInsideBuffer == true for post-release volatility")
        assert(resCPI.minutesDelta == -15, "Expected -15 minutes, got \(resCPI.minutesDelta)")
        assert(resCPI.advisoryText.contains("15 menit lalu"), "Expected text to mention 15 menit lalu")
        assert(resCPI.advisoryText.contains("STAND ASIDE"), "Expected STAND ASIDE advice")
        print("  ✅ [PASS] 15 menit pasca CPI terdeteksi di dalam buffer volatilitas (STAND ASIDE aktif)")

        // -------------------------------------------------------------
        // TEST 3: Approaching NFP 90 minutes before (2025-03-07 12:00 UTC / 07:00 EST)
        // NFP is at 08:30 EST / 13:30 UTC
        // -------------------------------------------------------------
        print("\n[TEST 3: 90 MENIT MENJELANG NFP (INFO AGENDA DI LUAR BUFFER)]")
        let dateBeforeNFP = iso.date(from: "2025-03-07T12:00:00Z")!
        let resNFP = engine.evaluateBuffer(currentDate: dateBeforeNFP)

        assert(resNFP.isInsideBuffer == false, "Expected isInsideBuffer == false (90 min > 45 min)")
        assert(resNFP.minutesDelta == 90, "Expected 90 minutes, got \(resNFP.minutesDelta)")
        assert(resNFP.alertBadge?.contains("INFO AGENDA") == true, "Expected info agenda badge")
        assert(resNFP.advisoryText.contains("1 jam 30 menit"), "Expected countdown advice")
        print("  ✅ [PASS] 90 menit sebelum NFP berada di luar buffer (Info agenda countdown tampil)")

        // -------------------------------------------------------------
        // TEST 4: Quiet day (No major economic news within 4 hours)
        // -------------------------------------------------------------
        print("\n[TEST 4: HARI TENANG TANPA AGENDA TIER-1]")
        let dateQuiet = iso.date(from: "2025-02-20T12:00:00Z")!
        let resQuiet = engine.evaluateBuffer(currentDate: dateQuiet)

        assert(resQuiet.isInsideBuffer == false, "Expected isInsideBuffer == false")
        assert(resQuiet.alertBadge == nil, "Expected nil alertBadge on quiet day")
        assert(resQuiet.advisoryText.contains("aman"), "Expected 'aman' in text")
        print("  ✅ [PASS] Hari tenang terdeteksi aman tanpa false-positive")

        // -------------------------------------------------------------
        // TEST 5: Daylight Saving Time (DST) Resilience (Winter EST vs Summer EDT)
        // Winter: Jan 15 2025 (08:30 EST = 13:30 UTC) -> 20 min before at 13:10 UTC
        // Summer: Jun 11 2025 (08:30 EDT = 12:30 UTC) -> 20 min before at 12:10 UTC
        // -------------------------------------------------------------
        print("\n[TEST 5: KEKEBALAN DAYLIGHT SAVING TIME (DST) AMERIKA (EDT VS EST)]")
        let winterDate = iso.date(from: "2025-01-15T13:10:00Z")! // 20m before CPI Winter
        let resWinter = engine.evaluateBuffer(currentDate: winterDate)
        assert(resWinter.isInsideBuffer == true, "Expected inside buffer for winter CPI")
        assert(resWinter.minutesDelta == 20, "Expected 20 min remaining in winter, got \(resWinter.minutesDelta)")

        let summerDate = iso.date(from: "2025-06-11T12:10:00Z")! // 20m before CPI Summer
        let resSummer = engine.evaluateBuffer(currentDate: summerDate)
        assert(resSummer.isInsideBuffer == true, "Expected inside buffer for summer CPI")
        assert(resSummer.minutesDelta == 20, "Expected 20 min remaining in summer, got \(resSummer.minutesDelta)")
        print("  ✅ [PASS] DST Amerika teruji 100% presisi (Winter 13:30 UTC vs Summer 12:30 UTC)")

        // -------------------------------------------------------------
        // TEST 6: Expired Calendar past validUntil (2027-01-15)
        // -------------------------------------------------------------
        print("\n[TEST 6: DETEKSI KALENDER KEDALUWARSA (PASCA 2026-12-31)]")
        let dateExpired = iso.date(from: "2027-01-15T12:00:00Z")!
        let resExpired = engine.evaluateBuffer(currentDate: dateExpired)

        assert(resExpired.isExpiredCalendar == true, "Expected isExpiredCalendar == true")
        assert(resExpired.alertBadge?.contains("KEDALUWARSA") == true, "Expected alert badge for expired calendar")
        assert(resExpired.advisoryText.contains("melewati masa berlaku"), "Expected warning message about expired calendar")
        print("  ✅ [PASS] Kalender kadaluwarsa terdeteksi fail-open dengan peringatan transparan")

        // -------------------------------------------------------------
        // TEST 7: Data Integrity & Single Source Verification (Auditor Agent 1 Mandate)
        // -------------------------------------------------------------
        print("\n[TEST 7: INTEGRITAS DATA KALENDER RESMI & ANTI-PHANTOM MEETING LOCK]")
        let calendar = engine.calendarData
        assert(calendar.events.count == 72, "Expected exactly 72 events (2025-2026), got \(calendar.events.count)")
        assert(calendar.validUntil == "2026-12-31T23:59:59Z", "Expected validUntil 2026-12-31T23:59:59Z, got \(calendar.validUntil)")

        // Check official source URLs
        assert(calendar.sources?["fomc"]?.contains("federalreserve.gov") == true, "Missing official Fed FOMC source URL")
        assert(calendar.sources?["cpi"]?.contains("bls.gov") == true, "Missing official BLS CPI source URL")
        assert(calendar.sources?["empsit"]?.contains("bls.gov") == true, "Missing official BLS NFP source URL")
        assert(calendar.sources?["gdp"]?.contains("bea.gov") == true, "Missing official BEA GDP source URL")

        // Official FOMC 2025 verification (8/8)
        let expectedFOMC2025 = [
            "2025-01-29", "2025-03-19", "2025-05-07", "2025-06-18",
            "2025-07-30", "2025-09-17", "2025-10-29", "2025-12-10"
        ]
        let actualFOMC2025 = calendar.events.filter { $0.name == "FOMC Rate Decision" && $0.date.hasPrefix("2025") }.map { $0.date }
        assert(actualFOMC2025 == expectedFOMC2025, "FOMC 2025 dates mismatch! Got: \(actualFOMC2025)")
        print("  ✅ [PASS] FOMC 2025: 8/8 tanggal keputusan resmi terverifikasi identik")

        // Official FOMC 2026 verification (8/8)
        let expectedFOMC2026 = [
            "2026-01-28", "2026-03-18", "2026-04-29", "2026-06-17",
            "2026-07-29", "2026-09-16", "2026-10-28", "2026-12-09"
        ]
        let actualFOMC2026 = calendar.events.filter { $0.name == "FOMC Rate Decision" && $0.date.hasPrefix("2026") }.map { $0.date }
        assert(!actualFOMC2026.contains("2026-05-06"), "CRITICAL: Phantom meeting 2026-05-06 must NOT exist in calendar!")
        assert(actualFOMC2026.contains("2026-04-29"), "CRITICAL: Official FOMC meeting 2026-04-29 MUST exist in calendar!")
        assert(actualFOMC2026 == expectedFOMC2026, "FOMC 2026 dates mismatch! Got: \(actualFOMC2026)")
        print("  ✅ [PASS] FOMC 2026: 8/8 tanggal keputusan resmi terverifikasi (Phantom 6 Mei terhapus, 29 April terdaftar)")

        // -------------------------------------------------------------
        // TEST 8: Behavioral Simulation (30 Min Before CPI 2026-04-10)
        // -------------------------------------------------------------
        print("\n[TEST 8: SIMULASI PERILAKU SISTEM: 30 MENIT SEBELUM CPI 2026-04-10]")
        // 2026-04-10 is EDT (UTC-4). CPI is 08:30 EDT = 12:30 UTC.
        // 30 min before = 08:00 EDT = 12:00 UTC.
        let simDate = iso.date(from: "2026-04-10T12:00:00Z")!
        let simBuffer = engine.evaluateBuffer(currentDate: simDate)

        assert(simBuffer.isInsideBuffer == true, "Simulation must trigger isInsideBuffer == true")
        assert(simBuffer.activeEvent?.name == "US CPI Inflation", "Simulation event must be US CPI Inflation")
        assert(simBuffer.minutesDelta == 30, "Simulation delta must be exactly 30 minutes, got \(simBuffer.minutesDelta)")
        print("  ✅ [PASS] Simulasi Perilaku: 30 menit sebelum CPI 10 April 2026 memicu buffer aktif (STAND ASIDE)")

        print("\n=================================================================")
        print("🏁 SELURUH UJI TDD ASTRONACCI ECONOMIC CALENDAR LOLOS 100%!")
        print("=================================================================")
    }
}
