//
//  CuaMotionEngine.swift
//  izaNotch
//
//  1:1 Direct Mathematical & Physical Port of CuaDriver's motion engine:
//  - CubicBezier & Dubins Path Planner (from libs/cua-driver/rust/crates/cursor-overlay/src/bezier.rs & path_planner.rs)
//  - Smootherstep speed profile + 4-substep spring-damper physics (from libs/cua-driver/rust/crates/cursor-overlay/src/render_state.rs)
//

import Foundation
import CoreGraphics

// MARK: - Point & Geometry

public struct CuaPoint: Equatable {
    public var x: Double
    public var y: Double

    public static let zero = CuaPoint(x: 0, y: 0)

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(_ cgPoint: CGPoint) {
        self.x = Double(cgPoint.x)
        self.y = Double(cgPoint.y)
    }

    public var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }

    public func hypot(to other: CuaPoint) -> Double {
        let dx = self.x - other.x
        let dy = self.y - other.y
        return Darwin.hypot(dx, dy)
    }
}

// MARK: - Cubic Bezier (from bezier.rs)

public struct CuaCubicBezier {
    public let start: CuaPoint
    public let control1: CuaPoint
    public let control2: CuaPoint
    public let end: CuaPoint
    public let length: Double

    public init(start: CuaPoint, control1: CuaPoint, control2: CuaPoint, end: CuaPoint) {
        self.start = start
        self.control1 = control1
        self.control2 = control2
        self.end = end
        self.length = Self.measureLength(start: start, control1: control1, control2: control2, end: end)
    }

    public func point(at t: Double) -> CuaPoint {
        let clampedT = min(max(t, 0.0), 1.0)
        let u = 1.0 - clampedT
        let uu = u * u
        let uuu = uu * u
        let tt = clampedT * clampedT
        let ttt = tt * clampedT

        let x = uuu * start.x
            + 3.0 * uu * clampedT * control1.x
            + 3.0 * u * tt * control2.x
            + ttt * end.x
        let y = uuu * start.y
            + 3.0 * uu * clampedT * control1.y
            + 3.0 * u * tt * control2.y
            + ttt * end.y

        return CuaPoint(x: x, y: y)
    }

    public func tangent(at t: Double) -> CuaPoint {
        let clampedT = min(max(t, 0.0), 1.0)
        let u = 1.0 - clampedT
        let a = 3.0 * u * u
        let b = 6.0 * u * clampedT
        let c = 3.0 * clampedT * clampedT

        let x = a * (control1.x - start.x)
            + b * (control2.x - control1.x)
            + c * (end.x - control2.x)
        let y = a * (control1.y - start.y)
            + b * (control2.y - control1.y)
            + c * (end.y - control2.y)

        return CuaPoint(x: x, y: y)
    }

    public func heading(at t: Double) -> Double {
        let tg = tangent(at: t)
        return atan2(tg.y, tg.x)
    }

    private static func measureLength(start: CuaPoint, control1: CuaPoint, control2: CuaPoint, end: CuaPoint) -> Double {
        var len = 0.0
        var prev = start
        let tempCurve = CuaCubicBezierUnmeasured(start: start, control1: control1, control2: control2, end: end)
        for i in 1...32 {
            let p = tempCurve.point(at: Double(i) / 32.0)
            len += prev.hypot(to: p)
            prev = p
        }
        return len
    }

    public func sample(at distance: Double) -> (point: CuaPoint, heading: Double) {
        if length <= 0.0 {
            return (end, heading(at: 1.0))
        }
        let t = min(max(distance / length, 0.0), 1.0)
        return (point(at: t), heading(at: t))
    }

    private struct CuaCubicBezierUnmeasured {
        let start: CuaPoint
        let control1: CuaPoint
        let control2: CuaPoint
        let end: CuaPoint

