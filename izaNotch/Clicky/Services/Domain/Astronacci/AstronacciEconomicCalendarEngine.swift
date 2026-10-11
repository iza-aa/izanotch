//
//  AstronacciEconomicCalendarEngine.swift
//  izaNotch
//
//  Created for Izanotchy - Advanced Astronacci Foundations (Pillar: High-Impact Economic News Buffer)
//  Enforces Chapter 7 Astronacci Scalping SOP: Jarak rilis berita High-Impact <= 45 menit -> STAND ASIDE.
//  Uses official versioned calendar (2025-2026) with validUntil, ET tzdb parsing (DST resilient).
//  Pure Swift, thread-safe, Sendable, fail-closed / fail-open warning on expiration.
//

import Foundation

public struct EconomicEvent: Codable, Equatable, Sendable {
    public let name: String
    let date: String      // YYYY-MM-DD
    let timeET: String    // HH:mm in America/New_York
}
struct EconomicCalendarData: Codable, Equatable, Sendable {
    let validUntil: String // ISO8601
    let timeZone: String   // "America/New_York"
    let events: [EconomicEvent]
}
public struct NewsBufferResult: Equatable, Sendable {
    public let isInsideBuffer: Bool
    public let activeEvent: EconomicEvent?
    public let minutesDelta: Int // negative = before event, positive = after event
    public let isExpiredCalendar: Bool

    public init(
        isInsideBuffer: Bool,
        activeEvent: EconomicEvent?,
        minutesDelta: Int,
        isExpiredCalendar: Bool
    ) {
        self.isInsideBuffer = isInsideBuffer
        self.activeEvent = activeEvent
        self.minutesDelta = minutesDelta
        self.isExpiredCalendar = isExpiredCalendar
    }

    public static let clear = NewsBufferResult(
        isInsideBuffer: false,
        activeEvent: nil,
        minutesDelta: 0,
        isExpiredCalendar: false
    )
}

struct AstronacciEconomicCalendarEngine: Sendable {
    let parsedEvents: [(event: EconomicEvent, utcDate: Date)]
    let validUntilDate: Date?

    /// Single Source of Truth loader: loads from Bundle.main resource or repo file paths.
    /// Strictly eliminates duplicate hardcoded constants and manual sync drift.
    static func loadSingleSourceCalendar() -> EconomicCalendarData {
        // 1. Production AppKit runtime inside izaNotch.app
        if let bundleURL = Bundle.main.url(forResource: "economic_calendar_2025_2026", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let decoded = try? JSONDecoder().decode(EconomicCalendarData.self, from: data) {
            return decoded
        }

        // 2. CLI test runners and scripts executing from repository root
        let searchPaths = [
            "boringNotch/Clicky/Resources/economic_calendar_2025_2026.json",
            "../boringNotch/Clicky/Resources/economic_calendar_2025_2026.json",
            "Resources/economic_calendar_2025_2026.json"
        ]
        for path in searchPaths {
            let fileURL = URL(fileURLWithPath: path)
            if let data = try? Data(contentsOf: fileURL),
               let decoded = try? JSONDecoder().decode(EconomicCalendarData.self, from: data) {
                return decoded
            }
        }

        // 3. Fail-Open Warning Fallback: Expired calendar triggers explicit warning rather than silent errors
        return EconomicCalendarData(
            validUntil: "1970-01-01T00:00:00Z",
            timeZone: "America/New_York",
            events: []
        )
    }

    init(jsonString: String? = nil, fileURL: URL? = nil) {
        let decoded: EconomicCalendarData
        if let js = jsonString, let d = js.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(EconomicCalendarData.self, from: d) {
            decoded = parsed
        } else if let url = fileURL, let d = try? Data(contentsOf: url),
                  let parsed = try? JSONDecoder().decode(EconomicCalendarData.self, from: d) {
            decoded = parsed
        } else {
            decoded = Self.loadSingleSourceCalendar()
        }

        // Parse validUntil
        let iso = ISO8601DateFormatter()
        self.validUntilDate = iso.date(from: decoded.validUntil)

        // Parse events with ET tzdb
        var nyCalendar = Calendar(identifier: .gregorian)
        nyCalendar.timeZone = TimeZone(identifier: decoded.timeZone) ?? TimeZone(identifier: "America/New_York")!

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = nyCalendar
        dateFormatter.timeZone = nyCalendar.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var list: [(EconomicEvent, Date)] = []
        for ev in decoded.events {
            let dtString = "\(ev.date) \(ev.timeET)"
            if let d = dateFormatter.date(from: dtString) {
                list.append((ev, d))
            }
        }
        self.parsedEvents = list.sorted(by: { $0.1 < $1.1 })
    }

    /// Evaluates if the current date/time is within the high-impact news buffer (+- 45 minutes).
    func evaluateBuffer(currentDate: Date = Date(), bufferMinutes: Int = 45) -> NewsBufferResult {
        // 1. Check expiration
        let isExpired: Bool
        if let vDate = validUntilDate, currentDate > vDate {
            isExpired = true
        } else {
            isExpired = false
        }

        let bufferSeconds = Double(bufferMinutes) * 60.0

        // Find the closest high impact event
        var closestEvent: (event: EconomicEvent, date: Date, deltaSeconds: Double)? = nil
        var minAbsDelta: Double = .infinity

        for (ev, date) in parsedEvents {
            let delta = date.timeIntervalSince(currentDate) // positive: future, negative: past
            let absDelta = abs(delta)

            if absDelta < minAbsDelta {
                minAbsDelta = absDelta
                closestEvent = (ev, date, delta)
            }
        }

        if isExpired {
            return NewsBufferResult(
                isInsideBuffer: false,
                activeEvent: closestEvent?.event,
                minutesDelta: Int((closestEvent?.deltaSeconds ?? 0) / 60.0),
                isExpiredCalendar: true
            )
        }

        guard let closest = closestEvent else {
            return .clear
        }

        let deltaMin = Int(closest.deltaSeconds / 60.0)

        // Inside buffer: |delta| <= 45 minutes
        if minAbsDelta <= bufferSeconds {
            return NewsBufferResult(
                isInsideBuffer: true,
                activeEvent: closest.event,
                minutesDelta: deltaMin,
                isExpiredCalendar: false
            )
        } else if deltaMin > 0 && deltaMin <= 240 {
            // Upcoming in next 4 hours
            return NewsBufferResult(
                isInsideBuffer: false,
                activeEvent: closest.event,
                minutesDelta: deltaMin,
                isExpiredCalendar: false
            )
        } else {
            return NewsBufferResult(
                isInsideBuffer: false,
                activeEvent: closest.event,
                minutesDelta: deltaMin,
                isExpiredCalendar: false
            )
        }
    }
}
