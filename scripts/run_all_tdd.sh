#!/usr/bin/env bash
#
#  run_all_tdd.sh — Izanotchy Canonical TDD & Regression Runner
#  Runs all 7 test suites (5 Advanced Foundations, Chart Analyst Core, and OOS Gate 2)
#  Standardized for Auditor Agent 1 & Agent 2 Independent Verification.
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "========================================================================"
echo "🚀 IZANOTCHY UNIFIED TDD & VERIFICATION SUITE RUNNER"
echo "========================================================================"
echo "Workspace: $REPO_ROOT"
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "========================================================================"

SKIP_SLOW=false
for arg in "$@"; do
    case "$arg" in
        --fast|--skip-slow)
            SKIP_SLOW=true
            ;;
    esac
done

START_TIME=$(date +%s)
FAILED_SUITES=0
PASSED_SUITES=0

run_suite() {
    local SUITE_NAME="$1"
    local BINARY_NAME="$2"
    shift 2
    local SOURCES=("$@")

    echo ""
    echo "------------------------------------------------------------------------"
    echo "▶️ [RUNNING] $SUITE_NAME"
    echo "------------------------------------------------------------------------"

    local OUT_BIN="/tmp/$BINARY_NAME"
    rm -f "$OUT_BIN"

    if swiftc -parse-as-library -O "${SOURCES[@]}" -o "$OUT_BIN"; then
        if "$OUT_BIN"; then
            echo "✅ [SUCCESS] $SUITE_NAME passed."
            PASSED_SUITES=$((PASSED_SUITES + 1))
        else
            echo "❌ [FAILURE] $SUITE_NAME failed at runtime."
            FAILED_SUITES=$((FAILED_SUITES + 1))
        fi
    else
        echo "❌ [COMPILE ERROR] $SUITE_NAME failed compilation."
        FAILED_SUITES=$((FAILED_SUITES + 1))
    fi
}

# 1. Fibonacci Cluster (KRZ) Suite
run_suite "1. Fibonacci Cluster Engine (KRZ)" "test_cluster_suite" \
    scripts/test_fibonacci_cluster.swift \
    boringNotch/Clicky/AstronacciClusterEngine.swift \
    boringNotch/Clicky/AstronacciDeterministicEngine.swift

# 2. Structural Divergence Engine Suite
run_suite "2. Structural Divergence Engine" "test_divergence_suite" \
    scripts/test_astronacci_divergence.swift \
    boringNotch/Clicky/AstronacciDivergenceEngine.swift \
    boringNotch/Clicky/AstronacciDeterministicEngine.swift

# 3. Quasimodo Pattern Recognizer Suite
run_suite "3. Quasimodo Pattern Recognizer" "test_quasimodo_suite" \
    scripts/test_astronacci_quasimodo.swift \
    boringNotch/Clicky/AstronacciQuasimodoEngine.swift \
    boringNotch/Clicky/AstronacciDeterministicEngine.swift

# 4. Astronomical Ephemeris Engine Suite (Meeus Canon)
run_suite "4. Astronomical Ephemeris Engine (5 Historical Benchmarks)" "test_ephemeris_suite" \
    scripts/test_astronacci_ephemeris.swift \
    boringNotch/Clicky/AstronacciEphemerisEngine.swift

# 5. Time Cycles & Projection Suite
run_suite "5. Time Cycles & Fibonacci Projection" "test_time_cycles_suite" \
    scripts/test_astronacci_time_cycles.swift \
    boringNotch/Clicky/FuturesScoutCoreAnalyst.swift \
    boringNotch/Clicky/AstronacciDeterministicEngine.swift \
    boringNotch/Clicky/AstronacciClusterEngine.swift \
    boringNotch/Clicky/AstronacciDivergenceEngine.swift \
    boringNotch/Clicky/AstronacciQuasimodoEngine.swift \
    boringNotch/Clicky/AstronacciEphemerisEngine.swift \
    boringNotch/Clicky/AstronacciEconomicCalendarEngine.swift \
    boringNotch/Clicky/AstronacciPlanetaryAspectEngine.swift \
    boringNotch/Clicky/FuturesScoutMarketDataService.swift \
    boringNotch/Clicky/ClickyLogger.swift

# 6. Chart Analyst Core, Presentation & CUA Security Sweep
run_suite "6. Full Chart Analyst Core & CUA Keycode Sweep" "test_chart_analyst_suite" \
    scripts/test_chart_analyst.swift \
    boringNotch/Clicky/Tools/TradingViewInputSupport.swift \
    boringNotch/Clicky/FuturesScoutCoreAnalyst.swift \
    boringNotch/Clicky/AstronacciDeterministicEngine.swift \
    boringNotch/Clicky/AstronacciClusterEngine.swift \
    boringNotch/Clicky/AstronacciDivergenceEngine.swift \
    boringNotch/Clicky/AstronacciQuasimodoEngine.swift \
    boringNotch/Clicky/AstronacciEphemerisEngine.swift \
    boringNotch/Clicky/AstronacciEconomicCalendarEngine.swift \
    boringNotch/Clicky/AstronacciPlanetaryAspectEngine.swift \
    boringNotch/Clicky/FuturesScoutMarketDataService.swift \
    boringNotch/Clicky/ClickyLogger.swift

