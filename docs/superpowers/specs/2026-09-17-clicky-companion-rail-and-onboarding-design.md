# Specification: Clicky Companion Rail, Onboarding Interview Engine, & Dynamic Cursor Color Sync

- **Date**: 2026-09-17
- **Author**: Antigravity & User (Pair Programming)
- **Status**: Proposed / Approved by User
- **Reference Ground Truth**: HeyClicky v1.0.50 (`heyclicky-reference/docs/`, `HeyClicky.app` binary, user screenshots)

---

## 1. Vision & Purpose

Transform the Clicky companion experience in Izanotchy from a single monolithic Notch dropdown into a multi-agent desktop system with:
1. **3-Slot Right-Edge Floating Companion Rail**: A minimal, non-intrusive floating strip hugging the top-right screen edge displaying up to 3 active companion slots, with an overflow popover (`[...]`) for instant switching when 4+ companions exist.
2. **Onboarding Interview Engine**: A conversational agent creator that digs deeply into user requirements (minimum 2 iterative questions) before generating a dedicated `<companion>.md` persona spec and attaching relevant skill `.md` integrations.
3. **Dynamic Cursor Color Synchronization**: The cursor assistant (classic Farza flying triangle + aura wave) dynamically shifts its color palette to match the active companion's cloud identity (e.g. Green for Research Buddy, Purple for Shippy, Blue for classic Clicky).
4. **Companion Action Popover Cards**: Clicking an active companion on the rail slides open a floating status card with actionable buttons (`[ ↗ Show me ]`, `[ Stop ]`, `[ Open ]`).
5. **Notch Speaking HUD**: Real-time integration with BoringNotch showing `Speaking` and orange audio waveform bars `||||` when a companion speaks.

---

## 2. Architecture & Components

```
boringNotch/Clicky/
├── Rail/
│   ├── FloatingCompanionRailWindow.swift   # Borderless NSPanel anchored to top-right screen edge
│   ├── FloatingCompanionRailView.swift     # 3-slot vertical capsule with chevron [^], slots, and [...]
│   ├── CompanionPopoverCardView.swift      # Floating action card (Foto 2 & 3: [ ↗ Show me ], [ Stop ] [ Open ])
│   └── CompanionOverflowSwitcherView.swift # Quick swap dropdown for 4+ companions
├── Roster/
│   ├── CompanionProfile.swift              # Model: id, name, slug, cloudColorHex, ringColorHex, status, mdPath
│   ├── CompanionRosterStore.swift          # Persistence (Defaults/JSON), 3 active slots management
│   └── CompanionWorkspaceManager.swift     # Creates ~/.izanotchy/companions/<slug>/ and <slug>.md
├── Onboarding/
│   ├── CompanionInterviewEngine.swift      # 2-turn conversational questioner (Steve Jobs persona)
│   ├── SkillLibraryRegistry.swift          # Catalog of bundled skills (notion.md, github.md, etc.)
│   └── CompanionCreatorView.swift          # Interactive onboarding dialog
├── Overlay/
│   └── BlueCursorView.swift                # (Updated) Dynamic tint binding to active companion's cloudColor
└── Core/
    └── CompanionManager.swift              # (Updated) Multi-companion state coordinator
```

---

## 3. Component Details

### 3.1 3-Slot Right-Edge Companion Rail
- **Window Specs**:
  - `NSPanel` (.nonactivatingPanel, .borderless, level: `.floating` / `.statusBar`).
  - Anchored at `x: screen.visibleFrame.maxX - 68`, `y: screen.visibleFrame.maxY - 180`.
  - Dimensions: width `52 pt`, height auto-adjusting (`~160 pt`).
  - Background: dark frosted glass (`#141517` with 0.85 opacity, stroke `#FFFFFF15`, corner radius `26 pt`).
- **Slot System**:
  - Top: Collapse/Expand chevron `[^]` (`Image(systemName: "chevron.up")`).
  - Slot 1: Active companion circle (42×42 pt) with colored ring, cloud avatar, and status dot (`🟢 Done`, `🔵 Working`, `⚪️ Idle`).
  - Slot 2: Secondary companion circle.
  - Slot 3:
    - If total companions $\le 3$: Shows tertiary companion (or `(+)` if slot is empty).
    - If total companions $\ge 4$: Shows `[...]` capsule. Clicking opens `CompanionOverflowSwitcherView` showing remaining companions. Clicking any companion swaps them into Slot 3 or makes them active.

### 3.2 Companion Popover Card (Foto 2 & 3)
- Positioned immediately to the left of the clicked companion slot (`x: rail.minX - width - 12`).
- Width: `300 pt`.
- Contains:
  - Header: Avatar circle + Companion Name + Status pill (`🟢 Done` / `🔵 Working`) + Close `✕`.
  - Body: Latest response or working thought text.
  - Live progress: Typing dots indicator `...` during streaming.
  - Action buttons:
    - Done state: Glossy blue glass button `[ ↗ Show me ]`.
    - Working state: Dual buttons `[ Stop ]` and `[ Open ]`.
  - Footer: Expandable `History ⌄`.

### 3.3 Onboarding Interview Engine & `.md` Spec Generation
- Triggered when clicking `(+)` or selecting "New Companion".
- Adheres to HeyClicky's Golden Rules:
  1. **Two Questions Minimum, Always**: Never generate from a single brief.
  2. **Goal-Driven**: Asks what the user wants to achieve, inputs/outputs, and cadence.
  3. **Auto-generate Spec**:
     - Writes to `~/.izanotchy/companions/<slug>/<slug>.md`.
     - Selects relevant skills from `heyclicky-reference/docs/` (e.g. `notion.md`, `google-workspace.md`).
  4. **Distinct Appearance**: Generates unique cloud color hex (Green, Purple, Yellow, Coral, Cyan) and matching ring color.

### 3.4 Dynamic Cursor Color Synchronization
- In `CompanionManager`:
  - `currentCursorColor: Color` derived from `activeCompanion.cloudColorHex`.
- In `BlueCursorView`:
  - Classical triangle fill, outer glow, and trail smoothly animate to the companion's color.

---

## 4. Verification Plan
1. **Compilation**: Clean `xcodebuild` exit 0 on `boringNotch.xcodeproj`.
2. **Visual Verification**:
   - `screencapture` showing the 3-slot rail docked to the top-right of the screen.
   - Popover card appearing upon clicking a companion.
   - `[...]` overflow switcher test when $\ge 4$ companions exist.
   - Dynamic cursor color verification when switching between companions.
