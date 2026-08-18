# Notch Geometry & Shadow Fix Specification — P0-1

**Priority:** 🔴 P0 BLOCKER  
**Target Files:** `NotchRootView.swift`, `NotchGeometryCalculator.swift`, `NotchWindowController.swift`  
**Reference:** `docs/references/notchkit-skill.md`, `DESIGN_TOKENS_SPEC.md`

---

## 🎯 Problem Statement

Current collapsed notch background renders as a **single continuous `NotchShape` spanning full window width**, creating visible "side ears" extending beyond the physical camera housing. Shadow at `opacity 0.45, radius 14` masks this but violates spec (must be 0.03–0.08).

**Required:** Collapsed background = **three distinct parts** — Left Wing | Camera Gap (transparent) | Right Wing — each aligned to hardware `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`.

---

## 📐 Hardware Notch Metrics (Source of Truth)

```swift
// NotchGeometryCalculator.swift — already implemented, USE THESE
@MainActor
public static func notchWidth(for screen: NSScreen) -> CGFloat
@MainActor  
public static func notchHeight(for screen: NSScreen) -> CGFloat
@MainActor
public static func hasPhysicalNotch(screen: NSScreen) -> Bool

// Derived wing metrics (NotchKit spec)
let leftWingWidth  = screen.auxiliaryTopLeftArea?.width  ?? 0
let rightWingWidth = screen.auxiliaryTopRightArea?.width ?? 0
let cameraGapWidth = notchWidth  // physical camera housing
```

---

## 🛠 Fix: NotchRootView.swift — Collapsed Background

### Current (Wrong)
```swift
NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
    .fill(Color.black)
    .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 7)  // VIOLATION
```

### Required (Three-Part Background)
```swift
private var collapsedBackground: some View {
    GeometryReader { geo in
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let hasNotch = NotchGeometryCalculator.hasPhysicalNotch(screen: screen)
        
        if hasNotch {
            // Hardware-aligned three-part background
            let leftWing  = screen.auxiliaryTopLeftArea?.width  ?? 0
            let rightWing = screen.auxiliaryTopRightArea?.width ?? 0
            let notchW    = NotchGeometryCalculator.notchWidth(for: screen)
            
            HStack(spacing: 0) {
                // LEFT WING — ends exactly at camera housing
                NotchShape(topCornerRadius: DesignTokens.Radius.notchCollapsedTop,
                          bottomCornerRadius: DesignTokens.Radius.notchCollapsedBottom)
                    .fill(DesignTokens.Color.notchBackground)
                    .frame(width: leftWing)
                
                // CAMERA GAP — fully transparent, matches physical notch width
                Color.clear.frame(width: notchW)
                
                // RIGHT WING — starts exactly after camera housing
                NotchShape(topCornerRadius: DesignTokens.Radius.notchCollapsedTop,
                          bottomCornerRadius: DesignTokens.Radius.notchCollapsedBottom)
                    .fill(DesignTokens.Color.notchBackground)
                    .frame(width: rightWing)
            }
            .designShadow(DesignTokens.Shadow.notchBackground)  // 0.06 opacity, radius 8
        } else {
            // Non-notch display: centered pill, no camera gap
            NotchShape(topCornerRadius: DesignTokens.Radius.notchCollapsedTop,
                      bottomCornerRadius: DesignTokens.Radius.notchCollapsedBottom)
                .fill(DesignTokens.Color.notchBackground)
                .frame(width: 160)  // fallback
                .designShadow(DesignTokens.Shadow.notchBackground)
        }
    }
    .frame(height: collapsedHeight)
}
```

---

## 🛠 Fix: NotchRootView.swift — Collapsed Content (Already Correct, Verify)

```swift
// Content already split correctly — LEFT WING | CAMERA GAP | RIGHT WING
// Just ensure cameraGapWidth uses hardware notch width:
private var cameraGapWidth: CGFloat {
    hasPhysicalNotch ? hardwareNotchWidth : 8  // hardwareNotchWidth from NotchWindowController
}
```

