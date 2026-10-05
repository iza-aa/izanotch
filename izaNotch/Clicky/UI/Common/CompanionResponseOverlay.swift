//
//  CompanionResponseOverlay.swift
//  izaNotch
//
//  Cursor-following overlay that displays streaming AI response text.
//  Uses a non-activating NSPanel so it floats above all apps without
//  stealing focus, and repositions itself near the mouse cursor each frame.
//  Matches Farza's official implementation in leanring-buddy.
//

import AppKit
import Combine
import Defaults
import SwiftUI

// MARK: - View Model

@MainActor
final class CompanionResponseOverlayViewModel: ObservableObject {
    @Published var streamingResponseText: String = ""
    @Published var isShowingResponse: Bool = false
}

// MARK: - Overlay Manager

@MainActor
final class CompanionResponseOverlayManager {
    static let shared = CompanionResponseOverlayManager()

    private let overlayViewModel = CompanionResponseOverlayViewModel()
    private var overlayPanel: NSPanel?
    private var cursorTrackingTimer: Timer?
    private var autoHideWorkItem: DispatchWorkItem?

    /// The horizontal offset from the cursor to the left edge of the overlay panel.
    private let cursorOffsetX: CGFloat = 22
    /// The vertical offset from the cursor downward to the top edge of the overlay panel.
    private let cursorOffsetY: CGFloat = 6
    /// Maximum width of the overlay panel.
    private let overlayMaxWidth: CGFloat = 328

    func showOverlayAndBeginStreaming() {
        // Rendered unified directly inside OverlayWindow (Option 1)
        hideOverlay()
    }

    func updateStreamingText(_ accumulatedText: String) {
        // Rendered unified directly inside OverlayWindow (Option 1)
    }

    func finishStreaming(spokenText: String? = nil) {
        // Rendered unified directly inside OverlayWindow (Option 1)
    }

    func hideOverlay() {
        autoHideWorkItem?.cancel()
        autoHideWorkItem = nil
        stopCursorTracking()
        overlayViewModel.isShowingResponse = false
        overlayViewModel.streamingResponseText = ""
        overlayPanel?.orderOut(nil)
    }

    // MARK: - Private

    private func createOverlayPanelIfNeeded() {
        if overlayPanel != nil { return }

        let initialFrame = NSRect(x: 0, y: 0, width: overlayMaxWidth, height: 40)
        let responseOverlayPanel = NSPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        responseOverlayPanel.level = .screenSaver
        responseOverlayPanel.isOpaque = false
        responseOverlayPanel.backgroundColor = .clear
        responseOverlayPanel.hasShadow = false
        responseOverlayPanel.hidesOnDeactivate = false
        responseOverlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        responseOverlayPanel.isExcludedFromWindowsMenu = true

        let hostingView = NSHostingView(
            rootView: CompanionResponseOverlayView(viewModel: overlayViewModel)
                .frame(maxWidth: overlayMaxWidth)
                .allowsHitTesting(false)
        )
        hostingView.frame = initialFrame
        responseOverlayPanel.contentView = hostingView
        // In AppKit, setting contentView resets ignoresMouseEvents to false.
        // MUST explicitly set to true afterwards to ensure click-through & notch hover.
        responseOverlayPanel.ignoresMouseEvents = true

        overlayPanel = responseOverlayPanel
    }

    private func startCursorTracking() {
        cursorTrackingTimer?.invalidate()
        // 60fps cursor tracking scheduled on .common mode so it tracks even during key events
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.repositionPanelNearCursor()
        }
        RunLoop.main.add(timer, forMode: .common)
        cursorTrackingTimer = timer
    }

    private func stopCursorTracking() {
        cursorTrackingTimer?.invalidate()
        cursorTrackingTimer = nil
    }

    private func repositionPanelNearCursor() {
        guard let overlayPanel else { return }

        let mouseLocation = NSEvent.mouseLocation
        let panelSize = overlayPanel.frame.size
        let currentScreen = screenContainingPoint(mouseLocation)
        let visibleFrame = currentScreen.visibleFrame

        // Position the panel to the right of and slightly below the cursor.
        // In macOS screen coordinates (Cocoa), Y increases upward, so "below" means
        // subtracting from the cursor Y.
        var panelOriginX = mouseLocation.x + cursorOffsetX
        var panelOriginY = mouseLocation.y - cursorOffsetY - panelSize.height

        // 1. If overflowing right edge, flip to the left of the cursor
        if panelOriginX + panelSize.width > visibleFrame.maxX - 16 {
            panelOriginX = mouseLocation.x - cursorOffsetX - panelSize.width
        }

        // 2. If overflowing bottom edge (dock area), flip above the cursor
        if panelOriginY < visibleFrame.minY + 16 {
            panelOriginY = mouseLocation.y + cursorOffsetY
        }

        // 3. If overflowing top edge (menu bar / notch area), push below the cursor
        if panelOriginY + panelSize.height > visibleFrame.maxY - 16 {
            panelOriginY = mouseLocation.y - cursorOffsetY - panelSize.height
        }

        // 4. Final strict clamp within visible frame boundaries
        panelOriginX = max(visibleFrame.minX + 8, min(panelOriginX, visibleFrame.maxX - panelSize.width - 8))
        panelOriginY = max(visibleFrame.minY + 8, min(panelOriginY, visibleFrame.maxY - panelSize.height - 8))

        overlayPanel.setFrameOrigin(CGPoint(x: panelOriginX, y: panelOriginY))
    }

    private func resizePanelToFitContent() {
        guard let overlayPanel, let contentView = overlayPanel.contentView else { return }

        let fittingSize = contentView.fittingSize
        let newWidth = max(50, min(fittingSize.width, overlayMaxWidth))
        let maxScreenHeight = screenContainingPoint(NSEvent.mouseLocation).visibleFrame.height - 100
        let newHeight = max(32, min(fittingSize.height, maxScreenHeight))
        let newSize = CGSize(width: newWidth, height: newHeight)

        // Set content size directly without destructive frame.origin.y mutations
        overlayPanel.setContentSize(newSize)
        contentView.frame = NSRect(origin: .zero, size: newSize)

        // Instantly recalculate position so the bubble remains glued to the cursor
        repositionPanelNearCursor()
    }

    private func fadeOutAndHide() {
        guard let overlayPanel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            overlayPanel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.hideOverlay()
            }
        })
    }

    private func screenContainingPoint(_ point: CGPoint) -> NSScreen {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

// MARK: - SwiftUI View

struct CompanionResponseOverlayView: View {
    @ObservedObject var viewModel: CompanionResponseOverlayViewModel

    var body: some View {
        if viewModel.isShowingResponse {
            Text(viewModel.streamingResponseText.isEmpty ? "..." : viewModel.streamingResponseText)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(DS.Colors.textPrimary)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DS.Colors.surface1.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DS.Colors.borderSubtle.opacity(0.5), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
                )
        }
    }
}
