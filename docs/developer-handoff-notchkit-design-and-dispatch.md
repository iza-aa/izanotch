# NotchDeck — Developer Handoff

Status: **BLOCKED until visual and delivery acceptance criteria are met**

This document is the implementation handoff for the current NotchDeck redesign. The attached NotchKit material is a technical reference for notch geometry and window behavior. The attached SwiftUI Design Philosophy is the visual reference for spacing, typography, color, cards, inputs, and shadows. The product owner's visual references and decisions take priority over both documents.

Full developer references:

- [NotchKit skill reference](/Users/heizaaa/Desktop/cdev/iza-3/docs/references/notchkit-skill.md)
- [SwiftUI Design Philosophy reference](/Users/heizaaa/Desktop/cdev/iza-3/docs/references/swiftui-design-philosophy.md)

## Non-negotiable product rules

1. Do not create mock, sample, seeded, or hardcoded success data.
2. If a provider or data source is unavailable, show an explicit empty/error state.
3. Never report a message as delivered merely because it was written to a local file or pipe.
4. The notch must align to the physical notch; no artificial ears, side shadow, or panel bleed may be visible.
5. Every expanded feature panel must have visible, consistent left and right content insets.

## P0 — Physical notch geometry and side shadow

The current visual evidence shows the NotchDeck panel extending beyond the real hardware notch and producing an unclear shadow on both sides.

Relevant implementation:

- [NotchGeometryCalculator.swift](/Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Window/NotchGeometryCalculator.swift)
- [NotchShape.swift](/Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Views/NotchShape.swift)
- [NotchRootView.swift](/Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Views/NotchRootView.swift)

Required behavior:

- Detect the actual notch bounds using `NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea`, with a documented fallback for non-notch displays.
- Do not use a fixed notch width/height as the source of truth for physical hardware alignment.
- Keep the collapsed content split into left wing, camera gap, and right wing. Nothing may render inside the camera gap.
- The collapsed background must merge with the hardware notch and must not create visible side ears outside the hardware boundary.
- Expanded content may grow below the notch, but its top anchor must remain aligned to the actual notch boundary.
- The current shadow is visually too strong: `.shadow(opacity: 0.45, radius: 14, y: 7)`. It must be removed or replaced with a subtle downward-only shadow following the design reference (`opacity 0.03–0.08`, no lateral offset). Do not use a large shadow to hide geometry errors.
- Add visual QA evidence for: physical MacBook collapsed, physical MacBook expanded, external display collapsed, and external display expanded.

## P0 — AI dispatch must be real, not optimistic

The UI currently displays messages such as `Prompt 'hi' dispatched to active Antigravity session`, but the agent does not receive the message. The current implementation treats a successful local write as delivery:

- [MultiAIClient.swift](/Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/AIBridge/MultiAIClient.swift)
- [ActiveSessionBridge.swift](/Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/AIBridge/ActiveSessionBridge.swift)
- [NotchDeckApp.swift](/Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/NotchDeckApp.swift)

Required behavior:

- Identify and document the real input protocol of the active Antigravity session.
- Do not treat appending a `USER_INPUT` line to `transcript.jsonl` as proof that the agent consumed the input. A transcript is an output/history stream unless the agent protocol explicitly documents it as an input channel.
- Do not report `Sent` or `dispatched` until the active session acknowledges or demonstrably processes the message.
- If no active session, target session, writable transport, or acknowledgement exists, show a clear error such as `AI session unavailable`, `Delivery unconfirmed`, or the precise transport failure.
- Preserve the original user text and show delivery state separately from the chat bubble: `Sending`, `Delivered`, `Failed`, or `Unconfirmed`.
- Add an integration/protocol test that sends a unique token through the Notch UI and verifies that the real agent process receives it and produces a response. A test that only verifies a file was appended is insufficient.
- Remove error swallowing on this path. Do not use `try?` where it can turn failed delivery into an apparent success.

## No mock data policy

Remove hardcoded/demo content from production initialization, including:

- Seeded card examples in [CardDataStore.swift](/Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/Cards/CardDataStore.swift).
- Seeded `Ready to assist` chat content in [NotchStateController.swift](/Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/UI/State/NotchStateController.swift).
- Hardcoded track and lyrics in [MusicService.swift](/Users/heizaaa/Desktop/cdev/iza-3/Sources/NotchDeck/Music/MusicService.swift).

Use explicit states instead:

- `No AI notifications available`
- `No active AI session`
- `Spotify is not connected`
- `Lyrics unavailable for this track`
- `No notes yet`
- `No upcoming schedule`

Demo fixtures may exist only inside tests or a clearly isolated preview target. They must never appear in the running app.

## Visual design requirements

Use the supplied SwiftUI design reference as the token source:

- Page/content horizontal inset: 24pt where the panel allows it.
- Card inset: 16pt.
- Input horizontal inset: 16pt; vertical inset: 12pt; 16pt continuous corner radius.
- Spacing rhythm: 4, 8, 12, 16, 20–24, 32pt.
- Explicit SF Rounded typography; do not rely on implicit `.body` or `.title` styles.
- Shadows must be subtle: opacity 0.03–0.08, with no unexplained side bleed.
- Every expanded panel—AI Chat, Notes, Schedule, Music/Lyrics, and Clipboard—must have the same visible left/right safe inset.
- The AI panel must keep its dedicated bottom `Reply...` field; Notes and Schedule must keep separate input fields.

The black notch background remains necessary where it merges with the physical hardware. The light SwiftUI surface tokens apply to content components where appropriate; they do not justify adding a black rectangle beyond the actual notch.

## Acceptance checklist

The work is not ready for approval until all of these are demonstrated:

- [ ] No visible side shadow or artificial notch ears in collapsed mode.
- [ ] Expanded panel is anchored to the actual physical notch and does not escape its intended boundary.
- [ ] Left/right padding is visually obvious in every feature panel.
- [ ] No mock data appears in a fresh app launch.
- [ ] Provider failures and unavailable data show explicit UI errors.
- [ ] A real AI message sent from the Notch is acknowledged by the active session and produces a visible response.
- [ ] Delivery failure is shown as failure, never as success.
- [ ] Spotify data is real or clearly shown as unavailable; no hardcoded song/lyrics.
- [ ] Screenshots cover all five feature tabs plus hidden/collapsed/expanded states.
- [ ] Tests cover geometry bounds, shadow/visibility behavior, empty/error states, and the actual dispatch protocol.

Until this checklist is satisfied, the correct status is **Rejected / needs remediation**, not “implemented successfully”.
