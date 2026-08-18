import SwiftUI

/// A SwiftUI Shape matching the MacBook notch with quad curves.
///
/// Per NotchKit specification:
/// - Collapsed radii: top = 6, bottom = 14
/// - Expanded radii:  top = 19, bottom = 24
///
/// `animatableData` allows smooth animated transitions between states.
public struct NotchShape: Shape, Sendable {
    /// Small inward curve at the top corners (matches hardware notch corner curvature).
    public var topCornerRadius: CGFloat
    /// Larger outward curve at the bottom corners (creates smooth tray expansion).
    public var bottomCornerRadius: CGFloat

    public init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 14) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    // Allows SwiftUI animation to interpolate between collapsed and expanded radii
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let tr = topCornerRadius     // top inward curve (small)
        let br = bottomCornerRadius  // bottom outward curve (large)

        // Start at top-left
        path.move(to: CGPoint(x: minX, y: minY))

        // Top-left inward curve (matching hardware notch corner)
        path.addQuadCurve(
            to: CGPoint(x: minX + tr, y: minY + tr),
            control: CGPoint(x: minX + tr, y: minY)
        )

        // Left side down to bottom-left curve start
        path.addLine(to: CGPoint(x: minX + tr, y: maxY - br))

        // Bottom-left outward curve
        path.addArc(
            center: CGPoint(x: minX + tr + br, y: maxY - br),
            radius: br,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: maxX - tr - br, y: maxY))

        // Bottom-right outward curve
        path.addArc(
            center: CGPoint(x: maxX - tr - br, y: maxY - br),
            radius: br,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )

        // Right side up to top-right curve start
        path.addLine(to: CGPoint(x: maxX - tr, y: minY + tr))

        // Top-right inward curve (matching hardware notch corner)
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: minY),
            control: CGPoint(x: maxX - tr, y: minY)
        )

        // Close back to top-left
        path.addLine(to: CGPoint(x: minX, y: minY))
        path.closeSubpath()

        return path
    }
}

// MARK: - Backward compatibility alias (used in existing tests)
@available(*, deprecated, renamed: "NotchShape")
public typealias NotchEarShape = _LegacyNotchEarShape

/// Internal legacy wrapper preserved so existing tests that reference NotchEarShape continue to compile.
/// Do not use in new code — use NotchShape instead.
public struct _LegacyNotchEarShape: Shape, Sendable {
    public var hasPhysicalNotch: Bool
    public var cornerRadius: CGFloat
    public var earRadius: CGFloat

    public init(hasPhysicalNotch: Bool = true, cornerRadius: CGFloat = 24.0, earRadius: CGFloat = 14.0) {
        self.hasPhysicalNotch = hasPhysicalNotch
        self.cornerRadius = cornerRadius
        self.earRadius = earRadius
    }

    public func path(in rect: CGRect) -> Path {
        // Delegate to NotchShape with legacy parameters mapped
        return NotchShape(topCornerRadius: earRadius, bottomCornerRadius: cornerRadius).path(in: rect)
    }
}
