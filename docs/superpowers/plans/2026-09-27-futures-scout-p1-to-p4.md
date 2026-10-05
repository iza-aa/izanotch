# Futures Scout CUA Hardening & Background Watcher (P1 to P4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden TradingView Desktop CUA execution against UI lag, dead keys, and false-pass clipboard traps; establish reliable Pine Editor activation with dual-signal verification; provide visual context for outside-Golden-Pocket setups (Round 12/16 amendment); and build a passive, resource-capped background alert watcher service for automated market tracking.

**Architecture:** 
- **P0 (Completed & Verified)**: Centralized `formatPrice()` dynamic decimals multi-tier, elimination of the rigid $1.00 swing floor, fail-closed degenerate swings, and stochastic window constant replacement.
- **P1**: Replace blind sleeps with an adaptive async polling utility (`pollUntil` with `@Sendable` closure, hopping to `@MainActor` for pasteboard access), conduct live empirical testing of canvas selection vs `Cmd+C`, integrate dual-signal verification (sentinel clipboard + independent UI grounding), and enforce automated fail-closed recovery (Escape x2, sync clipboard restore, cursor park).
- **P2**: Total deprecation of `Option+E`. Implement deterministic multi-strategy activation for Pine Editor in modern TradingView Desktop via bounds-relative grounding, post-open Monaco buffer focus verification, post-compile overlay confirmation in legend, and graceful abort reporting.
- **P3**: Expand `FuturesScoutCoreAnalyst` and `FuturesScoutChartAnalyst` using enum `.standAsideOutsideGP` to render reference Golden Pocket context overlays when in a trending regime waiting for pullback, while keeping pure choppy markets strictly untouched (`return ""` + skip compile), with memory hygiene (`max_lines_count=500, max_labels_count=500`).
- **P4**: Construct a passive, opt-in background actor (`FuturesScoutBackgroundWatcher`) that monitors BingX market data asynchronously via API only (no background screencapture), strictly capped at max 3 simultaneous symbols, with 60s polling + backoff, 24h/Fib TTL expiration, Settings kill switch, and SSOT `CoreAnalyst.analyze`.

**Tech Stack:** Swift 5.9+, AppKit, Carbon HIToolbox, CoreGraphics, ApplicationServices (Accessibility API), Vision Framework, Defaults.

**Spec & Approvals:**
- Approved by Agent 1 (with 4 conditions: empirical Cmd+C test, dual-signal check, documented empty editor behavior, post-compile check).
- Approved by Agent 2 (with 5 amendments: Task 0 P0 recording, @Sendable pollUntil + swiftc compile, Option+E deprecation, .standAsideOutsideGP enum alignment, passive P4 cap-3 watcher).

---

## Global Constraints

1. **Strict Fail-Closed Invariant**: No canvas mutations or blind clicks if element focus, window bounds, or trade status cannot be verified 100%.
2. **Zero Order Execution Hotkeys**: Centralized keycode allowlist strictly blocks order hotkeys (`Shift+B`, `Shift+S`, `Alt+B`, `Alt+S`) and window close (`Cmd+W`). Total deprecation of `Option+E`.
3. **Synchronous User Clipboard Restoration**: User pasteboard content must be restored immediately after all paste/copy operations via `defer`.
4. **Preserve BoringNotch Core**: Companion and notch media/battery/HUD features must remain 100% operational across all builds.
5. **No Blind Fullscreen Screenshots**: Window capture is strictly targeted by Window ID (`screencapture -l <WID>`).
6. **Code Signing Requirement**: All builds must be signed with `IzanotchyDev` using `./scripts/build_and_run.sh` to preserve Accessibility and ScreenCapture permissions.
7. **Test Compilation Standard**: All test scripts must be compiled via `swiftc -parse-as-library ... -o /tmp/... && /tmp/...` (never raw `swift scripts/...`).

---

## File Map & Decomposition

### Modified Files:
- `boringNotch/Clicky/Tools/TradingViewInputSupport.swift`: Add `@Sendable` `pollUntil`, enhance keystroke/mouse synchronization, add focus assertion helpers.
- `boringNotch/Clicky/TradingViewActionDispatcher.swift`: Upgrade `injectPineScript` with dual-signal verification, bounds-relative multi-strategy opener, safe recovery, and post-compile check.
- `boringNotch/Clicky/FuturesScoutCoreAnalyst.swift`: Support `.standAsideOutsideGP` reference overlays in Pine Script v5 generator with memory limits (`max_lines_count=500`).
- `boringNotch/Clicky/FuturesScoutChartAnalyst.swift`: Update CUA dispatch logic to support `.standAsideOutsideGP` context overlays and skip injection on `.standAsideChoppy`.
- `boringNotch/Clicky/Tools/TradingViewTypes.swift`: Add watcher state types, action definitions, and watcher preferences.

