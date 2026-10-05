#!/usr/bin/env swift
// grounding-eval runner — Stage 0 baseline for cursor-assist grounding.
// Mirrors CompanionManager.parsePointingCoordinates branching + triggerElementFlight
// branch selection WITHOUT AppKit/CG dependencies, so it runs as a plain script.
//
// Usage: swift scripts/grounding-eval/run.swift
// Exit 0 = all expectations met. Non-zero = count of mismatches (baseline recorder).

import Foundation

struct EvalCase: Decodable {
    let id: String
    let category: String
    let transcript: String
    let response: String
    let expectedBranch: String
    let colorClaim: String?
}

struct EvalFile: Decodable {
    let version: Int
    let tolerancePx: Double
    let cases: [EvalCase]
}

enum Branch: String {
    case candidateId = "candidate-id"
    case dockBypass = "dock-bypass"
    case trafficSnap = "traffic-snap"
    case normalizedBox = "normalized-box"
    case rawPixel = "raw-pixel"
    case rawPixelScreen2 = "raw-pixel-screen2"
    case noFlight = "no-flight"
    case needsHsvCheck = "needs-hsv-check"
    case needsRoiZoom = "needs-roi-zoom"
    case unknown
}

func parseBranch(response: String, transcript: String) -> (Branch, String) {
    let candidatePattern = #"(?i)\[CANDIDATE:([A-Za-z0-9_\-]+)(?::([^\]:]*?))?\]"#
    if let _ = response.range(of: candidatePattern, options: .regularExpression) {
        return (.candidateId, "Stage 2 candidate tag -> OS truth")
    }
    let boxPattern = #"(?i)\[(?:TARGET|POINT|BOX):(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?::([^\]:\s][^\]:]*?))?(?::screen(\d+))?\]"#
    if let _ = response.range(of: boxPattern, options: .regularExpression) {
        return (.normalizedBox, "4-value box tag")
    }
    let pointPattern = #"(?i)\[(?:TARGET|POINT):(?:none|(\d+)\s*,\s*(\d+)(?:\s*,\s*(\d+))?(?::([^\]:\s][^\]:]*?))?(?::screen(\d+))?)\]"#
    guard let regex = try? NSRegularExpression(pattern: pointPattern, options: []),
          let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) else {
        // No tag parsed -> production semantic fallback (:2234) may fire:
        let combined = "\(transcript) \(response)".lowercased()
        let dockish = ["dock", "ikon", "icon", "app", "mana", "dimana"].contains(where: combined.contains)
        if dockish { return (.dockBypass, "semantic dock fallback (no tag)") }
        return (.noFlight, "no tag parsed")
    }
    func s(_ i: Int) -> String? {
        guard match.numberOfRanges > i, let r = Range(match.range(at: i), in: response) else { return nil }
        return String(response[r])
    }
    if s(1) == nil { return (.noFlight, "[POINT:none] or unparsable") }
    let y = Double(s(2) ?? "") ?? -1
    let label = (s(4) ?? "").lowercased()
    let screen = s(5).flatMap(Int.init)
    if screen == 2 { return (.rawPixelScreen2, "screen2 tag") }
    // Parsed tag -> straight to triggerElementFlight label gates (:1691+):
    // Stage-1 branch math mirrors:
    // NOTE: production semantic fallback (CompanionManager :2234) only runs when
    // resolvedCoordinate == nil (no tag parsed). Parsed tags below skip straight
    // to triggerElementFlight label gates, so dockish check must NOT fire here.
    if y >= 900 { return (.dockBypass, "y>=900 display-point bypass") }
    if label.contains("orange") { return (.needsHsvCheck, "color claim orange needs HSV") }
    if label.contains("candle") || label.contains("chart") { return (.needsRoiZoom, "canvas needs ROI zoom") }
    if label.contains("close") || label.contains("red") || label.contains("merah") || label.contains("tutup") {
        return (.trafficSnap, "traffic-light label gate")
    }
    if label.contains("minimi") || label.contains("kuning") || label.contains("yellow") {
        return (.trafficSnap, "traffic-light minimize label gate")
    }
    return (.rawPixel, "raw pixel passthrough")
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let casesURL = scriptURL.appendingPathComponent("cases.json")
let baselineURL = scriptURL.appendingPathComponent("baseline.json")
let data = try Data(contentsOf: casesURL)
let evalFile = try JSONDecoder().decode(EvalFile.self, from: data)

var mismatches: [(String, String, String)] = []
var branchCounts: [String: Int] = [:]
for c in evalFile.cases {
    let (branch, reason) = parseBranch(response: c.response, transcript: c.transcript)
    branchCounts[branch.rawValue, default: 0] += 1
    let status = branch.rawValue == c.expectedBranch ? "OK " : "MISS"
    print("[\(status)] \(c.id) (\(c.category)): got=\(branch.rawValue) want=\(c.expectedBranch) — \(reason)")
    if branch.rawValue != c.expectedBranch {
        mismatches.append((c.id, branch.rawValue, c.expectedBranch))
    }
}

let baseline: [String: Any] = [
    "recordedAt": ISO8601DateFormatter().string(from: Date()),
    "total": evalFile.cases.count,
    "mismatches": mismatches.map { ["id": $0.0, "got": $0.1, "want": $0.2] },
    "branchCounts": branchCounts
]
let out = try JSONSerialization.data(withJSONObject: baseline, options: [.prettyPrinted, .sortedKeys])
try out.write(to: baselineURL)
print("\n\(evalFile.cases.count - mismatches.count)/\(evalFile.cases.count) match. Baseline written to \(baselineURL.path)")
exit(mismatches.isEmpty ? 0 : 1)