# 7. Out-of-Sample (OOS 30%) Protocol & Stop-Rule Verifier (Gate 2 Check)
if [ "$SKIP_SLOW" = true ]; then
    echo ""
    echo "------------------------------------------------------------------------"
    echo "⏩ [SKIPPED] 7. Gate 2 Protocol Verifier: STOP-RULE ENFORCED (BTC 5,347 bars) [--fast/--skip-slow active]"
    echo "------------------------------------------------------------------------"
else
    run_suite "7. Gate 2 Protocol Verifier: STOP-RULE ENFORCED (BTC 5,347 bars)" "test_oos_verifier" \
        scripts/backtest_h1_oos.swift \
        boringNotch/Clicky/AstronacciDeterministicEngine.swift
fi

# 8. High-Impact Economic News Buffer Calendar Suite (SOP Bab 7)
run_suite "8. High-Impact Economic News Buffer Calendar" "test_economic_calendar_suite" \
    scripts/test_astronacci_economic_calendar.swift \
    boringNotch/Clicky/AstronacciEconomicCalendarEngine.swift

# 9. Planetary Aspects & Zodiac Ingress Engine Suite (Eye of Future)
run_suite "9. Planetary Aspects & Zodiac Ingress Engine" "test_planetary_aspects_suite" \
    scripts/test_astronacci_planetary_aspects.swift \
    boringNotch/Clicky/AstronacciPlanetaryAspectEngine.swift \
    boringNotch/Clicky/AstronacciEphemerisEngine.swift

# 10. Closed-Loop TradingView Window Title Verification & Readiness Polling Gate Suite
run_suite "10. Closed-Loop Window Title Verification & Readiness Polling Gate" "test_title_verification_suite" \
    scripts/test_tradingview_title_verification.swift \
    boringNotch/Clicky/Tools/TradingViewNavigationTool.swift \
    boringNotch/Clicky/Tools/TradingViewInputSupport.swift \
    boringNotch/Clicky/Tools/TradingViewLayoutTool.swift \
    boringNotch/Clicky/Tools/CuaVisualGrounder.swift \
    boringNotch/Clicky/ClickyLogger.swift \
    boringNotch/Clicky/CuaActionCursorManager.swift \
    boringNotch/Clicky/CuaMotionEngine.swift \
    boringNotch/Clicky/CuaDriverClient.swift

# 11. CuaDrive Visual Grounder Suite (Dynamic Bounding Box & Center Detection)
run_suite "11. CuaDrive Visual Grounder (Zero Hardcoded XY)" "test_visual_grounder_suite" \
    scripts/test_cuadrive_visual_grounder.swift \
    boringNotch/Clicky/Tools/CuaVisualGrounder.swift \
    boringNotch/Clicky/ClickyLogger.swift

# 12. Multi-Market Radar Analyst Suite (Reviewer SSOT Canon)
run_suite "12. Multi-Market Radar Analyst (Reviewer SSOT Canon)" "test_market_radar_suite" \
    scripts/test_market_radar_analyst.swift \
    boringNotch/Clicky/FuturesScoutCoreAnalyst.swift \
    boringNotch/Clicky/FuturesScoutMarketDataService.swift \
    boringNotch/Clicky/AstronacciDeterministicEngine.swift \
    boringNotch/Clicky/AstronacciClusterEngine.swift \
    boringNotch/Clicky/AstronacciDivergenceEngine.swift \
    boringNotch/Clicky/AstronacciQuasimodoEngine.swift \
    boringNotch/Clicky/AstronacciEphemerisEngine.swift \
    boringNotch/Clicky/AstronacciEconomicCalendarEngine.swift \
    boringNotch/Clicky/AstronacciPlanetaryAspectEngine.swift \
    boringNotch/Clicky/ClickyLogger.swift

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo "========================================================================"
echo "📊 UNIFIED TDD RUN SUMMARY"
echo "========================================================================"
echo "Passed Suites: $PASSED_SUITES / $((PASSED_SUITES + FAILED_SUITES))"
echo "Failed Suites: $FAILED_SUITES"
echo "Elapsed Time:  ${ELAPSED}s"
echo "========================================================================"

if [ "$FAILED_SUITES" -eq 0 ]; then
    echo "🎉 ALL SUITES PASSED CLEANLY (100% SUCCESS)!"
    exit 0
else
    echo "⚠️ $FAILED_SUITES SUITE(S) FAILED."
    exit 1
fi
