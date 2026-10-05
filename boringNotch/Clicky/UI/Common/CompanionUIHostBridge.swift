//
//  CompanionUIHostBridge.swift
//  boringNotch
//
//  Concrete implementation of CompanionUIHost decoupling UI Layer (L6)
//  from Agent Layer (L5) and Foundation (L0).
//

import AppKit
import Foundation

@MainActor
public final class CompanionUIHostBridge: CompanionUIHost {
    public static let shared = CompanionUIHostBridge()
    
    public init() {}
    
    public var isHomeSpaceVisible: Bool {
        HomeSpaceWindowManager.shared.isVisible
    }
    
    public func showHomeSpace() {
        HomeSpaceWindowManager.shared.show()
    }
    
    public func hideHomeSpace() {
        HomeSpaceWindowManager.shared.hide()
    }
    
    public func toggleHomeSpace() {
        HomeSpaceWindowManager.shared.toggle()
    }
    
    public var isOverlayVisible: Bool {
        OverlayWindowManager.shared.isOverlayVisible
    }
    
    public func showOverlay() {
        OverlayWindowManager.shared.showAllOverlays()
    }
    
    public func hideOverlay() {
        OverlayWindowManager.shared.hideOverlay()
    }
}
