# Fitur F-07: Interactive "Computer" Card (1:1 Foto 1) Implementation Plan

> **Date:** 2026-10-02  
> **Status:** Approved (Opsi A: 1:1 Foto 1 Full Fidelity)  
> **Target Feature:** F-07 from `09_FEATURE_BY_FEATURE_TRACKER.md`

---

## 🎯 1. Objective & Scope

Build the native SwiftUI interactive chat card component `[Computer • Working / Done]` that embeds directly inside the assistant message bubble flow of `HomeSpaceRootView.swift`, matching the exact visual layout and styling of Foto 1 (`docs/grok-bot-companion-adoption/assets/grok_bot_computer_card_reference.png`).

---

## 🛠️ 2. Architectural Decomposition & File Structure

| Step | Target File | Responsibility |
| :---: | :--- | :--- |
| **Backend** | `boringNotch/Clicky/ClickyEnums.swift` | Data models: `ComputerCardStatus`, `ComputerCardQueueItem`, `ComputerCardPayload`, and optional integration into `HomeSpaceChatMessage`. |
| **Frontend** | `boringNotch/Clicky/HomeSpace/HomeSpaceComputerCardView.swift` | SwiftUI component: Header with "Computer", status pill (`Working`/`Done`/`Takeover Needed`), instruction text, and visual canvas with scenic nature background & floating macOS dark mode windows. |
| **Scaffolding** | `boringNotch.xcodeproj/project.pbxproj` | Project registration: Add `HomeSpaceComputerCardView.swift` to `boringNotch` build phase. |
| **Integration** | `boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift` | Chat stream rendering: Display `HomeSpaceComputerCardView` inside assistant message bubble when `message.computerPayload != nil`. |
| **Verification** | `scripts/test_revisions_f07_computercard.swift` | TDD test suite validating payload models, serialization, component structure, and PBX registration. |

---

## 📋 3. Step-by-Step Execution Plan

### Step 1: Write TDD Test Suite (Red State)
- Create `scripts/test_revisions_f07_computercard.swift`.
- Define test assertions for:
  1. `ComputerCardStatus` raw values (`Working`, `Done`, `Takeover Needed`, `Failed`).
  2. `ComputerCardPayload` initialization, Codable encoding/decoding, and default values.
  3. `HomeSpaceChatMessage` with `computerPayload`.
  4. `HomeSpaceComputerCardView.swift` file existence and AST token validation.
  5. `boringNotch.xcodeproj` registration check.
- Run test and observe failures for missing types/files.

### Step 2: Implement Data Models in `ClickyEnums.swift` (Backend)
- Add `ComputerCardStatus` (`case working = "Working"`, `case done = "Done"`, `case takeoverNeeded = "Takeover Needed"`, `case failed = "Failed"`).
- Add `ComputerCardQueueItem` (`name: String`, `statusBadge: String`, `isChecked: Bool`).
- Add `ComputerCardPayload` (title, status, instructionText, snapshotImagePath, targetWindowId, targetAppName, queueSummary, queueItems, updatedAt).
- Add `public var computerPayload: ComputerCardPayload? = nil` to `HomeSpaceChatMessage`.

### Step 3: Implement `HomeSpaceComputerCardView.swift` (Frontend)
- Implement `HomeSpaceComputerCardView` in `boringNotch/Clicky/HomeSpace/`:
  - Outer rounded container (`#18191B` / `#1E1F22` background, continuous corner radius 20, 0.8pt subtle border).
  - Header row: Display icon + "Computer" (19pt semibold) + Status Capsule Pill (`• Done` / animated pulsing `• Working` / `• Takeover Needed`).
  - Subtitle: `payload.instructionText` (15pt regular, white opacity 0.88).
  - Canvas frame: Rounded container (16pt corner radius) with:
    - Fallback: Scenic nature wallpaper (sunlit grassy meadow, turquoise river, mountain ridge) + floating macOS dark mode windows:
      * Back window: Accounts list with traffic lights and teal checkmarks.
      * Front window: "Outreach queue" with traffic lights, prospek rows (Priya Natarajan, Marcus Webb, Elena Sørensen, Daniel Alvarez) with `Draft` badges, and footer "52 accounts • 36 drafts queued • 0 sent".
    - Snapshot: If `payload.snapshotImagePath` is given and file exists, render actual `NSImage`.
  - Takeover CTA: If `status == .takeoverNeeded`, display high-contrast amber button.

### Step 4: Register in Xcode Project
- Register `HomeSpaceComputerCardView.swift` in `boringNotch.xcodeproj/project.pbxproj` with unique build ID and file ID.

### Step 5: Integrate into `HomeSpaceRootView.swift`
- In `displayedMessages` loop, check `if let payload = message.computerPayload`:
  - Render `HomeSpaceComputerCardView(payload: payload)` within the message layout.

### Step 6: Verify Tests (Green State) & Build
- Run `swift scripts/test_revisions_f07_computercard.swift` -> confirm 100% PASS.
- Run `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build` -> confirm `** BUILD SUCCEEDED **`.
- Relaunch app via `./scripts/launch_app.sh`, verify running PID.
- Document in `CHANGELOG.md`, `AGENTS.md`, and `09_FEATURE_BY_FEATURE_TRACKER.md`.
