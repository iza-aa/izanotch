import SwiftUI
import AppKit

// MARK: - HomeSpaceComputerCardView (F-07: 1:1 Foto 1 Full Fidelity)
/// Kartu chat interaktif "Computer" yang disematkan di dalam bubble pesan asisten.
/// Menampilkan status otomasi, instruksi operasional, dan frame canvas desktop/jendela aplikasi.
public struct HomeSpaceComputerCardView: View {
    public let payload: ComputerCardPayload
    public var onTakeoverClicked: (() -> Void)? = nil
    public var onOpenWindowClicked: (() -> Void)? = nil
    public var onCardTapped: (() -> Void)? = nil
    public var isCollapsible: Bool = false
    public var isCollapsed: Binding<Bool>? = nil

    @ObservedObject private var streamService = CompanionWindowStreamService.shared
    @State private var pulseAnimation: Bool = false
    @State private var isHovered: Bool = false
    @State private var internalIsCollapsed: Bool = false

    private var effectiveIsCollapsed: Bool {
        if payload.status == .working || payload.status == .takeoverNeeded {
            return false
        }
        return isCollapsed?.wrappedValue ?? internalIsCollapsed
    }

    private var effectiveQueueItems: [ComputerCardQueueItem]? {
        if let q = payload.queueItems, !q.isEmpty {
            return q
        }
        if let summ = payload.deliverableSummary ?? payload.queueSummary, !summ.isEmpty {
            return [ComputerCardQueueItem(name: summ, statusBadge: "Done", isChecked: true)]
        }
        return nil
    }

