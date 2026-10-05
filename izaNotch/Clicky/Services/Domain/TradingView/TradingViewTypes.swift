//
//  TradingViewTypes.swift
//  izaNotch
//
//  Modular TradingView Data Types & Action Protocol
//  Reusable across multiple companions (Futures Scout, Research Buddy, etc.)
//

import AppKit
import Foundation

public enum TradingViewActionType: String, Codable, Equatable {
    case chain              // Execute a sequence of multiple actions sequentially
    case setupWorkspace     // All-in-one hygiene: Maximize + Close Sidebar + Symbol Alignment
    case timeframe          // Switch timeframe (1, 5, 15, 60, 240, D)
    case symbol             // Switch ticker symbol (BTCUSDT, ETHUSDT)
    case resetScale         // Auto-Scale & Reset Chart View (Option + R)
    case selectTool         // Universal Command Palette (Cmd+K)
    case drawPoints         // Multi-point canvas execution (1-point, 2-point, 3-point)
    case drawWithTool       // Select tool via palette and draw at points
    case addIndicator       // Search and add indicator (/)
    case injectPineScript   // Pine Script v5 Dynamic Generator & Injector
    case clearDrawings      // Clear all drawings on chart
    case closeModal         // Dismiss/Close active modal or popup
    case toggleSidebar      // Toggle Watchlist & Details sidebar (Option + W or button click)
    case maximize           // Maximize TradingView window / Fullscreen chart
}

public struct TradingViewActionPayload: Codable, Equatable {
    public let actionType: TradingViewActionType
    public let toolName: String?
    public let parameter: String?       // Timeframe, symbol, or indicator name
    public let points: [CGPoint]?       // Canvas coordinates (normalized or screen points)
    public let pineScript: String?      // Pine Script v5 source code
    public let subActions: [TradingViewActionPayload]? // Sequential sub-actions for .chain
    public let rawDetails: String

    public init(
        actionType: TradingViewActionType,
        toolName: String? = nil,
        parameter: String? = nil,
        points: [CGPoint]? = nil,
        pineScript: String? = nil,
        subActions: [TradingViewActionPayload]? = nil,
        rawDetails: String = ""
    ) {
        self.actionType = actionType
        self.toolName = toolName
        self.parameter = parameter
        self.points = points
        self.pineScript = pineScript
        self.subActions = subActions
        self.rawDetails = rawDetails
    }
}
