# SwiftUI Design Philosophy

A design system rooted in minimalism, friendliness, and clarity. Apps built with this philosophy feel light, approachable, and polished through soft colors, rounded typography, generous spacing, and subtle depth.

## Core Principles

- **Minimal & Clean** — Remove visual noise. Every element earns its place.
- **Friendly & Approachable** — Rounded fonts, emoji accents, and warm illustrations make the app feel human.
- **Clear Hierarchy** — Size, weight, color, and spacing work together so users instantly see what matters.
- **Consistent Patterns** — Reuse the same tokens, components, and rhythms everywhere.
- **Delightful Details** — Subtle animations and celebratory moments reward engagement.

## Color System

| Role | Value | Usage |
|---|---|---|
| Background | `#F9F9F9` | App-wide background |
| Surface | `#FFFFFF` | Cards, sheets, modals |
| Input Fill | `#F5F5F5` | Text fields and search bars |
| Primary Text | `#2D2D2D` | Headlines and body text |
| Secondary Text | `#8E8E93` | Captions, timestamps, hints |

Suggested low-opacity category accents:

| Category | Color | Hex |
|---|---|---|
| Purple | Soft lavender | `#DCD6F7` |
| Green | Soft sage | `#E1EACD` |
| Blue | Soft sky | `#C6E7FF` |
| Orange | Soft peach | `#FFDDAE` |

Use category colors at 0.1–0.3 opacity for backgrounds, and full strength only for small accents such as dots or chips.

## Shadow and Depth

Shadows must be subtle and neutral:

```swift
// Standard card shadow
.shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)

// Elevated element
.shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)

// Optional inner depth
.overlay(
    RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(Color.black.opacity(0.03), lineWidth: 1)
)
```

Rules:

- Keep shadow opacity between 0.03 and 0.08
- Never use dark or colored shadows
- Avoid lateral shadow bleed around a notch that should merge with hardware
- Do not use shadow to conceal incorrect geometry

## Typography

Use SF Rounded explicitly:

```swift
.font(.system(size: 16, weight: .medium, design: .rounded))
```

Never rely on implicit `.body`, `.title`, or other system styles.

| Level | Size | Weight | Usage |
|---|---:|---|---|
| Display | 34pt | Bold | Hero numbers and greetings |
| Title 1 | 24–28pt | Semibold/Bold | Page titles and section headers |
| Title 2 | 18–22pt | Bold | Card titles and feature names |
| Body | 16–17pt | Medium | Primary content and labels |
| Caption | 13–14pt | Medium/Semibold | Secondary information |
| Micro | 10–12pt | Bold | Badges and tiny labels |

## Layout and Spacing

Spacing scale:

| Token | Value | Usage |
|---|---:|---|
| xs | 4pt | Tight icon-to-label gaps |
| sm | 8pt | Inline spacing |
| md | 12pt | Within components |
| lg | 16pt | Card padding and element gaps |
| xl | 20–24pt | Section gaps and page padding |
| 2xl | 32pt | Major section separation |

Reference page layout:

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 20) {
        // Content
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
    .padding(.bottom, 24)
}
```

Rules:

- Text is leading aligned
- Cards are full-width with internal leading alignment
- Primary buttons are centered and easy to target
- Every feature panel must have visible left and right content insets
- Do not rely on top/bottom padding alone

## Components

### Cards

```swift
VStack(alignment: .leading, spacing: 12) {
    // Card content
}
.padding(16)
.background(Color.white)
.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
.shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
```

Use continuous corner radii between 16pt and 24pt.

### Inputs

```swift
TextField("Placeholder", text: $value)
    .font(.system(size: 16, weight: .medium, design: .rounded))
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.inputFill)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
```

Inputs should use a fill rather than a visible border.

### Icon Buttons

Interactive targets should be at least 44pt where practical:

```swift
Image(systemName: "plus")
    .font(.system(size: 20, weight: .bold))
    .foregroundStyle(Color.primaryText)
    .frame(width: 44, height: 44)
    .background(Color.white)
    .clipShape(Circle())
    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
```

Disabled controls use a gray background with no interaction feedback.

### Sheets

Use a consistent sheet height and show the drag indicator:

```swift
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
}
```

Sheet content uses the same 24pt horizontal padding and a white background.

### Category Chips

```swift
Text(category.name)
    .font(.system(size: 13, weight: .semibold, design: .rounded))
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(isSelected ? categoryColor.opacity(0.25) : Color.gray.opacity(0.08))
    .clipShape(Capsule())
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
```

### Navigation

Use a custom tab bar for full design control:

- Height: 56pt
- White background with a top shadow
- Icons: 22pt semibold SF Symbols
- Active: primary text color
- Inactive: secondary text color
- Icons only, or small labels where clarity requires them

Navigation headers use an 18pt bold rounded title, a 44pt circular back button, and trailing action buttons with the same circular style.

## Icons and Personality

Use SF Symbols at semibold to bold weights, generally 14–22pt depending on context. Use primary text or secondary text colors consistently.

Emoji are visual accents, not decoration:

- Place them in circular containers
- Use category-colored backgrounds at low opacity
- Use approximately 22–30pt emoji inside 36–70pt circles

Custom illustrations may be used for empty states and celebrations. Hide decorative illustrations from accessibility with `.accessibilityHidden(true)`.

## Animation

Animations must be subtle and purposeful:

```swift
// State changes
withAnimation(.easeInOut(duration: 0.2)) {
    isExpanded.toggle()
}

// Interactive feedback
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
```

Guidelines:

- State toggle: 0.2s easeInOut
- Interactive selection: 0.3s spring
- Keep UI state animations under 0.4s
- Never animate without a clear purpose

## Visual Hierarchy Checklist

For each screen verify:

- One focal point is clearly the largest or boldest element
- Maximum three text sizes per card
- Spacing follows the defined scale
- Cards group related content
- Secondary information is smaller and lighter
- Whitespace is generous
- Interactive targets are at least 44pt

## Quick Reference

```text
Colors:     Background #F9F9F9 | Surface #FFFFFF | Input #F5F5F5
            Primary Text #2D2D2D | Secondary Text #8E8E93
Font:       Always .design(.rounded)
Spacing:    Page H-pad 24pt | Card pad 16pt | Section gap 20–32pt
Radius:     Cards 16–24pt | Inputs 16pt | Buttons 16pt | Chips Capsule
Shadows:    Cards 0.04/8/0/4 | Elevated 0.08/12/0/6
Animation:  State 0.2s easeInOut | Interactive 0.3s spring
```
