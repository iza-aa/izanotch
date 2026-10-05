// real_eval.swift — Fase 1 formal runner: ground tiap case gt.json via grounderd :8001,
// hit = titik di dalam gtBox. Usage: swift scripts/grounding-eval/real_eval.swift
// Requires: grounderd running (warmUp di app, atau manual `python3 -m mlx_vlm.server ...`),
// model path absolut (lihat UIVenusGrounderClient.modelPath).
import Foundation

struct GTBox: Decodable { let x, y, w, h: Double }
struct GTCase: Decodable { let id, screenshot, expression, category: String; let gtBox: GTBox }
struct GTFile: Decodable { let version: Int; let recordedAt: String; let toleranceNote: String; let cases: [GTCase] }

func scriptDir() -> String {
    let arg0 = CommandLine.arguments[0]
    if arg0.hasPrefix("/") { return (arg0 as NSString).deletingLastPathComponent }
    return FileManager.default.currentDirectoryPath + "/scripts/grounding-eval"
}
let dir = scriptDir()
let gtURL = URL(fileURLWithPath: dir + "/real_cases/gt.json")
let gt = try JSONDecoder().decode(GTFile.self, from: Data(contentsOf: gtURL))
let modelPath = NSString(string: "~/.izanotchy/models/\(ProcessInfo.processInfo.environment["UI_VENUS_MODEL_DIR"] ?? "UI-Venus-1.5-2B-mlx-6bit")").expandingTildeInPath

func ground(expression: String, pngPath: String) -> (point: (Double, Double)?, latency: Double, raw: String) {
    guard let imgData = try? Data(contentsOf: URL(fileURLWithPath: pngPath)) else { return (nil, 0, "no-image") }
    let prompt = "Output the center point of the position corresponding to the following instruction: \n\(expression). \n\nThe output should just be the coordinates of a point, in the format [x,y]. Additionally, if the task is infeasible (e.g., the task is not related to the image), the output should be [-1,-1]."
    let body: [String: Any] = [
        "model": modelPath,
        "messages": [["role": "user", "content": [
            ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(imgData.base64EncodedString())"]],
            ["type": "text", "text": prompt]]]],
        "max_tokens": 64, "temperature": 0.0]
    guard let httpBody = try? JSONSerialization.data(withJSONObject: body),
          let url = URL(string: "http://127.0.0.1:8001/v1/chat/completions") else { return (nil, 0, "bad-request") }
    var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 120
    req.setValue("application/json", forHTTPHeaderField: "Content-Type"); req.httpBody = httpBody
    let t0 = Date()
    var out: (point: (Double, Double)?, latency: Double, raw: String) = (nil, 0, "error")
    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { data, _, _ in
        defer { sem.signal() }
        out.latency = Date().timeIntervalSince(t0)
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let content = msg["content"] as? String else { out.raw = "bad-response"; return }
        out.raw = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let pat = #"\[\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\]"#
        if let rx = try? NSRegularExpression(pattern: pat),
           let m = rx.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           m.numberOfRanges >= 3,
           let xr = Range(m.range(at: 1), in: content), let yr = Range(m.range(at: 2), in: content),
           let x = Double(content[xr]), let y = Double(content[yr]), x >= 0, y >= 0 {
            out.point = (x, y)
        }
    }.resume()
    _ = sem.wait(timeout: .now() + 130)
    return out
}

var hits = 0, textHits = 0, textTotal = 0, iconHits = 0, iconTotal = 0
var rows: [[String: Any]] = []
for c in gt.cases {
    let (pt, lat, raw) = ground(expression: c.expression, pngPath: dir + "/real_cases/" + c.screenshot)
    var hit = false, detail = raw
    if let (nx, ny) = pt {
        let px = nx / 1000.0 * 1280.0, py = ny / 1000.0 * 831.0
        let b = c.gtBox
        hit = px >= b.x && px <= b.x + b.w && py >= b.y && py <= b.y + b.h
        detail = "[\(Int(nx)), \(Int(ny))] -> (\(Int(px)), \(Int(py))) vs box (\(Int(b.x)),\(Int(b.y)),\(Int(b.w))x\(Int(b.h)))"
    }
    if hit { hits += 1 }
    let isIcon = c.category.contains("icon") || c.category == "traffic-light"
    if isIcon { iconTotal += 1; if hit { iconHits += 1 } } else { textTotal += 1; if hit { textHits += 1 } }
    print("[\(hit ? "HIT " : "MISS")] \(c.id) (\(c.category)): \(detail) [\(String(format: "%.1f", lat))s]")
    rows.append(["id": c.id, "hit": hit, "detail": detail, "latency": lat])
}
print("\nTotal: \(hits)/\(gt.cases.count) | text: \(textHits)/\(textTotal) | icon: \(iconHits)/\(iconTotal)")
let result: [String: Any] = ["recordedAt": ISO8601DateFormatter().string(from: Date()),
    "model": (modelPath as NSString).lastPathComponent,
    "hits": hits, "total": gt.cases.count,
    "textHits": textHits, "textTotal": textTotal, "iconHits": iconHits, "iconTotal": iconTotal,
    "rows": rows]
if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: URL(fileURLWithPath: dir + "/real_result.json"))
    print("Wrote real_result.json")
}
exit(hits == gt.cases.count ? 0 : 1)
