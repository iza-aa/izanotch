//
//  CompanionProceduralAvatarView.swift
//  izaNotch
//
//  Autentik 1:1 Engine Render Geometri 3D Strobi dari Bible Strong Avatar Lab
//  Mendukung Procedural Blinking Alami (Squash Height) & Transisi Ekspresi Halus (Fitur F-02)
//  (https://github.com/smontlouis/bible-strong-avatar-lab)
//

import SwiftUI
import AppKit
import ClickyFoundation

// MARK: - Matematika Proyeksi 3D Strobi (Direct Port dari avatar-core/geometry.ts)
public struct StrobiPoint3: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct StrobiQuaternion: Equatable, Sendable {
    public var w: Double
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ w: Double, _ x: Double, _ y: Double, _ z: Double) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct Strobi3DMath {
    public static let RADIUS: Double = 120.0
    public static let FOCAL_LENGTH: Double = 620.0
    public static let QUARTER_ARC_SAMPLES: Int = 10

    @inline(__always)
    public static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180.0
    }

    public static func quaternionFromAxisAngle(axis: StrobiPoint3, angle: Double) -> StrobiQuaternion {
        let half = angle / 2.0
        let s = sin(half)
        return StrobiQuaternion(cos(half), axis.x * s, axis.y * s, axis.z * s)
    }

    public static func multiplyQuaternions(_ a: StrobiQuaternion, _ b: StrobiQuaternion) -> StrobiQuaternion {
        StrobiQuaternion(
            a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
            a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w
        )
    }

    public static func quaternionFromEuler(x: Double, y: Double, z: Double) -> StrobiQuaternion {
        let xRot = quaternionFromAxisAngle(axis: StrobiPoint3(1, 0, 0), angle: x)
        let yRot = quaternionFromAxisAngle(axis: StrobiPoint3(0, 1, 0), angle: y)
        let zRot = quaternionFromAxisAngle(axis: StrobiPoint3(0, 0, 1), angle: z)
        return multiplyQuaternions(multiplyQuaternions(zRot, xRot), yRot)
    }

    public static func rotateWithQuaternion(_ q: StrobiQuaternion, _ p: StrobiPoint3) -> StrobiPoint3 {
        let tx = 2.0 * (q.y * p.z - q.z * p.y)
        let ty = 2.0 * (q.z * p.x - q.x * p.z)
        let tz = 2.0 * (q.x * p.y - q.y * p.x)
        return StrobiPoint3(
            p.x + q.w * tx + (q.y * tz - q.z * ty),
            p.y + q.w * ty + (q.z * tx - q.x * tz),
            p.z + q.w * tz + (q.x * ty - q.y * tx)
        )
    }

    public static func canonicalFaceCoordinates(x: Double, y: Double) -> (Double, Double) {
        let longitude = x / RADIUS
        let latitude = y / RADIUS
        return (RADIUS * cos(latitude) * sin(longitude), RADIUS * sin(latitude))
    }

    public static func ellipsoidFrontSample(
        x: Double, y: Double,
        radiusX: Double, radiusY: Double, radiusZ: Double
    ) -> (point: StrobiPoint3, normal: StrobiPoint3) {
        let rx = max(radiusX, 1.0)
        let ry = max(radiusY, 1.0)
        let rz = max(radiusZ, 1.0)
        let term = 1.0 - (x * x) / (rx * rx) - (y * y) / (ry * ry)
        let z = rz * sqrt(max(0.0, term))

        let nx = x / (rx * rx)
        let ny = y / (ry * ry)
        let nz = z / (rz * rz)
        let len = sqrt(nx * nx + ny * ny + nz * nz)
        let normal = (len > 0.0001) ? StrobiPoint3(nx / len, ny / len, nz / len) : StrobiPoint3(0, 0, 1)

        return (point: StrobiPoint3(x, y, z), normal: normal)
    }

    public static func roundedRectangle(width: Double, height: Double) -> [(Double, Double)] {
        let halfW = width / 2.0
        let halfH = height / 2.0
        let r = min(halfH, halfW)
        var points: [(Double, Double)] = []

        func addLine(start: (Double, Double), end: (Double, Double)) {
            let dx = end.0 - start.0
            let dy = end.1 - start.1
            let dist = sqrt(dx * dx + dy * dy)
            let samples = max(2, Int(ceil(dist / 2.5)))
            for i in 0..<samples {
                let prog = Double(i) / Double(samples)
                points.append((start.0 + dx * prog, start.1 + dy * prog))
            }
        }

        func addArc(centerX: Double, centerY: Double, startAngle: Double) {
            for i in 0..<QUARTER_ARC_SAMPLES {
                let angle = startAngle + (Double(i) / Double(QUARTER_ARC_SAMPLES)) * (.pi / 2.0)
                points.append((centerX + cos(angle) * r, centerY + sin(angle) * r))
            }
        }

        addLine(start: (-halfW + r, -halfH), end: (halfW - r, -halfH))
        addArc(centerX: halfW - r, centerY: -halfH + r, startAngle: -.pi / 2.0)
        addLine(start: (halfW, -halfH + r), end: (halfW, halfH - r))
        addArc(centerX: halfW - r, centerY: halfH - r, startAngle: 0.0)
        addLine(start: (halfW - r, halfH), end: (-halfW + r, halfH))
        addArc(centerX: -halfW + r, centerY: halfH - r, startAngle: .pi / 2.0)
        addLine(start: (-halfW, halfH - r), end: (-halfW, -halfH + r))
        addArc(centerX: -halfW + r, centerY: -halfH + r, startAngle: .pi)

        return points
    }

    public static func sampleEye(
        expression: AvatarExpression,
        surface: AvatarSurfaceConfig,
        orientation: StrobiQuaternion,
        side: Double, // -1.0 = Left, +1.0 = Right
        blink: Double,
        offset: CGPoint = .zero
    ) -> (points: [CGPoint], isVisible: Bool) {
        let isLeft = side < 0
        let width = isLeft ? expression.widthLeft : expression.widthRight
        let restingHeight = isLeft ? expression.heightLeft : expression.heightRight
        let height = 5.0 + (restingHeight - 5.0) * blink
        let posX = isLeft ? expression.positionXLeft : expression.positionXRight
        let posY = isLeft ? expression.positionYLeft : expression.positionYRight
        let angleDeg = isLeft ? expression.leftAngle : expression.rightAngle
        let angle = radians(angleDeg)

        let centerX = (side * expression.spacing) / 2.0 + posX + Double(offset.x)
        let centerY = posY + Double(offset.y)

        let localPolygon = roundedRectangle(width: width, height: height)
        var projected: [CGPoint] = []
        var normalZSum: Double = 0.0

        let rx = surface.width / 2.0
        let ry = surface.height / 2.0
        let rz = surface.depth / 2.0

        for (lx, ly) in localPolygon {
            let rotX = lx * cos(angle) - ly * sin(angle)
            let rotY = lx * sin(angle) + ly * cos(angle)
            let rawX = centerX + rotX
            let rawY = centerY + rotY

            let (faceX, faceY) = canonicalFaceCoordinates(x: rawX, y: rawY)
            let sample = ellipsoidFrontSample(x: faceX, y: faceY, radiusX: rx, radiusY: ry, radiusZ: rz)

            let rotPt = rotateWithQuaternion(orientation, sample.point)
            let rotNorm = rotateWithQuaternion(orientation, sample.normal)
            normalZSum += rotNorm.z

            let denom = FOCAL_LENGTH - rotPt.z * expression.perspective
            let scale = FOCAL_LENGTH / max(denom, 0.0001)
            projected.append(CGPoint(x: rotPt.x * scale, y: rotPt.y * scale))
        }

        return (points: projected, isVisible: normalZSum > 0)
    }
}

