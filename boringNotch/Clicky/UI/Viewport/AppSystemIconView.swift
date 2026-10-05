//
//  AppSystemIconView.swift
//  boringNotch
//
//  Renders authentic macOS Retina application icons extracted directly from the system
//  Replaces flat custom SF Symbols with 100% genuine Apple Mail & Safari 3D icons.
//

import SwiftUI
import AppKit

public struct AppSystemIconView: View {
    public let appName: String
    public let size: CGFloat
    
    public init(appName: String, size: CGFloat = 32) {
        self.appName = appName
        self.size = size
    }
    
    private var systemAppIcon: NSImage? {
        let clean = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let appURL = InstalledAppsDiscoveryService.shared.findAppURL(appName: clean) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: size * 2.0, height: size * 2.0)
            return icon
        }
        return nil
    }
    
    public var body: some View {
        Group {
            if let icon = systemAppIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.30), radius: 3, x: 0, y: 1.5)
            } else {
                // Universal fallback application glyph
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(Color(hex: "#38BDF8"))
                    .frame(width: size, height: size)
            }
        }
    }
}
