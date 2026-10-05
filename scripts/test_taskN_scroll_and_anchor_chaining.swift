import Foundation

// Unit test script for Visual Anchor Chaining logic in CompanionVMAgentLoop

func resolveCardIndices(newCards: [String], previousItems: [(index: Int, content: String)]) -> [Int] {
    guard !previousItems.isEmpty else { return newCards.indices.map { $0 + 1 } }
    var anchorNewIdx: Int?
    var anchorKnownIndex: Int?
    for (newIdx, newContent) in newCards.enumerated() {
        let cleanNew = newContent.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanNew.count >= 6 else { continue }
        if let match = previousItems.first(where: { prev in
            let cleanPrev = prev.content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanPrev.count >= 6 else { return false }
            let prevPrefix = String(cleanPrev.prefix(30))
            let newPrefix = String(cleanNew.prefix(30))
            return cleanNew.contains(prevPrefix) || cleanPrev.contains(newPrefix)
        }) {
            anchorNewIdx = newIdx
            anchorKnownIndex = match.index
            break
        }
    }
    if let anchorNew = anchorNewIdx, let knownIdx = anchorKnownIndex {
        return newCards.enumerated().map { (idx, _) in
            let offset = idx - anchorNew
            return max(1, knownIdx + offset)
        }
    }
    return newCards.indices.map { $0 + 1 }
}

print("--- Testing Visual Anchor Chaining ---")

// Screen 1: Visible items 1 to 6
let screen1 = [
    "UNIQLO Indonesia • LifeWear Collection 2026",
    "GitHub • Security Alert for repo iza-3",
    "Chess.com • It's your turn against Magnus",
    "Apple Developer • App Store Review Complete",
    "Substack • Weekly Engineering Digest #42",
    "Stripe • Payout of $1,450.00 is on its way"
]

var sessionObserved: [(index: Int, content: String)] = []
let indices1 = resolveCardIndices(newCards: screen1, previousItems: sessionObserved)
print("Screen 1 indices:", indices1)
assert(indices1 == [1, 2, 3, 4, 5, 6], "Screen 1 should have indices 1...6")

for (idx, item) in zip(indices1, screen1) {
    sessionObserved.append((index: idx, content: item))
}

// User asks: "kalau email yang ke 10 tentang apa ya?"
// Assistant scrolls down.
// Screen 2: Items 5 and 6 are still visible at the top, followed by items 7, 8, 9, 10, 11
let screen2 = [
    "Substack • Weekly Engineering Digest #42", // previously index 5
    "Stripe • Payout of $1,450.00 is on its way", // previously index 6
    "Linear • Cycle 14 completed with 18 issues", // new -> should be 7
    "Google Cloud • Monthly invoice ready",        // new -> should be 8
    "Figma • Design feedback from Sarah",         // new -> should be 9
    "Slack • 3 new unread mentions in #general",   // new -> should be 10!
    "Spotify • Your Discover Weekly is ready"     // new -> should be 11
]

let indices2 = resolveCardIndices(newCards: screen2, previousItems: sessionObserved)
print("Screen 2 indices:", indices2)
assert(indices2 == [5, 6, 7, 8, 9, 10, 11], "Screen 2 should have chained indices 5...11")

for (idx, item) in zip(indices2, screen2) {
    if !sessionObserved.contains(where: { $0.index == idx }) {
        sessionObserved.append((index: idx, content: item))
    }
}

let item10 = sessionObserved.first(where: { $0.index == 10 })
print("Item 10 content:", item10?.content ?? "NOT FOUND")
assert(item10?.content.contains("Slack") == true, "Item 10 should be the Slack email!")

print("✅ All Visual Anchor Chaining tests PASSED successfully!")
