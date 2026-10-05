import SwiftUI

// MARK: - AgentCloudFaceMood
// Binary-confirmed: AgentCloudFaceMood
public enum AgentCloudFaceMood: String, CaseIterable, Codable {
    case neutral
    case happy
    case sleepy
    case thinking
    case surprised
    case focused

    public var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .focused: return "Focused"
        case .thinking: return "Thinking"
        case .surprised: return "Surprised"
        case .neutral: return "Neutral"
        case .sleepy: return "Sleepy"
        }
    }
}

// MARK: - CloudFaceExpression
// Binary-confirmed: CloudFaceExpression
enum CloudFaceExpression: String, CaseIterable {
    case idle
    case blink
    case listening
    case talking
    case thinking
}

// MARK: - AgentCloudEyePose
// Binary-confirmed: AgentCloudEyePose
struct AgentCloudEyePose: Equatable {
    var leftEyeScale: CGFloat = 1.0
    var rightEyeScale: CGFloat = 1.0
    var gazeOffset: CGSize = .zero
}

// MARK: - CloudFaceEyeAnimationOverride
// Binary-confirmed: CloudFaceEyeAnimationOverride
struct CloudFaceEyeAnimationOverride {
    var isWinking: Bool = false
    var isSleeping: Bool = false
}

// MARK: - AgentCloudFaceTraits
// Binary-confirmed: AgentCloudFaceTraits
struct AgentCloudFaceTraits {
    var mood: AgentCloudFaceMood = .neutral
    var eyePose: AgentCloudEyePose = AgentCloudEyePose()
    var isBlinking: Bool = false
}

// MARK: - AgentCloudEyeShape
// Binary-confirmed: AgentCloudEyeShape
struct AgentCloudEyeShape: Shape {
    var isOpen: Bool = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isOpen {
            path.addEllipse(in: rect)
        } else {
            // Closed eye curve
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        }
        return path
    }
}

// MARK: - AgentCloudHappyEyeShape (Signature ^ ^ Arched Eyes)
struct AgentCloudHappyEyeShape: Shape {
    var isOpen: Bool = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if !isOpen {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

// MARK: - AgentCloudCurvedHappyEyeShape (Smooth Smiling Arcs ⌒)
struct AgentCloudCurvedHappyEyeShape: Shape {
    var isOpen: Bool = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if !isOpen {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.15)
        )
        return path
    }
}

// MARK: - AgentCloudThinkingEyeShape (Asymmetrical Inquisitive Brow Shape)
struct AgentCloudThinkingEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX * 0.9, y: rect.minY - rect.height * 0.25)
        )
        return path
    }
}

// MARK: - ExpressionVectorIconView (Pure SVG / Vector Face Shapes for Buttons)
public struct ExpressionVectorIconView: View {
    public let mood: AgentCloudFaceMood
    public var isSelected: Bool = false
    public var color: Color? = nil

    private var strokeColor: Color {
        if let c = color { return c }
        return isSelected ? .white : .white.opacity(0.65)
    }

    public init(mood: AgentCloudFaceMood, isSelected: Bool = false, color: Color? = nil) {
        self.mood = mood
        self.isSelected = isSelected
        self.color = color
    }

    public var body: some View {
        ZStack {
            switch mood {
            case .happy, .neutral:
                // Arched smiling eye curves ⌒ ⌒
                HStack(spacing: 3.5) {
                    AgentCloudCurvedHappyEyeShape(isOpen: true)
                        .stroke(strokeColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 6.5, height: 4.5)
                    AgentCloudCurvedHappyEyeShape(isOpen: true)
                        .stroke(strokeColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 6.5, height: 4.5)
                }

            case .focused:
                // Focused alert solid circular pupils ● ●
                HStack(spacing: 4.5) {
                    Circle()
                        .fill(strokeColor)
                        .frame(width: 4.2, height: 4.2)
                    Circle()
                        .fill(strokeColor)
                        .frame(width: 4.2, height: 4.2)
                }

            case .thinking:
                // Asymmetrical inquisitive face (curious dot + raised arched eyebrow)
                HStack(alignment: .center, spacing: 3.5) {
                    Circle()
                        .fill(strokeColor)
                        .frame(width: 3.8, height: 3.8)
                        .offset(y: 1)

                    AgentCloudThinkingEyeShape()
                        .stroke(strokeColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 6.5, height: 5.5)
                        .offset(y: -1)
                }

            case .surprised:
                // Surprised open eyes ○ ○ + open round mouth o below
                VStack(spacing: 1.5) {
                    HStack(spacing: 3.5) {
                        Circle()
                            .stroke(strokeColor, lineWidth: 1.25)
                            .frame(width: 4.2, height: 4.2)
                        Circle()
                            .stroke(strokeColor, lineWidth: 1.25)
                            .frame(width: 4.2, height: 4.2)
                    }
                    Ellipse()
                        .fill(strokeColor.opacity(0.85))
                        .frame(width: 2.8, height: 2.0)
                }

            case .sleepy:
                HStack(spacing: 3.5) {
                    Capsule()
                        .fill(strokeColor)
                        .frame(width: 5.5, height: 1.5)
                    Capsule()
                        .fill(strokeColor)
                        .frame(width: 5.5, height: 1.5)
                }
            }
        }
        .frame(width: 20, height: 14)
    }
}

// MARK: - AgentCloudSleepZShape
// Binary-confirmed: AgentCloudSleepZShape
struct AgentCloudSleepZShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

// MARK: - AgentCloudSilhouette
// Binary-confirmed: AgentCloudSilhouette
struct AgentCloudSilhouette {
    static func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Cloud silhouette constructed from smooth interconnected circular arcs
        let r = h * 0.28
        path.addRoundedContainer(in: rect, cornerRadius: r)
        return path
    }
}

private extension Path {
    mutating func addRoundedContainer(in rect: CGRect, cornerRadius: CGFloat) {
        let w = rect.width
        let h = rect.height
        
        // Bottom line
        move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY))
        addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
               radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        
        // Right puff
        addArc(center: CGPoint(x: rect.maxX - cornerRadius * 0.8, y: rect.midY),
               radius: cornerRadius * 0.9, startAngle: .degrees(0), endAngle: .degrees(270), clockwise: true)
        
        // Top puffs
        addArc(center: CGPoint(x: rect.minX + w * 0.65, y: rect.minY + cornerRadius * 1.1),
               radius: cornerRadius * 1.15, startAngle: .degrees(30), endAngle: .degrees(180), clockwise: true)
        addArc(center: CGPoint(x: rect.minX + w * 0.35, y: rect.minY + cornerRadius * 1.2),
               radius: cornerRadius * 1.05, startAngle: .degrees(0), endAngle: .degrees(200), clockwise: true)
        
        // Left puff
        addArc(center: CGPoint(x: rect.minX + cornerRadius * 0.8, y: rect.midY),
               radius: cornerRadius * 0.9, startAngle: .degrees(270), endAngle: .degrees(180), clockwise: true)
        addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
               radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        closeSubpath()
    }
}

// MARK: - AgentCloudShape
// Binary-confirmed: AgentCloudShape
struct AgentCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        AgentCloudSilhouette.path(in: rect)
    }
}
