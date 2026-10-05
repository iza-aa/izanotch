//
//  AstronacciEphemerisEngine.swift
//  boringNotch
//
//  Created for Izanotchy - Advanced Astronacci Foundations (Pillar 7: Financial Astrology / Ephemeris)
//  Pure Swift deterministic calculation of Jean Meeus Astronomical Algorithms:
//  1. High-precision Lunar Phase & Moon Age (0° New Moon, 180° Full Moon).
//  2. High-precision Mercury Geocentric Apparent Motion (Direct, Retrograde, Stationary).
//  Strictly pure-mathematical, zero network calls, zero internet dependency, thread-safe & Sendable.
//  INVARIANT: Presentational only. Never mutates core engine trading vetoes or risk sizing.
//

import Foundation

public enum LunarPhase: String, Equatable, Sendable {
    case newMoon = "Bulan Baru (New Moon)"
    case waxingCrescent = "Bulan Sabit Awal (Waxing Crescent)"
    case firstQuarter = "Kuartal Pertama (First Quarter)"
    case waxingGibbous = "Bulan Cembung Awal (Waxing Gibbous)"
    case fullMoon = "Bulan Purnama (Full Moon)"
    case waningGibbous = "Bulan Cembung Akhir (Waning Gibbous)"
    case lastQuarter = "Kuartal Terakhir (Last Quarter)"
    case waningCrescent = "Bulan Sabit Akhir (Waning Crescent)"
}

public enum PlanetaryMotion: String, Equatable, Sendable {
    case direct = "Direct (Maju Normal)"
    case retrograde = "Retrograde (Mundur Semu)"
    case stationary = "Stationary (Stasioner / Berbalik Arah)"
}

public struct AstronacciAstroReport: Equatable, Sendable {
    public let date: Date
    public let lunarPhase: LunarPhase
    public let moonAgeDays: Double
    public let moonElongationDeg: Double
    public let isNearNewOrFullMoon: Bool
    public let mercuryMotion: PlanetaryMotion
    public let mercuryVelocityDegPerDay: Double
    public let description: String

    public init(
        date: Date,
        lunarPhase: LunarPhase,
        moonAgeDays: Double,
        moonElongationDeg: Double,
        isNearNewOrFullMoon: Bool,
        mercuryMotion: PlanetaryMotion,
        mercuryVelocityDegPerDay: Double,
        description: String
    ) {
        self.date = date
        self.lunarPhase = lunarPhase
        self.moonAgeDays = moonAgeDays
        self.moonElongationDeg = moonElongationDeg
        self.isNearNewOrFullMoon = isNearNewOrFullMoon
        self.mercuryMotion = mercuryMotion
        self.mercuryVelocityDegPerDay = mercuryVelocityDegPerDay
        self.description = description
    }

    public static let standard = AstronacciAstroReport(
        date: Date(),
        lunarPhase: .waxingGibbous,
        moonAgeDays: 12.0,
        moonElongationDeg: 145.0,
        isNearNewOrFullMoon: false,
        mercuryMotion: .direct,
        mercuryVelocityDegPerDay: 1.2,
        description: "Fase Bulan: Waxing Gibbous • Merkurius: Direct"
    )
}

public struct AstronacciEphemerisEngine: Sendable {
    public init() {}

    private func toRad(_ deg: Double) -> Double { deg * .pi / 180.0 }
    private func toDeg(_ rad: Double) -> Double { rad * 180.0 / .pi }
    private func normalizeDeg(_ deg: Double) -> Double {
        var d = deg.truncatingRemainder(dividingBy: 360.0)
        if d < 0 { d += 360.0 }
        return d
    }

    /// Converts Date to Julian Day Number (JD) in Universal Time (UT)
    public func calculateJulianDay(date: Date) -> Double {
        let calendar = Calendar(identifier: .gregorian)
        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let comps = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        let year = comps.year ?? 2000
        let month = comps.month ?? 1
        let day = Double(comps.day ?? 1)
        let hour = Double(comps.hour ?? 0)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0) + Double(comps.nanosecond ?? 0) / 1_000_000_000.0

        let dayFraction = day + (hour / 24.0) + (minute / 1440.0) + (second / 86400.0)

        var y = Double(year)
        var m = Double(month)
        if m <= 2 {
            y -= 1
            m += 12
        }

