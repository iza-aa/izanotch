# NotchKit — Agent Skill for macOS Notch Apps

Build macOS apps that live in the MacBook notch. This skill gives you the foundation — notch detection, floating panel, hover expand/collapse, curved shape — so you focus on the app logic.

## When to Use

Activate this skill when the user wants to:

- Build a macOS notch app / notch widget
- Create a utility that lives in the MacBook notch
- Build something similar to BoringNotch, NotchNook, or Alcove
- Add a notch-hugging UI to an existing macOS app

## Architecture Overview

```text
NotchKit/
  NotchApp.swift           App entry point (@main, SwiftUI lifecycle)
  NotchAppDelegate.swift   Menu bar icon + app lifecycle + clean quit
  NotchPanel.swift         NSPanel (floating, non-activating, .mainMenu + 3)
  NotchShape.swift         SwiftUI Shape matching notch (animatable radii)
  NotchWindow.swift        Notch detection, expand/collapse, hover tracking
  NotchContentView.swift   THE FILE TO CUSTOMIZE (collapsed + expanded UI)
  Info.plist               LSUIElement = true (agent app, no dock icon)
```

## Key Concepts

### NotchPanel

A floating NSPanel that:

- Sits above all windows (`level: .mainMenu + 3`)
- Never steals focus (`canBecomeKey = false`)
- Is visible on all spaces and in fullscreen
- Has a transparent background; content defines the visible shape

### NotchShape

A SwiftUI Shape with quad curves matching the MacBook notch:

- Small top corner radius curves inward, matching the real notch
- Large bottom corner radius creates a smooth tray expansion
- `animatableData` should support smooth transitions between collapsed and expanded

Default radii:

- Collapsed: top = 6, bottom = 14
- Expanded: top = 19, bottom = 24

### NotchWindow

Detect the actual notch dimensions via `NSScreen.auxiliaryTopLeftArea` and `NSScreen.auxiliaryTopRightArea`. Fall back to `185x32` for non-notch Macs.

States:

- Collapsed: window = notch width + wing extension; content appears on both sides of the camera
- Expanded: window grows to a custom size and the full tray UI appears

Hover behavior:

- Hover enter triggers expansion with a 0.4s spring
- Mouse leave collapses after an 0.8s delay with a 0.35s animation

### NotchContentView

The main customization point has two sections:

- `collapsedContent` — left wing + camera gap + right wing
- `expandedContent` — full tray panel

## Collapsed View

The collapsed structure must always keep the camera gap clear:

```swift
var collapsedContent: some View {
    HStack(spacing: 0) {
        // LEFT WING (app name, icon, status)
        HStack(spacing: 4) {
            // Content here
        }
        .frame(maxWidth: .infinity, alignment: .center)

        // CAMERA GAP — never put content here
        Color.clear.frame(width: viewModel.notchWidth - 30)

        // RIGHT WING (counter, timer, status)
        HStack(spacing: 4) {
            // Content here
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .clipShape(NotchShape(topCornerRadius: 6, bottomCornerRadius: 14))
}
```

Rules:

- Background must be black so it merges with the hardware notch
- Keep collapsed content minimal; wings are approximately 90px each
- Use monospaced fonts at 8–10pt for readability
- Camera gap width uses the detected `viewModel.notchWidth - 30`
- Do not use fixed geometry as the source of truth when actual NSScreen notch areas are available

## Expanded View

Expanded content is a normal SwiftUI view and may contain the product UI:

```swift
var expandedContent: some View {
    VStack(spacing: 10) {
        // Main content
        // Action buttons
        // Toolbar / tabs
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

Reference starting dimensions:

```swift
var expandedWidth: CGFloat = 420
var expandedHeight: CGFloat = 240
var wingExtension: CGFloat = 180
```

The product owner’s approved measurements take precedence over these defaults.

## Recommended Build Workflow

### Phase 1: Understand the Product

Before implementation, confirm:

- What the app does
- What should remain visible in collapsed mode on each side of the notch
- What appears in expanded mode
- Whether the theme is dark, light, or toggleable

For NotchDeck, these decisions are already supplied by the product owner. Do not invent additional product behavior or mock content.

### Phase 2: Clone and Set Up

For a new NotchKit project:

```bash
git clone https://github.com/aishwaryaashok14/notch-kit.git <project-name>
cd <project-name>
```

Rename the package and app identifiers as needed:

- `Package.swift`
- `Info.plist` (`CFBundleName` and `CFBundleIdentifier`)
- `build-app.sh` (binary and app name)

For the existing NotchDeck project, do not replace the project with a clone. Apply the relevant architecture and geometry rules to the existing implementation.

## App Logic

Create separate Swift files for:

- Data models
- Timers and state management using `ObservableObject` and `@Published`
- Persistence using `UserDefaults` for settings and JSON files for structured data
- Notifications using `UNUserNotificationCenter`

Pass state from the app delegate through the notch window into the content view.

## Menu Bar Items

The menu bar item may expose settings and app actions:

```swift
func setupMenuBar() {
    button.image = NSImage(
        systemSymbolName: "your.icon",
        accessibilityDescription: "Your App"
    )

    let action = NSMenuItem(
        title: "Your Action",
        action: #selector(yourMethod),
        keyEquivalent: ""
    )
    action.target = self
    menu.addItem(action)
}
```

## Persistence and Sleep/Wake

- Use `UserDefaults` for settings.
- Use JSON under `~/Library/Application Support/<AppName>/` for structured data.
- Observe `NSWorkspace.willSleepNotification` and `NSWorkspace.didWakeNotification` for time-sensitive apps.

## Menu Bar and Lifecycle

The app may use a menu bar item for settings and actions. Always implement clean termination:

```swift
func applicationWillTerminate(_ notification: Notification) {
    notchWindow?.destroy()
    if let item = statusItem {
        NSStatusBar.system.removeStatusItem(item)
    }
}
```

The app must not leave ghost windows after termination.

## Build and Test

For a standalone NotchKit app:

```bash
chmod +x build-app.sh
bash build-app.sh
open dist/<AppName>.app
```

On a new Mac, Gatekeeper may require right-clicking the app and choosing Open once.

## Distribution

To create a DMG for a standalone app:

```bash
hdiutil create -volname <AppName> -srcfolder dist -ov -format UDZO <AppName>.dmg
```

## Platform Requirements

- macOS 13+
- Swift 5.9+
- Swift Package Manager; no Xcode project required
- Must work on MacBooks with and without a physical notch

## Example

WalkOS is an example walking reminder app built on the same foundation. It adds timers, quick-log buttons, streak tracking, work hours, pause, sleep/wake handling, weekly summaries, themes, and walk history.
