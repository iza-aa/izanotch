---
name: clicky-research-report
description: Research a topic, market, competitor set, product, person, or question and deliver the findings, in the chat reply by default, as a Markdown, PDF, DOCX, or CSV file only when the user asked for one. Use for competitor research, market intel, source-backed summaries, web research, research briefs, and shareable reports.
---

# HeyClicky Research Report

Turn research into a clear, finished answer. The chat reply is the deliverable by default: findings as prose, bullets, and markdown tables that the user reads right in the conversation. A file (Markdown, PDF, DOCX, CSV) is made only when the user asked for one or the result genuinely cannot live in a chat message (dozens of rows to sort, something that must be shared or printed as a file). Prefer search, fetch, curl/API access, source files, and local extraction before any GUI/browser work. Use Cua/Computer Use only when the source truly requires logged-in or visible browser interaction and the runtime exposes that capability.

## Use When
- The user asks for research, a report, brief, competitor analysis, market map, list, source summary, or PDF.
- The user asked for the output to be saved, exported, opened, or shared as a file.
- The work needs sources, citations, or tables.

## Do Not Use When
- The user mainly wants to click through a visible website or app; use `cua-driver` only when Computer Use is exposed for that GUI control.
- The user only wants to open/find a previously created report; use `clicky-artifacts`.
- The user asks about private Google Workspace files or email; start with `clicky-google-workspace`.

## Primary Path
1. Restate the research target in operational terms: question, scope, geography/timeframe, and output format.
2. Gather sources with search/fetch/curl/API paths first.
3. Extract facts into a concise outline before writing the answer.
4. Write the findings into the final chat reply: lead with the result, use markdown tables for comparisons and lists of items (creators, competitors, products, options), cite sources inline.
5. Only when the user asked for a file, or the result cannot live in the chat, use internal capabilities:
   - `pdf` and `doc` for report files.
   - `spreadsheet` for large source tables, CSVs, and comparison matrices the user will sort or share.
   - `clicky-artifacts` for final open/reveal/export.
   - `frontend-design` only when the requested output is a website/dashboard/report UI.

## Fallbacks
- Use Cua/Computer Use when sites require interactive pages, login, JavaScript-only content, or visible page inspection and the runtime exposes that capability.
- If provider-backed image, video, or slide generation is requested, report that those provider routes are not shipped in this release unless a real runtime capability is exposed. Do not frame unshipped slide/image routes as retryable auth failures.
- If live web access is blocked, create a grounded report from provided files/screenshots and call out missing live sources.
- If the user did not name an output format, deliver the findings in the chat reply and offer a PDF/DOCX/CSV as a next action instead of producing one unasked.

## Safety
- Cite sources or name source files for factual claims.
- Separate verified facts from inference.
- Do not use GUI browser control for normal research when search/fetch/curl/source files are enough.

## Artifacts (only when a file was asked for or needed)
- Save under `output/reports/<slug>/` unless the user gave a destination.
- List only the final report and any exported PDF/DOCX/CSV; source notes and scratch files stay out of the artifact list.
- The full findings still go in the chat reply; the file is the export of them, not a substitute.

## Verification
- Confirm the reply covers the user-requested scope with sources named.
- When a file was made, confirm it exists; for PDFs, render or inspect at least the first page when possible.
