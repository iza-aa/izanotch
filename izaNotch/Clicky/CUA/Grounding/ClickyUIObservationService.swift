//
//  ClickyUIObservationService.swift
//  izaNotch
//
//  Universal UI Observation Service for macOS Applications.
//  Executes Vision OCR, font-height dynamic gap clustering, multi-card consensus indexing,
//  and dynamic container layout discovery (AXOutline, AXTable, AXToolbar).
//  Zero App-Specific Hardcoding — Single Responsibility Architecture.
//

import Foundation
import CoreGraphics
import AppKit
import Vision

public struct UIObservationSnapshot: Sendable {
    public let viewport: (isAtTop: Bool, scrollOffset: Float)
    public let activeContainer: String?
    public let navigationElements: [String]
    public let toolbarControls: [String]
    public let observedText: [String]
    public let cardBoxes: [Int: CGRect]
    public let formattedSummary: String

    public init(
        viewport: (isAtTop: Bool, scrollOffset: Float),
        activeContainer: String?,
        navigationElements: [String],
        toolbarControls: [String],
        observedText: [String],
        cardBoxes: [Int: CGRect],
        formattedSummary: String
    ) {
        self.viewport = viewport
        self.activeContainer = activeContainer
        self.navigationElements = navigationElements
        self.toolbarControls = toolbarControls
        self.observedText = observedText
        self.cardBoxes = cardBoxes
        self.formattedSummary = formattedSummary
    }
}

@MainActor
public final class ClickyUIObservationService: ObservableObject {
    public static let shared = ClickyUIObservationService()

    @Published public private(set) var observedListItems: [(index: Int, content: String)] = []
    @Published public private(set) var observedCardBoxes: [Int: CGRect] = [:]
    @Published public private(set) var observedElements: [(text: String, box: CGRect)] = []
    @Published public private(set) var latestFormFields: [String: String] = [:]
    @Published public private(set) var latestFormFieldBoxes: [String: CGRect] = [:]
    @Published public private(set) var latestWindowType: String = "general_viewer"
    @Published public private(set) var latestHasModalOrError: Bool = false
    @Published public private(set) var latestErrorMessage: String? = nil
    @Published public private(set) var latestTopBarItems: [String] = []

    private init() {}

    /// Resets all ephemeral session observation state between autonomous runs
    public func resetSession() {
        observedListItems.removeAll()
        observedCardBoxes.removeAll()
        observedElements.removeAll()
        latestFormFields.removeAll()
        latestFormFieldBoxes.removeAll()
        latestWindowType = "general_viewer"
        latestHasModalOrError = false
        latestErrorMessage = nil
        latestTopBarItems.removeAll()
    }

    /// Reads screen contents into a structured, section-based JSON representation
    /// Sections: topBar, sidebar, listItems (with explicit 1-based indexing), previewPane, content
    public func readStructuredObservation(
        appName: String,
        pid: pid_t? = nil,
        snapshotPath: String? = nil,
        targetSection: String? = nil,
        intentType: String? = nil
    ) async -> String {
        guard let snapPath = snapshotPath ?? CompanionWindowStreamService.shared.activeSnapshotPath,
              FileManager.default.fileExists(atPath: snapPath),
              let img = NSImage(contentsOfFile: snapPath),
              let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            // Fallback to AX if snapshot unavailable
            if let pid = pid, pid > 0 {
                let appElement = AXUIElementCreateApplication(pid)
                var windowRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
                   let win = windowRef {
                    let axTexts = extractAXElementTextRecursive(from: win as! AXUIElement, maxDepth: 4)
                    let fallbackDict: [String: Any] = ["content": axTexts]
                    if let data = try? JSONSerialization.data(withJSONObject: fallbackDict, options: [.prettyPrinted]),
                       let str = String(data: data, encoding: .utf8) {
                        return str
                    }
                }
            }
            return "{}"
        }

        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([req])

        guard let results = req.results, !results.isEmpty else {
            return "{}"
        }

        struct DetectedItem {
            let text: String
            let box: CGRect
        }

        var topBarItems: [String] = []
        var sidebarItems: [String] = []
        var previewPaneItems: [String] = []
        var listRawItems: [DetectedItem] = []
        var generalItems: [DetectedItem] = []
        observedElements.removeAll()

