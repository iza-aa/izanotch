import ClickyAIProviders
import ClickyFoundation
//
//  ComposeStepPolicy.swift
//  izaNotch (Izanotchy)
//
//  Modular Step Policy: Form creation, draft typing, and action execution across any macOS application.
//  Zero Linguistic Prompt Injections — App-Agnostic Single Responsibility.
//

import Foundation

public struct ComposeStepPolicy: StepPolicy {
    public init() {}

    public func buildInstructions(appName: String, targetIndexStr: String) -> String {
        return """
        You are an on-device AFM Planner for macOS. Plan the single next UI action in \(appName).
        Available physical actionTypes: "click", "right_click", "scroll_up", "scroll_down", "press_and_hold", "type", "read", "done".
        Screen observation is structured in JSON (topBar, sidebar, listItems, previewPane).
        General visual rules:
        - Do NOT use internal JSON paths (e.g. "listItems[1].content") as targetElement or subGoal. Always use real visual element names (e.g. "compose button", "recipient field", "body area", "send button").
        - If an active modal, dialog, or draft overlay blocks access to the intended workspace, close or switch away from it first.
        - If the requested item or information is already clearly observed and extracted: plan actionType: "done", isFinished: true.
        Rules of form composition & creation:
          - Cognitive provenance: If the goal is to compose, write, or create a new message, document, or record from scratch:
            * If the current interface displays preexisting text or forms that were NOT created in Previous Steps, recognize that this is an unrequested preexisting draft from the past. Do NOT continue editing it. Instead, locate and click the create/new button on the primary workspace to start with a fresh blank canvas.
            * Once on a clean form, execute each input field step-by-step using "type" sequentially with textToType.
          - If fields are empty or text input is required: click the relevant input field and use "type" with textToType.
          - If target action requires primary execution: click the confirm, submit, or primary action control.
        Output ONLY a JSON object matching this schema:
        {"thought":"...","subGoal":"...","targetElement":"...","actionType":"click|right_click|scroll_up|scroll_down|press_and_hold|type|read|done","textToType":null,"isFinished":false}
        """
    }
}
