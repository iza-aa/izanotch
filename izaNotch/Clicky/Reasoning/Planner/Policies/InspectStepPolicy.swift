//
//  InspectStepPolicy.swift
//  izaNotch (Izanotchy)
//
//  Modular Step Policy: Master-detail navigation & item inspection across any macOS list/table collection.
//  Zero Linguistic Prompt Injections — App-Agnostic Single Responsibility.
//

import Foundation

public struct InspectStepPolicy: StepPolicy {
    public init() {}

    public func buildInstructions(appName: String, targetIndexStr: String, targetContainer: String? = nil) -> String {
        let hasCustomContainer = targetContainer != nil && !targetContainer!.isEmpty && targetContainer!.lowercased() != "unspecified"
        
        let containerRule: String
        if hasCustomContainer {
            containerRule = """
            - Universal Container & Navigation Routing:
              * If activeContainer does not match "\(targetContainer!)", open it first: plan actionType: "click", setting targetElement to the exact label in navigationElements (e.g. "\(targetContainer!)"). NEVER target generic container names like "sidebar" or "toolbar"!
              * NEVER plan actionType: "click" on listItems when activeContainer is in the wrong container.
            """
        } else {
            containerRule = """
            - Target Container:
              * Current container is active. Do NOT click sidebar or navigation elements. Focus 100% on listItems.
            """
        }

        return """
        You are an on-device AFM Planner for macOS. Plan the single next UI action in \(appName).
        Screen observation is structured in JSON (activeContainer, navigationElements, listItems, previewPane, viewport).

        Action Planning Rules:
        \(containerRule)
        - Contract Index Fidelity & Exact Item Targeting:
          * Align your target directly with the entry matching target index \(targetIndexStr) in listItems.
          * Respect the target index established by the task contract.
        - Viewport Position & Ordinals:
          * If viewport.isAtTop is false and target is the topmost item, plan actionType: "scroll_up", targetElement: "item list".
        - Item Selection:
          * When target index \(targetIndexStr) is visible in listItems, select it: plan actionType: "click", setting targetElement to the headline or sender snippet from listItems.
          * If target index is greater than visible items, plan actionType: "scroll_down", targetElement: "item list".
        - Reading & Completion:
          * Once target item is selected and its content appears in previewPane: plan actionType: "read" or actionType: "done", isFinished: true.

        Output ONLY a JSON object:
        {"thought":"...","subGoal":"...","targetElement":"...","actionType":"click|scroll_up|scroll_down|read|done","textToType":null,"isFinished":false}
        """
    }
}
