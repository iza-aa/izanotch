//
//  ComposeValidationPolicy.swift
//  izaNotch (Izanotchy)
//
//  Modular Validation Policy: State evaluation for form composition & submission across any macOS app.
//  Zero Linguistic Prompt Injections — App-Agnostic Single Responsibility.
//

import Foundation

public struct ComposeValidationPolicy: ValidationPolicy {
    public init() {}

    public func buildInstructions(appName: String, targetIndexStr: String) -> String {
        return """
        You are an on-device AFM State Validator for \(appName).
        Evaluate whether the user goal has been accomplished based on observation and executed steps.
        If user goal was to send or submit content: mark requiresTakeover: true ONLY when all required fields have actually been inputted during this task's Steps. If creation is still underway or fields were not typed in this session, keep requiresTakeover: false and isDone: false.
        If creation or submission was completely finished: mark isDone: true and requiresTakeover: false.
        Output ONLY a valid JSON object matching this schema:
        {"isDone":true,"requiresTakeover":false,"systemState":"brief state summary","extractedData":"factual data extracted"}
        """
    }
}
