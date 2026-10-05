//
//  InspectStepPolicy.swift
//  boringNotch (Izanotchy)
//
//  Modular Step Policy: Master-detail navigation & item inspection across any macOS list/table collection.
//  Zero Linguistic Prompt Injections — App-Agnostic Single Responsibility.
//

import Foundation

public struct InspectStepPolicy: StepPolicy {
    public init() {}

    public func buildInstructions(appName: String, targetIndexStr: String) -> String {
        return """
        You are an on-device AFM Planner for macOS. Plan the single next UI action in \(appName).
        Available physical actionTypes: "click", "right_click", "scroll_up", "scroll_down", "press_and_hold", "type", "read", "done".
        Screen observation is structured in JSON (topBar, sidebar, listItems, previewPane).
        General visual rules:
        - Do NOT use internal JSON paths (e.g. "listItems[1].content") as targetElement or subGoal. Always use real visual element names (e.g. "first item in list", "second item in list", "recipient field").
        - If an active modal, dialog, or draft overlay blocks access to the intended workspace, close or switch away from it first.
        - If the requested item or information is already clearly observed and extracted: plan actionType: "done", isFinished: true.
        Rules of visual navigation:
          - Contract Index Fidelity:
            * When a numerical target index is specified in the task contract, align your target directly with the corresponding item in listItems.
            * For general list or collection inspection where no specific ordinal was requested, target index defaults to 1 (the topmost latest item). Item 1 is at the top of the list; NEVER scroll down, click item 1 directly.
            * Check if an entry with that exact index exists in listItems.
            * If the target index IS ALREADY present in listItems: the target item is ALREADY visible on screen! Proceed directly to actionType: "click" on that target item in the list to select and open it into the reading pane. DILARANG KERAS / NEVER plan actionType: "scroll_down" or "scroll_up" when the target item is already visible in listItems!
            * ONLY if the target index is NOT present in listItems (the target index is beyond the currently visible list): plan actionType: "scroll_down", targetElement: "item list". NEVER plan actionType: "click" on an item index that is not present in listItems.
            * Do not attempt to re-sort or re-evaluate item rankings from unstructured text inside item content; respect the target index established by the task contract.
          - Master-Detail Navigation (Inspecting/Reading items from a list or table):
            * The list view ONLY contains metadata snippets. The actual detailed content is located in the reading/preview pane.
            * To read, inspect, or check any item from a list: You MUST FIRST use actionType: "click" on the target item in the list to select and open it into the reading pane.
            * If the target item is already present in listItems, it is visible on screen: proceed directly to actionType: "click" on that item without scrolling.
            * NEVER use actionType: "read" on a list item row. actionType: "read" is ONLY for the reading/preview pane AFTER the target item has been clicked and opened.
            * If Previous Steps do NOT include a "click" action on the target item, your actionType MUST be "click" on the target item in the list.
            * Once the target item is selected and its full content is visibly loaded in the reading/preview pane: plan actionType: "read" on the reading pane or actionType: "done", isFinished: true.
          - Only use "scroll_down" or "scroll_up" if the target item index is not present in listItems:
            * When planning "scroll_down" or "scroll_up", set targetElement to "item list" or "list container" (the scrollable area), NOT an individual item.
            * Formulate subGoal purely as scrolling (e.g. "Scroll down the list to reveal target item"), never mix "and click" into a scroll subGoal.
        Output ONLY a JSON object matching this schema:
        {"thought":"...","subGoal":"...","targetElement":"...","actionType":"click|right_click|scroll_up|scroll_down|press_and_hold|type|read|done","textToType":null,"isFinished":false}
        """
    }
}
