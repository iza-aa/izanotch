# INTENT_SPEC.md — Canonical Task Intent Specifications

<!-- Single Source of Truth for Autonomous Reasoning Intents across all macOS Applications -->

## 🌐 1. Universal & App-Agnostic Design Philosophy
Clicky/Izanotchy operates across ANY macOS application (e.g. Mail, Notes, Reminders, Finder, Safari, Calendar, Telegram, TradingView).
All intent classifications, target entities, and sub-goals MUST remain 100% abstract and app-agnostic.

---

## 🧭 2. Canonical Intent Taxonomy

| `intentType` | Domain Semantics | Applicable Applications | Expected Output / Behavior |
| :--- | :--- | :--- | :--- |
| `inspect` / `read` | Viewing or extracting details from an item in a list or collection | Mail (emails), Notes (notes), Reminders (todos), Finder (files), Telegram (chats) | Master-detail click to preview pane; extract factual metadata/body |
| `search` | Filtering collection items with an explicit query | Any app with a search field or filter bar | Focus search field, type query, wait for filtered items |
| `compose` / `create` | Creating a new document, record, or message from scratch | Notes (new note), Mail (new draft), Reminders (new item), Terminal (new window) | Fresh blank canvas check; sequential typing across fields |
| `send` / `submit` | Executing primary confirmation or submitting formed content | Form submissions, message dispatch, transaction confirmation | Human takeover check (`requiresTakeoverOnCompletion`) |
| `interact` | General UI action (toggling menus, clicking buttons) | Any application interface | Targeted UI element click or hotkey |
| `conversational` | Direct communication with user (no app manipulation) | Companion chat | Direct synthesized answer in `userLanguage` |

---

## 🔒 3. Canonical Invariants per Intent

### 1. `inspect` / `read` Invariants:
1. **Target Index Fidelity**: Numerical ordinals ("pertama", "second", "ke-3") resolve to a 1-based integer index (`targetIndex`). If unstated in general collections, defaults to `1` (topmost item).
2. **Master-Detail Flow**: List items only contain metadata rows. Full body is located in the preview pane. The agent MUST click the item before reading.
3. **Observation Focus**: Observes only the clicked row + loaded preview pane. Zero full-screen JSON dumps.

### 2. `compose` / `create` Invariants:
1. **Cognitive Provenance**: Never type into unrequested preexisting draft content. Click 'create/new' to ensure a blank canvas.
2. **Sequential Typing**: Input fields are filled one-by-one via `type` action tool.

### 3. `send` / `submit` Invariants:
1. **Autonomous Safety Gate**: Primary submit actions that send real data externally or perform destructive changes require explicit human takeover (`requiresTakeover: true`).
