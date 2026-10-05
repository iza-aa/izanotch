//
//  NotchUnifiedHuggingShape.swift
//  izaNotch (Izanotchy)
//
//  Physical Notch Hugging Shape (Seamless Concave ) ( Ears & Card Body)
//  Flairs the MacBook Notch outward into the HomeSpace card top edge with smooth fillets.
//

import SwiftUI

public struct NotchUnifiedHuggingShape: Shape {
    public var notchLeft: CGFloat
    public var notchRight: CGFloat
    public var notchHeight: CGFloat = 32
    public var earRadius: CGFloat = 18
    public var cornerRadius: CGFloat = 20

    public init(
        notchLeft: CGFloat,
        notchRight: CGFloat,
        notchHeight: CGFloat = 32,
        earRadius: CGFloat = 18,
        cornerRadius: CGFloat = 20
    ) {
        self.notchLeft = notchLeft
        self.notchRight = notchRight
        self.notchHeight = notchHeight
        self.earRadius = earRadius
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        // 1. Top-left corner of the card
        path.move(to: CGPoint(x: 0, y: notchHeight + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: notchHeight),
            control: CGPoint(x: 0, y: notchHeight)
        )

        // 2. Card top edge to left notch ear
        path.addLine(to: CGPoint(x: notchLeft - earRadius, y: notchHeight))

        // 3. Concave flair ')' flaring UP into the notch left wall
        path.addQuadCurve(
            to: CGPoint(x: notchLeft, y: notchHeight - earRadius),
            control: CGPoint(x: notchLeft, y: notchHeight)
        )

        // 4. Up the left wall of notch
        path.addLine(to: CGPoint(x: notchLeft, y: 0))

        // 5. Across top behind notch
        path.addLine(to: CGPoint(x: notchRight, y: 0))

        // 6. Down the right wall of notch
        path.addLine(to: CGPoint(x: notchRight, y: notchHeight - earRadius))

        // 7. Concave flair '(' flaring DOWN into the card top edge
        path.addQuadCurve(
            to: CGPoint(x: notchRight + earRadius, y: notchHeight),
            control: CGPoint(x: notchRight, y: notchHeight)
        )

        // 8. Card top edge to top-right corner
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: notchHeight))

        // 9. Top-right corner of the card
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: notchHeight + cornerRadius),
            control: CGPoint(x: rect.width, y: notchHeight)
        )

        // 10. Down the right edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - cornerRadius))

        // 11. Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width - cornerRadius, y: rect.height),
            control: CGPoint(x: rect.width, y: rect.height)
        )

        // 12. Across bottom edge
        path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))

        // 13. Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height - cornerRadius),
            control: CGPoint(x: 0, y: rect.height)
        )

        // 14. Close subpath up left edge to start
        path.closeSubpath()

        return path
    }
}
