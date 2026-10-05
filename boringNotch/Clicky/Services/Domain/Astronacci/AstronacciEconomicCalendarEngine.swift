//
//  AstronacciEconomicCalendarEngine.swift
//  boringNotch
//
//  Created for Izanotchy - Advanced Astronacci Foundations (Pillar: High-Impact Economic News Buffer)
//  Enforces Chapter 7 Astronacci Scalping SOP: Jarak rilis berita High-Impact <= 45 menit -> STAND ASIDE.
//  Uses official versioned calendar (2025-2026) with validUntil, ET tzdb parsing (DST resilient).
//  Pure Swift, thread-safe, Sendable, fail-closed / fail-open warning on expiration.
//

import Foundation

public struct EconomicEvent: Codable, Equatable, Sendable {
    public let name: String
    public let date: String      // YYYY-MM-DD
    public let timeET: String    // HH:mm in America/New_York
    public let impact: String    // HIGH, MEDIUM, LOW

    public init(name: String, date: String, timeET: String, impact: String = "HIGH") {
        self.name = name
        self.date = date
        self.timeET = timeET
        self.impact = impact
    }
}

public struct EconomicCalendarData: Codable, Equatable, Sendable {
    public let version: String
    public let source: String?
    public let sources: [String: String]?
    public let validUntil: String // ISO8601
    public let timeZone: String   // "America/New_York"
    public let events: [EconomicEvent]

    public init(
        version: String,
        source: String? = nil,
        sources: [String: String]? = nil,
        validUntil: String,
        timeZone: String,
        events: [EconomicEvent]
    ) {
        self.version = version
        self.source = source
        self.sources = sources
        self.validUntil = validUntil
        self.timeZone = timeZone
        self.events = events
    }
}

public struct NewsBufferResult: Equatable, Sendable {
    public let isInsideBuffer: Bool
    public let activeEvent: EconomicEvent?
    public let eventDateUTC: Date?
    public let minutesDelta: Int // negative = before event, positive = after event
    public let isExpiredCalendar: Bool
    public let alertBadge: String?
    public let advisoryText: String

    public init(
        isInsideBuffer: Bool,
        activeEvent: EconomicEvent?,
        eventDateUTC: Date?,
        minutesDelta: Int,
        isExpiredCalendar: Bool,
        alertBadge: String?,
        advisoryText: String
    ) {
        self.isInsideBuffer = isInsideBuffer
        self.activeEvent = activeEvent
        self.eventDateUTC = eventDateUTC
        self.minutesDelta = minutesDelta
        self.isExpiredCalendar = isExpiredCalendar
        self.alertBadge = alertBadge
        self.advisoryText = advisoryText
    }

    public static let clear = NewsBufferResult(
        isInsideBuffer: false,
        activeEvent: nil,
        eventDateUTC: nil,
        minutesDelta: 0,
        isExpiredCalendar: false,
        alertBadge: nil,
        advisoryText: "Jadwal berita aman (> 45 menit dari rilis data High-Impact)."
    )
}

public struct AstronacciEconomicCalendarEngine: Sendable {
    public let calendarData: EconomicCalendarData
    public let parsedEvents: [(event: EconomicEvent, utcDate: Date)]
    public let validUntilDate: Date?

    /// Single Source of Truth loader: loads from Bundle.main resource or repo file paths.
    /// Strictly eliminates duplicate hardcoded constants and manual sync drift.
    public static func loadSingleSourceCalendar() -> EconomicCalendarData {
        // 1. Production AppKit runtime inside boringNotch.app
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
            version: "1.1-missing",
            source: "Missing Calendar Resource",
            sources: nil,
            validUntil: "1970-01-01T00:00:00Z",
            timeZone: "America/New_York",
            events: []
        )
    }

    public init(jsonString: String? = nil, fileURL: URL? = nil) {
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
        self.calendarData = decoded

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
    public func evaluateBuffer(currentDate: Date = Date(), bufferMinutes: Int = 45) -> NewsBufferResult {
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
            let validStr = validUntilDate != nil ? ISO8601DateFormatter().string(from: validUntilDate!) : "2026-12-31"
            return NewsBufferResult(
                isInsideBuffer: false,
                activeEvent: closestEvent?.event,
                eventDateUTC: closestEvent?.date,
                minutesDelta: Int((closestEvent?.deltaSeconds ?? 0) / 60.0),
                isExpiredCalendar: true,
                alertBadge: "⚠️ JADWAL BERITA KEDALUWARSA",
                advisoryText: "Jadwal kalender ekonomi telah melewati masa berlaku (\(validStr)) — mohon perbarui data kalender."
            )
        }

        guard let closest = closestEvent else {
            return .clear
        }

        let deltaMin = Int(closest.deltaSeconds / 60.0)

        // Inside buffer: |delta| <= 45 minutes
        if minAbsDelta <= bufferSeconds {
            let timingWord = deltaMin >= 0 ? "dalam \(deltaMin) menit" : "\(abs(deltaMin)) menit lalu"
            let badge = "🚨 BUFFER BERITA TINGGI (\(closest.event.name))"
            let advice = "Peringatan SOP Bab 7 Astronacci: \(closest.event.name) dijadwalkan \(timingWord). Pasar rentan lonjakan volatilitas, slippage, dan manipulasi likuiditas. Status disarankan: STAND ASIDE."
            return NewsBufferResult(
                isInsideBuffer: true,
                activeEvent: closest.event,
                eventDateUTC: closest.date,
                minutesDelta: deltaMin,
                isExpiredCalendar: false,
                alertBadge: badge,
                advisoryText: advice
            )
        } else if deltaMin > 0 && deltaMin <= 240 {
            // Upcoming in next 4 hours
            let hours = deltaMin / 60
            let remMin = deltaMin % 60
            let timeStr = hours > 0 ? "\(hours) jam \(remMin) menit" : "\(remMin) menit"
            let advice = "Rilis berita besar \(closest.event.name) dijadwalkan dalam \(timeStr). Pantau pergerakan harga menjelang jam rilis."
            return NewsBufferResult(
                isInsideBuffer: false,
                activeEvent: closest.event,
                eventDateUTC: closest.date,
                minutesDelta: deltaMin,
                isExpiredCalendar: false,
                alertBadge: "⏱️ INFO AGENDA",
                advisoryText: advice
            )
        } else {
            return NewsBufferResult(
                isInsideBuffer: false,
                activeEvent: closest.event,
                eventDateUTC: closest.date,
                minutesDelta: deltaMin,
                isExpiredCalendar: false,
                alertBadge: nil,
                advisoryText: "Jadwal berita aman (> 45 menit dari rilis data High-Impact)."
            )
        }
    }
}
