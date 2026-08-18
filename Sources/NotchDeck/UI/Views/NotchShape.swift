import SwiftUI

public struct NotchEarShape: Shape, Sendable {
    public var hasPhysicalNotch: Bool
    public var cornerRadius: CGFloat
    public var earRadius: CGFloat

    public init(
        hasPhysicalNotch: Bool = true,
        cornerRadius: CGFloat = 24.0,
        earRadius: CGFloat = 12.0
    ) {
        self.hasPhysicalNotch = hasPhysicalNotch
        self.cornerRadius = cornerRadius
        self.earRadius = earRadius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        if !hasPhysicalNotch {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)
            return path
        }

        // Notch integrated shape with top outer concave ears
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let cr = cornerRadius
        let er = earRadius

        // Start at top-left ear
        path.move(to: CGPoint(x: minX, y: minY))

        // Concave curve from top-left into the left side
        path.addQuadCurve(
            to: CGPoint(x: minX + er, y: minY + er),
            control: CGPoint(x: minX + er, y: minY)
        )

        // Left side down to bottom-left corner
        path.addLine(to: CGPoint(x: minX + er, y: maxY - cr))

        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: minX + er + cr, y: maxY - cr),
            radius: cr,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: maxX - er - cr, y: maxY))

        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: maxX - er - cr, y: maxY - cr),
            radius: cr,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )

        // Right side up to top-right ear
        path.addLine(to: CGPoint(x: maxX - er, y: minY + er))

        // Concave curve from right side into top-right edge
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: minY),
            control: CGPoint(x: maxX - er, y: minY)
        )

        // Close top edge across bezel
        path.addLine(to: CGPoint(x: minX, y: minY))
        path.closeSubpath()

        return path
    }
}