        // Dynamic Layout Discovery via AXUIElement Hierarchy
        var detectedSidebarMaxX: CGFloat = 0.20
        var detectedListMaxX: CGFloat = 0.55
        var hasOutline = false
        var hasTable = false

        if let p = pid, p > 0 {
            let app = AXUIElementCreateApplication(p)
            var winRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
               let win = winRef as! AXUIElement? {
                var winPosRef: CFTypeRef?
                var winSizeRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &winPosRef) == .success,
                   AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &winSizeRef) == .success {
                    var winPos = CGPoint.zero
                    var winSize = CGSize.zero
                    AXValueGetValue(winPosRef as! AXValue, .cgPoint, &winPos)
                    AXValueGetValue(winSizeRef as! AXValue, .cgSize, &winSize)

                    if winSize.width > 200 {
                        if let outline = self.findFirstAXElement(parent: win, role: "AXOutline") {
                            hasOutline = true
                            var outPosRef: CFTypeRef?
                            var outSizeRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(outline, kAXPositionAttribute as CFString, &outPosRef) == .success,
                               AXUIElementCopyAttributeValue(outline, kAXSizeAttribute as CFString, &outSizeRef) == .success {
                                var outPos = CGPoint.zero
                                var outSize = CGSize.zero
                                AXValueGetValue(outPosRef as! AXValue, .cgPoint, &outPos)
                                AXValueGetValue(outSizeRef as! AXValue, .cgSize, &outSize)
                                let relRight = (outPos.x + outSize.width - winPos.x) / winSize.width
                                if relRight > 0.08 && relRight < 0.45 {
                                    detectedSidebarMaxX = relRight
                                }
                            }
                        }
                        if let table = self.findFirstAXElement(parent: win, role: "AXTable") {
                            hasTable = true
                            var tblPosRef: CFTypeRef?
                            var tblSizeRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(table, kAXPositionAttribute as CFString, &tblPosRef) == .success,
                               AXUIElementCopyAttributeValue(table, kAXSizeAttribute as CFString, &tblSizeRef) == .success {
                                var tblPos = CGPoint.zero
                                var tblSize = CGSize.zero
                                AXValueGetValue(tblPosRef as! AXValue, .cgPoint, &tblPos)
                                AXValueGetValue(tblSizeRef as! AXValue, .cgSize, &tblSize)
                                let relRight = (tblPos.x + tblSize.width - winPos.x) / winSize.width
                                if relRight > detectedSidebarMaxX && relRight < 0.85 {
                                    detectedListMaxX = relRight
                                }
                            }
                            var visRowsRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(table, "AXVisibleRows" as CFString, &visRowsRef) == .success,
                               let visRows = visRowsRef as? [AXUIElement] {
                                ClickyLogger.info("[UI_OBSERVATION]", "Dynamic layout detected AXTable with \(visRows.count) visible rows")
                            }
                        }
                        if let tb = self.findFirstAXElement(parent: win, role: "AXToolbar") {
                            self.extractAXToolbarControls(from: tb, winPos: winPos, winSize: winSize, into: &topBarItems)
                        }
                    }
                }
            }
        }

        for obs in results {
            guard let str = obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                  str.count >= 2 else { continue }
            let b = obs.boundingBox
            if !observedElements.contains(where: { $0.text.lowercased() == str.lowercased() }) {
                observedElements.append((text: str, box: b))
            }

            // Top bar / toolbar: only for controls near top and without colons (to prevent swallowing form fields)
            let isFormLabelOrValue = str.contains(":") && !str.contains("://")
            if b.midY >= 0.94 && !isFormLabelOrValue {
                if !topBarItems.contains(str) { topBarItems.append(str) }
            }
            // Sidebar / Navigation Elements (only if outline detected)
            else if hasOutline && b.maxX <= detectedSidebarMaxX {
                if !sidebarItems.contains(str) { sidebarItems.append(str) }
            }
            // Preview / detail pane (only if table detected)
            else if hasTable && b.minX >= detectedListMaxX {
                if !previewPaneItems.contains(str) { previewPaneItems.append(str) }
            }
            // Middle column: list items (only if table detected)
            else if hasTable && b.minX >= (hasOutline ? (detectedSidebarMaxX - 0.03) : 0.0) && b.maxX <= detectedListMaxX {
                listRawItems.append(DetectedItem(text: str, box: b))
            } else {
                generalItems.append(DetectedItem(text: str, box: b))
            }
        }

        // Group middle column into distinct list item cards using font-relative dynamic gap clustering
        let sortedList = listRawItems.sorted { $0.box.midY > $1.box.midY }
        var cards: [[DetectedItem]] = []

        let heights = sortedList.map { $0.box.height }.sorted()
        let medianLineHeight: CGFloat = heights.isEmpty ? 0.018 : heights[heights.count / 2]
        // Dynamic gap threshold proportional to text line height (scale- and resolution-invariant)
        let dynamicGapThreshold = max(medianLineHeight * 1.8, 0.024)

        for item in sortedList {
            if let lastIdx = cards.indices.last {
                let lastCard = cards[lastIdx]
                let bottomItem = lastCard.min(by: { $0.box.midY < $1.box.midY })!
                let midYGap = bottomItem.box.midY - item.box.midY
                if midYGap <= dynamicGapThreshold {
                    cards[lastIdx].append(item)
                } else {
                    cards.append([item])
                }
            } else {
                cards.append([item])
            }
        }

        var rawSummaries: [String] = []
        var cardBoxes: [CGRect] = []
        for card in cards {
            let sortedCard = card.sorted {
                if abs($0.box.midY - $1.box.midY) < 0.02 {
                    return $0.box.minX < $1.box.minX
                }
                return $0.box.midY > $1.box.midY
            }
            rawSummaries.append(sortedCard.map { $0.text }.joined(separator: " | "))

            var unionBox = card.first?.box ?? .zero
            for item in card.dropFirst() {
                unionBox = unionBox.union(item.box)
            }
            cardBoxes.append(unionBox)
        }

        let scrollState = pid != nil ? CUAScrollActionTool.getScrollState(pid: pid!) : CUAScrollState(isAtTop: true)
        let assignedIndices = resolveCardIndices(newCards: rawSummaries, previousItems: observedListItems, isAtTop: scrollState.isAtTop)
        var formattedListItems: [[String: Any]] = []
        for (idx, (summary, box)) in zip(assignedIndices, zip(rawSummaries, cardBoxes)) {
            formattedListItems.append([
                "index": idx,
                "content": summary
            ])
            observedCardBoxes[idx] = box
            if !observedListItems.contains(where: { $0.index == idx }) {
                observedListItems.append((index: idx, content: summary))
            }
        }

        // Active Container Resolution
        let activeContainer: String? = {
            if let title = CompanionWindowStreamService.shared.activeWindowTitle, !title.isEmpty {
                return title
            }
            if let p = pid, p > 0 {
                let app = AXUIElementCreateApplication(p)
                var winRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
                   let win = winRef {
                    var tRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(win as! AXUIElement, kAXTitleAttribute as CFString, &tRef) == .success,
                       let tStr = tRef as? String, !tStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return tStr.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            return nil
        }()

        // Dynamic Form Field & Modal Alert State Synthesis
        var detectedFormFields: [String: String] = [:]
        var detectedFormFieldBoxes: [String: CGRect] = [:]
        var consumedFormTokenTexts: Set<String> = []
        let isCollectionWindow = hasOutline || hasTable

        // Only extract form fields if this is NOT a collection list window.
        // In a collection list (e.g. Mail's 3-pane inbox), reading pane headers like "To:", "From:", "Date:"
        // are static read-only metadata of received messages, NOT form inputs to be filled or submitted!
        if !isCollectionWindow {
            let sortedTokens = observedElements.sorted { $0.box.midY > $1.box.midY }
            for token in sortedTokens {
                let t = token.text
                if t.contains(":") && !t.contains("://") {
                    let parts = t.components(separatedBy: ":")
                    let label = parts[0].trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
                    let afterColon = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard label.count >= 2 && label.count <= 25 else { continue }

                    if !afterColon.isEmpty {
                        detectedFormFields[label] = afterColon
                        detectedFormFieldBoxes[label] = token.box
                        consumedFormTokenTexts.insert(token.text)
                    } else {
                        let sameBand = sortedTokens.filter { other in
                            other.text != t && abs(other.box.midY - token.box.midY) < 0.035 && other.box.minX > token.box.minX
                        }
                        if let next = sameBand.first {
                            detectedFormFields[label] = next.text
                            detectedFormFieldBoxes[label] = next.box
                            consumedFormTokenTexts.insert(token.text)
                            consumedFormTokenTexts.insert(next.text)
                        } else {
                            detectedFormFields[label] = "[empty]"
                            detectedFormFieldBoxes[label] = CGRect(x: token.box.maxX + 0.02, y: token.box.minY, width: 0.35, height: token.box.height)
                            consumedFormTokenTexts.insert(token.text)
                        }
                    }
                }
            }
            if !detectedFormFields.isEmpty {
                let lowestHeaderY = detectedFormFieldBoxes.values.map { $0.minY }.min() ?? 0.65
                let bodyBox = CGRect(x: 0.08, y: 0.10, width: 0.84, height: max(lowestHeaderY - 0.12, 0.40))
                detectedFormFieldBoxes["Body"] = bodyBox
                observedElements.append((text: "Body", box: bodyBox))

                let bodyCandidates = sortedTokens.filter { token in
                    !consumedFormTokenTexts.contains(token.text) &&
                    token.box.midY < (lowestHeaderY - 0.02) &&
                    !topBarItems.contains(token.text) &&
                    !sidebarItems.contains(token.text)
                }
                if !bodyCandidates.isEmpty {
                    let bodyText = bodyCandidates.map { $0.text }.joined(separator: " ")
                    if !bodyText.isEmpty {
                        detectedFormFields["Body"] = bodyText
                    }
                } else if detectedFormFields["Body"] == nil {
                    detectedFormFields["Body"] = "[empty]"
                }
            }
        }

        let detectedWindowType: String = {
            if isCollectionWindow {
                return "collection_list"
            }
            if detectedFormFields.count >= 2 || detectedFormFields["To"] != nil || detectedFormFields["Subject"] != nil {
                return "draft_composer"
            }
            if let activeCont = activeContainer?.lowercased(),
               activeCont.contains("dialog") || activeCont.contains("alert") || activeCont.contains("error") {
                return "dialog_or_alert"
            }
            return "general_viewer"
        }()

        var hasModalOrError = false
        var detectedErrorMessage: String? = nil
        let alertKeywords = ["cannot send", "error", "failed to send", "invalid address", "peringatan", "gagal", "alert"]
        for elem in observedElements {
            let lower = elem.text.lowercased()
            if alertKeywords.contains(where: { lower.contains($0) }) {
                hasModalOrError = true
                detectedErrorMessage = elem.text
                break
            }
        }

        self.latestFormFields = detectedFormFields
        self.latestFormFieldBoxes = detectedFormFieldBoxes
        self.latestWindowType = detectedWindowType
        self.latestHasModalOrError = hasModalOrError
        self.latestErrorMessage = detectedErrorMessage
        self.latestTopBarItems = topBarItems

        var sectionJSON: [String: Any] = [:]
        if let actCont = activeContainer, !actCont.isEmpty { sectionJSON["activeContainer"] = actCont }
        sectionJSON["windowType"] = detectedWindowType
        if !detectedFormFields.isEmpty { sectionJSON["formFields"] = detectedFormFields }
        if hasModalOrError {
            sectionJSON["hasModalOrError"] = true
            if let err = detectedErrorMessage { sectionJSON["errorOrAlertMessage"] = err }
        }
        if !topBarItems.isEmpty { sectionJSON["topBar"] = topBarItems }
        if !sidebarItems.isEmpty {
            sectionJSON["navigationElements"] = sidebarItems
            sectionJSON["sidebar"] = sidebarItems
        }

        let isComposeOrSend = intentType?.lowercased() == "compose" ||
                              intentType?.lowercased() == "send" ||
                              intentType?.lowercased() == "create" ||
                              targetSection?.lowercased() == "toolbar"
        let shouldOmitList = isComposeOrSend && !topBarItems.isEmpty

        if !formattedListItems.isEmpty && !shouldOmitList { sectionJSON["listItems"] = formattedListItems }
        if !previewPaneItems.isEmpty && !shouldOmitList { sectionJSON["previewPane"] = previewPaneItems }

        var viewportDict: [String: Any] = ["isAtTop": scrollState.isAtTop]
        if let sVal = scrollState.scrollValue {
            viewportDict["scrollOffset"] = round(Double(sVal) * 100.0) / 100.0
        }
        sectionJSON["viewport"] = viewportDict

        // Single-pane or general content fallback
        if (formattedListItems.isEmpty || shouldOmitList) && !generalItems.isEmpty {
            let genSorted = generalItems.sorted { $0.box.midY > $1.box.midY }
            sectionJSON["content"] = genSorted.map { $0.text }
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: sectionJSON, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            ClickyLogger.info("[UI_OBSERVATION]", "Structured observation: \(topBarItems.count) topBar, \(detectedFormFields.count) formFields (\(detectedWindowType)), \(sidebarItems.count) sidebar, \(formattedListItems.count) listItems")
            return jsonString
        }

        return "{}"
    }

    /// Produces a concise, targeted per-item summary of screen state delta following an action.
    /// Eliminates token bloating by focusing strictly on the interacted item and reading pane.
    public func summarizeTargetedObservation(
        actionType: String,
        targetElement: String,
        observationJSON: String,
        targetIndex: Int?
    ) -> String {
        guard let data = observationJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }

        let preview = (dict["previewPane"] as? [String]) ?? []
        let previewSummary = preview.prefix(4).joined(separator: " | ")
        let listItems = (dict["listItems"] as? [[String: Any]]) ?? []

        if actionType == "click" || actionType == "right_click" {
            var itemSummary = ""
            if let tIdx = targetIndex, let match = listItems.first(where: { ($0["index"] as? Int) == tIdx }) {
                let content = (match["content"] as? String) ?? ""
                itemSummary = "Target Item #\(tIdx): '\(content)'"
            } else if let firstItem = listItems.first {
                let idx = (firstItem["index"] as? Int) ?? 1
                let content = (firstItem["content"] as? String) ?? ""
                itemSummary = "Item #\(idx): '\(content)'"
            }

            var components: [String] = []
            if !itemSummary.isEmpty { components.append(itemSummary) }
            if !previewSummary.isEmpty { components.append("Reading Pane: '\(previewSummary)'") }
            return components.joined(separator: " | ")
        } else if actionType.contains("scroll") {
            let indices = listItems.compactMap { $0["index"] as? Int }.sorted()
            if let minIdx = indices.first, let maxIdx = indices.last {
                return "Visible list items now: indices \(minIdx) to \(maxIdx) (count: \(indices.count))"
            }
            return "List scrolled"
        } else if actionType == "type" {
            return "Input field '\(targetElement)' updated"
        } else {
            if !previewSummary.isEmpty {
                return "Display: '\(previewSummary)'"
            }
            return ""
        }
    }

    /// Finds matching OCR element using whole phrase match, Laya zero-shot selection, or token overlap
    public func findMatchingOcrElement(query: String) async -> (text: String, box: CGRect)? {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !observedElements.isEmpty else { return nil }
        // 0. Direct Form Field Box Lookup (P3 Mandate)
        if let directBox = latestFormFieldBoxes.first(where: { (key, _) in
            let kLower = key.lowercased()
            return kLower == q || q.contains(kLower) || (kLower.count >= 2 && kLower.contains(q))
        }) {
            return (text: directBox.key, box: directBox.value)
        }

        // 1. Direct whole phrase or token match
        if let direct = observedElements.first(where: { elem in
            let lower = elem.text.lowercased()
            return lower == q || lower.contains(q) || (lower.count >= 2 && q.contains(lower))
        }) {
            return direct
        }

        // 2. Zero-Shot Semantic Element Selection via Laya (~20ms)
        var candidateChoices: [String: String] = [:]
        var candidateLookup: [String: (text: String, box: CGRect)] = [:]
        for (idx, elem) in observedElements.prefix(25).enumerated() {
            let key = "cand_\(idx)"
            candidateChoices[key] = elem.text
            candidateLookup[key] = elem
        }

        if let layaPick = await LayaDecisionEngine.shared.selectElement(targetQuery: query, candidates: candidateChoices),
           layaPick.confidence >= 0.20,
           let chosenElem = candidateLookup[layaPick.id] {
            ClickyLogger.info("[UI_OBSERVATION]", "Laya semantically grounded '\(query)' -> '\(chosenElem.text)' (conf: \(String(format: "%.2f", layaPick.confidence)))")
            return chosenElem
        }

        // 3. Mathematical token overlap without hardcoded synonym dictionary
        let queryTokens = q.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 }
        if !queryTokens.isEmpty {
            for candidate in observedElements {
                let words = candidate.text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
                if queryTokens.contains(where: { words.contains($0) }) {
                    return candidate
                }
            }
        }

        return nil
    }

    /// Visual Anchor Chaining: matches overlapping cards from previous observations
    /// to assign continuous, absolute 1-based indices across vertical scroll actions using multi-card consensus voting.
    public func resolveCardIndices(newCards: [String], previousItems: [(index: Int, content: String)], isAtTop: Bool = true) -> [Int] {
        guard !previousItems.isEmpty else {
            if isAtTop {
                return newCards.indices.map { $0 + 1 }
            } else {
                return newCards.indices.map { $0 + 11 }
            }
        }
        if isAtTop {
            return newCards.indices.map { $0 + 1 }
        }

        func tokenize(_ str: String) -> Set<String> {
            let words = str.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            return Set(words.filter { $0.count >= 4 })
        }

        // Multi-Card Consensus: collect baseIndex votes from all matching pairs
        var baseIndexVotes: [Int: Int] = [:]

        for (newIdx, newContent) in newCards.enumerated() {
            let newTokens = tokenize(newContent)
            guard newTokens.count >= 2 else { continue }

            var bestPrevIndex: Int?
            var bestScore: Double = 0.0

            for prev in previousItems {
                let prevTokens = tokenize(prev.content)
                guard prevTokens.count >= 2 else { continue }

                let common = newTokens.intersection(prevTokens)
                guard common.count >= 2 else { continue }

                let score = Double(common.count) / Double(newTokens.union(prevTokens).count)
                if score > bestScore && score >= 0.20 {
                    bestScore = score
                    bestPrevIndex = prev.index
                }
            }

            if let knownIdx = bestPrevIndex {
                let impliedBase = knownIdx - newIdx
                if impliedBase >= 1 {
                    baseIndexVotes[impliedBase, default: 0] += 1
                }
            }
        }

        // Base index with highest consensus votes
        if let bestBase = baseIndexVotes.max(by: { $0.value < $1.value })?.key {
            ClickyLogger.info("[UI_OBSERVATION]", "Consensus anchor resolved baseIndex \(bestBase) with \(baseIndexVotes[bestBase] ?? 0) votes")
            return newCards.indices.map { bestBase + $0 }
        }

        // Fallback: prefix matching if token consensus had insufficient votes
        for (newIdx, newContent) in newCards.enumerated() {
            let cleanNew = newContent.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanNew.count >= 6 else { continue }
            if let match = previousItems.first(where: { prev in
                let cleanPrev = prev.content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard cleanPrev.count >= 6 else { return false }
                let prevPrefix = String(cleanPrev.prefix(25))
                let newPrefix = String(cleanNew.prefix(25))
                return cleanNew.contains(prevPrefix) || cleanPrev.contains(newPrefix)
            }) {
                let impliedBase = max(1, match.index - newIdx)
                return newCards.indices.map { impliedBase + $0 }
            }
        }

        return newCards.indices.map { $0 + (isAtTop ? 1 : 11) }
    }

    // MARK: - Accessibility Hierarchy Helpers

    public func findTargetAXApplication(appName: String) -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.localizedName?.localizedCaseInsensitiveContains(appName) == true }) {
            return AXUIElementCreateApplication(app.processIdentifier)
        }
        return nil
    }

    public func findFirstAXElement(parent: AXUIElement, role: String, depth: Int = 0, maxDepth: Int = 4) -> AXUIElement? {
        guard depth <= maxDepth else { return nil }
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &roleRef) == .success,
           let r = roleRef as? String, r == role {
            return parent
        }
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findFirstAXElement(parent: child, role: role, depth: depth + 1, maxDepth: maxDepth) {
                    return found
                }
            }
        }
        return nil
    }

    public func extractAXElementTitles(from element: AXUIElement) -> [String] {
        return extractAXElementTextRecursive(from: element, maxDepth: 3)
    }

    public func extractAXElementTextRecursive(from element: AXUIElement, depth: Int = 0, maxDepth: Int = 4) -> [String] {
        guard depth <= maxDepth else { return [] }
        var results: [String] = []

        var titleRef: CFTypeRef?
        var valRef: CFTypeRef?
        var descRef: CFTypeRef?

        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
           let title = titleRef as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(title.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valRef) == .success,
           let val = valRef as? String, !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(val.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
           let desc = descRef as? String, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(desc.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Traverse rows if table or outline view
        var rowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRowsAttribute as CFString, &rowsRef) == .success,
           let rows = rowsRef as? [AXUIElement] {
            for row in rows.prefix(15) {
                let rowTexts = extractAXElementTextRecursive(from: row, depth: depth + 1, maxDepth: maxDepth)
                if !rowTexts.isEmpty {
                    results.append(rowTexts.joined(separator: " | "))
                }
                if results.count >= 20 { break }
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children.prefix(20) {
                let childTexts = extractAXElementTextRecursive(from: child, depth: depth + 1, maxDepth: maxDepth)
                results.append(contentsOf: childTexts)
                if results.count >= 25 { break }
            }
        }

        var unique: [String] = []
        for text in results {
            if text.count > 2 && !unique.contains(text) {
                unique.append(text)
            }
        }
        return Array(unique.prefix(25))
    }

    public func extractAXToolbarControls(
        from element: AXUIElement,
        winPos: CGPoint,
        winSize: CGSize,
        into topBarItems: inout [String],
        depth: Int = 0
    ) {
        if depth > 2 { return }
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return }

        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""

            if role == "AXGroup" || role == "AXRadioGroup" || role == "AXToolbar" {
                extractAXToolbarControls(from: child, winPos: winPos, winSize: winSize, into: &topBarItems, depth: depth + 1)
                continue
            }

            var descRef: CFTypeRef?
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descRef)
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)

            let desc = (descRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = (titleRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let label = !desc.isEmpty ? desc : title
            guard !label.isEmpty, label.count >= 2 else { continue }

            if !topBarItems.contains(label) {
                topBarItems.append(label)
            }

            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &posRef) == .success,
               AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeRef) == .success,
               let posVal = posRef, let sizeVal = sizeRef,
               CFGetTypeID(posVal) == AXValueGetTypeID(),
               CFGetTypeID(sizeVal) == AXValueGetTypeID() {
                var pos = CGPoint.zero
                var size = CGSize.zero
                if AXValueGetValue(posVal as! AXValue, .cgPoint, &pos),
                   AXValueGetValue(sizeVal as! AXValue, .cgSize, &size),
                   winSize.width > 0, winSize.height > 0 {
                    let normX = (pos.x - winPos.x) / winSize.width
                    let normW = size.width / winSize.width
                    let normH = size.height / winSize.height
                    let normY = 1.0 - ((pos.y - winPos.y + size.height) / winSize.height)
                    let box = CGRect(x: normX, y: normY, width: normW, height: normH)
                    if !observedElements.contains(where: { $0.text.lowercased() == label.lowercased() }) {
                        observedElements.append((text: label, box: box))
                    }
                }
            }
        }
    }

    #if DEBUG
    public func evaluateAXTreeForE2E(
        targetAppName: String,
        expectedAX: [[String: Any]]
    ) -> (passed: Bool, reason: String) {
        if targetAppName.lowercased() == "none" || targetAppName.isEmpty {
            return (true, "No application interaction expected for conversational scenario.")
        }

        guard !expectedAX.isEmpty else {
            return (false, "AX assertions cannot be empty for interactive scenario on '\(targetAppName)'")
        }

        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: {
            guard let name = $0.localizedName else { return false }
            return name.localizedCaseInsensitiveContains(targetAppName) ||
                   targetAppName.localizedCaseInsensitiveContains(name)
        }) else {
            return (false, "Target application '\(targetAppName)' is not running.")
        }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowsVal: AnyObject?
        let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsVal)
        guard err == .success, let windows = windowsVal as? [AXUIElement], !windows.isEmpty else {
            return (false, "Target application '\(targetAppName)' (PID \(pid)) has no accessible windows (err: \(err.rawValue)).")
        }

        for spec in expectedAX {
            let role = spec["role"] as? String ?? ""
            let labelHint = (spec["labelHint"] as? String ?? "").lowercased()
            let valueContains = spec["valueContains"] as? String
            let minRowCount = spec["minRowCount"] as? Int
            var matched = false
            for win in windows {
                var visited = 0
                if findAndAssertElementInWin(
                    in: win,
                    role: role,
                    labelHint: labelHint,
                    valueContains: valueContains,
                    minRowCount: minRowCount,
                    depth: 0,
                    visitedNodes: &visited,
                    maxNodes: 100
                ) {
                    matched = true
                    break
                }
            }

            if !matched {
                return (false, "Failed to find AX element matching role='\(role)', hint='\(labelHint)', valueContains='\(valueContains ?? "")'")
            }
        }

        return (true, "All AX assertions passed successfully on PID \(pid).")
    }

    private func findAndAssertElementInWin(
        in element: AXUIElement,
        role: String,
        labelHint: String,
        valueContains: String?,
        minRowCount: Int?,
        depth: Int = 0,
        visitedNodes: inout Int,
        maxNodes: Int = 100
    ) -> Bool {
        if depth > 8 || visitedNodes >= maxNodes { return false }
        visitedNodes += 1

        var roleVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
        let elemRole = roleVal as? String ?? ""

        var titleVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleVal)
        let title = (titleVal as? String ?? "").lowercased()

        var descVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descVal)
        let desc = (descVal as? String ?? "").lowercased()

        var valueVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueVal)
        var valStr = (valueVal as? String ?? "")
        if valStr.isEmpty, let tokenArray = valueVal as? [AXUIElement] {
            let tokenTexts = tokenArray.compactMap { tok -> String? in
                var tRef: CFTypeRef?
                AXUIElementCopyAttributeValue(tok, kAXTitleAttribute as CFString, &tRef)
                if let t = tRef as? String, !t.isEmpty { return t }
                var vRef: CFTypeRef?
                AXUIElementCopyAttributeValue(tok, kAXValueAttribute as CFString, &vRef)
                if let v = vRef as? String, !v.isEmpty { return v }
                var dRef: CFTypeRef?
                AXUIElementCopyAttributeValue(tok, kAXDescriptionAttribute as CFString, &dRef)
                return dRef as? String
            }
            valStr = tokenTexts.joined(separator: " ")
        }
        if elemRole == role || role.isEmpty {
            var valueMatched = true
            if let vc = valueContains, !vc.isEmpty {
                valueMatched = valStr.localizedCaseInsensitiveContains(vc)
            }
            let hintMatched = labelHint.isEmpty || title.contains(labelHint) || desc.contains(labelHint) || valStr.lowercased().contains(labelHint) || (valueContains != nil && !valueContains!.isEmpty && valueMatched)
            if hintMatched && valueMatched {
                var rowMatched = true
                if let minRows = minRowCount, (elemRole == "AXTable" || elemRole == "AXOutline") {
                    var rowsVal: AnyObject?
                    AXUIElementCopyAttributeValue(element, kAXRowsAttribute as CFString, &rowsVal)
                    let rowCount = (rowsVal as? [AXUIElement])?.count ?? 0
                    rowMatched = (rowCount >= minRows)
                }

                if valueMatched && rowMatched {
                    return true
                }
            }
        }

        var childrenVal: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal)
        if err == .success, let children = childrenVal as? [AXUIElement] {
            for child in children.prefix(20) {
                if findAndAssertElementInWin(
                    in: child,
                    role: role,
                    labelHint: labelHint,
                    valueContains: valueContains,
                    minRowCount: minRowCount,
                    depth: depth + 1,
                    visitedNodes: &visitedNodes,
                    maxNodes: maxNodes
                ) {
                    return true
                }
                if visitedNodes >= maxNodes { break }
            }
        }

        return false
    }
    #endif
}
