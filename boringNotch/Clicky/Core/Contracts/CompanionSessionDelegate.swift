//
//  CompanionSessionDelegate.swift
//  boringNotch
//
//  Capability protocol decoupling Roster (L4) from concrete CompanionManager (L5).
//  Eliminates upward dependencies from ClickyRoster to ClickyAgent.
//

import Foundation

@MainActor
public protocol CompanionSessionDelegate: AnyObject {
    func syncSessionsFromRoster()
    func setActiveCompanion(_ profileId: UUID?)
    func selectSession(id: UUID)
    func markSessionRead(id: UUID)
    func updateSessionDetails(id: UUID)
    func stopCurrentTaskIfActive(id: UUID, companionName: String)
}

@MainActor
public enum CompanionSessionDelegateRegistry {
    public static weak var shared: CompanionSessionDelegate? = nil
}
