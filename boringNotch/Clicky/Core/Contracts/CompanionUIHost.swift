//
//  CompanionUIHost.swift
//  boringNotch
//
//  Capability protocol decoupling core agent logic from concrete UI Window Managers.
//  Enforces clean downward dependency from ClickyUI (L6) to Foundation (L0).
//

import AppKit
import Foundation

@MainActor
public protocol CompanionUIHost: AnyObject {
    var isHomeSpaceVisible: Bool { get }
    func showHomeSpace()
    func hideHomeSpace()
    func toggleHomeSpace()
    
    var isOverlayVisible: Bool { get }
    func showOverlay()
    func hideOverlay()
    func fadeOutOverlay()
    
    func showConsent(with request: ComputerUseRequest)
    func dismissConsent()
    func hideResponseOverlay()
    
    var activeAccountEmail: String { get }
    var activeAccountPlan: String { get }
}

extension CompanionUIHost {
    public func fadeOutOverlay() {
        hideOverlay()
    }
    
    public func showConsent(with request: ComputerUseRequest) {}
    public func dismissConsent() {}
    public func hideResponseOverlay() {}
    
    public var activeAccountEmail: String { "" }
    public var activeAccountPlan: String { "" }
}

@MainActor
public enum CompanionUIHostRegistry {
    public static weak var shared: CompanionUIHost? = nil
}
