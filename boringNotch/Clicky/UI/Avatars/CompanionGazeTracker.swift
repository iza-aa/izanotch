//
//  CompanionGazeTracker.swift
//  boringNotch (Izanotchy • Fitur F-03 Dynamic Gaze Tracking)
//
//  Real-time mouse gaze tracking engine for Strobi 3D procedural avatars.
//  Captures global/local cursor coordinates, calculates normalized distance
//  relative to the avatar screen position, and applies exponential smoothing
//  damping (spring-like physics) to drive natural head and eye glances.
//

import SwiftUI
import Combine

@MainActor
public final class CompanionGazeTracker: ObservableObject {
    public static let shared = CompanionGazeTracker()

    @Published public private(set) var gazeOffset: CGPoint = .zero
    @Published public var isTrackingEnabled: Bool = true

    private var currentTarget: CGPoint = .zero
    private var displayLinkTimer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var avatarScreenFrame: CGRect = .zero

    public init() {
        startTracking()
    }

    deinit {
        // Singleton lives for the app lifecycle
    }

    public func updateAvatarPosition(screenFrame: CGRect) {
        self.avatarScreenFrame = screenFrame
    }

    public func startTracking() {
        guard displayLinkTimer == nil else { return }

        // 1. Damping animation loop (~60fps)
        displayLinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isTrackingEnabled else { return }
                self.tickDamping()
            }
        }

        // 2. Global mouse monitor (when cursor is anywhere on screen)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMouseMoved(NSEvent.mouseLocation)
            }
        }

        // 3. Local monitor (when cursor is over our app windows)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleMouseMoved(NSEvent.mouseLocation)
            return event
        }
    }

    public func stopTracking() {
        displayLinkTimer?.invalidate()
        displayLinkTimer = nil
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
    }

    public func handleMouseMoved(_ mouseCocoa: CGPoint) {
        guard isTrackingEnabled else { return }

        let origin: CGPoint
        if avatarScreenFrame != .zero {
            origin = CGPoint(x: avatarScreenFrame.midX, y: avatarScreenFrame.midY)
        } else if let mainScreen = NSScreen.main {
            // Default ke tengah atas layar (area Notch) jika frame belum di-bind
            origin = CGPoint(x: mainScreen.frame.midX, y: mainScreen.frame.maxY - 20)
        } else {
            origin = CGPoint(x: 700, y: 800)
        }

        // Delta posisi kursor dari avatar (Cocoa: Y positif ke atas)
        let dx = mouseCocoa.x - origin.x
        let dy = -(mouseCocoa.y - origin.y) // Invert Y agar ke bawah bernilai positif di SwiftUI 3D math

        // Radius pengaruh tatapan (~380px horizontal, ~280px vertikal untuk lirik penuh)
        let spanX: CGFloat = 380.0
        let spanY: CGFloat = 280.0

        let targetX = max(-1.0, min(1.0, dx / spanX))
        let targetY = max(-1.0, min(1.0, dy / spanY))

        // Redaman halus kontinu (Smoothstep Hermite ~40px) untuk transisi dead-center yang mulus tanpa jitter
        let distance = hypot(dx, dy)
        let deadbandRadius: CGFloat = 40.0
        let factor: CGFloat
        if distance <= 0.001 {
            factor = 0.0
        } else if distance < deadbandRadius {
            let t = distance / deadbandRadius
            factor = t * t * (3.0 - 2.0 * t)
        } else {
            factor = 1.0
        }

        currentTarget = CGPoint(x: targetX * factor, y: targetY * factor)
    }

    /// Update manual dari hover view lokal (misal: Open Notch container)
    public func updateLocalGaze(normalizedX: CGFloat, normalizedY: CGFloat) {
        currentTarget = CGPoint(
            x: max(-1.0, min(1.0, normalizedX)),
            y: max(-1.0, min(1.0, normalizedY))
        )
    }

    private func tickDamping() {
        // Exponential smoothing (damping factor 0.18 = sangat lentur dan responsif)
        let alpha: CGFloat = 0.18
        let newX = gazeOffset.x + (currentTarget.x - gazeOffset.x) * alpha
        let newY = gazeOffset.y + (currentTarget.y - gazeOffset.y) * alpha

        // Cegah perulangan mikroskopis jika sudah konvergen
        if abs(newX - gazeOffset.x) > 0.001 || abs(newY - gazeOffset.y) > 0.001 {
            gazeOffset = CGPoint(x: newX, y: newY)
        }
    }
}
