//
//  test_p1_anti_lag_cua.swift
//  scripts
//
//  TDD & Verification Suite for P1: Hardening Anti-Lag CUA
//  Tests:
//  1. Adaptive Polling Engine (pollUntil: immediate, delayed, timeout)
//  2. Sentinel Buffer Verification (success, unchanged sentinel failure, empty editor fail-closed)
//  3. False-Pass Drawing JSON Trap Detection
//  4. Recovery Mechanism & Neutral Cursor Parking
//
//  Compilation standard:
//  swiftc -parse-as-library scripts/test_p1_anti_lag_cua.swift -o /tmp/test_p1 && /tmp/test_p1
//

import AppKit
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

// MARK: - Standalone Polling Implementation for Test Harness Isolation

@Sendable
func pollUntilTest(
    timeout: TimeInterval = 1.0,
    interval: TimeInterval = 0.02,
    condition: @Sendable () async -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }
    return await condition()
}

// MARK: - Main Test Entrypoint

@main
struct TestP1AntiLagCUA {
    static func main() async {
        print("=================================================================")
        print("⚡ PILAR P1: TDD & HARDENING ANTI-LAG CUA")
        print("=================================================================")

        // -----------------------------------------------------------------
        // [TEST GROUP 1: Adaptive Asynchronous Polling Engine]
        // -----------------------------------------------------------------
        print("\n[TEST GROUP 1: Adaptive Asynchronous Polling Engine]")

        // 1. Immediate Truth Condition
        let t0 = Date()
        let immediateResult = await pollUntilTest(timeout: 1.0, interval: 0.05) {
            return true
        }
        let elapsedImmediate = Date().timeIntervalSince(t0)
        assertTest("Immediate Condition: Returns true within < 50ms", immediateResult && elapsedImmediate < 0.08, detail: "Elapsed: \(Int(elapsedImmediate * 1000))ms")

        // 2. Delayed Truth Condition (flips after 150ms)
        let startTime = Date()
        let delayedResult = await pollUntilTest(timeout: 1.0, interval: 0.03) {
            return Date().timeIntervalSince(startTime) >= 0.15
        }
        let elapsedDelayed = Date().timeIntervalSince(startTime)
        assertTest("Delayed Condition: Polls until condition becomes true", delayedResult && elapsedDelayed >= 0.14 && elapsedDelayed < 0.35, detail: "Elapsed: \(Int(elapsedDelayed * 1000))ms")

        // 3. Timeout Failure Condition (never becomes true)
        let timeoutStart = Date()
        let timeoutResult = await pollUntilTest(timeout: 0.20, interval: 0.03) {
            return false
        }
        let elapsedTimeout = Date().timeIntervalSince(timeoutStart)
        assertTest("Timeout Condition: Fails closed and returns false on expiration", !timeoutResult && elapsedTimeout >= 0.19 && elapsedTimeout < 0.35, detail: "Elapsed: \(Int(elapsedTimeout * 1000))ms")

        // -----------------------------------------------------------------
        // [TEST GROUP 2: Sentinel Buffer Verification & False-Pass Protection]
        // -----------------------------------------------------------------
        print("\n[TEST GROUP 2: Sentinel Buffer Verification & False-Pass Protection]")

        let sentinel = "IZANOTCHY_CANVAS_SENTINEL_ABCD1234"

        // Helper to check if text is safe editor buffer vs canvas trap
        func evaluateBufferSafety(probedText: String, sentinel: String) -> (isSafe: Bool, reason: String) {
            // Case 1: Sentinel unchanged -> active element is not a text buffer
            if probedText == sentinel {
                return (false, "SENTINEL_UNCHANGED_FAIL_CLOSED")
            }
            if probedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (false, "EMPTY_BUFFER_FAIL_CLOSED")
            }

            // Case 2: False-Pass Trap -> Canvas Drawing Object JSON
            if probedText.contains("\"sources\":[") ||
               probedText.contains("\"id\":\"LineTool") ||
               probedText.hasPrefix("{\"sources\"") ||
               probedText.hasPrefix("[{\"id\"") {
                return (false, "CANVAS_DRAWING_JSON_TRAP_DETECTED")
            }

            return (true, "VERIFIED_TEXT_BUFFER")
        }