// MARK: - Native Cocoa Screen Coordinate Tracking Bridge (Opsi 1)
public struct ScreenCoordinateReader: NSViewRepresentable {
    public var onPositionChange: (CGRect) -> Void

    public init(onPositionChange: @escaping (CGRect) -> Void) {
        self.onPositionChange = onPositionChange
    }

    public func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onPositionChange = onPositionChange
        return view
    }

    public func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onPositionChange = onPositionChange
    }
}

public final class TrackingNSView: NSView {
    var onPositionChange: ((CGRect) -> Void)?

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        if let window = self.window {
            postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(handleFrameChange), name: NSView.frameDidChangeNotification, object: self)
            NotificationCenter.default.addObserver(self, selector: #selector(handleFrameChange), name: NSWindow.didMoveNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(handleFrameChange), name: NSWindow.didResizeNotification, object: window)
        }
        reportPosition()
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            NotificationCenter.default.removeObserver(self)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleFrameChange() {
        reportPosition()
    }

    public override func layout() {
        super.layout()
        reportPosition()
    }

    func reportPosition() {
        guard let window = self.window else { return }
        let windowRect = self.convert(self.bounds, to: nil)
        let screenRect = window.convertToScreen(windowRect)
        guard screenRect.width > 0, screenRect.height > 0 else { return }
        onPositionChange?(screenRect)
    }
}

