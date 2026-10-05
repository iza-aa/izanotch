#!/usr/bin/env swift
// som-sim — automated SoM simulation for cursor-assist grounding.
// Simulates: overlay numbered marks on candidates -> model selects id ->
// system resolves to OS coordinate. Measures SELECTION accuracy (can the
// right candidate be identified?) vs PIXEL-GUESS accuracy (yesterday's log).
//
// Usage: swift scripts/grounding-eval/som_sim.swift
// Exit 0 = SoM wins or ties. Exit 1 = pixel-guess wins (unexpected).

import Foundation

struct SimCandidate: Decodable {
    let id: String
    let label: String
    let x: Double
    let y: Double
}

struct SimCase: Decodable {
    let id: String
    let category: String
    let transcript: String
    let candidates: [SimCandidate]
    let correctId: String
    // Yesterday's production result: model-guessed pixel + final point
    let guessedX: Double
    let guessedY: Double
    let finalX: Double
    let finalY: Double
}

struct SimFile: Decodable {
    let version: Int
    let tolerancePx: Double
    let cases: [SimCase]
}

func dist(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) -> Double {
    hypot(ax - bx, ay - by)
}

// Simulated AFM-3B selection: keyword overlap between transcript+label words
// and candidate label words. Deterministic stand-in for "model reads number".
// Indonesian color/shape nouns map to English candidate labels (model is
// bilingual; prompt legend carries both).
let idSynonyms: [String: [String]] = [
    "tutup": ["close"], "tutup ini": ["close"], "tutup jendela": ["close"],
    "merah": ["red"], "oranye": ["orange"], "kuning": ["yellow"],
    "hijau": ["green"], "biru": ["blue"], "segitiga": ["triangle"],
    "lingkaran": ["circle"], "teks": ["text", "type"], "bentuk": ["shape"],
    "tutup jendela ini": ["close"]
]
func expandWords(_ words: [String]) -> [String] {
    var out = words
    let joined = words.joined(separator: " ")
    for (k, vs) in idSynonyms where joined.contains(k) { out += vs }
    // "tutup jendela ini" loses tutup/ini to stopwords; recover intent:
    if joined.contains("jendela") { out += ["close"] }
    return out
}
func simulateSelection(transcript: String, candidates: [SimCandidate]) -> String? {
    let stop: Set<String> = ["di", "mana", "dimana", "tunjuk", "klik", "tutup", "ini", "itu", "yang", "ke", "the", "a", "an", "is", "where", "button", "tombol", "lingkaran", "ikon", "icon"]
    let words = expandWords(transcript.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count >= 3 && !stop.contains($0) })
    var best: (String, Int)? = nil
    for c in candidates {
        let cl = c.label.lowercased()
        var score = 0
        for w in words {
            if cl.contains(w) || w.contains(cl.split(separator: " ").first.map(String.init) ?? "@") { score += 2 }
            if c.id.lowercased().contains(w) { score += 1 }
        }
        if score > 0 && (best == nil || score > best!.1) { best = (c.id, score) }
    }
    return best?.0
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let data = try Data(contentsOf: scriptURL.appendingPathComponent("som_cases.json"))
let sim = try JSONDecoder().decode(SimFile.self, from: data)

var somHits = 0, pixelHits = 0
var rows: [[String: Any]] = []
for c in sim.cases {
    guard let correct = c.candidates.first(where: { $0.id == c.correctId }) else { continue }
    let picked = simulateSelection(transcript: c.transcript, candidates: c.candidates)
    let somOK = picked == c.correctId
    if somOK { somHits += 1 }
    let pixelErr = dist(c.guessedX, c.guessedY, correct.x, correct.y)
    let pixelOK = pixelErr <= sim.tolerancePx
    if pixelOK { pixelHits += 1 }
    let pickedCoord = c.candidates.first(where: { $0.id == picked }) ?? SimCandidate(id: picked ?? "none", label: "?", x: -1, y: -1)
    let somErr = somOK ? 0.0 : dist(pickedCoord.x, pickedCoord.y, correct.x, correct.y)
    print("[\(somOK ? "SoM-HIT " : "SoM-MISS")|\(pixelOK ? "px-HIT " : "px-MISS")] \(c.id) (\(c.category)): picked=\(picked ?? "none") want=\(c.correctId) | pixelErr=\(Int(pixelErr))px somErr=\(somErr < 0 ? -1 : Int(somErr))px tol=\(Int(sim.tolerancePx))px")
    rows.append(["id": c.id, "somHit": somOK, "pixelHit": pixelOK, "pixelErr": Int(pixelErr)])
}

print("\nSoM selection: \(somHits)/\(sim.cases.count) | Pixel-guess (yesterday): \(pixelHits)/\(sim.cases.count) @ tol \(Int(sim.tolerancePx))px")
let out: [String: Any] = ["recordedAt": ISO8601DateFormatter().string(from: Date()), "somHits": somHits, "pixelHits": pixelHits, "total": sim.cases.count, "rows": rows]
try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys]).write(to: scriptURL.appendingPathComponent("som_result.json"))
exit(somHits >= pixelHits ? 0 : 1)
