//
//  StepPolicyRegistry.swift
//  boringNotch (Izanotchy)
//
//  Step Policy Protocol & Registry: Routes atomic action planning to intent-specific modular policies.
//  Zero Linguistic Prompt Injections — Single Responsibility Architecture.
//

import Foundation

public protocol StepPolicy: Sendable {
    func buildInstructions(appName: String, targetIndexStr: String) -> String
}

public enum StepPolicyRegistry: Sendable {
    public static func policy(for intentType: String) -> StepPolicy {
        switch intentType.lowercased() {
        case "inspect", "read", "search":
            return InspectStepPolicy()
        case "compose", "send":
            return ComposeStepPolicy()
        default:
            return GeneralStepPolicy()
        }
    }
}

public struct GeneralStepPolicy: StepPolicy {
    public init() {}

    public func buildInstructions(appName: String, targetIndexStr: String) -> String {
        return """
        You are an on-device AFM Planner for macOS. Plan the single next UI action in \(appName).
        Available physical actionTypes: "click", "right_click", "scroll_up", "scroll_down", "press_and_hold", "type", "read", "done".
        Screen observation is structured in JSON (topBar, sidebar, listItems, previewPane).
        General visual rules:
        - Do NOT use internal JSON paths (e.g. "listItems[1].content") as targetElement or subGoal. Always use real visual element names (e.g. "first item in list", "recipient field", "confirm button").
        - If an active modal, dialog, or draft overlay blocks access to the intended workspace, close or switch away from it first.
        - If the requested item or information is already clearly observed and extracted: plan actionType: "done", isFinished: true.
        - Identify the target element described in the goal.
        - If target element is not visible: use "scroll_down" or "scroll_up" on the container.
        - If fields are empty or text input is required: click the relevant input field and use "type" with textToType.
        - If target action requires primary execution: click the confirm, submit, or primary action control.
        Output ONLY a JSON object matching this schema:
        {"thought":"...","subGoal":"...","targetElement":"...","actionType":"click|right_click|scroll_up|scroll_down|press_and_hold|type|read|done","textToType":null,"isFinished":false}
        """
    }
}