        func point(at t: Double) -> CuaPoint {
            let clampedT = min(max(t, 0.0), 1.0)
            let u = 1.0 - clampedT
            let uu = u * u
            let uuu = uu * u
            let tt = clampedT * clampedT
            let ttt = tt * clampedT
            return CuaPoint(
                x: uuu * start.x + 3.0 * uu * clampedT * control1.x + 3.0 * u * tt * control2.x + ttt * end.x,
                y: uuu * start.y + 3.0 * uu * clampedT * control1.y + 3.0 * u * tt * control2.y + ttt * end.y
            )
        }
    }

    public static func buildMotionBezier(
        start: CuaPoint,
        end: CuaPoint,
        startHandle: Double = 0.3,
        endHandle: Double = 0.3,
        arcSize: Double = 0.25,
        arcFlow: Double = 0.0
    ) -> CuaCubicBezier {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(Darwin.hypot(dx, dy), 1.0)

        // Unit perpendicular (90° CCW of direction vector)
        let perpX = -dy / length
        let perpY = dx / length

        let deflection = length * arcSize
        let flowBias = (arcFlow + 1.0) / 2.0 // map [-1,1] -> [0,1]

        let c1Deflect = deflection * (1.0 - 0.5 * flowBias)
        let c2Deflect = deflection * (1.0 - 0.5 * (1.0 - flowBias))

        let c1Base = CuaPoint(x: start.x + dx * startHandle, y: start.y + dy * startHandle)
        let c2Base = CuaPoint(x: end.x - dx * endHandle, y: end.y - dy * endHandle)

        let control1 = CuaPoint(
            x: c1Base.x + perpX * c1Deflect,
            y: c1Base.y + perpY * c1Deflect
        )
        let control2 = CuaPoint(
            x: c2Base.x + perpX * c2Deflect,
            y: c2Base.y + perpY * c2Deflect
        )

        return CuaCubicBezier(start: start, control1: control1, control2: control2, end: end)
    }
}

// MARK: - Dubins Path Planning (from path_planner.rs)

public struct CuaPathState {
    public let x: Double
    public let y: Double
    public let heading: Double
}

public enum CuaPathKind {
    case dubins
    case linear
}

public enum CuaSegType {
    case L
    case R
    case S
}

public struct CuaPlannedPath {
    public let length: Double
    public let endVisualHeading: Double
    public let kind: CuaPathKind

    let x0: Double
    let y0: Double
    let th0: Double
    let r: Double
    let seg1: Double
    let seg2: Double
    let seg3: Double
    let types: (CuaSegType, CuaSegType, CuaSegType)

    let x1: Double
    let y1: Double
    let th1: Double

    public func sample(at distance: Double) -> CuaPathState {
        switch kind {
        case .linear:
            return sampleLinear(distance)
        case .dubins:
            return sampleDubins(distance)
        }
    }

    private func sampleLinear(_ s: Double) -> CuaPathState {
        let len = max(length, 1.0)
        let u = min(max(s / len, 0.0), 1.0)
        var diff = th1 - th0
        while diff > .pi { diff -= 2.0 * .pi }
        while diff < -.pi { diff += 2.0 * .pi }
        return CuaPathState(
            x: x0 + (x1 - x0) * u,
            y: y0 + (y1 - y0) * u,
            heading: th0 + diff * u
        )
    }

    private func sampleDubins(_ sIn: Double) -> CuaPathState {
        if sIn <= 0.0 {
            return CuaPathState(x: x0, y: y0, heading: th0)
        }
        let l1 = seg1 * r
        let l2 = seg2 * r
        let l3 = seg3 * r
        let s = min(sIn, l1 + l2 + l3)

        var x = x0
        var y = y0
        var th = th0

        let advance: (Double, CuaSegType) -> Void = { len, seg in
            if seg == .S {
                x += cos(th) * len
                y += sin(th) * len
            } else {
                let dth = (len / r) * (seg == .L ? 1.0 : -1.0)
                let perp = seg == .L ? (Double.pi / 2.0) : (-Double.pi / 2.0)
                let cx = x + cos(th + perp) * r
                let cy = y + sin(th + perp) * r
                let ang = atan2(y - cy, x - cx)
                x = cx + cos(ang + dth) * r
                y = cy + sin(ang + dth) * r
                th += dth
            }
        }

        if s <= l1 {
            advance(s, types.0)
            return CuaPathState(x: x, y: y, heading: th)
        }
        advance(l1, types.0)
        if s <= l1 + l2 {
            advance(s - l1, types.1)
            return CuaPathState(x: x, y: y, heading: th)
        }
        advance(l2, types.1)
        advance(s - l1 - l2, types.2)
        return CuaPathState(x: x, y: y, heading: th)
    }
}

