import SwiftUI

public struct NotchEarShape: Shape, Sendable {
    public var hasPhysicalNotch: Bool
    public var cornerRadius: CGFloat
    public var earRadius: CGFloat

    public init(
        hasPhysicalNotch: Bool = true,
        cornerRadius: CGFloat = 24.0,
        earRadius: CGFloat = 14.0
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

        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let cr = cornerRadius
        let er = earRadius

        path.move(to: CGPoint(x: minX, y: minY))

        path.addQuadCurve(
            to: CGPoint(x: minX + er, y: minY + er),
            control: CGPoint(x: minX + er, y: minY)
        )

        path.addLine(to: CGPoint(x: minX + er, y: maxY - cr))

        path.addArc(
            center: CGPoint(x: minX + er + cr, y: maxY - cr),
            radius: cr,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )

        path.addLine(to: CGPoint(x: maxX - er - cr, y: maxY))

        path.addArc(
            center: CGPoint(x: maxX - er - cr, y: maxY - cr),
            radius: cr,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )

        path.addLine(to: CGPoint(x: maxX - er, y: minY + er))

        path.addQuadCurve(
            to: CGPoint(x: maxX, y: minY),
            control: CGPoint(x: maxX - er, y: minY)
        )

        path.addLine(to: CGPoint(x: minX, y: minY))
        path.closeSubpath()

        return path
    }
}