    public init(
        payload: ComputerCardPayload,
        onTakeoverClicked: (() -> Void)? = nil,
        onOpenWindowClicked: (() -> Void)? = nil,
        onCardTapped: (() -> Void)? = nil,
        isCollapsible: Bool = false,
        isCollapsed: Binding<Bool>? = nil
    ) {
        self.payload = payload
        self.onTakeoverClicked = onTakeoverClicked
        self.onOpenWindowClicked = onOpenWindowClicked
        self.onCardTapped = onCardTapped
        self.isCollapsible = isCollapsible
        self.isCollapsed = isCollapsed
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: effectiveIsCollapsed ? 0 : 14) {
            // 1. Top Header: Title "Computer" & Status Capsule Pill & Action Controls
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "display")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "#38BDF8"))

                    Text(payload.cardTitle)
                        .font(.system(size: 18.5, weight: .bold, design: .default))
                        .foregroundColor(.white)

                    if let app = payload.targetAppName ?? payload.activeWorkflowApp {
                        Text("(\(app))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                statusPill

                if isCollapsible {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if let binding = isCollapsed {
                                binding.wrappedValue.toggle()
                            } else {
                                internalIsCollapsed.toggle()
                            }
                        }
                    }) {
                        Image(systemName: effectiveIsCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help(effectiveIsCollapsed ? "Expand Workspace" : "Collapse Workspace")
                }

                Button(action: {
                    onCardTapped?()
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Maximize Workspace")
            }

            if !effectiveIsCollapsed {
                // 2. Subtitle / Instruction Text (1:1 Foto 1)
                if !payload.instructionText.isEmpty {
                    Text(payload.instructionText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.88))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 3. Desktop Canvas Frame (Scenic Nature Wallpaper + Floating App Windows)
                canvasFrame
                    .frame(maxWidth: .infinity)
                    .frame(height: 290)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )

                // 4. Action Steps Directly Underneath Computer Screen ("terus stepnya itu tetap dibawah computernya")
                if let items = effectiveQueueItems, !items.isEmpty {
                    embeddedActionStepsView(items: items)
                }

                // 5. Live Action Ticker (When companion is operating)
                if payload.status == .working, let action = payload.currentActionLabel, !action.isEmpty {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: "#38BDF8"))
                            .frame(width: 7, height: 7)
                            .scaleEffect(pulseAnimation ? 1.25 : 0.8)

                        Text(action)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.92))

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(hex: "#38BDF8").opacity(0.25), lineWidth: 0.8)
                            )
                    )
                }

                // 5. Action Bar (Jika Takeover Diperlukan atau Window ID Tersedia)
                if payload.status == .takeoverNeeded {
                    Button(action: {
                        onTakeoverClicked?()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Take Over Screen")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: Color(hex: "#F59E0B").opacity(0.4), radius: 6, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#18191B"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isHovered ? Color(hex: "#38BDF8").opacity(0.35) : Color.white.opacity(0.08), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 6)
        )
        .scaleEffect(isHovered ? 1.008 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            onCardTapped?()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .frame(maxWidth: 560, alignment: .leading)
        .onAppear {
            if payload.status == .working {
                withAnimation(Animation.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
    }

    // MARK: - Status Capsule Pill
    @ViewBuilder
    private var statusPill: some View {
        switch payload.status {
        case .done:
            HStack(spacing: 5.5) {
                Circle()
                    .fill(Color(hex: "#34D399"))
                    .frame(width: 6, height: 6)

                Text("Done")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#34D399"))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(Color(hex: "#064E3B").opacity(0.55))
                    .overlay(
                        Capsule().stroke(Color(hex: "#10B981").opacity(0.35), lineWidth: 0.8)
                    )
            )

        case .working:
            HStack(spacing: 5.5) {
                Circle()
                    .fill(Color(hex: "#38BDF8"))
                    .frame(width: 6, height: 6)
                    .scaleEffect(pulseAnimation ? 1.25 : 0.8)
                    .opacity(pulseAnimation ? 1.0 : 0.5)

                Text("Working")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#38BDF8"))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(Color(hex: "#0C4A6E").opacity(0.55))
                    .overlay(
                        Capsule().stroke(Color(hex: "#38BDF8").opacity(0.35), lineWidth: 0.8)
                    )
            )

        case .takeoverNeeded:
            HStack(spacing: 5.5) {
                Circle()
                    .fill(Color(hex: "#F59E0B"))
                    .frame(width: 6, height: 6)

                Text("Takeover Needed")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#F59E0B"))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(Color(hex: "#78350F").opacity(0.55))
                    .overlay(
                        Capsule().stroke(Color(hex: "#F59E0B").opacity(0.35), lineWidth: 0.8)
                    )
            )

        case .failed:
            HStack(spacing: 5.5) {
                Circle()
                    .fill(Color(hex: "#EF4444"))
                    .frame(width: 6, height: 6)

                Text("Failed")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#EF4444"))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(Color(hex: "#7F1D1D").opacity(0.55))
                    .overlay(
                        Capsule().stroke(Color(hex: "#EF4444").opacity(0.35), lineWidth: 0.8)
                    )
            )
        }
    }

    // MARK: - Embedded Action Steps View (F-07: Action Steps Directly Below Computer Screen)
    private func embeddedActionStepsView(items: [ComputerCardQueueItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#38BDF8"))

                let completedCount = items.filter { $0.isChecked || payload.status == .done }.count
                Text("Action Steps (\(completedCount)/\(items.count))")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                if let summary = payload.queueSummary ?? payload.deliverableSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .center, spacing: 8) {
                        if item.isChecked || payload.status == .done {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(Color(hex: "#34D399"))
                                .frame(width: 14, height: 14)
                        } else if item.statusBadge.contains("Active") || item.statusBadge.contains("Progress") || item.statusBadge.contains("Starting") {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 14, height: 14)
                        } else {
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                .frame(width: 9, height: 9)
                                .padding(2.5)
                        }

                        Text(item.name)
                            .font(.system(size: 11.5, weight: (item.isChecked || payload.status == .done) ? .regular : .medium))
                            .foregroundColor((item.isChecked || payload.status == .done) ? .white.opacity(0.85) : (item.statusBadge.contains("Active") ? Color(hex: "#38BDF8") : .white.opacity(0.5)))
                            .lineLimit(1)

                        Spacer()

                        if item.statusBadge.contains("Takeover") || item.statusBadge.contains("Review") {
                            Button(action: {
                                onTakeoverClicked?()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 8.5, weight: .bold))
                                    Text("Take Over")
                                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(item.statusBadge)
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundColor((item.isChecked || payload.status == .done) ? Color(hex: "#34D399").opacity(0.8) : (item.statusBadge.contains("Active") ? Color(hex: "#38BDF8") : .white.opacity(0.35)))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill((item.isChecked || payload.status == .done) ? Color(hex: "#34D399").opacity(0.1) : Color.white.opacity(0.04))
                                )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Canvas Frame (Live Snapshot & Precision Grounder)
    @ViewBuilder
    private var canvasFrame: some View {
        ZStack {
            Color(hex: "#0F1115")

            let customImg = streamService.activeSnapshot ?? (payload.snapshotImagePath.flatMap { NSImage(contentsOfFile: $0) }) ?? MascotVirtualDesktopService.shared.activeSnapshot

            let target = payload.targetAppName ?? CompanionManager.shared.activeBuddy.workflowAppNames.first ?? "Workspace"
            let activeSlug = CompanionManager.shared.activeBuddy.slug

            InteractiveVirtualDesktopView(
                targetAppName: target,
                slug: activeSlug,
                customSnapshot: customImg,
                isInteractive: false
            )
            .scaledToFit()
            .allowsHitTesting(false)

            // Hybrid Precision Grounder (Grid + Coordinate Ruler + Crosshair)
            precisionGroundingOverlay
        }
    }

    // MARK: - Workspace Connection Placeholder
    private var workspaceConnectionPlaceholder: some View {
        let appName = payload.activeWorkflowApp ?? payload.targetAppName ?? CompanionManager.shared.activeBuddy.workflowAppNames.first ?? "Workspace"
        let isSafari = appName.lowercased().contains("safari")

        return ZStack {
            Color(hex: "#0F1115")

            VStack(spacing: 12) {
                AppSystemIconView(appName: appName, size: 48)

                VStack(spacing: 4) {
                    Text("\(appName) Workspace Ready")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text("Bring \(appName) to foreground to mirror live screen.")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.60))
                        .multilineTextAlignment(.center)
                }

                Button(action: {
                    streamService.launchOrFocusWorkflowApp(appName: appName)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .bold))
                        Text("Launch \(appName)")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#2563EB"))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
    }

    // MARK: - Precision Grounding Overlay (100px Grid + Coordinate Marks + Target Crosshair)
    private var precisionGroundingOverlay: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // 1. Subtle 50px & 100px Coordinate Grid Lines
                Path { path in
                    stride(from: 0, through: geo.size.width, by: 50).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    stride(from: 0, through: geo.size.height, by: 50).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Color(hex: "#38BDF8").opacity(0.12), style: StrokeStyle(lineWidth: 0.6, dash: [3, 4]))

                // 2. Corner Pixel Coordinate Indicators
                HStack {
                    Text("0,0")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#38BDF8").opacity(0.55))
                        .padding(5)
                    Spacer()
                    Text("\(Int(geo.size.width)),0")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#38BDF8").opacity(0.55))
                        .padding(5)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - HomeSpaceComputerReceiptView (xAI Grok Bot Compact Inline Receipt)
/// Komponen tanda terima ringkas yang ditampilkan di dalam riwayat percakapan chat.
/// Menghindari penumpukan kartu komputer besar secara berulang di feed percakapan.
public struct HomeSpaceComputerReceiptView: View {
    public let payload: ComputerCardPayload
    public var onTapped: (() -> Void)? = nil

    @State private var isHovered: Bool = false

    public init(payload: ComputerCardPayload, onTapped: (() -> Void)? = nil) {
        self.payload = payload
        self.onTapped = onTapped
    }

    public var body: some View {
        Button(action: {
            onTapped?()
        }) {
            HStack(spacing: 8) {
                Image(systemName: payload.status == .working ? "arrow.triangle.2.circlepath" : "desktopcomputer")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Color(hex: "#38BDF8"))

                Text(payload.targetAppName ?? payload.cardTitle)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("•")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))

                Text(payload.deliverableSummary ?? payload.queueSummary ?? payload.instructionText)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.82))
                    .lineLimit(1)

                Spacer(minLength: 4)

                statusBadge
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#1A1D24"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isHovered ? Color(hex: "#38BDF8").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .frame(maxWidth: 460, alignment: .leading)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch payload.status {
        case .done:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("Done")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(hex: "#34D399"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: "#064E3B").opacity(0.6)))

        case .working:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: "#38BDF8"))
                    .frame(width: 5, height: 5)
                Text("Working")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(hex: "#38BDF8"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: "#0369A1").opacity(0.4)))

        case .takeoverNeeded:
            HStack(spacing: 4) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("Takeover")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(hex: "#F59E0B"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: "#78350F").opacity(0.6)))

        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                Text("Failed")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(hex: "#EF4444"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: "#7F1D1D").opacity(0.6)))
        }
    }
}