public class CuaPathPlanner {
    private static func mod2pi(_ x: Double) -> Double {
        let tau = 2.0 * Double.pi
        let r = x - tau * floor(x / tau)
        return r < 0.0 ? r + tau : r
    }

    private struct DubinsSol {
        let t: Double
        let p: Double
        let q: Double
        let types: (CuaSegType, CuaSegType, CuaSegType)

        var length: Double {
            return t + p + q
        }
    }

    private static func dubinsLSL(d: Double, a: Double, b: Double) -> DubinsSol? {
        let tmp0 = d + sin(a) - sin(b)
        let p2 = 2.0 + d * d - 2.0 * cos(a - b) + 2.0 * d * (sin(a) - sin(b))
        if p2 < 0.0 { return nil }
        let tmp1 = atan2(cos(b) - cos(a), tmp0)
        return DubinsSol(
            t: mod2pi(-a + tmp1),
            p: sqrt(p2),
            q: mod2pi(b - tmp1),
            types: (.L, .S, .L)
        )
    }

    private static func dubinsRSR(d: Double, a: Double, b: Double) -> DubinsSol? {
        let tmp0 = d - sin(a) + sin(b)
        let p2 = 2.0 + d * d - 2.0 * cos(a - b) + 2.0 * d * (sin(b) - sin(a))
        if p2 < 0.0 { return nil }
        let tmp1 = atan2(cos(a) - cos(b), tmp0)
        return DubinsSol(
            t: mod2pi(a - tmp1),
            p: sqrt(p2),
            q: mod2pi(-b + tmp1),
            types: (.R, .S, .R)
        )
    }

    private static func dubinsLSR(d: Double, a: Double, b: Double) -> DubinsSol? {
        let p2 = -2.0 + d * d + 2.0 * cos(a - b) + 2.0 * d * (sin(a) + sin(b))
        if p2 < 0.0 { return nil }
        let p = sqrt(p2)
        let tmp1 = atan2(-(cos(a) + cos(b)), d + sin(a) + sin(b)) - atan2(-2.0, p)
        return DubinsSol(
            t: mod2pi(-a + tmp1),
            p: p,
            q: mod2pi(-mod2pi(b) + tmp1),
            types: (.L, .S, .R)
        )
    }

    private static func dubinsRSL(d: Double, a: Double, b: Double) -> DubinsSol? {
        let p2 = d * d - 2.0 + 2.0 * cos(a - b) - 2.0 * d * (sin(a) + sin(b))
        if p2 < 0.0 { return nil }
        let p = sqrt(p2)
        let tmp1 = atan2(cos(a) + cos(b), d - sin(a) - sin(b)) - atan2(2.0, p)
        return DubinsSol(
            t: mod2pi(a - tmp1),
            p: p,
            q: mod2pi(b - tmp1),
            types: (.R, .S, .L)
        )
    }

    private static func dubinsRLR(d: Double, a: Double, b: Double) -> DubinsSol? {
        let tmp = (6.0 - d * d + 2.0 * cos(a - b) + 2.0 * d * (sin(a) - sin(b))) / 8.0
        if abs(tmp) > 1.0 { return nil }
        let p = mod2pi(2.0 * .pi - acos(tmp))
        let t = mod2pi(a - atan2(cos(a) - cos(b), d - sin(a) + sin(b)) + p / 2.0)
        return DubinsSol(
            t: t,
            p: p,
            q: mod2pi(a - b - t + p),
            types: (.R, .L, .R)
        )
    }

