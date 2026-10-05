//
//  test_p2_pine_editor_opener.swift
//  scripts
//
//  TDD & Verification Suite for P2: Multi-Strategy Pine Editor Opener & Post-Compile Check
//  Tests:
//  1. Bounds-Relative Coordinate Geometry (Strategy 1 & Strategy 2 & Editor Focus)
//  2. Total Deprecation of Option+E in Allowlist
//  3. Multi-Strategy Priority & Fail-Closed Abort
//  4. Post-Compile Keycode Authorization (Cmd+Return)
//  5. Graceful Fallback Card Text Verification
//
//  Compilation standard:
//  swiftc -parse-as-library scripts/test_p2_pine_editor_opener.swift -o /tmp/test_p2 && /tmp/test_p2
//

import AppKit
import Carbon.HIToolbox
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

// MARK: - Isolated Mock Harness for Allowlist & Geometry Verification

struct MockTradingViewGeometry {
    static func calculateStrategy1Point(bounds: CGRect) -> CGPoint {
        return CGPoint(x: bounds.maxX - 22.0, y: bounds.origin.y + 594.0)
    }

    static func calculateStrategy2Point(bounds: CGRect) -> CGPoint {
        return CGPoint(x: bounds.origin.x + 180.0, y: bounds.maxY - 14.0)
    }

    static func calculateEditorFocusPoint(bounds: CGRect) -> CGPoint {
        return CGPoint(x: bounds.origin.x + 200.0, y: bounds.maxY - 120.0)
    }

    static func isPointInBounds(_ pt: CGPoint, bounds: CGRect) -> Bool {
        return bounds.contains(pt)
    }
}

struct MockInputAllowlist {
    static func isAllowedKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) -> Bool {
        switch keyCode {
        case CGKeyCode(kVK_Escape):
            return true
        case CGKeyCode(kVK_Return):
            return flags.isEmpty || flags == [.maskCommand] // Cmd+Return allowed for Pine compile
        case CGKeyCode(kVK_ANSI_E):
            return flags.isEmpty // Plain 'E' only. Option+E strictly rejected (dead key ´)
        case CGKeyCode(kVK_ANSI_K):
            return flags == [.maskCommand] || flags == [.maskCommand, .maskAlternate]
        case CGKeyCode(kVK_ANSI_A), CGKeyCode(kVK_ANSI_V), CGKeyCode(kVK_ANSI_Z):
            return flags == [.maskCommand]
        case CGKeyCode(kVK_ANSI_C):
            return flags == [.maskCommand]
        default:
            return false
        }
    }
}

actor MockPineOpenerOrchestrator {
    enum StrategyOutcome {
        case success
        case failure
    }

    var strat1Outcome: StrategyOutcome = .failure
    var strat2Outcome: StrategyOutcome = .failure
    var strat3Outcome: StrategyOutcome = .failure

    var executedStrategies: [String] = []
    var recoveryInvoked: Bool = false
    var parkedCoordinate: CGPoint? = nil

    func configure(s1: StrategyOutcome, s2: StrategyOutcome, s3: StrategyOutcome) {
        self.strat1Outcome = s1
        self.strat2Outcome = s2
        self.strat3Outcome = s3
        self.executedStrategies.removeAll()
        self.recoveryInvoked = false
        self.parkedCoordinate = nil
    }

    func openPineEditorPanel(bounds: CGRect) async -> (isOpen: Bool, fallbackNote: String) {
        // Strategy 1
        executedStrategies.append("Strategy1_RightDock")
        if strat1Outcome == .success {
            return (true, "")
        }

        // Strategy 2
        executedStrategies.append("Strategy2_BottomUncollapse")
        if strat2Outcome == .success {
            return (true, "")
        }

        // Strategy 3
        executedStrategies.append("Strategy3_CommandPalette")
        if strat3Outcome == .success {
            return (true, "")
        }

        // All failed -> Fail-Closed Recovery
        recoveryInvoked = true
        parkedCoordinate = CGPoint(x: bounds.origin.x + 60.0, y: bounds.origin.y + 24.0)
        return (false, "Editor Pine tidak dapat dibuka — level tersedia di kartu")
    }
}