// MARK: - HomeSpaceComputerStepsView
/// Komponen daftar langkah (steps queue) untuk aksi komputer.
/// Ketika aksi aktif (isPastTurn == false): Ditampilkan langsung di bawah layar komputer ("stepnya itu tetap dibawah computernya").
/// Ketika aksi selesai dan ada aksi baru (isPastTurn == true): Layar berpindah ke bawah dan meninggalkan daftar langkah yang sudah selesai ("meninggalkan stepnya yg sudah selesai tadi").
public struct HomeSpaceComputerStepsView: View {
    public let queueItems: [ComputerCardQueueItem]
    public let status: ComputerCardStatus
    public let isPastTurn: Bool
    public var targetAppName: String? = nil
    public var summary: String? = nil
    public var onTapped: (() -> Void)? = nil

    @State private var isExpanded: Bool = true
    @State private var isHovered: Bool = false

    public init(
        queueItems: [ComputerCardQueueItem],
        status: ComputerCardStatus,
        isPastTurn: Bool,
        targetAppName: String? = nil,
        summary: String? = nil,
        onTapped: (() -> Void)? = nil
    ) {
        self.queueItems = queueItems
        self.status = status
        self.isPastTurn = isPastTurn
        self.targetAppName = targetAppName
        self.summary = summary
        self.onTapped = onTapped
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row
            HStack(spacing: 8) {
                if isPastTurn {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#34D399"))

                    Text(targetAppName ?? "Computer")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))

                    Text("\(queueItems.count) steps completed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))

                    Spacer()

                    statusBadge

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Active Turn Header (underneath computer screen)
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#38BDF8"))

                        let completedCount = queueItems.filter { $0.isChecked || status == .done }.count
                        Text("Action Steps (\(completedCount)/\(queueItems.count))")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    if let summ = summary, !summ.isEmpty {
                        Text(summ)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
            }

            // Step List
            if isExpanded && !queueItems.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(queueItems.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 9) {
                            if item.isChecked || status == .done {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#34D399"))
                                    .frame(width: 14, height: 14)
                            } else if item.statusBadge.contains("Active") || item.statusBadge.contains("Progress") || item.statusBadge.contains("Starting") {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 14, height: 14)
                            } else {
                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    .frame(width: 10, height: 10)
                                    .padding(2)
                            }

                            Text(item.name)
                                .font(.system(size: 12, weight: (item.isChecked || status == .done) ? .regular : .medium))
                                .foregroundColor((item.isChecked || status == .done) ? .white.opacity(0.85) : (item.statusBadge.contains("Active") ? Color(hex: "#38BDF8") : .white.opacity(0.5)))
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()

                            if !isPastTurn && (item.statusBadge.contains("Active") || item.statusBadge.contains("Starting")) {
                                Text("In Progress")
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: "#38BDF8"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color(hex: "#0284C7").opacity(0.35)))
                            }
                        }
                    }
                }
                .padding(.top, isPastTurn ? 4 : 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isPastTurn ? Color(hex: "#17181C") : Color(hex: "#15171B"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isPastTurn ? Color.white.opacity(0.08) : Color(hex: "#38BDF8").opacity(0.18), lineWidth: 0.8)
                )
        )
        .frame(maxWidth: 560, alignment: .leading)
        .onHover { isHovered = $0 }
        .onTapGesture {
            if isPastTurn {
                onTapped?()
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .done:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("Done")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(hex: "#34D399"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: "#064E3B").opacity(0.6)))

        case .working:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: "#38BDF8"))
                    .frame(width: 5, height: 5)
                Text("Working")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(hex: "#38BDF8"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: "#0369A1").opacity(0.4)))

        case .takeoverNeeded:
            HStack(spacing: 4) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("Takeover")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(hex: "#F59E0B"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: "#78350F").opacity(0.6)))

        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                Text("Failed")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(hex: "#EF4444"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: "#7F1D1D").opacity(0.6)))
        }
    }
}


