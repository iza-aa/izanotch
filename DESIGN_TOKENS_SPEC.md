# Design Tokens Specification — NotchDeck

**Purpose:** Single source of truth for all visual design decisions. Every panel, card, input, and notch UI element must reference these tokens. **No magic numbers in views.**

---

## 📐 Spacing Rhythm (4pt Base Unit)

| Token | Value | Use Case |
|-------|-------|----------|
| `xs` | 4pt | Micro gaps (icon-text, inline elements) |
| `sm` | 8pt | Tight related groups (button groups, chip rows) |
| `md` | 12pt | Standard related (card internal, list items) |
| `lg` | 16pt | Standard separation (card-to-card, section gaps) |
| `xl` | 20pt | Loose separation (panel-to-dock, major sections) |
| `xxl` | 24pt | **Page/content horizontal inset** — mandatory |
| `xxxl` | 32pt | Major section breaks (full-screen transitions) |

**Rule:** Only these values. No 5, 6, 7, 9, 11, 13, 15, 18, 22, 28, 30.

---

## 🔘 Corner Radius

| Token | Value | Use Case |
|-------|-------|----------|
| `xs` | 4pt | Tiny chips, badges |
| `sm` | 8pt | Small buttons, tags |
| `md` | 12pt | Legacy cards (migrate to `lg`) |
| `lg` | **16pt** | **Inputs, cards — continuous style** |
| `xl` | 20pt | Panels, large containers |
| `notchCollapsedTop` | 6pt | NotchShape collapsed top |
| `notchCollapsedBottom` | 14pt | NotchShape collapsed bottom |
| `notchExpandedTop` | 19pt | NotchShape expanded top |
| `notchExpandedBottom` | 24pt | NotchShape expanded bottom |

**Rule:** All inputs and cards use `lg` (16pt) with `.continuous` style. NotchShape radii per NotchKit spec.

---

## 🌫 Shadows (Subtle — Spec: Opacity 0.03–0.08, No Lateral Offset)

| Token | Color | Radius | X | Y | Use Case |
|-------|-------|--------|---|---|----------|
| `notchBackground` | `black.opacity(0.06)` | 8 | 0 | 4 | Collapsed/expanded notch background |
| `card` | `black.opacity(0.04)` | 6 | 0 | 2 | Cards, panels |
| `elevated` | `black.opacity(0.08)` | 12 | 0 | 6 | Modals, dropdowns, hover states |

**Forbidden:** Opacity > 0.08, x-offset ≠ 0, radius > 12 (except notch background max 8).

---

## 🔤 Typography (Explicit SF Rounded — No Implicit Styles)

| Token | Definition | Use Case |
|-------|------------|----------|
| `displayLarge` | `.system(size: 28, weight: .bold, design: .rounded)` | Hero, empty states |
| `displayMedium` | `.system(size: 22, weight: .semibold, design: .rounded)` | Panel titles |
| `headline` | `.system(size: 17, weight: .semibold, design: .rounded)` | Section headers |
| `subheadline` | `.system(size: 15, weight: .medium, design: .rounded)` | Sub-sections, card titles |
| `bodyLarge` | `.system(size: 15, weight: .regular, design: .rounded)` | Primary reading text |
| `body` | `.system(size: 13, weight: .regular, design: .rounded)` | Standard UI text |
| `bodySmall` | `.system(size: 12, weight: .regular, design: .rounded)` | Secondary content |
| `button` | `.system(size: 13, weight: .semibold, design: .rounded)` | Primary buttons |
| `buttonSmall` | `.system(size: 11, weight: .semibold, design: .rounded)` | Secondary buttons |
| `caption` | `.system(size: 11, weight: .medium, design: .rounded)` | Metadata, timestamps |
| `captionMono` | `.system(size: 11, weight: .semibold, design: .monospaced)` | Countdowns, codes |
| `overline` | `.system(size: 10, weight: .medium, design: .rounded)` | Labels, categories |
| `notchLabel` | `.system(size: 10, weight: .medium, design: .rounded)` | Collapsed left wing |
| `notchLabelBold` | `.system(size: 10, weight: .semibold, design: .rounded)` | Collapsed right wing |

**Forbidden:** `.body`, `.title`, `.caption`, `.headline` implicit styles. Always explicit.

---

## 📦 Layout Constants