        let a = floor(y / 100.0)
        let b = 2 - a + floor(a / 4.0)
        let jd = floor(365.25 * (y + 4716.0)) + floor(30.6001 * (m + 1.0)) + dayFraction + b - 1524.5
        return jd
    }

    /// Calculates Solar Apparent Ecliptic Longitude (Meeus Chapter 25)
    public func calculateSunLongitude(T: Double) -> Double {
        let L0 = normalizeDeg(280.46646 + 36000.76983 * T + 0.0003032 * T * T)
        let M = normalizeDeg(357.52911 + 35999.05029 * T - 0.0001537 * T * T)
        let C = (1.914602 - 0.004817 * T) * sin(toRad(M)) + (0.019993 - 0.000101 * T) * sin(toRad(2.0 * M)) + 0.000289 * sin(toRad(3.0 * M))
        return normalizeDeg(L0 + C)
    }

    /// Calculates Lunar Apparent Ecliptic Longitude (Meeus Chapter 47)
    public func calculateMoonLongitude(T: Double) -> Double {
        let Lp = normalizeDeg(218.3164477 + 481267.88123421 * T - 0.0015786 * T * T)
        let D = normalizeDeg(297.8501921 + 445267.5105277 * T - 0.0018819 * T * T)
        let M = normalizeDeg(357.5291092 + 35999.0502909 * T - 0.0001536 * T * T)
        let Mp = normalizeDeg(134.9633964 + 477198.8675055 * T + 0.0087414 * T * T)
        let F = normalizeDeg(93.2720950 + 483202.0175233 * T - 0.0036539 * T * T)

        let sigmaL = 6.288774 * sin(toRad(Mp))
                   + 1.274027 * sin(toRad(2.0 * D - Mp))
                   + 0.658314 * sin(toRad(2.0 * D))
                   + 0.213618 * sin(toRad(2.0 * Mp))
                   - 0.185116 * sin(toRad(M))
                   - 0.114332 * sin(toRad(2.0 * F))
                   + 0.058793 * sin(toRad(2.0 * D - 2.0 * Mp))
                   + 0.057066 * sin(toRad(2.0 * D - M - Mp))

        return normalizeDeg(Lp + sigmaL)
    }

    /// Calculates Mercury Geocentric Ecliptic Longitude (Meeus Heliocentric reduction)
    public func calculateMercuryGeocentricLongitude(jd: Double) -> Double {
        let T = (jd - 2451545.0) / 36525.0

        // Earth Keplerian orbit
        let Le = normalizeDeg(100.46457166 + 36000.76982779 * T)
        let ae = 1.00000011
        let ee = 0.01671022 - 0.00003804 * T
        let pe = normalizeDeg(102.93768193 + 0.32327364 * T)
        let Me = normalizeDeg(Le - pe)
        let nuE = toRad(Me) + (2.0 * ee - pow(ee, 3.0)/4.0) * sin(toRad(Me)) + (5.0/4.0) * pow(ee, 2.0) * sin(2.0 * toRad(Me))
        let rE = ae * (1.0 - pow(ee, 2.0)) / (1.0 + ee * cos(nuE))
        let Xe = rE * cos(nuE + toRad(pe))
        let Ye = rE * sin(nuE + toRad(pe))

        // Mercury Keplerian orbit
        let Lm = normalizeDeg(252.2507 + 149472.6741 * T)
        let am = 0.38709893
        let em = 0.20563069 + 0.00002527 * T
        let pm = normalizeDeg(77.45645 + 1.55648 * T)
        let Mm = normalizeDeg(Lm - pm)
        let nuM = toRad(Mm) + (2.0 * em - pow(em, 3.0)/4.0) * sin(toRad(Mm)) + (5.0/4.0) * pow(em, 2.0) * sin(2.0 * toRad(Mm))
        let rM = am * (1.0 - pow(em, 2.0)) / (1.0 + em * cos(nuM))
        let Xm = rM * cos(nuM + toRad(pm))
        let Ym = rM * sin(nuM + toRad(pm))

        // Geocentric vector
        let dX = Xm - Xe
        let dY = Ym - Ye
        return normalizeDeg(toDeg(atan2(dY, dX)))
    }

    /// Evaluates the complete Astronomical Ephemeris report for the given Date
    public func calculateAstroReport(date: Date) -> AstronacciAstroReport {
        let jd = calculateJulianDay(date: date)
        let T = (jd - 2451545.0) / 36525.0

        let sunLon = calculateSunLongitude(T: T)
        let moonLon = calculateMoonLongitude(T: T)

        let elongation = normalizeDeg(moonLon - sunLon)
        let synodicMonth = 29.53058867
        let moonAge = (elongation / 360.0) * synodicMonth

        // Determine Lunar Phase
        let phase: LunarPhase
        let isNearPeak: Bool
        if elongation >= 345.0 || elongation < 15.0 {
            phase = .newMoon
            isNearPeak = true
        } else if elongation < 75.0 {
            phase = .waxingCrescent
            isNearPeak = false
        } else if elongation < 105.0 {
            phase = .firstQuarter
            isNearPeak = false
        } else if elongation < 165.0 {
            phase = .waxingGibbous
            isNearPeak = false
        } else if elongation < 195.0 {
            phase = .fullMoon
            isNearPeak = true
        } else if elongation < 255.0 {
            phase = .waningGibbous
            isNearPeak = false
        } else if elongation < 285.0 {
            phase = .lastQuarter
            isNearPeak = false
        } else {
            phase = .waningCrescent
            isNearPeak = false
        }

        // Mercury apparent velocity (differential over 1 day)
        let lonPrev = calculateMercuryGeocentricLongitude(jd: jd - 0.5)
        let lonNext = calculateMercuryGeocentricLongitude(jd: jd + 0.5)
        var velocity = lonNext - lonPrev
        if velocity > 180.0 { velocity -= 360.0 }
        if velocity < -180.0 { velocity += 360.0 }

        let motion: PlanetaryMotion
        if velocity < -0.05 {
            motion = .retrograde
        } else if abs(velocity) <= 0.05 {
            motion = .stationary
        } else {
            motion = .direct
        }

        let moonIcon = isNearPeak ? (phase == .fullMoon ? "🌕" : "🌑") : "🌓"
        let retroIcon = motion == .retrograde ? "⚠️" : "🪐"
        let desc = "\(moonIcon) \(phase.rawValue) (Usia: \(String(format: "%.1f", moonAge)) hari) • \(retroIcon) Merkurius \(motion.rawValue)"

        return AstronacciAstroReport(
            date: date,
            lunarPhase: phase,
            moonAgeDays: moonAge,
            moonElongationDeg: elongation,
            isNearNewOrFullMoon: isNearPeak,
            mercuryMotion: motion,
            mercuryVelocityDegPerDay: velocity,
            description: desc
        )
    }
}
