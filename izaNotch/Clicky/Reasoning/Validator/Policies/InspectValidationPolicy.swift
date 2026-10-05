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
        For inspecting or checking an item from a list or table:
          - Target Index Presence Check:
            * The task is NOT done (isDone: false) unless an entry matching the target index (index \(targetIndexStr)) is present in listItems AND that item has been clicked in executed Steps.
            * DILARANG KERAS / NEVER declare the task complete or report item content after a preparatory scroll action.
          - Reading Pane Prerequisite:
            * the task is ONLY accomplished (isDone: true) AFTER the target item was clicked and its content/message is visible in the preview/reading pane.
            * If the reading pane still displays an unrelated previous item or is empty, keep isDone: false.
            * The reported content in extractedData MUST strictly describe the content displayed in the preview/reading pane for the clicked target item. NEVER hallucinate or report text from an unrelated item (such as item 1).
        Output ONLY a valid JSON object matching this schema:
        {"isDone":true,"requiresTakeover":false,"systemState":"brief state summary","extractedData":"factual data extracted"}
        """
    }
}
