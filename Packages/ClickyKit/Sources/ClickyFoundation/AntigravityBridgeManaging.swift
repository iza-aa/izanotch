//
//  AntigravityBridgeManaging.swift
//  ClickyFoundation
//
//  Capability contract for bridging local Antigravity AI service.
//

import Foundation

@MainActor
public protocol AntigravityBridgeManaging: AnyObject {
    var isRunning: Bool { get }
    func startBridge() async
}
