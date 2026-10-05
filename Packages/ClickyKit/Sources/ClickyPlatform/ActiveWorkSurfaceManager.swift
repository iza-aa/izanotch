//
//  ActiveWorkSurfaceManager.swift
//  boringNotch (Izanotchy)
//
//  Active work surface tracking and frontmost window detection.
//

import ClickyFoundation
import AppKit
import ApplicationServices
import Foundation

public struct ActiveWorkSurface {
    public let appName: String
    public let windowTitle: String
    public let frame: CGRect
    public let ownerPID: pid_t?

    public init(appName: String, windowTitle: String, frame: CGRect, ownerPID: pid_t?) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.frame = frame
        self.ownerPID = ownerPID
    }

    /// The center coordinates of the macOS traffic light close button (red circle)
    public var trafficLightCloseCenter: CGPoint {
        // macOS standard traffic light close button is inset ~18pt from left and ~17pt from top of window frame
        CGPoint(x: frame.origin.x + 18, y: frame.origin.y + 17)
    }

    /// The center coordinates of the macOS traffic light minimize button (yellow circle)
    public var trafficLightMinimizeCenter: CGPoint {
        CGPoint(x: frame.origin.x + 38, y: frame.origin.y + 17)
    }

    /// The center coordinates of the macOS traffic light zoom/fullscreen button (green circle)
    public var trafficLightZoomCenter: CGPoint {
        CGPoint(x: frame.origin.x + 58, y: frame.origin.y + 17)
    }

    /// The center coordinates of the window's title bar header
    public var titleBarCenter: CGPoint {
        CGPoint(x: frame.midX, y: frame.origin.y + 17)
    }

    /// The center of the window
    public var windowCenter: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}

/// Represents a resolved UI location of a macOS Dock item

public enum ActiveWorkSurfaceManager {
    /// Discovers the active application window on screen (excluding boringNotch itself, cua-driver, and system overlays)
    public static func getActiveWorkSurface(targetAppName: String? = nil, queryHint: String? = nil) -> ActiveWorkSurface? {
        let ignoredOwners: Set<String> = [
            "Window Server", "Dock", "boringNotch", "cua-driver", "Siri",
            "Notification Center", "Control Center", "SystemUIServer", "Spotlight", "TextInputMenuAgent"
        ]

        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        // Pass 0: Explicit app match from targetAppName or queryHint
        let hint = (queryHint ?? "").lowercased()
        var explicitAppName: String? = targetAppName
        if explicitAppName == nil && !hint.isEmpty {
            for app in runningApps {
                let name = app.localizedName ?? ""
                if !name.isEmpty && hint.contains(name.lowercased()) {
                    explicitAppName = name
                    break
                }
            }
        }

        if let target = explicitAppName {
            for w in windowList {
                let layer = w[kCGWindowLayer as String] as? Int ?? -1
                let owner = w[kCGWindowOwnerName as String] as? String ?? ""
                let ownerPID = w[kCGWindowOwnerPID as String] as? pid_t
                let title = w[kCGWindowName as String] as? String ?? ""
                guard layer == 0, !ignoredOwners.contains(where: { owner.localizedCaseInsensitiveContains($0) }) else { continue }

                if owner.localizedCaseInsensitiveContains(target) {
                    if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
                       let x = boundsDict["X"] as? Double,
                       let y = boundsDict["Y"] as? Double,
                       let width = boundsDict["Width"] as? Double,
                       let height = boundsDict["Height"] as? Double {
                        let rect = CGRect(x: x, y: y, width: width, height: height)
                        if rect.width > 200 && rect.height > 100 {
                            return ActiveWorkSurface(
                                appName: owner,
                                windowTitle: title,
                                frame: rect,
                                ownerPID: ownerPID
                            )
                        }
                    }
                }
            }
        }

        // Pass 1: Frontmost application window (if not boringNotch or ignored)
        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontAppName = frontApp?.localizedName ?? ""
        let frontPID = frontApp?.processIdentifier
        if let frontPID = frontPID, !ignoredOwners.contains(where: { frontAppName.localizedCaseInsensitiveContains($0) }) {
            for w in windowList {
                let layer = w[kCGWindowLayer as String] as? Int ?? -1
                let ownerPID = w[kCGWindowOwnerPID as String] as? pid_t
                let owner = w[kCGWindowOwnerName as String] as? String ?? ""
                let title = w[kCGWindowName as String] as? String ?? ""
                guard layer == 0, ownerPID == frontPID else { continue }

                if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
                   let x = boundsDict["X"] as? Double,
                   let y = boundsDict["Y"] as? Double,
                   let width = boundsDict["Width"] as? Double,
                   let height = boundsDict["Height"] as? Double {
                    let rect = CGRect(x: x, y: y, width: width, height: height)
                    if rect.width > 200 && rect.height > 100 {
                        return ActiveWorkSurface(
                            appName: owner.isEmpty ? frontAppName : owner,
                            windowTitle: title,
                            frame: rect,
                            ownerPID: ownerPID
                        )
                    }
                }
            }
        }

        // Pass 2: Window directly under mouse cursor
        let mouseCocoa = NSEvent.mouseLocation
        let screenH = NSScreen.screens.first?.frame.height ?? 982
        let mouseCG = CGPoint(x: mouseCocoa.x, y: screenH - mouseCocoa.y)
        for w in windowList {
            let layer = w[kCGWindowLayer as String] as? Int ?? -1
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            let ownerPID = w[kCGWindowOwnerPID as String] as? pid_t
            let title = w[kCGWindowName as String] as? String ?? ""
            guard layer == 0, !ignoredOwners.contains(where: { owner.localizedCaseInsensitiveContains($0) }) else { continue }

            if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
               let x = boundsDict["X"] as? Double,
               let y = boundsDict["Y"] as? Double,
               let width = boundsDict["Width"] as? Double,
               let height = boundsDict["Height"] as? Double {
                let rect = CGRect(x: x, y: y, width: width, height: height)
                if rect.contains(mouseCG) && rect.width > 300 && rect.height > 200 && !owner.localizedCaseInsensitiveContains("iPhone Mirroring") {
                    return ActiveWorkSurface(
                        appName: owner,
                        windowTitle: title,
                        frame: rect,
                        ownerPID: ownerPID
                    )
                }
            }
        }

        // Pass 3: Topmost regular desktop window in z-order (deprioritizing iPhone Mirroring / accessory)
        var fallbackAccessory: ActiveWorkSurface? = nil
        for w in windowList {
            let layer = w[kCGWindowLayer as String] as? Int ?? -1
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            let ownerPID = w[kCGWindowOwnerPID as String] as? pid_t
            let title = w[kCGWindowName as String] as? String ?? ""
            guard layer == 0, !ignoredOwners.contains(where: { owner.localizedCaseInsensitiveContains($0) }) else { continue }

            if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
               let x = boundsDict["X"] as? Double,
               let y = boundsDict["Y"] as? Double,
               let width = boundsDict["Width"] as? Double,
               let height = boundsDict["Height"] as? Double {
                let rect = CGRect(x: x, y: y, width: width, height: height)
                if rect.width > 200 && rect.height > 100 {
                    let surface = ActiveWorkSurface(
                        appName: owner,
                        windowTitle: title,
                        frame: rect,
                        ownerPID: ownerPID
                    )
                    if owner.localizedCaseInsensitiveContains("iPhone Mirroring") {
                        if fallbackAccessory == nil {
                            fallbackAccessory = surface
                        }
                    } else {
                        return surface
                    }
                }
            }
        }

        return fallbackAccessory
    }
}

