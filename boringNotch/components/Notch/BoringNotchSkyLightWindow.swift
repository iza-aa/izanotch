//
//  BoringNotchSkyLightWindow.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-20.
//

import Cocoa
import SkyLightWindow
import Defaults
import Combine
import SwiftUI

extension SkyLightOperator {
    func undelegateWindow(_ window: NSWindow) {
        typealias F_SLSRemoveWindowsFromSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32
        
        let handler = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW)
        guard let SLSRemoveWindowsFromSpaces = unsafeBitCast(
            dlsym(handler, "SLSRemoveWindowsFromSpaces"),
            to: F_SLSRemoveWindowsFromSpaces?.self
        ) else {
            return
        }
        
        // Remove the window from the SkyLight space
        _ = SLSRemoveWindowsFromSpaces(
            connection,
            [window.windowNumber] as CFArray,
            [space] as CFArray
        )
    }
}

class BoringNotchSkyLightWindow: NSPanel {
    private var isSkyLightEnabled: Bool = false
    
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )
        
        configureWindow()
        setupObservers()
    }
    
    private func configureWindow() {
        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        level = .mainMenu + 3
        hasShadow = false
        isReleasedWhenClosed = false
        
        // Force dark appearance regardless of system setting
        appearance = NSAppearance(named: .darkAqua)
        
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
        
        // Apply initial sharing type setting
        updateSharingType()
    }
    
    private func setupObservers() {
        // Listen for changes to the hideFromScreenRecording setting
        Defaults.publisher(.hideFromScreenRecording)
            .sink { [weak self] _ in
                self?.updateSharingType()
            }
            .store(in: &observers)
    }
    
    private func updateSharingType() {
        if Defaults[.hideFromScreenRecording] {
            sharingType = .none
        } else {
            sharingType = .readWrite
        }
    }
    
    func enableSkyLight() {
        if !isSkyLightEnabled {
            SkyLightOperator.shared.delegateWindow(self)
            isSkyLightEnabled = true
        }
    }
    
    func disableSkyLight() {
        if isSkyLightEnabled {
            SkyLightOperator.shared.undelegateWindow(self)
            isSkyLightEnabled = false
        }
    }
    
    private var observers: Set<AnyCancellable> = []
    
    weak var viewModel: BoringViewModel? {
        didSet {
            setupViewModelObservation()
        }
    }
    
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var notchStateCancellable: AnyCancellable?
    
    deinit {
        stopMouseTracking()
    }
    
    func startMouseTracking() {
        guard globalMouseMonitor == nil else { return }
        
        setupViewModelObservation()
        updateMouseInteractivity(at: NSEvent.mouseLocation)
        
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.updateMouseInteractivity(at: NSEvent.mouseLocation)
        }
        
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.updateMouseInteractivity(at: NSEvent.mouseLocation)
            return event
        }
    }
    
    func stopMouseTracking() {
        if let g = globalMouseMonitor {
            NSEvent.removeMonitor(g)
            globalMouseMonitor = nil
        }
        if let l = localMouseMonitor {
            NSEvent.removeMonitor(l)
            localMouseMonitor = nil
        }
        notchStateCancellable?.cancel()
        notchStateCancellable = nil
    }
    
    private func setupViewModelObservation() {
        notchStateCancellable?.cancel()
        guard let vm = viewModel else { return }
        notchStateCancellable = vm.$notchState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMouseInteractivity()
            }
    }
    
    func updateMouseInteractivity(at screenPoint: NSPoint? = nil) {
        // If window is currently hidden (alphaValue == 0.0, e.g. HomeSpace is presented), ignore mouse events completely
        if alphaValue == 0.0 {
            if !ignoresMouseEvents {
                ignoresMouseEvents = true
            }
            return
        }

        guard let vm = viewModel else {
            ignoresMouseEvents = false
            return
        }
        
        // When notch is open, whole 640x210 canvas must be interactive (popovers, media, buttons, etc.)
        if vm.notchState == .open {
            if ignoresMouseEvents {
                ignoresMouseEvents = false
            }
            return
        }
        
        // When notch is closed:
        let mouseLoc = screenPoint ?? NSEvent.mouseLocation
        let winFrame = self.frame
        
        // If mouse is outside our 640x210 window entirely, window can safely ignore mouse events
        guard winFrame.contains(mouseLoc) else {
            if !ignoresMouseEvents {
                ignoresMouseEvents = true
            }
            return
        }
        
        // Inside 640x210 window bounds. Check if mouse is within active closed notch pill:
        let localPoint = NSPoint(x: mouseLoc.x - winFrame.origin.x, y: mouseLoc.y - winFrame.origin.y)
        let activeRect = vm.activeClosedNotchRect
        
        if activeRect.contains(localPoint) {
            // Inside the compact notch pill: MUST accept mouse events for hover, tap to open, and shelf drop!
            if ignoresMouseEvents {
                ignoresMouseEvents = false
            }
        } else {
            // Outside the compact notch pill (over IDE tabs, code editor, browser, etc): MUST ignore mouse events
            // so macOS WindowServer passes 100% of clicks through to the underlying application!
            if !ignoresMouseEvents {
                ignoresMouseEvents = true
            }
        }
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class BoringNotchHostingView<Content: View>: NSHostingView<Content> {
    weak var viewModel: BoringViewModel?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let vm = viewModel else { return nil }

        // When the notch is closed, only the compact notch pill intercepts mouse events.
        // All mouse clicks, hovers, and drags outside the closed notch rect pass straight through to underlying windows/apps!
        if vm.notchState == .closed {
            let activeRect = vm.activeClosedNotchRect
            if !activeRect.contains(point) {
                return nil
            }
            // Return SwiftUI subview if interactive, or fallback to this hosting view so gestures (tap/hover) always trigger reliably
            return super.hitTest(point) ?? self
        }

        return super.hitTest(point)
    }
}
