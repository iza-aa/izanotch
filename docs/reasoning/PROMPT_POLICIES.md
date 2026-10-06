# PROMPT_POLICIES.md — Modular Prompt Policies for 3B AFM Models

<!-- Specification of Single-Responsibility Modular Prompts for Apple Foundation Models (~3B) -->

## 🧠 1. Cognitive Architecture of 3B On-Device Models
On-device models (e.g. Apple Foundation Models ~3B parameters) have limited effective attention windows compared to massive cloud LLMs:
- **Attention Overload**: Bundling list-navigation, form-composition, and validation rules into one monolithic prompt causes attention drift and rule hallucination.
- **Few-Shot Overfitting**: Hardcoding literal numbers (e.g. "item 10") causes the model to fixate on that number instead of abstract targets.
- **Negative Constraint Failure**: Models struggle with complex negative conditions ("do not mark complete if last step was scroll").

---

## ⚡ 2. The Deterministic Short-Circuit Rule
**Never force a 3B model to evaluate boolean invariants that Swift can evaluate with 100% certainty.**

### Example: Preparatory Scrolling Guard
In [`TaskEgressValidator.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift):
```swift
if let lastStep = performedSteps.last?.lowercased(),
   lastStep.contains("scroll_down") || lastStep.contains("scroll_up") || lastStep.contains("scroll") {
    // Scrolling is strictly preparatory to reveal items.
    // Short-circuit immediately in Swift: zero tokens, zero latency, zero hallucination risk!
    return TaskStateEvaluation(isDone: false, requiresTakeover: false, systemState: "Navigating list viewport", extractedData: "")
}
```

---

## 🧩 3. Single-Responsibility Prompt Modularization

Both [`TaskStepPlanner`](file:///Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift) and [`TaskEgressValidator`](file:///Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift) construct prompt instructions dynamically using `intentType`:

### 1. `InspectPromptPolicy` (`intentType: inspect | read | search`)
- Focuses strictly on list/table presence check, master-detail selection, and preview pane extraction.
- Excludes all form composition, input field typing, and submission rules.

### 2. `ComposePromptPolicy` (`intentType: compose | send`)
- Focuses strictly on blank canvas provenance, sequential field typing, and human takeover gates.
- Excludes all list scrolling, ordinal indexing, and master-detail rules.

### 3. `GeneralPolicy` (`intentType: interact | generic`)
- Minimalist fallback for basic UI interaction.
