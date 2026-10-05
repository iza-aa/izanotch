# GEMINI.md — Izanotchy Agent Directives & Continuous Documentation Protocol

> **MANDATORY INSTRUCTION FOR ALL AI CODING AGENTS (GEMINI / ANTIGRAVITY / CLAUDE / CODEX):**
>
> 1. **Auto-Update Documentation:** Every time you complete a feature, bug fix, or code modification, you **MUST** update `CHANGELOG.md` with the milestone description and verification results, and update `AGENTS.md` with any new post-mortem insights or architectural notes. Never complete a turn without updating these files.
> 2. **Explicit Verification Before Completion:** Never state a task is finished without running a clean build, verifying the running PID, and validating with evidence (targeted diagnostic log assertion or targeted window capture via `screencapture -l <WindowID>`; NEVER take blind fullscreen screenshots of the user's private workspace).
> 3. **Stale Binary Prevention:** Whenever code is recompiled, you must kill the old running instance (`pkill -9 -f boringNotch`) and launch the newly compiled binary. Always verify the PID and process start time.

---

## 🛠️ Build & Verification Protocol

### 1. Clean Compilation
```bash
cd /Users/heizaaa/Desktop/cdev/iza-3
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build
```
*Confirm the output explicitly ends with `** BUILD SUCCEEDED **`.*

### 2. Restart Running Application (With Complete Child/Daemon Cleanup)
```bash
pkill -9 -f boringNotch || true; pkill -9 -f cua-driver || true; pkill -9 -f BoringNotchXPCHelper || true; rm -f /tmp/cua-izanotchy-*.sock && sleep 1 && open /Users/heizaaa/Library/Developer/Xcode/DerivedData/boringNotch-fynybjceasxenmesmqcnsmlcyoaj/Build/Products/Debug/boringNotch.app
```

### 3. Verify Running Process
```bash
ps aux | grep -i boringnotch | grep -v grep
```
*Ensure the PID is fresh and matches the recent launch time.*

### 4. Real-time Diagnostics Log Inspection
```bash
# View recent logs:
cat ~/Library/Logs/Izanotchy/clicky.log

# Or run the live streaming watcher:
./scripts/tail_logs.sh
```

### 5. Targeted & Action-Gated Verification (No Blind Full-Screen Dumps)
- **DO NOT** run blind fullscreen `screencapture -x` which captures the user's private workspace (browser, notes, unrelated apps) without purpose.
- **Log & State First**: For backend logic, permissions, and hotkeys, verify via PID, return codes, and `~/Library/Logs/Izanotchy/clicky.log`.
- **Targeted Window Capture**: When visual proof is truly needed, capture ONLY the specific target window via its Window ID:
  ```bash
  # Example: capture specific TradingView or Izanotchy window by ID without capturing user's other apps
  screencapture -l <TargetWindowID> /tmp/target_window.png
  ```
- **Action-Gated**: Only capture visuals if an actual interactive action was executed (proving a state change), not when the app is just sitting idle after launch.

---

## 🏗️ Architectural Invariants

1. **Target Separation:**
   - `boringNotch.xcodeproj` has two targets: `boringNotch` (main app) and `BoringNotchXPCHelper` (daemon).
   - **NEVER** add Clicky files to `BoringNotchXPCHelper` Sources build phase. `BoringNotchXPCHelper` does not link `Defaults` or SwiftUI companion components.
2. **Overlay Layering & Hit-Testing:**
   - `OverlayWindow` is fullscreen Layer 1000 (`.screenSaver`).
   - `window.ignoresMouseEvents = true` MUST be set **after** assigning `contentView`.
   - SwiftUI root view MUST have `.allowsHitTesting(false)` and `Color.clear` background to ensure mouse clicks and hover events pass through seamlessly to the MacBook Notch and desktop apps.
3. **Cursor State Synchronization:**
   - Companion state is driven by `Defaults[.cursorAssistantEnabled]` and `CompanionManager.shared.isClickyCursorEnabled`.
   - When toggled `false`, `OverlayWindowManager.shared.hideOverlay()` is called immediately and `buddyIsVisibleOnThisScreen` returns `false`.
4. **Shortcut Monitoring:**
   - Push-to-talk supports `⌥ Option` and `⌃ Control + ⌥ Option`.
   - Both `CGEvent.tapCreate` (when AX is trusted) and `NSEvent.addGlobalMonitorForEvents` are active simultaneously so events are never dropped.
5. **Diagnostic Logging:**
   - All critical actions must invoke `ClickyLogger.info/success/warning/error`.
   - `ClickyLogger` is thread-safe (`NSLock`) and nonisolated so it can be called safely from audio threads, event tap callbacks, and main thread.

---

## 📜 Mandatory Session Completion Checklist

Before reporting completion to the user, ensure:
- [ ] `xcodebuild` completed with code `0` (`** BUILD SUCCEEDED **`).
- [ ] Old binary was killed and new binary is confirmed running via `ps aux`.
- [ ] `~/Library/Logs/Izanotchy/clicky.log` shows clean initialization without runtime exceptions.
- [ ] `CHANGELOG.md` has been updated with the milestone description and technical details.
- [ ] `AGENTS.md` has been updated with any new post-mortem lessons or architectural notes.