@main
struct TestP2PineEditorOpener {
    static func main() async {
        print("==================================================")
        print("   P2: Pine Editor Opener & Post-Compile Check    ")
        print("==================================================")

        // 1. Geometry Calculation
        let bounds = CGRect(x: 180, y: 33, width: 1152, height: 864)
        let s1 = MockTradingViewGeometry.calculateStrategy1Point(bounds: bounds)
        assertTest(
            "Strategy 1 right dock tools/pine icon coordinate calculation",
            s1.x == 1310.0 && s1.y == 627.0,
            detail: "pt=\(s1)"
        )

        let s2 = MockTradingViewGeometry.calculateStrategy2Point(bounds: bounds)
        assertTest(
            "Strategy 2 bottom un-collapse handle coordinate calculation",
            s2.x == 360.0 && s2.y == 883.0,
            detail: "pt=\(s2)"
        )

        let sFocus = MockTradingViewGeometry.calculateEditorFocusPoint(bounds: bounds)
        assertTest(
            "Monaco editor internal focus point inside bottom panel",
            sFocus.x == 380.0 && sFocus.y == 777.0 && bounds.contains(sFocus),
            detail: "pt=\(sFocus)"
        )

        // 2. Allowlist Keycode Checks
        let optE = MockInputAllowlist.isAllowedKey(CGKeyCode(kVK_ANSI_E), flags: [.maskAlternate])
        let plainE = MockInputAllowlist.isAllowedKey(CGKeyCode(kVK_ANSI_E), flags: [])
        let cmdE = MockInputAllowlist.isAllowedKey(CGKeyCode(kVK_ANSI_E), flags: [.maskCommand])
        assertTest(
            "Option+E dead-key is strictly rejected while plain 'E' is authorized",
            !optE && plainE && !cmdE
        )

        let cmdReturn = MockInputAllowlist.isAllowedKey(CGKeyCode(kVK_Return), flags: [.maskCommand])
        assertTest(
            "Cmd+Return is authorized for Pine Script compilation",
            cmdReturn
        )

        // 3. Orchestration Simulation: Strat 1 Success
        let orchestrator = MockPineOpenerOrchestrator()
        await orchestrator.configure(s1: .success, s2: .failure, s3: .failure)
        let res1 = await orchestrator.openPineEditorPanel(bounds: bounds)
        let execs1 = await orchestrator.executedStrategies
        assertTest(
            "Strategy 1 success short-circuits subsequent strategies",
            res1.isOpen && execs1 == ["Strategy1_RightDock"]
        )

        // 4. Orchestration Simulation: Strat 1 Fails -> Strat 2 Succeeds
        await orchestrator.configure(s1: .failure, s2: .success, s3: .failure)
        let res2 = await orchestrator.openPineEditorPanel(bounds: bounds)
        let execs2 = await orchestrator.executedStrategies
        assertTest(
            "Strategy 1 failure seamlessly falls back to Strategy 2",
            res2.isOpen && execs2 == ["Strategy1_RightDock", "Strategy2_BottomUncollapse"]
        )

        // 5. Orchestration Simulation: Strat 1 & 2 Fail -> Strat 3 Succeeds
        await orchestrator.configure(s1: .failure, s2: .failure, s3: .success)
        let res3 = await orchestrator.openPineEditorPanel(bounds: bounds)
        let execs3 = await orchestrator.executedStrategies
        assertTest(
            "Strategy 1 & 2 failure falls back to Strategy 3 (Command Palette)",
            res3.isOpen && execs3 == ["Strategy1_RightDock", "Strategy2_BottomUncollapse", "Strategy3_CommandPalette"]
        )

        // 6. Orchestration Simulation: All Strategies Fail -> Fail-Closed Recovery
        await orchestrator.configure(s1: .failure, s2: .failure, s3: .failure)
        let res4 = await orchestrator.openPineEditorPanel(bounds: bounds)
        let recoveryInvoked = await orchestrator.recoveryInvoked
        let parked = await orchestrator.parkedCoordinate
        assertTest(
            "All strategies fail -> fail-closed abort with recovery and header cursor parking",
            !res4.isOpen && recoveryInvoked && parked == CGPoint(x: 240.0, y: 57.0),
            detail: "parked=\(String(describing: parked))"
        )

        // 7. Fallback Card Text Verification
        assertTest(
            "Graceful fallback report note matches exact user-facing canon",
            res4.fallbackNote == "Editor Pine tidak dapat dibuka — level tersedia di kartu"
        )

        print("\n--------------------------------------------------")
        print("P2 Results: \(passedAssertions)/\(totalAssertions) passed")
        print("--------------------------------------------------")

        if failedAssertions == 0 {
            print("🎉 ALL P2 OPENER & COMPILE TESTS PASSED (100%)!")
            exit(0)
        } else {
            print("💥 SOME P2 TESTS FAILED (\(failedAssertions) failures)!")
            exit(1)
        }
    }
}