**Verify:** `hardwareNotchWidth` passed to `NotchRootView` == `NotchGeometryCalculator.notchWidth(for: screen)`

---

## 🛠 Fix: NotchGeometryCalculator.swift — Expanded Anchor

### Current (Line 115-120)
```swift
case .expanded:
    let rawW = hasNotch ? max(620, notchW + 420) : 580
    let w = min(rawW, screenFrame.width - 48)
    let h: CGFloat = 400 + notchH
    return NSRect(x: screenFrame.midX - (w / 2.0), 
                  y: screenFrame.maxY - h,  // <-- MUST BE: screenFrame.maxY - notchH - 400
                  width: w, height: h)
```

### Required
```swift
case .expanded:
    let rawW = hasNotch ? max(620, notchW + 420) : 580
    let w = min(rawW, screenFrame.width - 48)
    let contentHeight: CGFloat = 400
    let h = contentHeight + notchH
    // Top anchor = screen.maxY - notchHeight (bottom of physical notch)
    let y = screenFrame.maxY - notchH - contentHeight
    return NSRect(x: screenFrame.midX - (w / 2.0), y: y, width: w, height: h)
```

**Rule:** Expanded panel top edge **always** at `screen.maxY - notchHeight`. Content grows downward.

---

## 🛠 Fix: NotchWindowController.swift — Verify Frame Sync

```swift
// updateFrame already calls NotchGeometryCalculator.calculateFrame(for:screen:)
// Just ensure NotchRootView doesn't add extra offset
// In NotchRootView.body: .frame(maxWidth: .infinity, maxHeight: .infinity) — CORRECT
// No additional .offset() or .padding() on root ZStack
```

---

## 🎨 Shadow Spec (DesignTokens.Shadow.notchBackground)

| Property | Value |
|----------|-------|
| Color | `Color.black.opacity(0.06)` |
| Radius | 8 |
| X | 0 |
| Y | 4 |

**Apply to:** Both collapsed (three-part) and expanded (single NotchShape) backgrounds.

---

## ✅ Validation Checklist (Definition of Done)

| Test | Device | Expected |
|------|--------|----------|
| Collapsed — no side ears | MacBook Pro (notch) | Background ends exactly at auxiliary areas |
| Collapsed — camera gap clear | MacBook Pro (notch) | Zero pixels rendered in camera housing |
| Collapsed — shadow subtle | MacBook Pro (notch) | Barely visible downward glow, no lateral bleed |
| Expanded — top anchor | MacBook Pro (notch) | Panel top = bottom of physical notch |
| Collapsed — centered pill | External display (no notch) | 160pt centered, no camera gap |
| Expanded — external | External display (no notch) | Standard panel, no notch offset |

**Visual Evidence Required:** Screenshots of all 6 states above.

---

## 🔧 Implementation Order

1. **NotchRootView.swift** — Replace collapsed background with three-part HStack
2. **NotchGeometryCalculator.swift** — Fix expanded `y` origin calculation
3. **NotchRootView.swift** — Apply `DesignTokens.Shadow.notchBackground` to both states
4. **Verify** `hardwareNotchWidth` passed from `NotchWindowController` matches calculator
5. **Test** on physical MacBook + external display
6. **Capture** visual evidence screenshots

---

## ⚠️ Common Mistakes to Avoid

| Mistake | Why It Fails |
|---------|--------------|
| Single `NotchShape` for collapsed | Creates side ears — background must split at camera |
| Using fixed 160pt notch width | Ignores actual hardware (varies by model) |
| Strong shadow to hide geometry | Spec forbids; exposes failure on external displays |
| Expanded `y = screen.maxY - h` | Drifts from notch bottom as content height changes |
| `hardwareNotchWidth` not synced | Camera gap width ≠ physical notch → text clips camera |

---

## 📝 Developer Notes

- `NotchGeometryCalculator` already has correct hardware detection — **trust it**
- `DesignTokens` provides spec-compliant shadow/radius — **use it**
- Three-part background is **only for collapsed**; expanded uses single `NotchShape` anchored to notch bottom
- No changes needed to `NotchPanel` or `NotchWindowController` frame logic if calculator is correct