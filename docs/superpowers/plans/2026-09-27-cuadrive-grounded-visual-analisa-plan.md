# CuaDrive Grounded Visual Analisa Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the complete Izanotchy `/analisa` TradingView workflow to use 100% CuaDrive visual action cursor with dynamic screen grounding ("mata visual"), zero hardcoded $(x, y)$ coordinates, multi-layered fail-closed gates, and instant purge of canvas drawing residue.

**Architecture:** 
1. **Perceptual Layer (CuaVisualGrounder)**: Provides "eyes" to CuaDrive by scanning TradingView window with Apple Vision Fast OCR, detecting target UI elements (symbol search pill, timeframe selector, toolbar icons, trash can, Pine Editor panel), extracting their exact bounding boxes, and calculating their exact center points (`CGPoint(midX, midY)`).
2. **Kinematic Layer (CuaActionCursorManager & CuaMotionEngine)**: Renders the visual CuaDrive action cursor on the screen, smoothly animating along 60fps Dubins / Bezier curves to the detected center points with contextual badges ("Simbol", "Timeframe", "Auto-Fit", "Hapus Residu", "Setup Area") and visual ripple clicks, while dispatching hardware events directly without hijacking user physical mouse.
3. **Execution & Gate Layer (TradingViewActionDispatcher & Closed-Loop Gates)**: Coordinates the 5 sequential phases with strict fail-closed safety. If an element is not visually confirmed, execution halts immediately (zero canvas text pasting). Backend mathematical analysis (BingX klines, Fibonacci, ATR, Ephemeris, Calendar) runs in parallel asynchronously.

**Tech Stack:**
- Swift 6 / AppKit / macOS WindowServer (`CGWindowListCopyWindowInfo`)
- Apple Vision Framework (`VNRecognizeTextRequest`, `VNRecognizedTextObservation`)
- Cua Motion Engine (`CuaMotionRunner`, Dubins paths, 60fps timer)
- Cua Action Cursor (`CuaActionCursorManager`, SwiftUI Overlay Layer 1000)
- BingX Live Market API & Astronacci Pure Core Engine

**Spec:** Local conversation spec and User Guidance: *"kita akan menggunakan cuadrive cursor 100% untuk aksi, tetap butuh visual agar cua nya ga buta... membaca layar melihat ukuran button mengklik bagian tengah nya pas dari ukuran button itu, layer per layer, tetap menjalankan parallel instruction analysis trading kita dibackend tapi secara visual sinkron 100% dengan user lihat, tidak ada hardcoded xy..."*

## Global Constraints
- **Zero Hardcoded Coordinates**: Under no circumstances should arbitrary $(x, y)$ coordinates be hardcoded for UI elements or buttons. All click points MUST be computed dynamically from detected element bounds (`center = (midX, midY)`).
- **Anti-Canvas Fail-Closed Invariant**: `Cmd + V` MUST NEVER be dispatched to the candlestick chart canvas. If Pine Editor is not physically verified on screen, CUA must fail-closed immediately (Zero Mutation on chart).
- **Zero Physical Mouse Hijacking**: The user's hardware mouse cursor must NEVER be dragged or locked across the screen. All visible motion belongs to the ephemeral CuaDrive Action Cursor.
- **Silent Screen Capture**: All screen captures MUST use the `"-x"` flag to ensure 100% silence (zero macOS camera shutter sound).
- **Single Source of Truth**: All calendar, ephemeris, and trade plan parameters must remain deterministic and reproducible.

---

### Task 1: CuaVisualGrounder — The Visual "Eyes" of CuaDrive (Dynamic Element Detection)

**Files:**
- Create: `boringNotch/Clicky/Tools/CuaVisualGrounder.swift`
- Modify: `boringNotch/Clicky/Tools/TradingViewInputSupport.swift`
- Test: `scripts/test_cuadrive_visual_grounder.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct GroundedUIElement: Sendable {
      public let text: String
      public let windowRect: CGRect
      public let centerPoint: CGPoint
      public let confidence: Float
  }

  public enum CuaVisualGrounder {
      public static func groundElement(matching pattern: String, inWindowId windowId: CGWindowID, windowBounds: CGRect, searchRegionNorm: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> GroundedUIElement?
      public static func groundSymbolPill(inWindowId windowId: CGWindowID, windowBounds: CGRect) -> GroundedUIElement?
      public static func groundTimeframeSelector(targetTf: String, inWindowId windowId: CGWindowID, windowBounds: CGRect) -> GroundedUIElement?
      public static func groundTrashCanButton(windowBounds: CGRect) -> CGPoint
      public static func groundPineEditor(inWindowId windowId: CGWindowID, windowBounds: CGRect) -> GroundedUIElement?
  }
  ```