### New Files:
- `boringNotch/Clicky/FuturesScoutBackgroundWatcher.swift`: Background market monitor actor, tracking price vs Golden Pocket, triggering notifications.
- `scripts/test_p1_anti_lag_cua.swift`: Automated tests for polling, sentinel timeouts, and recovery mechanisms.
- `scripts/test_p2_pine_editor_opener.swift`: Automated verification of Pine Editor detection and buffer focus handshake.
- `scripts/test_p3_outside_gp_overlay.swift`: Unit tests for Pine Script generator across all 4 market status regimes.
- `scripts/test_p4_background_watcher.swift`: Unit tests for background watcher state machine and alert gating.

---

## Implementation Tasks

### Task 0: P0 Review & Dynamic Decimals Alignment (Completed & Verified)

**Files:**
- Modified: `boringNotch/Clicky/FuturesScoutCoreAnalyst.swift`
- Modified: `boringNotch/Clicky/AstronacciDeterministicEngine.swift`
- Modified: `boringNotch/Clicky/Tools/TradingViewLayoutTool.swift`
- Verified: `scripts/test_chart_analyst.swift`, `scripts/test_astronacci_engine.swift`, `scripts/test_accounting_regression.swift`

- [x] **Step 1: Removal of rigid $1.00 swing floor**
  Replaced `max(1.0, swingHigh - swingLow)` with `minRange = max(currentLivePrice * 0.0005, 0.000001)`.
- [x] **Step 2: Fail-closed degenerate swing detection**
  Added `isDegenerateSwing = rawRange < minRange`, forcing `status = .standAsideChoppy` if flat.
- [x] **Step 3: Centralized multi-tier `formatPrice()`**
  Implemented multi-tier formatting: $\ge \$1000$ (1 dec), $\ge \$1$ (2 dec), $\ge \$0.01$ (4 dec), $< \$0.01$ (8 dec). Applied to briefing card, speech TTS, and Pine Script `#.####`.
- [x] **Step 4: Layout tool fail-closed guard**
  `collapseSidebarIfOpen()` updated with `guard sidebarState == true else { return true }` (0 clicks on closed/nil).
- [x] **Step 5: Verified with existing test suites**
  76/76 Astronacci engine assertions pass, 12/12 accounting regression assertions pass, 17/17 chart analyst groups pass.

---

### Task 1: P1 — Empirical Test of `Cmd+C` on Canvas Selection & False-Pass Hardening

**Files:**
- Create: `scripts/test_p1_canvas_selection_probe.swift`
- Modify: `boringNotch/Clicky/TradingViewActionDispatcher.swift`
- Test: `scripts/test_p1_anti_lag_cua.swift`

**Interfaces:**
- Consumes: `NSPasteboard`, `TradingViewInputSupport`, `CGEvent`.
- Produces: Empirical proof of canvas selection clipboard payload + dual-signal verification rule.

- [ ] **Step 1: Run empirical live probe on TradingView canvas**
  Synthesize selection on canvas drawing, send `Cmd+C`, and print all `NSPasteboard.general.types` and string representations.
- [ ] **Step 2: Document empirical findings in AGENTS.md**
  Record exactly what TradingView places on the clipboard (e.g. JSON drawing structure, empty string, or binary data) to definitively prevent false-pass.
- [ ] **Step 3: Implement Dual-Signal Focus Verification in `TradingViewActionDispatcher.swift`**
  Signal 1: Pasteboard sentinel mismatch (`current != sentinel`).
  Signal 2: Independent UI / Content validation:
  - Verify that the copied buffer does NOT start with TradingView drawing JSON markers (e.g. `{"sources":` or `[{"id":`).
  - Or verify focused UI element or bottom panel container via AX / bounds presence.
- [ ] **Step 4: Document Empty-Editor Behavior (Fail-Closed)**
  Add code documentation: If the editor buffer is 100% empty, `Cmd+C` does not overwrite the sentinel, triggering a fail-closed abort. Document this as intentional fail-safe behavior.

---

### Task 2: P1 — `@Sendable` Adaptive Polling Engine & Auto-Recovery

