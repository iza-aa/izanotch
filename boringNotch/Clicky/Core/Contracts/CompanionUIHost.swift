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
}

@MainActor
public enum CompanionUIHostRegistry {
    public static weak var shared: CompanionUIHost? = nil
}