- [ ] **Step 1: Write the failing unit test script for CuaVisualGrounder**
  Create `scripts/test_cuadrive_visual_grounder.swift` that runs against the live TradingView window and asserts that `groundSymbolPill`, `groundElement("Trade")`, and `groundElement("Publish")` return non-nil `GroundedUIElement` with positive widths/heights and center points strictly inside TradingView window bounds.
- [ ] **Step 2: Run test to confirm it fails (file missing)**
  Execute `swift scripts/test_cuadrive_visual_grounder.swift` and verify failure.
- [ ] **Step 3: Implement `CuaVisualGrounder.swift`**
  Implement high-precision text observation parsing using `VNRecognizeTextRequest(recognitionLevel: .fast)`. Convert normalized bottom-left Vision coordinates to macOS top-left window coordinates:
  ```swift
  let centerX = windowBounds.origin.x + (box.origin.x + box.width * 0.5) * windowBounds.width
  let centerY = windowBounds.origin.y + (1.0 - (box.origin.y + box.height * 0.5)) * windowBounds.height
  ```
- [ ] **Step 4: Run test to confirm it passes**
  Execute `swift scripts/test_cuadrive_visual_grounder.swift` and verify clean detection of element centers.
- [ ] **Step 5: Commit changes**

---

### Task 2: Purge Canvas Text Box Drawings via CuaDrive Action Cursor

**Files:**
- Modify: `boringNotch/Clicky/Tools/TradingViewDrawingTool.swift`
- Test: `scripts/purge_canvas_drawings.swift`

**Interfaces:**
- Consumes: `CuaVisualGrounder.groundTrashCanButton`, `CuaActionCursorManager.shared.fly`, `TradingViewInputSupport.clickMouseDirectly`
- Produces: `TradingViewDrawingTool.purgeResidualDrawings() async -> Bool`

- [ ] **Step 1: Write the standalone purge verification script**
  Create `scripts/purge_canvas_drawings.swift` to invoke `purgeResidualDrawings()`, capture the window before and after, and verify via Vision OCR that code fragments (`max_labels`, `style_line`, `Golden Pocket`, `tostring`) drop to 0.
- [ ] **Step 2: Run script to verify current residue exists**
  Confirm script reports the presence of residual code text on the user's chart.
- [ ] **Step 3: Implement `purgeResidualDrawings()` in `TradingViewDrawingTool.swift`**
  1. Have `CuaActionCursorManager.shared` fly smoothly to the Trash Can button on the left drawing toolbar with badge `"Hapus Gambar"`.
  2. Click the Trash Can icon directly via `clickMouseDirectly(at: trashPt, restoreUserCursor: true)`.
  3. Also execute native chart canvas reset: focus canvas, press `Cmd + Option + K` (Remove all drawings).
  4. Dismiss Cua Action Cursor with fade-out.
- [ ] **Step 4: Run script to confirm all text boxes are permanently purged from chart**
  Execute `swift scripts/purge_canvas_drawings.swift` and verify 0 stray code texts remain.
- [ ] **Step 5: Commit changes**

---

### Task 3: Grounded Symbol & Timeframe Switching (Zero Hardcoded XY)

**Files:**
- Modify: `boringNotch/Clicky/Tools/TradingViewNavigationTool.swift`
- Modify: `boringNotch/Clicky/Tools/TradingViewActionDispatcher.swift`
- Test: `scripts/probe_e2e_analisa.swift --step 2`, `scripts/probe_e2e_analisa.swift --step 3`

**Interfaces:**
- Consumes: `CuaVisualGrounder.groundSymbolPill`, `CuaVisualGrounder.groundTimeframeSelector`, `CuaActionCursorManager.shared.fly`
- Produces: Updated `TradingViewNavigationTool.switchSymbol(_:)` and `switchTimeframe(_:)` with 100% dynamic center point targeting.

- [ ] **Step 1: Update `switchSymbol` to use `CuaVisualGrounder`**
  Remove any hardcoded `(origin.x + 108, origin.y + 53)`.
  Dynamically resolve the Symbol Search Pill via `CuaVisualGrounder.groundSymbolPill()`.
  If detected:
  - Cua Action Cursor flies to `element.centerPoint` with badge `"Ganti Simbol"`.
  - Action cursor clicks `element.centerPoint`.
  - Types target symbol (e.g. `BTCUSDT.P`).
  - Presses `Return`.
  - Verifies WindowServer title transition via `verifySymbolTitle(targetSymbol:timeout: 3.0)`.
  Fallback: Command Palette `Cmd + K` if pill is occluded.
