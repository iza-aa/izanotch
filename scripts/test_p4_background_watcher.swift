//
//  test_p4_background_watcher.swift
//  scripts
//
//  TDD & Verification Suite for P4: Decoupled Passive Background Market Watcher Service
//  Tests:
//  1. Default State is OFF (Passive Opt-In Canon)
//  2. Monitored Symbols Cap (Strictly Max 3 Simultaneous Symbols)
//  3. Trigger Logic: Price touches/enters Golden Pocket
//  4. Cooldown Enforcement: 15-minute anti-spam suppression
//  5. TTL / 24-Hour Expiration to Terminal State (.expired)
//  6. Kill-Switch: Deactivation clears loop and halts monitoring
//
//  Compilation standard:
//  swiftc -parse-as-library scripts/test_p4_background_watcher.swift -o /tmp/test_p4 && /tmp/test_p4
//

import Foundation

var totalAssertions = 0
var passedAssertions = 0
var failedAssertions = 0

func assertTest(_ name: String, _ condition: Bool, detail: String = "") {
    totalAssertions += 1
    if condition {
        passedAssertions += 1
        if detail.isEmpty {
            print("  ✅ [PASS] \(name)")
        } else {
            print("  ✅ [PASS] \(name) (\(detail))")
        }
    } else {
        failedAssertions += 1
        print("  ❌ [FAIL] \(name) — \(detail.isEmpty ? "Condition evaluated to false" : detail)")
    }
}

// MARK: - Isolated P4 Watcher Model & Actor for Test Suite Verification

public enum WatcherSetupState: String, Equatable {
    case active
    case triggered
    case inCooldown
    case expired
}

public struct MonitoredSetup: Equatable {
    public let symbol: String
    public let displaySymbol: String
    public let addedAt: Date
    public let ttlSeconds: TimeInterval
    public let gpLow: Double
    public let gpHigh: Double
    public var lastAlertAt: Date?
    public var state: WatcherSetupState

    public init(
        symbol: String,
        displaySymbol: String,
        addedAt: Date = Date(),
        ttlSeconds: TimeInterval = 86400.0, // 24 hours
        gpLow: Double,
        gpHigh: Double,
        lastAlertAt: Date? = nil,
        state: WatcherSetupState = .active
    ) {
        self.symbol = symbol
        self.displaySymbol = displaySymbol
        self.addedAt = addedAt
        self.ttlSeconds = ttlSeconds
        self.gpLow = gpLow
        self.gpHigh = gpHigh
        self.lastAlertAt = lastAlertAt
        self.state = state
    }
}

public struct WatcherError: LocalizedError, Equatable {
    public let message: String
    public var errorDescription: String? { message }
}

