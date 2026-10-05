//
//  ClickyFunctionToolRegistry.swift
//  boringNotch
//
//  Central Registry for xAI-compatible Function Calling Tools
//  Thread-safe catalog for exporting JSON Schemas to LLMs and resolving tool executors.
//

import Foundation

public final class ClickyFunctionToolRegistry: @unchecked Sendable {
    public static let shared = ClickyFunctionToolRegistry()
    
    private let lock = NSLock()
    private var toolsMap: [String: ClickyFunctionTool] = [:]
    
    private init() {
        // Register core built-in tools: get_crypto_market_analysis, workspace_file_operation
        register(tool: GetCryptoMarketAnalysisTool())
        register(tool: WorkspaceFileOperationTool())
    }
    
    /// Registers a new function tool into the central registry
    public func register(tool: ClickyFunctionTool) {
        lock.lock()
        defer { lock.unlock() }
        toolsMap[tool.name] = tool
        ClickyLogger.info("[TOOL_REGISTRY]", "Registered tool: '\(tool.name)' (Category: \(tool.category.rawValue))")
    }
    
    /// Retrieves a tool by its unique name
    public func tool(named name: String) -> ClickyFunctionTool? {
        lock.lock()
        defer { lock.unlock() }
        return toolsMap[name]
    }
    
    /// Returns all registered tools
    public func allTools() -> [ClickyFunctionTool] {
        lock.lock()
        defer { lock.unlock() }
        return Array(toolsMap.values)
    }
    
    /// Returns all tools filtered by category
    public func tools(for category: ClickyToolCategory) -> [ClickyFunctionTool] {
        lock.lock()
        defer { lock.unlock() }
        return toolsMap.values.filter { $0.category == category }
    }
    
    /// Exports all registered tools as an array of standard xAI / OpenAI function schemas
    public func exportXAISchemas() -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return toolsMap.values.map { $0.toXAISchema() }
    }
}
