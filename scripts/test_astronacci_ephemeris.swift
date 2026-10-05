import Foundation

@main
struct TestAstronacciEphemeris {
    static func main() {
        print("=================================================================")
        print("🧪 UJI TDD DETERMINISTIC ASTRONOMICAL EPHEMERIS (MEEUS CANON)")
        print("=================================================================")

        let ephemeris = AstronacciEphemerisEngine()
        let iso = ISO8601DateFormatter()

        // Test 1: Full Moon Detection (2026-09-26 12:00 UTC)
        print("\n[TEST 1: FULL MOON PHASE (2026-09-26)]")
        let dateFullMoon = iso.date(from: "2026-09-26T12:00:00Z")!
        let reportFullMoon = ephemeris.calculateAstroReport(date: dateFullMoon)

        print("  Lunar Phase: \(reportFullMoon.lunarPhase.rawValue)")
        print("  Moon Age: \(String(format: "%.1f", reportFullMoon.moonAgeDays)) days (Elongation: \(String(format: "%.1f", reportFullMoon.moonElongationDeg))°)")
        print("  Near New/Full Moon: \(reportFullMoon.isNearNewOrFullMoon)")

        assert(reportFullMoon.lunarPhase == .fullMoon, "Expected .fullMoon, got \(reportFullMoon.lunarPhase)")
        assert(reportFullMoon.isNearNewOrFullMoon == true, "Expected isNearNewOrFullMoon == true for Full Moon")
        assert(reportFullMoon.moonAgeDays >= 13.5 && reportFullMoon.moonAgeDays <= 16.0, "Expected Moon Age ~14.5-15.5 days, got \(reportFullMoon.moonAgeDays)")
        print("  ✅ [PASS] Full Moon terdeteksi presisi (Usia Bulan: \(String(format: "%.1f", reportFullMoon.moonAgeDays)) hari, Dekat Full Moon: true)")

        // Test 2: New Moon Detection (2026-09-11 12:00 UTC)
        print("\n[TEST 2: NEW MOON PHASE (2026-09-11)]")
        let dateNewMoon = iso.date(from: "2026-09-11T12:00:00Z")!
        let reportNewMoon = ephemeris.calculateAstroReport(date: dateNewMoon)

        print("  Lunar Phase: \(reportNewMoon.lunarPhase.rawValue)")
        print("  Moon Age: \(String(format: "%.1f", reportNewMoon.moonAgeDays)) days")

        assert(reportNewMoon.lunarPhase == .newMoon, "Expected .newMoon, got \(reportNewMoon.lunarPhase)")
        assert(reportNewMoon.isNearNewOrFullMoon == true, "Expected isNearNewOrFullMoon == true for New Moon")
        print("  ✅ [PASS] New Moon terdeteksi presisi (Dekat New Moon: true)")

        // Test 3: Off-Peak Lunar Phase (First Quarter, 2026-09-18 12:00 UTC)
        print("\n[TEST 3: OFF-PEAK LUNAR PHASE (FIRST QUARTER 2026-09-18)]")
        let dateQuarter = iso.date(from: "2026-09-18T12:00:00Z")!
        let reportQuarter = ephemeris.calculateAstroReport(date: dateQuarter)

        print("  Lunar Phase: \(reportQuarter.lunarPhase.rawValue)")
        print("  Near New/Full Moon: \(reportQuarter.isNearNewOrFullMoon)")
        assert(reportQuarter.isNearNewOrFullMoon == false, "Expected isNearNewOrFullMoon == false for First Quarter")
        print("  ✅ [PASS] Fase kuartal terdeteksi bebas false-positive (Near New/Full Moon == false)")

        // Test 4: Mercury Retrograde (2026-03-05 12:00 UTC)
        print("\n[TEST 4: MERCURY RETROGRADE (2026-03-05)]")
        let dateRetro = iso.date(from: "2026-03-05T12:00:00Z")!
        let reportRetro = ephemeris.calculateAstroReport(date: dateRetro)

        print("  Mercury Motion: \(reportRetro.mercuryMotion.rawValue)")
        print("  Mercury Velocity: \(String(format: "%.2f", reportRetro.mercuryVelocityDegPerDay))°/day")
        assert(reportRetro.mercuryMotion == .retrograde, "Expected .retrograde, got \(reportRetro.mercuryMotion)")
        assert(reportRetro.mercuryVelocityDegPerDay < 0, "Expected negative velocity during retrograde")
        print("  ✅ [PASS] Merkurius Retrograde terdeteksi akurat (Kecepatan: \(String(format: "%.2f", reportRetro.mercuryVelocityDegPerDay))°/hari)")

        // Test 5: Mercury Direct (2026-09-26 12:00 UTC)
        print("\n[TEST 5: MERCURY DIRECT (2026-09-26)]")
        let reportDirect = ephemeris.calculateAstroReport(date: dateFullMoon)

        print("  Mercury Motion: \(reportDirect.mercuryMotion.rawValue)")
        print("  Mercury Velocity: \(String(format: "%.2f", reportDirect.mercuryVelocityDegPerDay))°/day")
        assert(reportDirect.mercuryMotion == .direct, "Expected .direct, got \(reportDirect.mercuryMotion)")
        assert(reportDirect.mercuryVelocityDegPerDay > 0.05, "Expected positive velocity for direct motion")
        print("  ✅ [PASS] Merkurius Direct terdeteksi akurat (Kecepatan: \(String(format: "%.2f", reportDirect.mercuryVelocityDegPerDay))°/hari)")

        // Test 6: Performance Benchmark (10,000 evaluations)
        print("\n[TEST 6: ZERO-NETWORK REAL-TIME PERFORMANCE (10,000 RUNS)]")
        let start = Date()
        for i in 0..<10000 {
            let d = dateFullMoon.addingTimeInterval(Double(i * 3600))
            _ = ephemeris.calculateAstroReport(date: d)
        }
        let elapsedMs = Date().timeIntervalSince(start) * 1000.0
        print("  Waktu eksekusi 10.000 kalkulasi ephemeris: \(String(format: "%.1f", elapsedMs)) ms (Avg: \(String(format: "%.3f", elapsedMs / 10000.0)) ms/call)")
        assert(elapsedMs < 2000.0, "Calculation took too long: \(elapsedMs) ms")
        print("  ✅ [PASS] Kinerja astronomis instan tanpa internet teruji super cepat (< 0.2 ms/call)")

        // Test 7: Historical Astronomical Reference Calibration (Auditor Agent 1 & Agent 2 Benchmark)
        print("\n[TEST 7: HISTORICAL ASTRONOMICAL BENCHMARK (5 AUDITOR REFERENCE DATES)]")
        
        // 1. New Moon 29 Jan 2025 (Tahun Baru Imlek 2576)
        let dImlek = iso.date(from: "2025-01-29T12:00:00Z")!
        let rImlek = ephemeris.calculateAstroReport(date: dImlek)
        assert(rImlek.lunarPhase == .newMoon, "Expected .newMoon for 29 Jan 2025, got \(rImlek.lunarPhase)")
        assert(rImlek.isNearNewOrFullMoon == true, "Expected nearNewOrFull == true for Imlek 2025")
        print("  ✅ [PASS] 29 Jan 2025 (Imlek): New Moon terkalibrasi presisi (Moon Age: \(String(format: "%.1f", rImlek.moonAgeDays)) hari)")

        // 2. Full Moon 12 Feb 2025 (Purnama Cap Go Meh)
        let dFull25 = iso.date(from: "2025-02-12T12:00:00Z")!
        let rFull25 = ephemeris.calculateAstroReport(date: dFull25)
        assert(rFull25.lunarPhase == .fullMoon, "Expected .fullMoon for 12 Feb 2025, got \(rFull25.lunarPhase)")
        assert(rFull25.isNearNewOrFullMoon == true, "Expected nearNewOrFull == true for Full Moon 12 Feb 2025")
        assert(rFull25.moonAgeDays >= 14.0 && rFull25.moonAgeDays <= 15.5, "Expected Moon Age ~14.7, got \(rFull25.moonAgeDays)")
        print("  ✅ [PASS] 12 Feb 2025: Full Moon terkalibrasi presisi (Moon Age: \(String(format: "%.1f", rFull25.moonAgeDays)) hari)")

        // 3. New Moon 1 Nov 2024
        let dNov24 = iso.date(from: "2024-11-01T12:00:00Z")!
        let rNov24 = ephemeris.calculateAstroReport(date: dNov24)
        assert(rNov24.lunarPhase == .newMoon, "Expected .newMoon for 1 Nov 2024, got \(rNov24.lunarPhase)")
        assert(rNov24.isNearNewOrFullMoon == true, "Expected nearNewOrFull == true for New Moon 1 Nov 2024")
        print("  ✅ [PASS] 1 Nov 2024: New Moon terkalibrasi presisi (Moon Age: \(String(format: "%.1f", rNov24.moonAgeDays)) hari)")

        // 4. Mercury Retrograde 25 Mar 2025
        let dRetro25 = iso.date(from: "2025-03-25T12:00:00Z")!
        let rRetro25 = ephemeris.calculateAstroReport(date: dRetro25)
        assert(rRetro25.mercuryMotion == .retrograde, "Expected .retrograde for 25 Mar 2025, got \(rRetro25.mercuryMotion)")
        assert(rRetro25.mercuryVelocityDegPerDay < 0, "Expected negative velocity, got \(rRetro25.mercuryVelocityDegPerDay)")
        print("  ✅ [PASS] 25 Mar 2025: Mercury Retrograde terkalibrasi presisi (Kecepatan: \(String(format: "%.2f", rRetro25.mercuryVelocityDegPerDay))°/hari)")

        // 5. Mercury Direct 15 May 2025
        let dDirect25 = iso.date(from: "2025-05-15T12:00:00Z")!
        let rDirect25 = ephemeris.calculateAstroReport(date: dDirect25)
        assert(rDirect25.mercuryMotion == .direct, "Expected .direct for 15 May 2025, got \(rDirect25.mercuryMotion)")
        assert(rDirect25.mercuryVelocityDegPerDay > 0, "Expected positive velocity, got \(rDirect25.mercuryVelocityDegPerDay)")
        print("  ✅ [PASS] 15 May 2025: Mercury Direct terkalibrasi presisi (Kecepatan: \(String(format: "%.2f", rDirect25.mercuryVelocityDegPerDay))°/hari)")

        print("\n=================================================================")
        print("🏁 SELURUH UJI TDD DETERMINISTIC ASTRONACCI EPHEMERIS LOLOS 100%!")
        print("=================================================================")
    }
}