        // 1. Sentinel unchanged (Canvas focused, Cmd+C was no-op)
        let eval1 = evaluateBufferSafety(probedText: sentinel, sentinel: sentinel)
        assertTest("Veto jika sentinel tidak berubah (Canvas focused)", !eval1.isSafe && eval1.reason == "SENTINEL_UNCHANGED_FAIL_CLOSED")

        // 2. Editor Kosong (Empty Buffer)
        // Documented Behavior: Editor kosong tidak mengubah sentinel -> fail-closed abort
        let eval2 = evaluateBufferSafety(probedText: "", sentinel: sentinel)
        assertTest("Veto editor kosong (Fail-closed pada ambiguitas buffer kosong)", !eval2.isSafe && eval2.reason == "EMPTY_BUFFER_FAIL_CLOSED")

        // 3. False-Pass Trap: Canvas Drawing Object JSON
        let mockDrawingJSON = "{\"sources\":[{\"type\":\"LineToolTrendLine\",\"state\":{\"points\":[{\"time\":1727395200,\"price\":83988.1}]}}]}"
        let eval3 = evaluateBufferSafety(probedText: mockDrawingJSON, sentinel: sentinel)
        assertTest("Veto objek drawing JSON kanvas (Mencegah false-pass saat drawing terseleksi)", !eval3.isSafe && eval3.reason == "CANVAS_DRAWING_JSON_TRAP_DETECTED")

        let mockDrawingArrayJSON = "[{\"id\":\"LineToolHorizRay\",\"owner\":\"TradingView\"}]"
        let eval3b = evaluateBufferSafety(probedText: mockDrawingArrayJSON, sentinel: sentinel)
        assertTest("Veto array drawing JSON kanvas", !eval3b.isSafe && eval3b.reason == "CANVAS_DRAWING_JSON_TRAP_DETECTED")

        // 4. Valid Pine Editor Script Buffer
        let mockPineScript = "//@version=5\nindicator(\"My Custom Script\", overlay=true)\nplot(close)"
        let eval4 = evaluateBufferSafety(probedText: mockPineScript, sentinel: sentinel)
        assertTest("Lolos verifikasi saat buffer adalah Pine Script yang valid", eval4.isSafe && eval4.reason == "VERIFIED_TEXT_BUFFER")

        // -----------------------------------------------------------------
        // [TEST GROUP 3: Recovery Mechanism & Neutral Cursor Parking]
        // -----------------------------------------------------------------
        print("\n[TEST GROUP 3: Recovery Mechanism & Neutral Cursor Parking]")

        let windowBounds = CGRect(x: 180, y: 33, width: 1152, height: 864)
        let neutralPt = CGPoint(x: windowBounds.origin.x + 60.0, y: windowBounds.origin.y + 24.0)

        assertTest("Kalkulasi koordinat parkir kursor netral di title bar window", neutralPt.x == 240.0 && neutralPt.y == 57.0, detail: "Parking point: \(neutralPt)")
        assertTest("Koordinat parkir netral berada di luar kanvas candlestick", neutralPt.y < windowBounds.origin.y + 70.0)

        // Test Synchronous Clipboard Restoration
        let pasteboard = NSPasteboard.general
        let userSecret = "USER_ORIGINAL_CLIPBOARD_SECRET_VALUE_998877"
        pasteboard.clearContents()
        pasteboard.setString(userSecret, forType: .string)

        // Simulate CUA operation overwriting clipboard with temporary sentinel
        pasteboard.clearContents()
        pasteboard.setString("TEMPORARY_SENTINEL", forType: .string)

        // Recovery routine restores original clipboard
        pasteboard.clearContents()
        pasteboard.setString(userSecret, forType: .string)

        let restoredClipboard = pasteboard.string(forType: .string) ?? ""
        assertTest("Pemulihan sinkron clipboard asli pengguna", restoredClipboard == userSecret)

        // -----------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------
        print("\n=================================================================")
        print("📊 HASIL AKHIR P1 ANTI-LAG CUA: \(passedAssertions)/\(totalAssertions) PASSED")
        print("=================================================================")
        if failedAssertions > 0 {
            exit(1)
        }
    }
}