    private static func dubinsLRL(d: Double, a: Double, b: Double) -> DubinsSol? {
        let tmp = (6.0 - d * d + 2.0 * cos(a - b) + 2.0 * d * (sin(b) - sin(a))) / 8.0
        if abs(tmp) > 1.0 { return nil }
        let p = mod2pi(2.0 * .pi - acos(tmp))
        let t = mod2pi(-a + atan2(-cos(a) + cos(b), d + sin(a) - sin(b)) + p / 2.0)
        return DubinsSol(
            t: t,
            p: p,
            q: mod2pi(mod2pi(b) - a - t + p),
            types: (.L, .R, .L)
        )
    }

    public static func plan(
        x0: Double, y0: Double, th0: Double,
        x1: Double, y1: Double, th1: Double,
        endVisualHeading: Double,
        turnRadius: Double = 80.0
    ) -> CuaPlannedPath {
        let r = max(turnRadius, 1.0)
        let dx = x1 - x0
        let dy = y1 - y0
        let dDist = Darwin.hypot(dx, dy)

        if dDist >= 0.5 {
            let d = dDist / r
            let theta = mod2pi(atan2(dy, dx))
            let a = mod2pi(th0 - theta)
            let b = mod2pi(th1 - theta)

            let solvers: [(Double, Double, Double) -> DubinsSol?] = [
                dubinsLSL, dubinsRSR, dubinsLSR, dubinsRSL, dubinsRLR, dubinsLRL
            ]

            var bestLen = Double.infinity
            var bestSol: DubinsSol? = nil

            for solver in solvers {
                if let sol = solver(d, a, b) {
                    let len = sol.length
                    if len.isFinite && len >= 0.0 && len < bestLen {
                        bestLen = len
                        bestSol = sol
                    }
                }
            }

            if let sol = bestSol {
                return CuaPlannedPath(
                    length: (sol.t + sol.p + sol.q) * r,
                    endVisualHeading: endVisualHeading,
                    kind: .dubins,
                    x0: x0, y0: y0, th0: th0,
                    r: r,
                    seg1: sol.t, seg2: sol.p, seg3: sol.q,
                    types: sol.types,
                    x1: x1, y1: y1, th1: th1
                )
            }
        }

        // Linear fallback
        let d = max(Darwin.hypot(dx, dy), 1.0)
        return CuaPlannedPath(
            length: d,
            endVisualHeading: endVisualHeading,
            kind: .linear,
            x0: x0, y0: y0, th0: th0,
            r: r,
            seg1: 0.0, seg2: 0.0, seg3: 0.0,
            types: (.S, .S, .S),
            x1: x1, y1: y1, th1: th1
        )
    }
}

// MARK: - Spring & Motion Config (from motion.rs)

public struct CuaSpring {
    public var ox: Double = 0.0
    public var oy: Double = 0.0
    public var vx: Double = 0.0
    public var vy: Double = 0.0

    public init(ox: Double = 0.0, oy: Double = 0.0, vx: Double = 0.0, vy: Double = 0.0) {
        self.ox = ox
        self.oy = oy
        self.vx = vx
        self.vy = vy
    }
}

public struct CuaMotionConfig {
    public var startHandle: Double = 0.3
    public var endHandle: Double = 0.3
    public var arcSize: Double = 0.25
    public var arcFlow: Double = 0.0
    public var spring: Double = 0.72
    public var glideDurationMs: Double = 0.0 // 0 = speed-based mode
    public var dwellAfterClickMs: Double = 80.0
    public var idleHideMs: Double = 20_000.0
    public var pressDurationMs: Double = 120.0
    public var peakSpeed: Double = 900.0
    public var minStartSpeed: Double = 300.0
    public var minEndSpeed: Double = 200.0
    public var turnRadius: Double = 80.0

    public static let `default` = CuaMotionConfig()
}

// MARK: - Motion Runner (from render_state.rs tick_swift_constants)

public final class CuaMotionRunner: @unchecked Sendable {
    public static let peakSpeed: Double = 900.0
    public static let minStartSpeed: Double = 300.0
    public static let minEndSpeed: Double = 200.0
    public static let springK: Double = 400.0
    public static let springC: Double = 17.0
    public static let springOvershoot: Double = 0.8