public actor MockBackgroundWatcherService {
    public static let maxSimultaneousSymbols = 3
    public static let alertCooldownSeconds: TimeInterval = 900.0 // 15 minutes

    public private(set) var isEnabled: Bool = false
    public private(set) var monitoredSetups: [String: MonitoredSetup] = [:]
    public private(set) var alertHistory: [(symbol: String, price: Double, timestamp: Date)] = []

    public init(defaultEnabled: Bool = false) {
        self.isEnabled = defaultEnabled
    }

    public func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        if !enabled {
            // Kill switch clears/pauses active monitoring
            monitoredSetups.removeAll()
        }
    }

    public func addSetup(
        symbol: String,
        displaySymbol: String,
        gpLow: Double,
        gpHigh: Double,
        referenceDate: Date = Date(),
        ttl: TimeInterval = 86400.0
    ) -> Result<MonitoredSetup, WatcherError> {
        if monitoredSetups[symbol] == nil && monitoredSetups.count >= Self.maxSimultaneousSymbols {
            return .failure(WatcherError(message: "Batas pengawasan aktif: maksimal \(Self.maxSimultaneousSymbols) simbol simultaneously"))
        }

        let setup = MonitoredSetup(
            symbol: symbol,
            displaySymbol: displaySymbol,
            addedAt: referenceDate,
            ttlSeconds: ttl,
            gpLow: min(gpLow, gpHigh),
            gpHigh: max(gpLow, gpHigh),
            lastAlertAt: nil,
            state: .active
        )
        monitoredSetups[symbol] = setup
        return .success(setup)
    }

    public func removeSetup(symbol: String) {
        monitoredSetups.removeValue(forKey: symbol)
    }

    public func evaluatePrice(
        symbol: String,
        currentLivePrice: Double,
        currentTime: Date = Date()
    ) -> (shouldAlert: Bool, reason: String) {
        guard isEnabled else {
            return (false, "Watcher is disabled")
        }
        guard var setup = monitoredSetups[symbol] else {
            return (false, "Symbol not monitored")
        }

        // 1. Check TTL Expiration (24h)
        if currentTime.timeIntervalSince(setup.addedAt) >= setup.ttlSeconds {
            setup.state = .expired
            monitoredSetups.removeValue(forKey: symbol)
            return (false, "Setup expired (TTL reached)")
        }

        // 2. Check Golden Pocket Boundaries
        let inGP = currentLivePrice >= setup.gpLow && currentLivePrice <= setup.gpHigh
        guard inGP else {
            setup.state = .active
            monitoredSetups[symbol] = setup
            return (false, "Price outside Golden Pocket")
        }

        // 3. Check Cooldown (15 minutes)
        if let lastAlert = setup.lastAlertAt {
            let elapsed = currentTime.timeIntervalSince(lastAlert)
            if elapsed < Self.alertCooldownSeconds {
                setup.state = .inCooldown
                monitoredSetups[symbol] = setup
                let remaining = Int(Self.alertCooldownSeconds - elapsed)
                return (false, "Cooldown active (\(remaining)s remaining)")
            }
        }

        // 4. Trigger Alert
        setup.lastAlertAt = currentTime
        setup.state = .triggered
        monitoredSetups[symbol] = setup
        alertHistory.append((symbol: symbol, price: currentLivePrice, timestamp: currentTime))

        return (true, "Price entered Golden Pocket ($\(setup.gpLow) - $\(setup.gpHigh))")
    }
}

