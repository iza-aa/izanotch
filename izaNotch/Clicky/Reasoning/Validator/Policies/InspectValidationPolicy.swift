//
//  InspectValidationPolicy.swift
//  izaNotch (Izanotchy)
//
//  Modular Validation Policy: State evaluation for list/table inspection & reading across any macOS app.
//  Zero Linguistic Prompt Injections — App-Agnostic Single Responsibility.
//

import Foundation

public struct InspectValidationPolicy: ValidationPolicy {
    public init() {}

    public func buildInstructions(appName: String, targetIndexStr: String) -> String {
        return """
        You are an on-device AFM State Validator for \(appName).
        Evaluate whether the user goal has been accomplished based on observation and executed steps.
        For inspecting an item:
        - Target Item Accomplishment:
          * Task is accomplished (isDone: true) when the entry matching target index \(targetIndexStr) has been opened and its content appears in the reading pane.
          * Set extractedData to the factual data displayed for the clicked target item.
        Output ONLY a valid JSON object:
        {"isDone":true,"requiresTakeover":false,"systemState":"<factual_state_summary>","extractedData":"<extracted_content_summary>"}
        """
    }
}