    public private(set) var currentPosition: CGPoint
    public private(set) var currentHeadingRadians: Double
    public private(set) var currentScale: Double = 1.0
    public private(set) var isCompleted: Bool = false

    public var isSpringSettling: Bool {
        return path == nil && spring != nil
    }

    private var path: CuaPlannedPath?
    private var dist: Double = 0.0
    private var spring: CuaSpring?
    private var springTarget: (x: Double, y: Double, heading: Double)?

    public init(startPosition: CGPoint, startHeadingRadians: Double = -35.0 * (.pi / 180.0)) {
        self.currentPosition = startPosition
        self.currentHeadingRadians = startHeadingRadians
    }

    public func planFlight(to target: CGPoint, endVisualHeading: Double = -35.0 * (.pi / 180.0)) {
        let p0 = CuaPoint(currentPosition)
        let p1 = CuaPoint(target)

        // Heading towards target
        let initialHeading = atan2(p1.y - p0.y, p1.x - p0.x)
        self.path = CuaPathPlanner.plan(
            x0: p0.x, y0: p0.y, th0: initialHeading,
            x1: p1.x, y1: p1.y, th1: endVisualHeading,
            endVisualHeading: endVisualHeading,
            turnRadius: 80.0
        )
        self.dist = 0.0
        self.spring = nil
        self.springTarget = nil
        self.isCompleted = false
    }

    /// Advances the simulation by dt seconds.
    /// Returns true when the entire animation (including spring settle) is finished.
    public func tick(dt: Double) -> Bool {
        if let p = path {
            let pathLen = max(p.length, 1.0)
            let u = min(dist / pathLen, 1.0)

            // Smootherstep speed profile (normalised: peak = 1.0 at u=0.5)
            let profile = (30.0 * u * u * (1.0 - u) * (1.0 - u)) / 1.875
            let floorSpeed = u < 0.5 ? Self.minStartSpeed : Self.minEndSpeed
            let currentSpeed = floorSpeed + (Self.peakSpeed - floorSpeed) * profile

            dist += currentSpeed * dt

            // Scale pulse: sin curve peaks at midpoint of the flight (~1.25x)
            currentScale = 1.0 + sin(u * .pi) * 0.25

            if dist >= pathLen {
                // Transition to spring settle
                let endState = p.sample(at: pathLen)
                let endHeading = p.endVisualHeading
                let vh = endState.heading
                let impulse = currentSpeed

                self.spring = CuaSpring(
                    ox: 0.0,
                    oy: 0.0,
                    vx: impulse * Self.springOvershoot * cos(vh),
                    vy: impulse * Self.springOvershoot * sin(vh)
                )
                self.springTarget = (endState.x, endState.y, endHeading)
                self.currentPosition = CGPoint(x: endState.x, y: endState.y)
                self.currentHeadingRadians = endHeading
                self.path = nil
                self.dist = 0.0
                self.currentScale = 1.0
            } else {
                let s = p.sample(at: dist)
                self.currentPosition = CGPoint(x: s.x, y: s.y)
                // Tangent heading of motion
                self.currentHeadingRadians = s.heading
            }
            return false
        } else if var s = spring, let (tx, ty, th) = springTarget {
            let substeps = 4
            let sdt = dt / Double(substeps)
            for _ in 0..<substeps {
                s.vx += (-Self.springK * s.ox - Self.springC * s.vx) * sdt
                s.vy += (-Self.springK * s.oy - Self.springC * s.vy) * sdt
                s.ox += s.vx * sdt
                s.oy += s.vy * sdt
            }
            self.currentPosition = CGPoint(x: tx + s.ox, y: ty + s.oy)
            self.currentHeadingRadians = th
            self.currentScale = 1.0

            if Darwin.hypot(s.ox, s.oy) < 0.3 && Darwin.hypot(s.vx, s.vy) < 2.0 {
                self.currentPosition = CGPoint(x: tx, y: ty)
                self.spring = nil
                self.springTarget = nil
                self.isCompleted = true
                return true
            } else {
                self.spring = s
                return false
            }
        }

        self.isCompleted = true
        return true
    }
}
