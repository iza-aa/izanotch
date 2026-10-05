import ClickyFoundation
//
//  ModelTurnResult.swift
//  izaNotch
//
//  Universal AI Model Turn Result & Tool Calling Data Contract.
//  Decoupled from third-party vendor naming (Claude/Anthropic).
//

import Foundation

public struct ModelToolCall: Sendable {
    public let id: String
    public let name: String
    public let arguments: [String: Any]

    public init(id: String, name: String, arguments: [String: Any] = [:]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

public struct ModelTurnResult: Sendable {
    public let text: String
    public let toolCalls: [ModelToolCall]
    public let stopReason: String?
    public let duration: TimeInterval

    public init(
        text: String,
        toolCalls: [ModelToolCall] = [],
        stopReason: String? = nil,
        duration: TimeInterval = 0
    ) {
        self.text = text
        self.toolCalls = toolCalls
        self.stopReason = stopReason
        self.duration = duration
    }
}

// MARK: - Compatibility Aliases for Smooth Migration
public typealias ClaudeToolCall = ModelToolCall
public typealias ClaudeTurnResult = ModelTurnResult
