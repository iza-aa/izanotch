# Notch Geometry Fix & High-End macOS Visual Polish Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix physical notch camera collision by dynamically calculating notch height insets, seamlessly integrate the window with the bezel using a custom Bézier curve shape (`NotchEarShape`), and elevate UI styling to native macOS Apple-grade glassmorphism (eliminating generic/slop styling).

**Architecture:** 
- `NotchGeometryCalculator`: Provides exact `physicalNotchHeight` and state frame dimensions that account for hardware cutouts.
- `NotchEarShape`: Custom SwiftUI `Shape` rendering concave "ears" on notched displays and continuous superellipses on external displays.
- `NotchRootView` & Subcomponents: Redesigned with `.ultraThinMaterial`, specular rim highlights, SF Pro typography, refined pill search bar, and Apple widget-style cards with SF Symbols.

**Tech Stack:** Swift 6, SwiftUI, AppKit, CoreGraphics.

---

### Task 1: Hardware Notch Height & Inset Geometry (TDD)

**Files:**
- Modify: `Sources/NotchDeck/UI/Window/NotchGeometryCalculator.swift`
- Modify: `Tests/NotchDeckTests/NotchGeometryCalculatorTests.swift`

- [ ] **Step 1: Write failing unit tests for notch height and content insets**

```swift
// Tests/NotchDeckTests/NotchGeometryCalculatorTests.swift
@Test("Calculate physical notch height and top content inset")
func testNotchHeightAndInset() {
    let mockScreenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
    let notchHeight = NotchGeometryCalculator.defaultNotchHeight
    #expect(notchHeight >= 32.0 && notchHeight <= 40.0)

    let expandedFrame = NotchGeometryCalculator.calculateFrame(
        for: .expanded,
        screenFrame: mockScreenFrame,
        hasPhysicalNotch: true
    )
    
    // Height should accommodate the notch + expanded content height
    #expect(expandedFrame.height > 240)
    #expect(expandedFrame.maxY == mockScreenFrame.maxY)
}
```

- [ ] **Step 2: Implement NotchGeometryCalculator updates**

Update `NotchGeometryCalculator.swift` with `defaultNotchHeight = 36.0`, `contentTopInset(hasPhysicalNotch: Bool) -> CGFloat`, and height adjustments for `.expanded` mode (`240 + notchHeight`).

- [ ] **Step 3: Run `swift test` and commit**

```bash
git add Sources/NotchDeck/UI/Window/NotchGeometryCalculator.swift Tests/NotchDeckTests/NotchGeometryCalculatorTests.swift
git commit -m "fix(geometry): calculate dynamic notch height and content top insets"
```

---

### Task 2: Custom Bézier Notch Ear Shape (TDD)

**Files:**
- Create: `Sources/NotchDeck/UI/Views/NotchShape.swift`
- Create: `Tests/NotchDeckTests/NotchShapeTests.swift`

- [ ] **Step 1: Write unit tests for NotchShape creation**

```swift
// Tests/NotchDeckTests/NotchShapeTests.swift
import Testing
import SwiftUI
@testable import NotchDeck

@Suite("Notch Shape Tests")
struct NotchShapeTests {
    @Test("NotchEarShape path builds without empty bounds")
    func testShapePath() {
        let shape = NotchEarShape(hasPhysicalNotch: true, cornerRadius: 22, earRadius: 10)
        let rect = CGRect(x: 0, y: 0, width: 560, height: 280)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }
}
```

- [ ] **Step 2: Implement NotchEarShape with smooth cubic Bézier curves**

Build `NotchEarShape` connecting top corners with smooth ears when `hasPhysicalNotch` is true, or returning standard continuous rounded rect when false.

- [ ] **Step 3: Run `swift test` and commit**

```bash
git add Sources/NotchDeck/UI/Views/NotchShape.swift Tests/NotchDeckTests/NotchShapeTests.swift
git commit -m "feat(ui): implement NotchEarShape with concave Bézier ear curves"
```

---

### Task 3: Redesign NotchRootView & Premium Glassmorphism Command Bar

**Files:**
- Modify: `Sources/NotchDeck/UI/Views/NotchRootView.swift`

- [ ] **Step 1: Update NotchRootView layout & materials**
  - Apply `NotchEarShape` as background clipping and stroke border.
  - Apply `.ultraThinMaterial` with specular top rim light (`LinearGradient` highlight).
  - Add `padding(.top, topInset)` so header bar is positioned cleanly below the camera cutout.
  - Elevate search bar to frosted pill with SF Symbols (`sparkle`, `magnifyingglass`, `mic.fill`).

- [ ] **Step 2: Run `swift test` and verify**

---

### Task 4: Polish Category Filter Bar & Native macOS Widget Cards

**Files:**
- Modify: `Sources/NotchDeck/UI/Views/CategoryFilterBarView.swift`
- Modify: `Sources/NotchDeck/UI/Views/CardCarouselView.swift`

- [ ] **Step 1: Enhance CategoryFilterBarView & CardCarouselView**
  - Add SF Symbols icons to category pills (`square.on.square` for Clipboard, `sparkles` for Prompts, `calendar.badge.clock` for Schedule, `arrow.down.doc` for Dropzone).
  - Redesign cards as frosted glass macOS widgets with subtle 1px border, SF Symbol badges, clean hierarchy, and hover glow.

- [ ] **Step 2: Run full build and test suite**

---

### Task 5: Relaunch Application & Visual Verification

- [ ] **Step 1: Terminate previous background task and run `swift run NotchDeck`**
- [ ] **Step 2: Verify live on user screen**
