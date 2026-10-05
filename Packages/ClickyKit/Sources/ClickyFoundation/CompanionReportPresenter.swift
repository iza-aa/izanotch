//
//  CompanionReportPresenter.swift
//  boringNotch
//
//  Capability protocol decoupling domain services (FuturesScout, Astronacci)
//  from CompanionManager presenter state.
//

import Foundation

@MainActor
public protocol CompanionReportPresenter: AnyObject {
    func setIntermediateStatusText(_ text: String)
    func speakAndReportText(_ text: String, speechNarrative: String?) async
}

@MainActor
public enum CompanionReportPresenterRegistry {
    public static weak var shared: CompanionReportPresenter? = nil
}
