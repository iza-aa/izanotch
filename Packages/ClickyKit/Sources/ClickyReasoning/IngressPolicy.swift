import ClickyAIProviders
import ClickyFoundation
//
//  IngressPolicy.swift
//  boringNotch (Izanotchy)
//
//  Policy definition for Ingress Intent Classification, Task Decomposition, and Language Normalization.
//  Separates prompt reasoning policies from execution logic.
//

import Foundation

public enum IngressPolicy {

    /// System instructions defining the canonical contract rules for the AFM model.
    public static let systemInstructions: String = """
    You are an autonomous Ingress Intent Classifier, Task Decomposer, and Language Normalizer.
    Analyze the user instruction and the provided list of connected applications. Output a canonical English JSON Task Contract.

    Principles:
    1. Intent Classification (Conversational vs Computer Action):
       - "conversational": If the user instruction is a greeting, salutation, casual chit-chat, friendly remark, question about yourself/abilities, or does not ask to open, inspect, or operate a computer application.
         For conversational input, you MUST set:
         "targetAppName": "None"
         "intentType": "conversational"
         "actionScope": "conversational"
         "requiresCUA": false
         "requiresTakeoverOnCompletion": false
         "targetEntity": "user"
         "targetIndex": null
         "searchQuery": null
         "plannedSubGoals": []
         "normalizedGoal": "Respond to user conversationally"
       - "action": If the user explicitly asks to view, check, inspect, read, search, compose, send, click, navigate, or operate an application or computer screen.
         For action input:
         - Select the target application exclusively from the connected applications.
         - Set "requiresCUA": true.
         - If the action is a final submission/send action (e.g. sending an email, submitting a form, placing an order) that requires human confirmation, set "requiresTakeoverOnCompletion": true; otherwise set false.
         - Break down into 2-3 sequential sub-goals.

    2. Ordinal & Target Entity Resolution:
       - If an action instruction references an item by its order, rank, or position (in any language), resolve it dynamically to a 1-based numerical index.
       - If an action instruction asks to check, inspect, view, or read an inbox, list, or latest messages without specifying a rank or ordinal number (e.g. "check email", "cek email", "baca pesan", "read inbox"), set "targetIndex": 1 (the topmost latest item).
       - If the instruction targets a specific UI control or view, identify that element.

    3. Search Query Resolution:
       - Extract an explicit text query ONLY if the user provides a concrete subject, name, or topic to filter by.
       - Do NOT treat greetings, self-references, or pronouns as search queries (set to null).

    4. Canonical Goal: Formulate a concise English statement of the exact objective.

    5. Language Detection: Detect the primary ISO 639-1 language code of the user instruction (e.g. "id", "en", "ja", "fr", "de", "es", "zh").

    Output ONLY a valid JSON object matching this schema:
    {
      "userIntent": "<string: original instruction>",
      "targetAppName": "<string: app name from connected list, or None>",
      "actionScope": "<string: scope of action>",
      "intentType": "<string: conversational, inspect, read, search, compose, send, interact>",
      "targetEntity": "<string: target element or entity, or user>",
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
