//
//  DomainActionDispatcher.swift
//  izaNotch
//
//  Capability protocol decoupling CUA physical executor from concrete domain dispatchers
//  such as TradingViewActionDispatcher.
//

import Foundation

@MainActor
public protocol DomainActionDispatcher: AnyObject {
    func executeDomainAction(payload: ComputerUseActionPayload) async
}

@MainActor
public enum DomainActionDispatcherRegistry {
    public static weak var shared: DomainActionDispatcher? = nil
}