- [ ] **Step 2: Update `switchTimeframe` to use `CuaVisualGrounder`**
  Resolve timeframe anchor or use canvas direct typing with focus verification.
  Cua Action Cursor flies to timeframe header with badge `"Timeframe \(tf)"`.
  Types timeframe and presses `Return`.
  Verifies via `isTimeframeSettled()`.
- [ ] **Step 3: Run Phase 2 and Phase 3 verification via CLI**
  Verify with `swift scripts/probe_e2e_analisa.swift --step 2` and `swift scripts/probe_e2e_analisa.swift --step 3`.
- [ ] **Step 4: Commit changes**

---

### Task 4: Grounded Layout Optimization & Auto-Fit (Option + R)

**Files:**
- Modify: `boringNotch/Clicky/Tools/TradingViewLayoutTool.swift`
- Test: `scripts/probe_e2e_analisa.swift --step 4`

**Interfaces:**
- Produces: Updated `TradingViewLayoutTool.collapseSidebarIfOpen()` and `resetChartScale()` with canvas focus guarantee.

- [ ] **Step 1: Implement idempotent sidebar detection via Vision / AX**
  Check right 25% of window for `"Watchlist"`.
  If closed, NO-OP (0 clicks).
  If open, Cua Action Cursor flies to the Watchlist toggle button and closes it.
- [ ] **Step 2: Implement canvas-focused `resetChartScale()`**
  Ensure canvas center is focused before sending `Option + R` to prevent registered trademark `®` leakage.
- [ ] **Step 3: Run Phase 4 verification via CLI**
  Execute `swift scripts/probe_e2e_analisa.swift --step 4` and verify sidebar is closed and scale is auto-fit.
- [ ] **Step 4: Commit changes**

---

### Task 5: Fail-Closed Trade Plan Presentation & Visual Pointing (Zero Canvas Paste Pollution)

**Files:**
- Modify: `boringNotch/Clicky/TradingViewActionDispatcher.swift`
- Modify: `boringNotch/Clicky/FuturesScoutChartAnalyst.swift`
- Test: `scripts/probe_e2e_analisa.swift`

**Interfaces:**
- Strict Rule: Before `Cmd + V` is ever executed, `CuaVisualGrounder.groundPineEditor()` MUST return a valid grounded element confirming that Pine Editor is physically open on screen.
- If `groundPineEditor()` returns `nil`:
  - **ABORT MUTATION IMMEDIATELY (Veto / Fail-Closed)**.
  - Zero `Cmd + V` sent to chart canvas.
  - Deliver complete Trade Plan via Clicky chat markdown card and ElevenLabs TTS audio narrative.
  - Cua Action Cursor flies to the candlestick chart center-right to visually point out the setup area with badge `"Area Setup"` and fades out.

- [ ] **Step 1: Implement Strict Anti-Canvas Lock in `injectPineScript`**
  Replace blind coordinates `(origin.x + 200, maxY - 120)` with `CuaVisualGrounder.groundPineEditor()`.
  If editor is detected, click its exact center point inside the Monaco Editor text area.
  If not detected, immediately return `false` without ever pressing `Cmd + V`.
- [ ] **Step 2: Wire Fail-Closed Reporting in `FuturesScoutChartAnalyst.swift`**
  When Pine Script injection is skipped or vetoed, ensure the chat card markdown clearly displays all technical levels (Entry, SL, TP1, TP2, Golden Pocket) and Clicky companion speaks the analysis smoothly.
- [ ] **Step 3: Commit changes**

---

### Task 6: End-to-End Verification & Real-Time Physical Validation

**Files:**
- Modify: `scripts/probe_e2e_analisa.swift`
- Test: Full E2E Analisa Workflow (`BTC 15m` and `SOL 15m`)

- [ ] **Step 1: Compile application with `xcodebuild`**
  Run `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build`.
  Confirm `** BUILD SUCCEEDED **`.
- [ ] **Step 2: Restart application with clean daemon state**
  Kill old PIDs, restart `boringNotch.app`, verify new PID via `ps aux`.
- [ ] **Step 3: Execute Full E2E Probe (`./scripts/probe_e2e_analisa.swift BTC 15m`)**
  Assert all 5 gates pass cleanly:
  - Gate 1: TV Frontmost & Ready
  - Gate 2: Simbol Grounded & Settled
  - Gate 3: Timeframe Grounded & Settled
  - Gate 4: Layout Settle (Sidebar Closed + Auto-Fit Scale)
  - Gate 5: Zero Canvas Pollution + Clean Presentation
- [ ] **Step 4: Inspect visual proof artifact (`/tmp/e2e_analisa_verified.png`)**
  Confirm 0 stray text boxes on candlestick chart and pristine chart layout.
- [ ] **Step 5: Update documentation (`CHANGELOG.md` & `AGENTS.md`)**
  Record Milestone 139 and post-mortem insights.
