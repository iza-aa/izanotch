import SwiftUI
import AppKit
import ClickyFoundation
import ClickyPlatform
import ClickyAgent

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
                    // Safe View-Only Mode: Pure SwiftUI, 0 Hit-Testing, 0 Event Interception
                    ZStack {
                        Color(hex: "#0F1115")
                        if let img = customSnapshot ?? vdService.activeSnapshot {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
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

                    // Project cursor accurately to aspect-fit rendered image rect
                    let img = customSnapshot ?? vdService.activeSnapshot
                    let imgSize = img?.size ?? CGSize(width: 1260, height: 800)
                    let viewW = geo.size.width
                    let viewH = geo.size.height

                    let scale = min(viewW / max(imgSize.width, 1), viewH / max(imgSize.height, 1))
                    let drawWidth = imgSize.width * scale
                    let drawHeight = imgSize.height * scale
                    let drawX = (viewW - drawWidth) / 2.0
                    let drawY = (viewH - drawHeight) / 2.0

                    let rx = drawX + (reticle.x * drawWidth)
                    let ry = drawY + (reticle.y * drawHeight)

                    ZStack(alignment: .topLeading) {
                        // Subtle ripple pulse on click in buddy color
                        if vdService.isClickingReticle {
                            Circle()
                                .stroke(buddyThemeColor.opacity(0.85), lineWidth: 1.2)
                                .frame(width: 14, height: 14)
                                .scaleEffect(1.4)
                                .offset(x: -7, y: -7)
                                .transition(.scale.combined(with: .opacity))
                        }

                        // Compact macOS-style arrow pointer with luminous buddy accent
                        MascotAgentCursorView(isClicking: vdService.isClickingReticle, accentColor: buddyThemeColor)
                            .offset(x: 4.5, y: 6.0)
                    }
                    .position(x: rx, y: ry)
                    .allowsHitTesting(false)
                }

                // 4. Header Bar / Mode Badge
                HStack(spacing: 6) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isInteractive ? Color(hex: "#10B981") : buddyThemeColor)
                            .frame(width: 6, height: 6)

                        Text(isInteractive ? "Human Takeover Active" : "AI Autonomous View")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.90))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.65))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.6)
                            )
                    )

                    Spacer()

                    if isHovering {
                        Text(isInteractive ? "Click and type directly in \(targetAppName)" : "View Mode • Click 'Take Over Screen' to interact")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding(10)
                .allowsHitTesting(false)
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
            Color(hex: "#0F1115")

            VStack(spacing: 12) {
                AppSystemIconView(appName: targetAppName, size: 48)

                VStack(spacing: 4) {
                    Text("\(targetAppName) Isolated Workspace")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text("Initializing virtual desktop space...")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.60))
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

// MARK: - Autonomous Mascot Agent Cursor View (F-08: Animated CUA Gliding Cursor)
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
            // Neon accent glow shadow in buddy color
            CursorArrowShape()
                .fill(accentColor.opacity(0.60))
                .frame(width: 9.5, height: 12.5)
                .blur(radius: 2.0)
                .offset(x: 0.5, y: 0.5)

            // Outer crisp border
            CursorArrowShape()
                .stroke(Color.white.opacity(0.95), lineWidth: 1.0)
                .frame(width: 9, height: 12)

            // Dynamic buddy-colored fill
            CursorArrowShape()
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 9, height: 12)

            // Subtle dark center core accent
            CursorArrowShape()
                .fill(Color(hex: "#0F172A").opacity(0.35))
                .frame(width: 4.5, height: 6.5)
                .offset(x: 2.0, y: 2.5)
        }
        .scaleEffect(isClicking ? 0.82 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.65), value: isClicking)
    }
}

struct CursorArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.65, y: h))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.58))
        path.addLine(to: CGPoint(x: w, y: h * 0.58))
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
