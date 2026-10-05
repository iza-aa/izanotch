//
//  ClickyToolDispatcher.swift
//  boringNotch
//
//  Parallel Execution Dispatcher for xAI Function Calling
//  Uses Swift structured concurrency (withTaskGroup) and provides reactive UI execution states.
//

import Foundation
import Combine
import ClickyFoundation

// MARK: - Standard Tool Call Request
public struct ClickyToolCall: Sendable, Codable {
    public let id: String
    public let functionName: String
    public let argumentsJSON: String
    
    public init(id: String, functionName: String, argumentsJSON: String) {
        self.id = id
        self.functionName = functionName
        self.argumentsJSON = argumentsJSON
    }
}

// MARK: - Clicky Tool Dispatcher
public final class ClickyToolDispatcher: ObservableObject, @unchecked Sendable {
    public static let shared = ClickyToolDispatcher()
    
    @MainActor @Published public var currentExecutingToolName: String? = nil
    @MainActor @Published public var isExecuting: Bool = false
    
    private init() {}
    
    /// Dispatches multiple tool calls in parallel using Swift withTaskGroup
    public func dispatch(toolCalls: [ClickyToolCall], context: CompanionExecutionContext) async -> [ClickyToolResult] {
        guard !toolCalls.isEmpty else { return [] }
        
        let toolNames = toolCalls.map { $0.functionName }.joined(separator: ", ")
        ClickyLogger.info("[TOOL_DISPATCHER]", "Dispatching \(toolCalls.count) tool calls in parallel: [\(toolNames)]")
        
        await MainActor.run {
            self.currentExecutingToolName = toolCalls.first?.functionName
            self.isExecuting = true
        }
        
        defer {
            Task { @MainActor in
                self.currentExecutingToolName = nil
                self.isExecuting = false
            }
        }
        
        return await withTaskGroup(of: ClickyToolResult.self) { group in
            for call in toolCalls {
                group.addTask {
                    guard let tool = ClickyFunctionToolRegistry.shared.tool(named: call.functionName) else {
                        ClickyLogger.error("[TOOL_DISPATCHER]", "Tool '\(call.functionName)' not found in registry (callId: \(call.id))")
                        return ClickyToolResult(callId: call.id, name: call.functionName, output: "Error: Tool '\(call.functionName)' not found.", isError: true)
                    }
                    
                    var parsedArgs: [String: Any] = [:]
                    if let data = call.argumentsJSON.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        parsedArgs = json
                    }
                    
                    do {
                        ClickyLogger.info("[TOOL_DISPATCHER]", "Executing tool '\(call.functionName)' (callId: \(call.id))...")
                        let result = try await tool.execute(callId: call.id, arguments: parsedArgs, context: context)
                        ClickyLogger.info("[TOOL_DISPATCHER]", "Tool '\(call.functionName)' completed (isError: \(result.isError))")
                        return result
                    } catch {
                        ClickyLogger.error("[TOOL_DISPATCHER]", "Tool '\(call.functionName)' failed: \(error.localizedDescription)")
                        return ClickyToolResult(callId: call.id, name: call.functionName, output: "Execution error: \(error.localizedDescription)", isError: true)
                    }
                }
            }
            
            var results: [ClickyToolResult] = []
            for await res in group {
                results.append(res)
            }
            return results
        }
    }
}
