//
//  ClickyDefaultsKeys.swift
//  ClickyFoundation
//
//  Defaults keys used across ClickyKit targets.
//

import Foundation
import Defaults

public extension Defaults.Keys {
    static let didClearLegacyURLCacheV1 = Key<Bool>("didClearLegacyURLCache_v1", default: false)
    
    // MARK: GitHub Activity
    static let githubUsername = Key<String>("githubUsername", default: "")
    static let githubPAT = Key<String>("githubPAT", default: "")
    
    // MARK: Antigravity Accounts
    static let activeAntigravityEmail = Key<String>("activeAntigravityEmail", default: "rezkyhaikal3@gmail.com")
    
    // MARK: Antigravity AI Bridge
    static let autoStartAntigravityBridge = Key<Bool>("autoStartAntigravityBridge", default: true)
    static let antigravityBridgePort = Key<Int>("antigravityBridgePort", default: 8080)
    
    // MARK: Cursor Assistant
    static let cursorAssistantEnabled = Key<Bool>("cursorAssistantEnabled", default: true)
    static let cursorAssistantVoiceEnabled = Key<Bool>("cursorAssistantVoiceEnabled", default: true)
    static let cursorAssistantVoiceOutputEnabled = Key<Bool>("cursorAssistantVoiceOutputEnabled", default: true)
    static let cursorAssistantAvatarStyle = Key<String>("cursorAssistantAvatarStyle", default: "pointer")
    static let cursorAssistantSoundEnabled = Key<Bool>("cursorAssistantSoundEnabled", default: true)
    static let cursorAssistantShowSubtitles = Key<Bool>("cursorAssistantShowSubtitles", default: true)
    static let anthropicApiKey = Key<String>("anthropicApiKey", default: "")
    static let geminiApiKey = Key<String>("geminiApiKey", default: "")
    static let selectedAIModel = Key<String>("selectedAIModel", default: "gemini-3.8-flash")
    static let selectedAIAssistant = Key<String>("selectedAIAssistant", default: "Siri AI (AFM)")
    
    // MARK: Proactive Notch & Floating Companion (HeyClicky Integration)
    static let proactiveNotchSuggestionsEnabled = Key<Bool>("proactiveNotchSuggestionsEnabled", default: true)
    static let floatingCompanionSphereEnabled = Key<Bool>("floatingCompanionSphereEnabled", default: true)
    static let alwaysAllowComputerUse = Key<Bool>("alwaysAllowComputerUse", default: false)
    
    // MARK: Work & Agents Autonomy
    static let agentFolderPath = Key<String>("agentFolderPath", default: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path)
    static let autoApproveExtraUsage = Key<Bool>("autoApproveExtraUsage", default: false)
    static let suggestAgentTasks = Key<Bool>("suggestAgentTasks", default: true)
    static let connectedIntegrationsJSON = Key<String>("connectedIntegrationsJSON", default: "[]")
    
    // MARK: TradingView & Chart Analyst
    static let autoDrawFibonacciOverlay = Key<Bool>("autoDrawFibonacciOverlay", default: true)
    static let autoCollapseTradingViewSidebar = Key<Bool>("autoCollapseTradingViewSidebar", default: true)
    
    // MARK: Futures Scout Background Watcher
    static let futuresScoutWatcherEnabled = Key<Bool>("futuresScoutWatcherEnabled", default: false)
    static let futuresScoutMonitoredSymbols = Key<[String]>("futuresScoutMonitoredSymbols", default: [])
}