| Token | Value | Rule |
|-------|-------|------|
| `pageHorizontalInset` | 24pt (`xxl`) | **Every expanded panel** — left & right |
| `pageVerticalInset` | 16pt (`lg`) | Panel top/bottom |
| `panelTopPadding` | 20pt (`xl`) | Below FeatureNavigationDock |
| `cardInset` | 16pt (`lg`) | **Every card** — all sides |
| `cardSpacing` | 12pt (`md`) | Between cards in lists |
| `inputHorizontalInset` | 16pt (`lg`) | **Every input field** — left & right |
| `inputVerticalInset` | 12pt (`md`) | **Every input field** — top & bottom |
| `inputCornerRadius` | 16pt (`lg`) | **Continuous** — all inputs |
| `collapsedHeight` | 32pt | Non-notch display fallback |
| `notchDefaultHeight` | 36pt | Physical notch fallback |
| `wingWidth` | 115pt | Per NotchKit spec — each side of collapsed |

---

## 🎨 Semantic Colors (Adapt to Light/Dark)

### Notch Background
| Token | Value |
|-------|-------|
| `notchBackground` | `black` |
| `notchBackgroundHover` | `black.opacity(0.95)` |

### Content Text
| Token | Value |
|-------|-------|
| `primaryText` | `white` |
| `secondaryText` | `white.opacity(0.7)` |
| `tertiaryText` | `white.opacity(0.5)` |
| `accentText` | `white.opacity(0.9)` |

### Status Indicators
| Token | Value |
|-------|-------|
| `statusActive` | `green.opacity(0.95)` |
| `statusWarning` | `orange.opacity(0.95)` |
| `statusError` | `red.opacity(0.95)` |
| `statusIdle` | `white.opacity(0.85)` |

### Inputs
| Token | Value |
|-------|-------|
| `inputBackground` | `white.opacity(0.08)` |
| `inputBackgroundHover` | `white.opacity(0.12)` |
| `inputBorder` | `white.opacity(0.1)` |
| `inputBorderFocus` | `blue.opacity(0.5)` |

### Cards
| Token | Value |
|-------|-------|
| `cardBackground` | `white.opacity(0.04)` |
| `cardBorder` | `white.opacity(0.06)` |
| `cardHoverBackground` | `white.opacity(0.08)` |

### Dividers
| Token | Value |
|-------|-------|
| `divider` | `white.opacity(0.08)` |

---

## ⏱ Animation

| Token | Definition | Use Case |
|-------|------------|----------|
| `springDefault` | `.spring(response: 0.35, dampingFraction: 0.8)` | State transitions (collapsed↔expanded) |
| `springSnappy` | `.spring(response: 0.3, dampingFraction: 0.75)` | Tab switches, panel swaps |
| `easeInOut` | `.easeInOut(duration: 0.2)` | Hover, focus, subtle transitions |
| `easeOut` | `.easeOut(duration: 0.15)` | Dismiss, fade out |

---

## ✅ Compliance Checklist (Every Panel/View)

- [ ] Uses `pageHorizontalInset` (24pt) left/right
- [ ] Cards use `cardInset` (16pt) + `cardStyle()` (16pt continuous radius)
- [ ] Inputs use `inputHorizontalInset` (16pt) + `inputVerticalInset` (12pt) + `inputStyle()` (16pt continuous)
- [ ] Spacing only from `Spacing` enum
- [ ] Radius only from `Radius` enum
- [ ] Shadows only from `Shadow` enum
- [ ] Fonts only from `Font` enum (explicit)
- [ ] Colors only from `Color` enum (semantic)
- [ ] Animations only from `Animation` enum

---

## 📁 Implementation Note for Developer Agent

Create `Sources/NotchDeck/UI/DesignTokens.swift` with the above as `public enum DesignTokens`. Add `View` extensions:

```swift
public extension View {
    func designShadow(_ token: DesignTokens.ShadowToken) -> some View
    func designFont(_ token: DesignTokens.FontToken) -> some View
    func pagePadding() -> some View      // 24pt horizontal, 16pt vertical
    func cardPadding() -> some View      // 16pt all sides
    func inputPadding() -> some View     // 16pt horizontal, 12pt vertical
    func inputStyle() -> some View       // background + border + radius
    func cardStyle() -> some View        // background + border + radius
}
```

Then **find-and-replace** every magic number in:
- `NotchRootView.swift`
- `FeatureNavigationDock.swift`
- `AIChatPanelView.swift`
- `NotesPanelView.swift`
- `SchedulePanelView.swift`
- `MusicLyricsPanelView.swift`
- `ClipboardPanelView.swift`
- `CategoryFilterBarView.swift`
- `AudioWaveformView.swift`
- `CardCarouselView.swift`
- `SettingsView.swift`