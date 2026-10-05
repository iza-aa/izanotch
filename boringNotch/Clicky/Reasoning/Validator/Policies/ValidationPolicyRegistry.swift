//
//  ValidationPolicyRegistry.swift
//  boringNotch (Izanotchy)
//
//  Validation Policy Protocol & Registry: Routes state evaluation to intent-specific modular policies.
//  Zero Linguistic Prompt Injections — Single Responsibility Architecture.
//

import Foundation

public protocol ValidationPolicy: Sendable {
    func buildInstructions(appName: String, targetIndexStr: String) -> String
}

public enum ValidationPolicyRegistry: Sendable {
    public static func policy(for intentType: String) -> ValidationPolicy {
        switch intentType.lowercased() {
        case "inspect", "read", "search":
            return InspectValidationPolicy()
        case "compose", "send":
            return ComposeValidationPolicy()
        default:
            return GeneralValidationPolicy()
        }
    }
}

public struct GeneralValidationPolicy: ValidationPolicy {
    public init() {}

    public func buildInstructions(appName: String, targetIndexStr: String) -> String {
        return """
        You are an on-device AFM State Validator for \(appName).
        Evaluate whether the user goal has been accomplished based on observation and executed steps.
        Output ONLY a valid JSON object matching this schema:
        {"isDone":true,"requiresTakeover":false,"systemState":"brief state summary","extractedData":"factual data extracted"}
        """
    }
}