// MARK: - SwiftUI Procedural Avatar View (Autentik Strobi 1:1 + Blinking & Morphing Engine)
public struct CompanionProceduralAvatarView: View {
    public var definition: CompanionAvatarDefinition
    public var expressionName: String
    public var isBlinking: Bool
    public var autoBlink: Bool
    public var blinkConfig: AvatarBlinkConfig
    public var gazeOffset: CGPoint   // Dynamic pitch/yaw offset
    public var trackMouse: Bool      // Dynamic real-time mouse gaze tracking (Fitur F-03)
    public var size: CGFloat

    @ObservedObject private var gazeTracker = CompanionGazeTracker.shared
    @State private var internalBlinkProgress: Double = 1.0
    @State private var renderedExpression: AvatarExpression
    @State private var isBlinkActive: Bool = false
    @State private var morphTask: Task<Void, Never>? = nil

    public init(
        definition: CompanionAvatarDefinition = .defaultClicky,
        expressionName: String = "neutral",
        isBlinking: Bool = false,
        autoBlink: Bool = false,
        blinkConfig: AvatarBlinkConfig = AvatarBlinkConfig(),
        gazeOffset: CGPoint = .zero,
        trackMouse: Bool = false,
        size: CGFloat = 44.0
    ) {
        self.definition = definition
        self.expressionName = expressionName
        self.isBlinking = isBlinking
        self.autoBlink = autoBlink
        self.blinkConfig = blinkConfig
        self.gazeOffset = gazeOffset
        self.trackMouse = trackMouse
        self.size = size

        let initialExpr = definition.expressions[expressionName]
            ?? CompanionAvatarLabCatalog.preset(byId: expressionName)?.expression
            ?? definition.expressions["neutral"]
            ?? AvatarExpression(id: "neutral")
        _renderedExpression = State(initialValue: initialExpr)
    }

    private var targetExpression: AvatarExpression {
        definition.expressions[expressionName]
            ?? CompanionAvatarLabCatalog.preset(byId: expressionName)?.expression
            ?? definition.expressions["neutral"]
            ?? AvatarExpression(id: "neutral")
    }

    private var effectiveBlink: Double {
        if isBlinking { return 0.0 }
        return internalBlinkProgress
    }

    private var effectiveGaze: CGPoint {
        // Kunci tatapan lurus ke depan ke mata pengguna (Dead-Center) saat mode hover-round atau pose foto aktif
        if expressionName == "hover-round" || expressionName == "hover-focus-upright" {
            return .zero
        }
        if trackMouse {
            return gazeTracker.gazeOffset
        }
        return gazeOffset
    }

    public var body: some View {
        let isShaking = (renderedExpression.bodyMotion == "shake" || renderedExpression.bodyMotion == "slowShake")

        Group {
            if isShaking {
                TimelineView(.animation) { _ in
                    avatarCanvas(isShaking: true)
                }
            } else {
                avatarCanvas(isShaking: false)
            }
        }
        .frame(width: size, height: size)
        .background(
            ScreenCoordinateReader { screenRect in
                if trackMouse {
                    gazeTracker.updateAvatarPosition(screenFrame: screenRect)
                }
            }
        )
        .onChange(of: expressionName) { _, newExprName in
            morphToNewExpression(newExprName)
        }
        .task(id: autoBlink) {
            guard autoBlink else { return }
            await runBlinkLoop()
        }
    }