**Files:**
- Modify: `boringNotch/Clicky/Tools/TradingViewInputSupport.swift`
- Modify: `boringNotch/Clicky/TradingViewActionDispatcher.swift`
- Test: `scripts/test_p1_anti_lag_cua.swift`

**Interfaces:**
- Consumes: Standard Swift concurrency (`Task.sleep`), `NSWorkspace`.
- Produces: `TradingViewInputSupport.pollUntil(timeout:interval:condition:) async -> Bool` with `@Sendable` closure.

- [ ] **Step 1: Write tests in `scripts/test_p1_anti_lag_cua.swift`**
  Compile with: `swiftc -parse-as-library scripts/test_p1_anti_lag_cua.swift -o /tmp/test_p1 && /tmp/test_p1`.
  - Immediate condition returns true immediately.
  - Delayed condition polling succeeds.
  - Timeout returns false.
  - Recovery sequence sends Escape x2 and parks cursor at `(origin.x + 60, origin.y + 24)`.
- [ ] **Step 2: Implement `pollUntil` in `TradingViewInputSupport.swift`**
  Mark closure `@Sendable` and ensure pasteboard access is performed on `@MainActor`.
- [ ] **Step 3: Implement centralized `recoverAndParkCursor()`**
  In `TradingViewActionDispatcher.swift`, add fail-closed handler:
  - Send Escape x2.
  - Restore user clipboard synchronously via `defer`.
  - Smoothly move cursor to neutral header coordinate `(bounds.origin.x + 60, bounds.origin.y + 24)`.
  - Log `[TRADINGVIEW_SECURITY] VETO` and return `false`.
- [ ] **Step 4: Verify P1 test suite**
  Run: `swiftc -parse-as-library scripts/test_p1_anti_lag_cua.swift -o /tmp/test_p1 && /tmp/test_p1` -> PASS.

---

### Task 3: P2 — Multi-Strategy Pine Editor Opener & Post-Compile Check

**Files:**
- Modify: `boringNotch/Clicky/TradingViewActionDispatcher.swift`
- Modify: `boringNotch/Clicky/Tools/TradingViewInputSupport.swift`
- Test: `scripts/test_p2_pine_editor_opener.swift`

**Interfaces:**
- Consumes: Bounds-relative coordinate calculations, `TradingViewInputSupport.clickMouse`.
- Produces: `openPineEditorPanel() async -> Bool`, post-compile verification, and graceful abort reporting.

- [ ] **Step 1: Deprecate `Option+E` total**
  Remove `Option+E` from all dispatcher execution paths and comments. Record in allowlist documentation.
- [ ] **Step 2: Write failing test in `scripts/test_p2_pine_editor_opener.swift`**
  - Verify bounds-relative coordinates for Strategy 1 (Right Dock Tools icon: `maxX - 22, origin.y + 594`) and Strategy 2 (Bottom Un-collapse handle: `origin.x + 180, maxY - 14`).
  - Verify fail-closed abort if both strategies fail.
  - Verify graceful card text: *"Editor Pine tidak dapat dibuka — level tersedia di kartu"*.
- [ ] **Step 3: Implement `openPineEditorPanel()` and Post-Compile Verification**
  - Execute Strategy 1 with polling focus check.
  - If fails, execute Strategy 2 with polling focus check.
  - If both fail: trigger `recoverAndParkCursor()`, set fallback report note, and return `false`.
  - After paste + `Cmd+Return`, wait 400ms and run post-compile check: verify chart overlay was accepted.
- [ ] **Step 4: Run test suite to verify P2**
  Run: `swiftc -parse-as-library scripts/test_p2_pine_editor_opener.swift -o /tmp/test_p2 && /tmp/test_p2` -> PASS.

---

### Task 4: P3 — Outside-GP Context Overlay & Trade Plan Persistence

**Files:**
- Modify: `boringNotch/Clicky/FuturesScoutCoreAnalyst.swift`
- Modify: `boringNotch/Clicky/FuturesScoutChartAnalyst.swift`
- Test: `scripts/test_p3_outside_gp_overlay.swift`

**Interfaces:**
- Consumes: `.standAsideChoppy`, `.standAsideOutsideGP`, `.inGoldenPocketWaiting`, `.setupDetected`.
- Produces: Status-differentiated Pine Script v5 with memory limits (`max_lines_count=500, max_labels_count=500`).

