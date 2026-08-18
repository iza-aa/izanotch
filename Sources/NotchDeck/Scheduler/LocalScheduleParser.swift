import Foundation

public struct LocalScheduleParser: Sendable {
    public static func parse(utterance: String, referenceDate: Date = Date()) -> ScheduleDetail? {
        let lower = utterance.lowercased()
        let cal = Calendar.current
        var targetDate = referenceDate
        var offsetMinutes = 0
        var extractedTitle = "Agenda"

        // Check offset: "X menit sebelum" / "X menit sebelumnya"
        if let offsetMatch = lower.range(of: #"(\d+)\s*menit\s*sebelum"#, options: .regularExpression) {
            let sub = String(lower[offsetMatch])
            if let num = Int(sub.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                offsetMinutes = num
            }
        }

        // Match "setengah jam lagi"
        if lower.contains("setengah jam lagi") {
            targetDate = cal.date(byAdding: .minute, value: 30, to: referenceDate) ?? referenceDate
            extractedTitle = extractTitle(from: utterance, removing: ["setengah jam lagi", "tolong ingatkan", "saya ada"])
        }
        // Match "X menit lagi"
        else if let minMatch = lower.range(of: #"(\d+)\s*menit\s*lagi"#, options: .regularExpression) {
            let sub = String(lower[minMatch])
            if let num = Int(sub.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                targetDate = cal.date(byAdding: .minute, value: num, to: referenceDate) ?? referenceDate
                extractedTitle = extractTitle(from: utterance, removing: [sub, "tolong ingatkan", "saya ada"])
            }
        }
        // Match "jam X" / "pukul X"
        else if let hourMatch = lower.range(of: #"(?:jam|pukul)\s*(\d{1,2})(?::(\d{2}))?"#, options: .regularExpression) {
            let sub = String(lower[hourMatch])
            let digits = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let hourInt = digits.first.flatMap(Int.init) {
                var hour24 = hourInt
                if hour24 < 12 && (lower.contains("sore") || lower.contains("malam") || (hour24 <= 6 && !lower.contains("pagi"))) {
                    hour24 += 12
                }
                
                var comp = cal.dateComponents([.year, .month, .day, .timeZone], from: referenceDate)
                comp.hour = hour24
                comp.minute = digits.count > 1 ? Int(digits[1]) ?? 0 : 0
                comp.second = 0

                if let candidate = cal.date(from: comp) {
                    if candidate < referenceDate && !lower.contains("kemarin") {
                        // Past-time rollover to tomorrow
                        targetDate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
                    } else {
                        targetDate = candidate
                    }
                }
                extractedTitle = extractTitle(from: utterance, removing: [sub, "sore", "malam", "pagi", "nanti", "tolong ingatkan", "saya ada", "10 menit sebelum", "sebelumnya"])
            }
        } else {
            return nil
        }

        let reminderDate = cal.date(byAdding: .minute, value: -offsetMinutes, to: targetDate) ?? targetDate
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]

        return ScheduleDetail(
            title: extractedTitle.isEmpty ? "Agenda" : extractedTitle.capitalized,
            eventType: "meeting",
            eventStartISO: isoFormatter.string(from: targetDate),
            reminderISO: isoFormatter.string(from: reminderDate),
            offsetMinutes: offsetMinutes,
            confidenceScore: 0.9
        )
    }

    private static func extractTitle(from text: String, removing phrases: [String]) -> String {
        var clean = text
        for p in phrases {
            clean = clean.replacingOccurrences(of: p, with: "", options: .caseInsensitive)
        }
        return clean.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }
}
