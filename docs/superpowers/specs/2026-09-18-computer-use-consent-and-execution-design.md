# Computer Use Consent & Full Physical Execution Engine Specification

## 1. Overview & Vision
Izanotchy provides an intelligent macOS companion that not only suggests actions and points at screen elements, but can also physically interact with the operating system on the user's behalf. 

This specification defines the two-tier permission system (**Ask Mode** vs **Full Access Mode**), the authentic HeyClicky **"Wants to use your Mac" Consent Card** (matching user reference `media_1789717035502.png`), its dual presentation (**beside the MacBook Notch** and **inline in HomeSpace Chat Workspace**), and the **Full Physical Execution Engine** (Mouse move/click, Keyboard typing, System Hotkeys, App Launch/Focus).

---

## 2. Permission Levels: Ask vs Full Access

| Dimension | Ask Mode (Default & Safe) | Full Access Mode (Autonomous) |
| :--- | :--- | :--- |
| **User Setting** | `Defaults[.alwaysAllowComputerUse] == false` | `Defaults[.alwaysAllowComputerUse] == true` |
| **Prompt Invariant** | Agent MUST request permission via `<COMPUTER_USE_REQUEST>` before any physical input. | Agent is pre-approved: `COMPUTER USE IS PRE-APPROVED`. Input actions execute immediately. |
| **Observation Tools** | Screenshots, window state, and element detection work freely without asking. | Screenshots, window state, and element detection work freely without asking. |
| **Input Execution** | Blocked until user clicks **`Allow once`** or **`Always allow`**. | Executed immediately upon command without showing a consent card. |

---

## 3. Communication Protocol (LLM & SSE Stream)

### 3.1 Tag Format in Ask Mode
When the companion determines an input action is required in Ask Mode, it outputs:
```text
<COMPUTER_USE_REQUEST>
[ACTION:action_type:target:details]
Natural conversational explanation in the user's language (e.g. "Aku perlu mengambil alih layar sebentar untuk mencari chat \"iweng toxic\" di WhatsApp dan mengirim pesan \"halo\". Boleh aku lakukan sekarang?")
</COMPUTER_USE_REQUEST>
```
`CompanionManager` extracts this block:
- Cleans the public chat text.
- Instantiates a `ComputerUseRequest` model.
- Sets `CompanionManager.shared.pendingComputerUseRequest`.
- Automatically opens the **Notch Consent Dropdown** and embeds the card in the **Chat Workspace**.

### 3.2 Tag Format in Full Access Mode
When Full Access is enabled, the agent returns the action tag directly:
```text
[ACTION:action_type:target:details]
Followed by short natural spoken response.
```
`CompanionManager` immediately parses the tag and dispatches it to `ComputerUsePhysicalExecutor` without presenting any prompt or blocking the turn.

---

## 4. UI Specification: `ComputerUseConsentCardView`

Matching reference image `media_1789717035502.png`:
- **Dimensions & Styling**:
  - Width: `340pt`
  - Corner radius: `24pt`
  - Background: Solid dark `#141517` / `#161719`
  - Border: `Color.white.opacity(0.12)`, `1pt`
  - Shadow: Radial drop shadow `radius: 20, y: 10`
- **Header Component**:
  - Avatar: 46×46 circular cloud face matching the companion's theme & mood (`HomeSpaceCloudFaceView`).
  - Title: Companion name (e.g. `Shippy`), font: `17pt .bold` in pure white.
  - Subtitle: `● Needs a yes` (`●` in companion ring color, font `13pt`).
  - Close button: Top-right `✕` circle (`28×28pt`, background `Color.white.opacity(0.1)`).
- **Heading**:
  - `"Wants to use your Mac"`, font: `18pt .bold` in white.
- **Body Text**:
  - Explanatory request string, font: `13.5pt .regular`, line spacing `3pt`, color: `Color.white.opacity(0.85)`.
- **Three Action Buttons**:
  1. **`Allow once`**:
     - Background: Pure white (`Color.white`)
     - Foreground: Solid black (`Color.black`), font `14pt .bold`
     - Icon: `Image(systemName: "circle.circle")`
     - Action: Approves for this single turn, dispatches execution, dismisses card.
  2. **`Always allow`**:
     - Background: `#26272B`, border `Color.white.opacity(0.1)`
     - Foreground: Pure white (`Color.white`), font `14pt .medium`
     - Icon: `Image(systemName: "infinity")`
     - Action: Sets `Defaults[.alwaysAllowComputerUse] = true`, dispatches execution, dismisses card.
  3. **`Not now`**:
     - Background: `#26272B`, border `Color.white.opacity(0.1)`
     - Foreground: Pure white (`Color.white`), font `14pt .medium`
     - Icon: `Image(systemName: "xmark")`
     - Action: Cancels action, sends cancellation message to chat, dismisses card.
- **Footer Component**:
  - Left label: `"Always allow can be turned off in Settings → Agent"` (`11pt`, muted grey).
  - Right label: `"History ⌵"` (`12pt`, muted grey).

---

## 5. Dual Placement Architecture

1. **Beside the MacBook Notch (`NotchConsentWindowController`)**:
   - Anchored at the top edge of the primary screen.
   - X position: `screen.midX + notchWidth/2 + 14` (right ear of the notch).
   - Y position: `screen.visibleFrame.maxY - cardHeight - 8`.
   - Transition: Drops down vertically with an authentic Apple spring curve (`response: 0.32, dampingFraction: 0.76`).
2. **Inline in Chat Workspace (`HomeSpaceRootView`)**:
   - Rendered as an interactive card directly in the scrollable message list for that companion session.
   - Buttons in both windows synchronize via `@ObservedObject var companionManager = CompanionManager.shared`.

---

## 6. Full Physical Execution Engine (`ComputerUsePhysicalExecutor`)

Native macOS execution module using CoreGraphics `CGEvent` and `NSWorkspace`:
1. **Mouse Navigation & Clicking**:
   - `executeMoveAndClick(at: CGPoint, button: CGMouseButton, clickCount: Int)`:
     - Animate blue indicator cursor flying to target coordinates.
     - Post `CGEvent(mouseType: .mouseMoved)`.
     - Post `CGEvent(mouseType: .leftMouseDown)` and `.leftMouseUp` (or right-click / double-click with `clickState = 2`).
2. **Natural Keyboard Typing**:
   - `executeTypeText(_ text: String)`:
     - Iterates through UTF-16 characters.
     - Synthesizes `CGEvent(keyboardEventSource:)` with `keyboardSetUnicodeString`.
     - Micro-delay `15-25ms` per character to mimic natural human typing without overflowing host input queues.
3. **Key Combinations & System Shortcuts**:
   - `executeKeyCombination(keys: [CGKeyCode], flags: CGEventFlags)`:
     - Key combos: `Return` (0x24) to send, `⌘ + Space` for Spotlight, `⌘ + W`, `Tab`, `Escape`.
4. **Application Launching & Focusing**:
   - `executeLaunchOrFocusApp(named: String)`:
     - Finds bundle ID or app path and activates frontmost window before sending clicks.

---

## 7. Safety Invariants & Fallbacks
- Input actions strictly require Accessibility Permissions (`AXIsProcessTrusted`).
- If Accessibility is not trusted, `ComputerUsePhysicalExecutor` logs a warning and opens System Settings prompt.
- Escape hatch: Pressing `Escape` or moving mouse vigorously can abort ongoing synthetic execution.
- All actions log structured diagnostics via `ClickyLogger.info("[COMPUTER_USE]", ...)`.
