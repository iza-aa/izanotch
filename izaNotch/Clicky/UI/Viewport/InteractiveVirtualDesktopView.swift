import SwiftUI
import AppKit

// MARK: - InteractiveVirtualDesktopView
/// Tampilan SwiftUI & NSView yang merender desktop virtual terisolasi maskot.
/// Secara default beroperasi dalam VIEW-ONLY MODE (pengguna tidak dapat mengklik/mengetik saat AI bekerja).
/// Interaksi pengguna (Human Takeover) HANYA aktif jika isInteractive bernilai true via tombol Takeover eksplisit.
public struct InteractiveVirtualDesktopView: View {
    @ObservedObject private var vdService = MascotVirtualDesktopService.shared
    @State private var isHovering: Bool = false

    public let targetAppName: String
    public let slug: String
    public var customSnapshot: NSImage? = nil
    public var isInteractive: Bool = false

    public init(
        targetAppName: String = "Mail",
        slug: String = "inbox-buddy",
        customSnapshot: NSImage? = nil,
        isInteractive: Bool = false
    ) {
        self.targetAppName = targetAppName
        self.slug = slug
        self.customSnapshot = customSnapshot
        self.isInteractive = isInteractive
    }

    private var buddyThemeColor: Color {
        if let session = CompanionManager.shared.sessions.first(where: { $0.slug == slug }) {
            return Color(hex: session.avatarColorHex)
        }
        return Color(hex: CompanionManager.shared.activeBuddy.avatarColorHex)
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // 1. Canvas Host: Interactive AppKit View (Takeover Mode) vs Pure SwiftUI Image (View-Only Mode)
                if isInteractive {
                    VirtualDesktopNSViewRepresentable(
                        image: customSnapshot ?? vdService.activeSnapshot,
                        viewSize: geo.size,
                        isInteractive: true,
                        onUserClick: { normalizedPoint in
                            vdService.handleUserDirectClick(normalizedPoint: normalizedPoint)
                        },
                        onUserKey: { char, code in
                            vdService.handleUserViewKey(character: char, keyCode: code)
                        }
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    // Safe View-Only Mode: Pure SwiftUI, 0 Hit-Testing, Aspect-Fit Proportional
                    ZStack {
                        Color(hex: "#18191B")
                        if let img = customSnapshot ?? vdService.activeSnapshot {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)
                }

                // 2. Fallback Placeholder jika belum ada snapshot
                if customSnapshot == nil && vdService.activeSnapshot == nil {
                    placeholderView(size: geo.size)
                        .allowsHitTesting(false)
                }

                // 3. Autonomous AI Cursor Pointer (Visible strictly when !isInteractive)
                if !isInteractive {
                    let reticle = vdService.virtualReticle

                    let viewW = geo.size.width
                    let viewH = geo.size.height

                    let activeImg = customSnapshot ?? vdService.activeSnapshot
                    let imgW = activeImg?.size.width ?? viewW
                    let imgH = activeImg?.size.height ?? viewH

                    let (canvasW, canvasH, offsetX, offsetY): (CGFloat, CGFloat, CGFloat, CGFloat) = {
                        guard imgW > 0, imgH > 0, viewW > 0, viewH > 0 else {
                            return (viewW, viewH, 0, 0)
                        }
                        let scale = min(viewW / imgW, viewH / imgH)
                        let dw = imgW * scale
                        let dh = imgH * scale
                        let ox = (viewW - dw) / 2.0
                        let oy = (viewH - dh) / 2.0
                        return (dw, dh, ox, oy)
                    }()

                    let rx = offsetX + (reticle.x * canvasW)
                    let ry = offsetY + (reticle.y * canvasH)

                    ZStack(alignment: .topLeading) {
                        // Subtle ripple pulse on click in crisp white
                        if vdService.isClickingReticle {
                            Circle()
                                .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                                .frame(width: 14, height: 14)
                                .scaleEffect(1.4)
                                .offset(x: -7, y: -7)
                                .transition(.scale.combined(with: .opacity))
                        }

                        // Precision tailless cursor in active buddy theme color (Foto 2 & Foto 3)
                        MascotAgentCursorView(isClicking: vdService.isClickingReticle, accentColor: buddyThemeColor)
                            .offset(x: 6.0, y: 8.0)
                    }
                    .position(x: rx, y: ry)
                    .opacity(vdService.isReticleVisible ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.25), value: vdService.isReticleVisible)
                    .allowsHitTesting(false)
                }

                // 4. Header Bar / Mode Badge (Strictly shown during Human Takeover mode)
                if isInteractive {
                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(hex: "#10B981"))
                                .frame(width: 6, height: 6)

                            Text("Human Takeover Active")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.75))
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.6)
                                )
                        )

                        Spacer()
                    }
                    .padding(10)
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
        }
        .onAppear {
            if isInteractive && vdService.isVirtualDisplayActive {
                vdService.startStreaming(interval: 0.8)
            }
        }
    }

    private func placeholderView(size: CGSize) -> some View {
        ZStack {
            // Foto 1 Clean White Canvas with Subtle Dot Grid
            Color.white

            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 16
                    stride(from: 8, through: geo.size.width, by: spacing).forEach { x in
                        stride(from: 8, through: geo.size.height, by: spacing).forEach { y in
                            path.addEllipse(in: CGRect(x: x, y: y, width: 1.2, height: 1.2))
                        }
                    }
                }
                .fill(Color(hex: "#94A3B8").opacity(0.22))
            }

            VStack(spacing: 12) {
                AppSystemIconView(appName: targetAppName, size: 48)

                VStack(spacing: 4) {
                    Text("\(targetAppName) Workspace")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#0F172A"))

                    Text("Connecting to \(targetAppName)...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#64748B"))
                }
            }
        }
    }
}

