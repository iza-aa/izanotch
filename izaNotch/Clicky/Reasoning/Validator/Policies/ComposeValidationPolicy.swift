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
        Verification Rules:
        - Verify that required content (recipient, subject, message body) actually appears in the screen Observation, not merely claimed in Steps. If form fields or body are still empty, set isDone: false.
        - Accept multilingual equivalence: the user goal may be in Indonesian (e.g. "sistem berhasil dibuat") or English ("system was created" / "system has been created"). If either language or semantic equivalent is present in the fields, consider the content verified!
        - If user goal was to send or submit content: mark requiresTakeover: true ONLY when all required fields (recipient, subject, message body) have actually been filled. If creation is still underway or fields are empty, keep requiresTakeover: false and isDone: false.
        - If creation or submission was completely finished: mark isDone: true and requiresTakeover: false.
        {"isDone":true,"requiresTakeover":false,"systemState":"<factual_state_summary>","extractedData":"<extracted_content_summary>"}
        """
    }
}