    @ViewBuilder
    private func avatarCanvas(isShaking: Bool) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            guard w > 0, h > 0 else { return }

            var cx = w / 2.0
            var cy = h / 2.0
            // viewBox standard Strobi adalah -150 sampai 150 (total 300 unit)
            let scale = min(w, h) / 300.0

            let expr = renderedExpression
            let surface = definition.body.primary
            let colors = definition.colors
            let effectiveEyesColor = expr.eyeColorHex.map { Color(hex: $0) } ?? colors.eyesColor

            // 1. Hitung Orientasi 3D Kepala (Euler Deg -> Rad) + Gaze Tracking
            var headEulerX = Strobi3DMath.radians(expr.headX - Double(effectiveGaze.y) * 16.0)
            var headEulerY = Strobi3DMath.radians(expr.headY + Double(effectiveGaze.x) * 22.0)
            var headEulerZ = Strobi3DMath.radians(expr.headZ)

            // Multi-harmonic shake: Cepat (Marah) vs Lambat & Halus (Slow Shake Hover)
            let isFastShaking = (expr.bodyMotion == "shake")
            let isSlowShaking = (expr.bodyMotion == "slowShake")

            if isFastShaking {
                let t = Date().timeIntervalSinceReferenceDate
                let shakeFactor = 2.8 * scale
                cx += (sin(t * 31.0) + sin(t * 53.0) * 0.45) * shakeFactor
                cy += (sin(t * 37.0) + sin(t * 61.0) * 0.4) * (2.0 * scale)
                headEulerX += Strobi3DMath.radians((sin(t * 31.0) + sin(t * 53.0) * 0.45) * 4.5)
                headEulerY += Strobi3DMath.radians((sin(t * 37.0) + sin(t * 61.0) * 0.4) * 5.5)
                headEulerZ += Strobi3DMath.radians(sin(t * 43.0) * 3.0)
            } else if isSlowShaking {
                let t = Date().timeIntervalSinceReferenceDate
                let shakeFactor = 1.3 * scale
                cx += (sin(t * 12.0) + sin(t * 19.0) * 0.4) * shakeFactor
                cy += (sin(t * 14.0) + sin(t * 23.0) * 0.35) * (1.0 * scale)
                headEulerX += Strobi3DMath.radians((sin(t * 12.0) + sin(t * 19.0) * 0.4) * 2.2)
                headEulerY += Strobi3DMath.radians((sin(t * 14.0) + sin(t * 23.0) * 0.35) * 2.8)
                headEulerZ += Strobi3DMath.radians(sin(t * 16.0) * 1.5)
            }

            let orientation = Strobi3DMath.quaternionFromEuler(x: headEulerX, y: headEulerY, z: headEulerZ)

            // 2. Gambar Siluet Kepala Tubuh 3D (Multi-Surface: Sphere, Cube, Capsule, Cone, Invisible)
            let hw = (surface.width / 2.0) * scale
            let hh = (surface.height / 2.0) * scale
            let headRect = CGRect(x: cx - hw, y: cy - hh, width: hw * 2, height: hh * 2)

            let headPath: Path
            switch surface.type {
            case "cube":
                let roundness = max(0.1, min(1.0, surface.roundness))
                let cornerRadius = roundness * min(hw, hh)
                headPath = Path(roundedRect: headRect, cornerRadius: cornerRadius)
            case "capsule":
                headPath = Path(roundedRect: headRect, cornerRadius: min(hw, hh))
            case "cone":
                var p = Path()
                let apexY = cy - hh
                let baseY = cy + hh
                let apexW = hw * 0.45
                p.move(to: CGPoint(x: cx - apexW, y: apexY + 8 * scale))
                p.addQuadCurve(to: CGPoint(x: cx + apexW, y: apexY + 8 * scale), control: CGPoint(x: cx, y: apexY))
                p.addLine(to: CGPoint(x: cx + hw, y: baseY - 10 * scale))
                p.addQuadCurve(to: CGPoint(x: cx - hw, y: baseY - 10 * scale), control: CGPoint(x: cx, y: baseY))
                p.closeSubpath()
                headPath = p
            default: // "sphere", "invisible", etc.
                headPath = Path(ellipseIn: headRect)
            }