// MARK: - AppKit View Representable for Real Mouse & Keyboard Interception
struct VirtualDesktopNSViewRepresentable: NSViewRepresentable {
    let image: NSImage?
    let viewSize: CGSize
    let isInteractive: Bool
    let onUserClick: (CGPoint) -> Void
    let onUserKey: (String, UInt16) -> Void

    func makeNSView(context: Context) -> InteractiveCanvasView {
        let view = InteractiveCanvasView()
        view.isInteractive = isInteractive
        view.onUserClick = onUserClick
        view.onUserKey = onUserKey
        view.image = image
        return view
    }

    func updateNSView(_ nsView: InteractiveCanvasView, context: Context) {
        nsView.image = image
        nsView.isInteractive = isInteractive
        nsView.onUserClick = onUserClick
        nsView.onUserKey = onUserKey
        nsView.needsDisplay = true
    }
}

// MARK: - InteractiveCanvasView
final class InteractiveCanvasView: NSView {
    var image: NSImage?
    var isInteractive: Bool = false
    var onUserClick: ((CGPoint) -> Void)?
    var onUserKey: ((String, UInt16) -> Void)?

    override var acceptsFirstResponder: Bool { isInteractive }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(hex: "#0F1115").cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isInteractive {
            addCursorRect(bounds, cursor: .arrow)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let img = image else { return }

        // Draw aspect-fit
        let viewBounds = bounds
        let imgSize = img.size
        guard imgSize.width > 0 && imgSize.height > 0 else { return }

        let scale = min(viewBounds.width / imgSize.width, viewBounds.height / imgSize.height)
        let drawWidth = imgSize.width * scale
        let drawHeight = imgSize.height * scale
        let drawX = (viewBounds.width - drawWidth) / 2.0
        let drawY = (viewBounds.height - drawHeight) / 2.0

        let drawRect = NSRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)
        img.draw(in: drawRect)
    }

    override func mouseDown(with event: NSEvent) {
        guard isInteractive else { return }
        window?.makeFirstResponder(self)
        let localPoint = convert(event.locationInWindow, from: nil)

        let viewBounds = bounds
        guard let img = image, img.size.width > 0, img.size.height > 0 else { return }
        let scale = min(viewBounds.width / img.size.width, viewBounds.height / img.size.height)
        let drawWidth = img.size.width * scale
        let drawHeight = img.size.height * scale
        let drawX = (viewBounds.width - drawWidth) / 2.0
        let drawY = (viewBounds.height - drawHeight) / 2.0

        let clickInDrawX = localPoint.x - drawX
        let clickInDrawY = (viewBounds.height - localPoint.y) - drawY

        guard drawWidth > 0 && drawHeight > 0 else { return }
        let normX = max(0.0, min(1.0, clickInDrawX / drawWidth))
        let normY = max(0.0, min(1.0, clickInDrawY / drawHeight))

        onUserClick?(CGPoint(x: normX, y: normY))
    }

    override func keyDown(with event: NSEvent) {
        guard isInteractive else { return }
        let characters = event.characters ?? ""
        onUserKey?(characters, event.keyCode)
    }
}

// MARK: - Autonomous Mascot Agent Cursor View (Precision Tailless Arrow - Foto 2 & Foto 3)
public struct MascotAgentCursorView: View {
    public let isClicking: Bool
    public var accentColor: Color

    public init(isClicking: Bool = false) {
        self.isClicking = isClicking
        self.accentColor = Color(hex: "#38BDF8")
    }

    public init(isClicking: Bool, accentColor: Color) {
        self.isClicking = isClicking
        self.accentColor = accentColor
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // 1. Soft dark drop shadow for high contrast (Foto 2 & Foto 3)
            CursorArrowShape()
                .fill(Color.black.opacity(0.35))
                .frame(width: 12, height: 16)
                .offset(x: 0.5, y: 1.0)

            // 2. Thick crisp white outline (Foto 2 & Foto 3)
            CursorArrowShape()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: 12, height: 16)

            // 3. Solid fill with active buddy theme color (Foto 2 & Foto 3)
            CursorArrowShape()
                .fill(accentColor)
                .frame(width: 12, height: 16)
        }
        .scaleEffect(isClicking ? 0.85 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isClicking)
    }
}

public struct CursorArrowShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Precision tailless arrowhead pointer (CuaDriver / Foto 2)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.68))
        path.addLine(to: CGPoint(x: w, y: h * 0.55))
        path.closeSubpath()

        return path
    }
}

private extension NSColor {
    convenience init(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        var rgbValue: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgbValue)
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}