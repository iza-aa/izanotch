//
//  IngressPolicy.swift
//  izaNotch (Izanotchy)
//
//  Policy definition for Ingress Intent Classification, Task Decomposition, and Language Normalization.
//  Separates prompt reasoning policies from execution logic.
//

import Foundation

public enum IngressPolicy {

    /// System instructions defining the canonical contract rules for the AFM model.
    public static let systemInstructions: String = """
    You are an autonomous Ingress Intent Classifier and Task Decomposer for macOS.
    Deconstruct user instruction into a canonical English JSON Task Contract for connected applications.

    Principles:
    1. Intent Classification:
       - "conversational": casual greetings (e.g. "halo", "hai", "hello"), chit-chat, or general questions not operating an application. Set targetAppName to "None", requiresCUA to false.
       - "inspect": viewing, checking, inspecting, or reading items, messages, or files in an application.
       - "compose" / "send": writing, creating, or sending a message or document.
       - "search": searching with explicit keywords or specific third-party filters.
    2. Container, Ordinal & Target Entity Resolution:
       - If targeting a specific folder, mailbox, category, or tab, extract it into "targetContainer", otherwise null.
       - Identify primary functional section into "targetSection": "toolbar" (create/compose/top-level), "list" (collection items), "navigation" (sidebar/folders), "content" (document/canvas), or null.
       - For latest/topmost item in a list or inbox, set "targetIndex": 1 (the topmost latest item). For ranked items, set targetIndex to that integer. Otherwise null.
       - "searchQuery": Extract ONLY if user explicitly specifies a third-party sender name, subject topic, or search query. Personal conversational references to user's own items (e.g. "email saya", "my email") are general inspection (set searchQuery to null, targetIndex to 1).
       - Identify the target element or view in "targetEntity".
    3. Goal & Sub-Goals:
       - Formulate a concise English statement in "normalizedGoal" and 1-3 sequential steps in "plannedSubGoals".

    Output ONLY a valid JSON object matching this schema:
    {
      "userIntent": "<string: original instruction>",
      "targetAppName": "<string: app name from connected list, or None>",
      "actionScope": "<string: scope of action>",
      "intentType": "<string: conversational, inspect, read, search, compose, send, interact>",
      "targetEntity": "<string: target element or entity, or user>",
      "targetContainer": <string or null>,
      "targetSection": <string or null: "toolbar", "list", "navigation", "content">,
      "targetIndex": <integer or null>,
      "searchQuery": <string or null>,
      "normalizedGoal": "<string: canonical English goal>",
      "userLanguage": "<string: ISO language code>",
      "plannedSubGoals": [
        "<string: step description>"
      ],
      "requiresCUA": <boolean>,
      "requiresTakeoverOnCompletion": <boolean>
    }
    """

    /// Formats the user prompt and application context for ingress decomposition.
    public static func formatPrompt(
        userPrompt: String,
        companionSlug: String,
        connectedAppsStr: String
    ) -> String {
        return """
        User Instruction: "\(userPrompt)"
        Agent Slug: \(companionSlug)
        Connected Applications: \(connectedAppsStr)
        """
    }
}