            // Full Solid 1 Warna: Tidak mempunyai gradasi putih/abu di bawahnya
            let solidBodyColor: Color

            if isFastShaking || expr.bodyColorHex == "#ba3636" {
                solidBodyColor = Color(hex: "#ba3636")
            } else if expr.bodyColorHex == "#adc3ff" {
                solidBodyColor = Color(hex: "#adc3ff")
            } else if let hex = expr.bodyColorHex {
                solidBodyColor = Color(hex: hex)
            } else {
                solidBodyColor = colors.bodyColor
            }

            let bodyShading = GraphicsContext.Shading.color(solidBodyColor)

            // Render Back Body Nodes (Ears, Sunee rays, Kirby feet, Cloudee puffs)
            for node in definition.body.nodes where node.positionZ <= 0 {
                let nodeScale = scale
                let nodeX = cx + node.positionX * nodeScale
                let nodeY = cy + node.positionY * nodeScale
                let nodeW = node.surface.width * nodeScale
                let nodeH = node.surface.height * nodeScale
                let nodeRect = CGRect(x: nodeX - nodeW / 2.0, y: nodeY - nodeH / 2.0, width: nodeW, height: nodeH)

                var nodePath = Path(ellipseIn: nodeRect)
                if node.surface.type == "cube" {
                    let r = max(2.0, node.surface.roundness * min(nodeW, nodeH) / 2.0)
                    nodePath = Path(roundedRect: nodeRect, cornerRadius: r)
                }
                context.fill(nodePath, with: bodyShading)
            }

            // Fill Head if not invisible
            if surface.type != "invisible" {
                context.fill(headPath, with: bodyShading)
            }

            // 3. Proyeksikan Sepasang Kapsul Mata Strobi 3D (Dual-Layer: Parallax eye shift)
            let eyeParallax = CGPoint(x: effectiveGaze.x * 6.5, y: effectiveGaze.y * 4.5)
            let leftResult = Strobi3DMath.sampleEye(
                expression: expr,
                surface: surface,
                orientation: orientation,
                side: -1.0,
                blink: effectiveBlink,
                offset: eyeParallax
            )
            let rightResult = Strobi3DMath.sampleEye(
                expression: expr,
                surface: surface,
                orientation: orientation,
                side: 1.0,
                blink: effectiveBlink,
                offset: eyeParallax
            )

            // 4. Render Mata dengan Clipping pada Kepala (url(#head-clip))
            var eyeContext = context
            eyeContext.clip(to: headPath)

            // Render Mata Kiri jika menghadap kamera
            if leftResult.isVisible && leftResult.points.count > 2 {
                var leftEyePath = Path()
                let first = transformPoint(leftResult.points[0], cx: cx, cy: cy, scale: scale)
                leftEyePath.move(to: first)
                for pt in leftResult.points.dropFirst() {
                    leftEyePath.addLine(to: transformPoint(pt, cx: cx, cy: cy, scale: scale))
                }
                leftEyePath.closeSubpath()
                eyeContext.fill(leftEyePath, with: .color(effectiveEyesColor))
            }

            // Render Mata Kanan jika menghadap kamera
            if rightResult.isVisible && rightResult.points.count > 2 {
                var rightEyePath = Path()
                let first = transformPoint(rightResult.points[0], cx: cx, cy: cy, scale: scale)
                rightEyePath.move(to: first)
                for pt in rightResult.points.dropFirst() {
                    rightEyePath.addLine(to: transformPoint(pt, cx: cx, cy: cy, scale: scale))
                }
                rightEyePath.closeSubpath()
                eyeContext.fill(rightEyePath, with: .color(effectiveEyesColor))
            }