- [ ] **Step 1: Write tests in `scripts/test_p3_outside_gp_overlay.swift`**
  - Status `.standAsideChoppy`: generator returns `""` AND caller skips injection (zero compile).
  - Status `.standAsideOutsideGP`: generates reference Pine Script with dotted Golden Pocket (50.0% - 61.8%), dominant swing lines, and status note `"Status: Menunggu Pullback ke Golden Pocket"`, with ZERO entry/stop-loss boxes.
  - Status `.inGoldenPocketWaiting` / `.setupDetected`: generates full Trade Plan Box with `box.delete` cleanup.
- [ ] **Step 2: Implement generator enhancements in `FuturesScoutCoreAnalyst.swift`**
  Update `generatePineScriptOverlay(result:)` to enforce memory limits and status differentiation.
- [ ] **Step 3: Update `FuturesScoutChartAnalyst.swift`**
  Skip injection when script is empty or market is choppy. Enable context overlay for `.standAsideOutsideGP` under `Defaults[.autoDrawFibonacciOverlay]`.
- [ ] **Step 4: Run test suite to verify P3**
  Run: `swiftc -parse-as-library scripts/test_p3_outside_gp_overlay.swift -o /tmp/test_p3 && /tmp/test_p3` -> PASS.

---

### Task 5: P4 — Decoupled Passive Background Market Watcher Service

**Files:**
- Create: `boringNotch/Clicky/FuturesScoutBackgroundWatcher.swift`
- Modify: `boringNotch/Clicky/Tools/TradingViewTypes.swift`
- Test: `scripts/test_p4_background_watcher.swift`

**Interfaces:**
- Consumes: `FuturesScoutMarketDataService`, `FuturesScoutCoreAnalyst.analyze` (SSOT).
- Produces: Passive background actor, capped at max 3 simultaneous symbols, 60s polling + backoff, TTL/24h expiration, Settings kill-switch.

- [ ] **Step 1: Write tests in `scripts/test_p4_background_watcher.swift`**
  - Verify default state is OFF (passive opt-in).
  - Verify enforcement of cap: max 3 simultaneous monitored symbols.
  - Verify `triggerMet` fires when price touches Golden Pocket boundaries.
  - Verify TTL / 24-hour expiration transitions to terminal state `.expired`.
  - Verify cooldown (15 minutes) prevents repetitive spamming.
- [ ] **Step 2: Implement `FuturesScoutBackgroundWatcher.swift`**
  Actor-isolated monitoring service using API calls only (zero background screen capture), with exponential backoff on network failure.
- [ ] **Step 3: Wire Alert Dispatcher to Companion Rail & Settings**
  Add toggle in Settings (Default: OFF). Emit audio chime and interactive card with 1-click `/analisa` button when triggered (Option 2 consent pattern).
- [ ] **Step 4: Run test suite to verify P4**
  Run: `swiftc -parse-as-library scripts/test_p4_background_watcher.swift -o /tmp/test_p4 && /tmp/test_p4` -> PASS.

---

### Task 6: Master Compilation, Integration & Physical Verification

**Files:**
- All modified and new files.
- Scripts: `./scripts/build_and_run.sh`

- [ ] **Step 1: Run complete automated test suite**
  ```bash
  swiftc -parse-as-library scripts/test_p1_anti_lag_cua.swift -o /tmp/test_p1 && /tmp/test_p1
  swiftc -parse-as-library scripts/test_p2_pine_editor_opener.swift -o /tmp/test_p2 && /tmp/test_p2
  swiftc -parse-as-library scripts/test_p3_outside_gp_overlay.swift -o /tmp/test_p3 && /tmp/test_p3
  swiftc -parse-as-library scripts/test_p4_background_watcher.swift -o /tmp/test_p4 && /tmp/test_p4
  swift scripts/test_chart_analyst.swift
  swift scripts/test_astronacci_engine.swift
  swift scripts/test_accounting_regression.swift
  ```
  Ensure 100% assertions pass across all test suites.

- [ ] **Step 2: Clean Xcode Compilation & Signing**
  ```bash
  ./scripts/build_and_run.sh
  ```
  Confirm `** BUILD SUCCEEDED **` and fresh PID launch.

- [ ] **Step 3: Physical Log Verification**
  Check `~/Library/Logs/Izanotchy/clicky.log`:
  - Clean startup without crashes or unhandled exceptions.
  - Watcher actor successfully instantiated.
  - CUA dispatcher registers anti-lag and sentinel handlers.

- [ ] **Step 4: Documentation Update**
  Update `CHANGELOG.md` and `AGENTS.md` recording all milestones, architectural invariants, and test results.