@main
struct TestP4BackgroundWatcher {
    static func main() async {
        print("==================================================")
        print("   P4: Decoupled Passive Background Market Watcher")
        print("==================================================")

        // --- Test 1: Passive Opt-In (Default State is OFF) ---
        let watcher = MockBackgroundWatcherService(defaultEnabled: false)
        let initialEnabled = await watcher.isEnabled
        assertTest(
            "Background Watcher is OFF by default (Passive Opt-In)",
            initialEnabled == false
        )

        // Enable watcher for subsequent tests
        await watcher.setEnabled(true)
        let activeEnabled = await watcher.isEnabled
        assertTest("Watcher successfully activated via toggle", activeEnabled == true)

        // --- Test 2: Monitored Symbols Cap (Max 3 Simultaneous Symbols) ---
        let baseDate = Date()
        let r1 = await watcher.addSetup(symbol: "BTC-USDT", displaySymbol: "BTC/USDT", gpLow: 84000, gpHigh: 84500, referenceDate: baseDate)
        let r2 = await watcher.addSetup(symbol: "ETH-USDT", displaySymbol: "ETH/USDT", gpLow: 2400, gpHigh: 2450, referenceDate: baseDate)
        let r3 = await watcher.addSetup(symbol: "SOL-USDT", displaySymbol: "SOL/USDT", gpLow: 130, gpHigh: 135, referenceDate: baseDate)
        let r4 = await watcher.addSetup(symbol: "ASTER-USDT", displaySymbol: "ASTER/USDT", gpLow: 0.73, gpHigh: 0.74, referenceDate: baseDate)

        assertTest("Adding symbol #1 (BTC) succeeds", (try? r1.get()) != nil)
        assertTest("Adding symbol #2 (ETH) succeeds", (try? r2.get()) != nil)
        assertTest("Adding symbol #3 (SOL) succeeds", (try? r3.get()) != nil)

        var capErrorReceived = false
        if case .failure(let err) = r4 {
            capErrorReceived = err.message.contains("maksimal 3 simbol simultaneously")
        }
        assertTest("Adding symbol #4 is strictly rejected by cap guard (Max 3)", capErrorReceived)

        // --- Test 3: Trigger Evaluation (Price Outside vs Inside Golden Pocket) ---
        // Price outside GP (85000 > 84500)
        let evalOutside = await watcher.evaluatePrice(symbol: "BTC-USDT", currentLivePrice: 85000.0, currentTime: baseDate)
        assertTest(
            "Price outside Golden Pocket does NOT trigger alert",
            !evalOutside.shouldAlert && evalOutside.reason == "Price outside Golden Pocket"
        )

        // Price inside GP (84200 is within 84000..84500)
        let evalInside = await watcher.evaluatePrice(symbol: "BTC-USDT", currentLivePrice: 84200.0, currentTime: baseDate)
        assertTest(
            "Price inside Golden Pocket triggers alert successfully",
            evalInside.shouldAlert && evalInside.reason.contains("Price entered Golden Pocket")
        )

        // --- Test 4: Cooldown & Spam Suppression (15 Minutes) ---
        // Price touches GP again after 2 minutes (120s < 900s) -> Must be suppressed
        let dateAfter2Min = baseDate.addingTimeInterval(120.0)
        let evalCooldown = await watcher.evaluatePrice(symbol: "BTC-USDT", currentLivePrice: 84250.0, currentTime: dateAfter2Min)
        assertTest(
            "Repetitive price oscillation within 15 minutes is suppressed by cooldown",
            !evalCooldown.shouldAlert && evalCooldown.reason.contains("Cooldown active")
        )

        // Price touches GP again after 16 minutes (960s > 900s) -> Permitted
        let dateAfter16Min = baseDate.addingTimeInterval(960.0)
        let evalAfterCooldown = await watcher.evaluatePrice(symbol: "BTC-USDT", currentLivePrice: 84150.0, currentTime: dateAfter16Min)
        assertTest(
            "Price touch after 15-minute cooldown triggers fresh alert",
            evalAfterCooldown.shouldAlert
        )

        // --- Test 5: TTL / 24-Hour Expiration ---
        // Advance time to 25 hours later (90000s > 86400s)
        let dateAfter25Hours = baseDate.addingTimeInterval(90000.0)
        let evalExpired = await watcher.evaluatePrice(symbol: "ETH-USDT", currentLivePrice: 2420.0, currentTime: dateAfter25Hours)
        assertTest(
            "Setup older than 24 hours transitions to expired and is purged",
            !evalExpired.shouldAlert && evalExpired.reason.contains("Setup expired")
        )

        let monitoredCountAfterTTL = await watcher.monitoredSetups.count
        assertTest("Expired symbol is automatically removed from active monitoring map", monitoredCountAfterTTL == 2)

        // --- Test 6: Kill-Switch Verification ---
        await watcher.setEnabled(false)
        let evalKill = await watcher.evaluatePrice(symbol: "SOL-USDT", currentLivePrice: 132.0, currentTime: dateAfter16Min)
        let countAfterKill = await watcher.monitoredSetups.count
        assertTest(
            "Kill-switch immediately halts watcher and empties active monitoring map",
            !evalKill.shouldAlert && countAfterKill == 0
        )

        print("\n--------------------------------------------------")
        print("P4 Results: \(passedAssertions)/\(totalAssertions) passed")
        print("--------------------------------------------------")

        if failedAssertions == 0 {
            print("🎉 ALL P4 BACKGROUND WATCHER TESTS PASSED (100%)!")
            exit(0)
        } else {
            print("💥 SOME P4 TESTS FAILED (\(failedAssertions) failures)!")
            exit(1)
        }
    }
}
