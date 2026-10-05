//
//  FloatingCompanionRailWindow.swift
//  boringNotch
//
//  Created for Izanotchy - Multi-Agent Desktop System
//

import AppKit
import SwiftUI

public final class FloatingCompanionRailPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
    }
}

public final class RailHostingView<Content: View>: NSHostingView<Content> {
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let hitView = super.hitTest(point)
        let hasPopover = CompanionRosterStore.shared.activePopoverCompanionId != nil
        let hasActiveMascots = CompanionRosterStore.shared.allCompanions.contains {
            CompanionRosterStore.shared.presentedRailCompanionIds.contains($0.id) &&
            !CompanionRosterStore.shared.dismissedCompanionIds.contains($0.id)
        }

        // If no popover and no active mascots on the rail: 100% click-through!
        if !hasPopover && !hasActiveMascots {
            return nil
        }

        if !hasPopover {
            // Only mascots on the right: only clicks/hover on the rightmost 76pt are interactive
            if point.x < bounds.width - 76 {
                return nil
            }
        } else {
            // Popover is showing: card lives on the left of mascots (card + mascot ~380pt wide, ~400pt tall)
            if point.y < bounds.height - 400 || point.x < bounds.width - 390 {
                return nil
            }
        }
        return hitView
    }
}

@MainActor
public final class FloatingCompanionRailWindowManager: ObservableObject {
    public static let shared = FloatingCompanionRailWindowManager()
    
    private var window: FloatingCompanionRailPanel?
    @Published public private(set) var isVisible: Bool = false
    
    private init() {}
    
    public func start() {
        showRail()
    }
    
    public func showRail() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        
        let width: CGFloat = 440
        let height: CGFloat = 580
        // Dock to right edge: rail sits at visibleFrame.maxX - 76, popover extends to left
        let originX = visibleFrame.maxX - width - 2
        let originY = visibleFrame.maxY - height - 8
        
        let frame = NSRect(x: originX, y: originY, width: width, height: height)
        
        if window == nil {
            let panel = FloatingCompanionRailPanel(contentRect: frame)
            let hostingView = RailHostingView(
                rootView: HStack(alignment: .top) {
                    Spacer()
                    FloatingCompanionRailView()
                }
                .frame(width: width, height: height, alignment: .topTrailing)
            )
            panel.contentView = hostingView
            panel.setFrame(frame, display: true)
            self.window = panel
        } else {
            window?.setFrame(frame, display: true)
        }
        
        window?.orderFront(nil)
        isVisible = true
    }
    
    public func hideRail() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    public func toggleRail() {
        if isVisible {
            hideRail()
        } else {
            showRail()
        }
    }
}
