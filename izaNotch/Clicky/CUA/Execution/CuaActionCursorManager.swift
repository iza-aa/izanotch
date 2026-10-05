//
//  CuaActionCursorManager.swift
//  izaNotch
//
//  Dedicated Coordinator for the Ephemeral CuaDrive Action Cursor (Phase 2 Canon)
//  Completely decoupled from CursorAssist Clicky:
//  - CursorAssist Clicky: Stays permanently beside the user hardware mouse (HUD, voice, companion)
//  - CuaDrive Action Cursor: Ephemeral worker cursor that only appears during active CUA actions,
//    flies using CuaMotionEngine physics (Dubins / Cubic Bezier at 60fps), clicks visually with ripple effect,
//    and smoothly fades out when the action finishes.
//

import AppKit
import Combine
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
public final class CuaActionCursorManager: ObservableObject {
    public static let shared = CuaActionCursorManager()

    @Published public var isActive: Bool = false
    @Published public var screenPosition: CGPoint = .zero
    @Published public var rotationDegrees: Double = -35.0
    @Published public var scale: CGFloat = 1.0
    @Published public var opacity: Double = 0.0
    @Published public var isClicking: Bool = false
    @Published public var badgeText: String? = nil

    private var flightTimer: Timer?
    private var runner: CuaMotionRunner?

    private init() {}

    /// Decommissioned: Action cursor is handled 100% natively by cua-driver daemon
    public func spawn(at screenPoint: CGPoint) {
        flightTimer?.invalidate()
        flightTimer = nil
        self.isActive = false
    }

    /// Decommissioned: Action cursor is handled 100% natively by cua-driver daemon
    public func fly(to destination: CGPoint, badge: String? = nil) async {
        flightTimer?.invalidate()
        flightTimer = nil
        self.isActive = false
    }

    /// Decommissioned: Click ripple is rendered 100% natively by cua-driver daemon
    public func triggerClick() async {
        // No-op: cua-driver daemon renders native click ripple ring automatically
    }

    /// Decommissioned: Action cursor lifecycle is handled 100% natively by cua-driver daemon
    public func dismiss() async {
        self.isActive = false
        self.flightTimer?.invalidate()
        self.flightTimer = nil
    }

    /// Converts CoreGraphics top-left screen coordinates to local SwiftUI OverlayWindow coordinates.
    public static func convertCGToSwiftUI(_ cgPoint: CGPoint, screenFrame: CGRect) -> CGPoint {
        let x = cgPoint.x - screenFrame.origin.x
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screenFrame.height
        let screenTopCG = primaryHeight - (screenFrame.origin.y + screenFrame.height)
        let y = cgPoint.y - screenTopCG
        return CGPoint(x: x, y: y)
    }
}

// MARK: - CuaDrive Action Cursor SwiftUI View (Decommissioned in favor of Native Cua-Driver Overlay)

public struct CuaActionCursorView: View {
    public init(screenFrame: CGRect) {}

    public var body: some View {
        EmptyView()
    }
}

public struct CuaActionCursorTriangle: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        Path()
    }
}