            // 5. Render Front Body Nodes (Snout cylinder Freddy, etc.)
            for node in definition.body.nodes where node.positionZ > 0 {
                let nodeScale = scale
                let nodeX = cx + node.positionX * nodeScale
                let nodeY = cy + node.positionY * nodeScale
                let nodeW = node.surface.width * nodeScale
                let nodeH = node.surface.height * nodeScale
                let nodeRect = CGRect(x: nodeX - nodeW / 2.0, y: nodeY - nodeH / 2.0, width: nodeW, height: nodeH)

                var frontPath = Path(ellipseIn: nodeRect)
                if node.surface.type == "cube" {
                    let r = max(2.0, node.surface.roundness * min(nodeW, nodeH) / 2.0)
                    frontPath = Path(roundedRect: nodeRect, cornerRadius: r)
                }
                context.fill(frontPath, with: bodyShading)
            }
        }
    }

    @inline(__always)
    private func transformPoint(_ pt: CGPoint, cx: CGFloat, cy: CGFloat, scale: CGFloat) -> CGPoint {
        CGPoint(x: cx + pt.x * scale, y: cy + pt.y * scale)
    }

    // MARK: - Loop Kedipan Alami Otomatis (Periodic Procedural Blinking)
    @MainActor
    private func runBlinkLoop() async {
        while !Task.isCancelled && autoBlink {
            let interval = Double.random(in: blinkConfig.minInterval...blinkConfig.maxInterval)
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            if Task.isCancelled || !autoBlink { break }

            // Lakukan animasi squash height (kedipan sinusoidal ~220ms)
            let steps = 14
            let stepDuration = blinkConfig.duration / Double(steps)
            isBlinkActive = true

            for i in 0...steps {
                let t = Double(i) / Double(steps)
                // Kurva harmonik: t=0 -> 1.0, t=0.5 -> 0.0 (tertutup), t=1.0 -> 1.0 (terbuka)
                internalBlinkProgress = 0.5 + 0.5 * cos(t * 2.0 * .pi)
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
            internalBlinkProgress = 1.0
            isBlinkActive = false
        }
    }

    // MARK: - Transisi Halus Antar-Ekspresi (Smooth Expression Morphing)
    private func morphToNewExpression(_ newExprName: String) {
        morphTask?.cancel()
        let fromExpr = renderedExpression
        let toExpr = targetExpression

        morphTask = Task { @MainActor in
            let isHoverRoundTransition = (newExprName == "hover-round" || fromExpr.id == "hover-round" || newExprName == "hover-focus-upright" || fromExpr.id == "hover-focus-upright")
            let steps = isHoverRoundTransition ? 28 : 14
            let totalDuration = isHoverRoundTransition ? 0.65 : 0.20 // 650ms perlahan lahan transisi halus
            let stepDuration = totalDuration / Double(steps)

            for i in 1...steps {
                guard !Task.isCancelled else { return }
                let t = Double(i) / Double(steps)
                // Easing cubic ease-in-out
                let ease = (t < 0.5) ? (4.0 * t * t * t) : (1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0)
                renderedExpression = fromExpr.interpolated(to: toExpr, progress: ease)
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            renderedExpression = toExpr
        }
    }
}

// MARK: - Interactive Preview / Inspector View (Strobi Avatar Lab • Fitur F-02 & F-03)
public struct CompanionAvatarInspectorView: View {
    @State private var selectedDefinition: CompanionAvatarDefinition = .defaultGrokBotWhite
    @State private var selectedExpression: String = "neutral"
    @State private var autoBlinkEnabled: Bool = true
    @State private var manualBlink: Bool = false
    @State private var trackMouseEnabled: Bool = true
    @State private var manualHeadX: Double = 0.0
    @State private var manualHeadY: Double = 0.0
    @State private var activeLifecycleState: CompanionLifecycleState = .idle

    private let presets: [CompanionAvatarDefinition] = [
        .defaultGrokBotWhite,
        .defaultClicky,
        .defaultMarketScout,
        .defaultResearchBuddy,
        .defaultShippy
    ]

    private let calibratedExpressions = [
        "neutral", "preset-25", "preset-26", "angry-brows", "uneasy-left", "upward-side-glance", "downward-gaze", "joyful-down-right",
        "curious-left", "skeptical-right", "surprised-left", "attentive-left",
        "sleepy-squint", "angry-left", "sad-downward", "playful-right", "eyes-closed"
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(selectedDefinition.colors.bodyColor)
                    .frame(width: 10, height: 10)
                Text("Bible Strong Avatar Lab • Strobi 3D Engine")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(autoBlinkEnabled ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                    Text(autoBlinkEnabled ? "Auto-Blink ON (3.5–5s)" : "Auto-Blink OFF")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(autoBlinkEnabled ? Color(hex: "#10B981") : .secondary)
                }
            }

            // Live 3D Avatar Render (Studio 96pt & Rail 44pt)
            HStack(spacing: 36) {
                VStack(spacing: 8) {
                    CompanionProceduralAvatarView(
                        definition: selectedDefinition,
                        expressionName: selectedExpression,
                        isBlinking: manualBlink,
                        autoBlink: autoBlinkEnabled,
                        gazeOffset: CGPoint(x: manualHeadY / 25.0, y: manualHeadX / 20.0),
                        trackMouse: trackMouseEnabled,
                        size: 96
                    )
                    Text("Studio 96pt (Gaze + Morph)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }

                VStack(spacing: 8) {
                    CompanionProceduralAvatarView(
                        definition: selectedDefinition,
                        expressionName: selectedExpression,
                        isBlinking: manualBlink,
                        autoBlink: autoBlinkEnabled,
                        gazeOffset: CGPoint(x: manualHeadY / 25.0, y: manualHeadX / 20.0),
                        trackMouse: trackMouseEnabled,
                        size: 44
                    )
                    Text("Rail 44pt")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.vertical, 4)

            // Selector Karakter Companion
            HStack(spacing: 8) {
                ForEach(presets) { preset in
                    Button(action: { selectedDefinition = preset }) {
                        Text(preset.name)
                            .font(.system(size: 11, weight: selectedDefinition.name == preset.name ? .bold : .regular))
                            .foregroundColor(selectedDefinition.name == preset.name ? .black : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(selectedDefinition.name == preset.name ? preset.colors.bodyColor : Color.white.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Status Siklus Hidup Companion (Lifecycle Triggers)
            VStack(alignment: .leading, spacing: 6) {
                Text("Companion Lifecycle States (Status ➔ Auto-Expression):")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 6) {
                    ForEach(CompanionLifecycleState.allCases, id: \.self) { state in
                        Button(action: {
                            activeLifecycleState = state
                            selectedExpression = state.defaultExpressionName
                            manualHeadX = 0
                            manualHeadY = 0
                        }) {
                            Text(state.rawValue.capitalized)
                                .font(.system(size: 10))
                                .foregroundColor(activeLifecycleState == state ? .black : .white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(activeLifecycleState == state ? Color.white : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Grid Tombol Ekspresi Calibrated Strobi (Transisi Halus)
            VStack(alignment: .leading, spacing: 6) {
                Text("Calibrated Strobi Expressions (Klik untuk Transisi Halus):")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 6) {
                    ForEach(calibratedExpressions, id: \.self) { expr in
                        Button(action: {
                            selectedExpression = expr
                            manualHeadX = 0
                            manualHeadY = 0
                        }) {
                            Text(expr)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(selectedExpression == expr ? .black : .white.opacity(0.85))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedExpression == expr ? Color.white : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Slider 3D Pitch / Yaw Manual
            VStack(spacing: 4) {
                HStack {
                    Text("Head Pitch (X): \(Int(manualHeadX))°")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                    Slider(value: $manualHeadX, in: -45...45)
                }
                HStack {
                    Text("Head Yaw (Y): \(Int(manualHeadY))°")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                    Slider(value: $manualHeadY, in: -45...45)
                }
            }
            .padding(.horizontal, 8)

            // Kontrol Kedipan & Gaze Tracking
            HStack(spacing: 20) {
                Toggle("Auto-Blink Periodik (3.5–5.2s)", isOn: $autoBlinkEnabled)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))

                Toggle("Dynamic Gaze (Ikuti Kursor Mouse)", isOn: $trackMouseEnabled)
                    .font(.system(size: 11))
                    .foregroundColor(trackMouseEnabled ? Color(hex: "#10B981") : .white.opacity(0.85))

                Toggle("Tahan Tutup Mata Manual", isOn: $manualBlink)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(18)
        .background(Color(hex: "#121316"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
