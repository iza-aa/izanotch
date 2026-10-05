//
//  MarketSession.swift
//  ClickyFoundation
//
//  Global financial market session evaluation with resilient dynamic TZDB.
//

import Foundation

public enum MarketSession: String, Sendable, Equatable {
    case london = "LONDON"
    case newYork = "NEW_YORK"
    case londonNYOverlap = "LONDON_NY_OVERLAP"
    case asianOffPeak = "ASIAN_OFF_PEAK"

    /// Evaluates current global market session with resilient dynamic TZDB (DST-free).
    public static func current(date: Date = Date()) -> MarketSession {
        var londonCal = Calendar(identifier: .gregorian)
        londonCal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let londonHour = Double(londonCal.component(.hour, from: date)) + Double(londonCal.component(.minute, from: date)) / 60.0
        let isLondonOpen = londonHour >= 8.0 && londonHour < 16.5

        var nyCal = Calendar(identifier: .gregorian)
        nyCal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let nyHour = Double(nyCal.component(.hour, from: date)) + Double(nyCal.component(.minute, from: date)) / 60.0
        let isNYOpen = nyHour >= 9.5 && nyHour < 16.0

        if isLondonOpen && isNYOpen {
            return .londonNYOverlap
        } else if isLondonOpen {
            return .london
        } else if isNYOpen {
            return .newYork
        } else {
            return .asianOffPeak
        }
    }
}
