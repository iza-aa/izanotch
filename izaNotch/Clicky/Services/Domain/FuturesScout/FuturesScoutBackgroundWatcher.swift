//
//  FuturesScoutBackgroundWatcher.swift
//  izaNotch
//
//  P4 Canon: Decoupled Passive Background Market Watcher Service
//  Actor-isolated monitoring service using BingX API quote klines only.
//  Strict invariants:
//  - Opt-in Default OFF (Defaults[.futuresScoutWatcherEnabled])
//  - Strictly capped at max 3 simultaneous monitored symbols
//  - 60s polling interval with exponential backoff on network errors
//  - Zero background screen capture or UI automation
//  - 15-minute alert cooldown per symbol
//  - 24-hour TTL expiration transitions to .expired and prunes setup
//  - Dispatches interactive alert card with 1-click /analisa consent pattern
//

import AppKit
import Defaults
import Foundation

public struct WatcherError: LocalizedError, Equatable {
    public let message: String
    public var errorDescription: String? { message }

    public init(message: String) {
        self.message = message
    }
}

public enum WatcherSetupState: String, Equatable, Codable {
    case active
    case triggered
    case inCooldown
    case expired
}

public struct MonitoredSetup: Equatable, Codable {
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

public actor FuturesScoutBackgroundWatcher {
    public static let shared = FuturesScoutBackgroundWatcher()

    public static let maxSimultaneousSymbols = 3
    public static let alertCooldownSeconds: TimeInterval = 900.0 // 15 minutes
    public static let basePollIntervalSeconds: Double = 60.0

    private var monitoredSetups: [String: MonitoredSetup] = [:]
    private var watcherTask: Task<Void, Never>? = nil
    private var currentBackoffSeconds: Double = 60.0

    private init() {}

    // MARK: - Lifecycle Control

    public func start() {
        guard Defaults[.futuresScoutWatcherEnabled] else {
            ClickyLogger.info("[WATCHER]", "Background watcher start requested, but toggle is OFF (Passive Opt-In)")
            return
        }

        guard watcherTask == nil else {
            ClickyLogger.info("[WATCHER]", "Background watcher task is already running")
            return
        }

        ClickyLogger.info("[WATCHER]", "Starting passive background market watcher loop (interval: \(Int(Self.basePollIntervalSeconds))s)...")
        watcherTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                await self.pollCycle()

                let sleepSec = await self.currentBackoffSeconds
                try? await Task.sleep(for: .seconds(sleepSec))
            }
        }
    }

    public func stop() {
        ClickyLogger.info("[WATCHER]", "Stopping background market watcher loop")
        watcherTask?.cancel()
        watcherTask = nil
        currentBackoffSeconds = Self.basePollIntervalSeconds
    }

    public func setEnabled(_ enabled: Bool) {
        Defaults[.futuresScoutWatcherEnabled] = enabled
        if enabled {
            start()
        } else {
            stop()
            monitoredSetups.removeAll()
            Defaults[.futuresScoutMonitoredSymbols] = []
        }
    }

    // MARK: - Setup Management (Cap: Max 3 Symbols)

    public func addSetup(
        symbol rawSymbol: String,
        gpLow: Double,
        gpHigh: Double,
        ttl: TimeInterval = 86400.0
    ) -> Result<MonitoredSetup, WatcherError> {
        let exchangeSymbol = FuturesScoutMarketDataService.normalizeSymbolForExchange(rawSymbol)
        let displaySymbol = exchangeSymbol.replacingOccurrences(of: "-", with: "/")

        if monitoredSetups[exchangeSymbol] == nil && monitoredSetups.count >= Self.maxSimultaneousSymbols {
            ClickyLogger.warning("[WATCHER]", "Rejected setup for \(displaySymbol): Cap of \(Self.maxSimultaneousSymbols) symbols reached")
            return .failure(WatcherError(message: "Batas pengawasan aktif: maksimal \(Self.maxSimultaneousSymbols) simbol simultaneously"))
        }

        let setup = MonitoredSetup(
            symbol: exchangeSymbol,
            displaySymbol: displaySymbol,
            addedAt: Date(),
            ttlSeconds: ttl,
            gpLow: min(gpLow, gpHigh),
            gpHigh: max(gpLow, gpHigh),
            lastAlertAt: nil,
            state: .active
        )

        monitoredSetups[exchangeSymbol] = setup
        Defaults[.futuresScoutMonitoredSymbols] = Array(monitoredSetups.keys)

        ClickyLogger.success("[WATCHER]", "Added setup to background watcher: \(displaySymbol) [GP: $\(setup.gpLow) - $\(setup.gpHigh)] (Active: \(monitoredSetups.count)/\(Self.maxSimultaneousSymbols))")

        // Auto-start loop if enabled
        if Defaults[.futuresScoutWatcherEnabled] && watcherTask == nil {
            start()
        }

        return .success(setup)
    }

    public func removeSetup(symbol rawSymbol: String) {
        let exchangeSymbol = FuturesScoutMarketDataService.normalizeSymbolForExchange(rawSymbol)
        monitoredSetups.removeValue(forKey: exchangeSymbol)
        Defaults[.futuresScoutMonitoredSymbols] = Array(monitoredSetups.keys)
        ClickyLogger.info("[WATCHER]", "Removed \(exchangeSymbol) from background watcher")
    }

    public func getMonitoredSetups() -> [MonitoredSetup] {
        return Array(monitoredSetups.values)
    }

    // MARK: - Decoupled Polling Cycle (API-Driven, Zero Screen Capture)

    private func pollCycle() async {
        guard !monitoredSetups.isEmpty else {
            return
        }

        let now = Date()
        var hadNetworkFailure = false

        // 1. Prune TTL-Expired Setups (24h)
        for (sym, setup) in monitoredSetups {
            if now.timeIntervalSince(setup.addedAt) >= setup.ttlSeconds {
                ClickyLogger.info("[WATCHER]", "Setup for \(sym) reached 24h TTL. Expiring and pruning...")
                monitoredSetups.removeValue(forKey: sym)
                Defaults[.futuresScoutMonitoredSymbols] = Array(monitoredSetups.keys)
            }
        }

        // 2. Evaluate Active Setups via BingX API
        for (sym, var setup) in monitoredSetups {
            do {
                let klines = try await FuturesScoutMarketDataService.shared.fetchKlines(symbol: sym, interval: "15m", limit: 5)
                guard let latest = klines.last else { continue }
                let currentLivePrice = latest.close

                // Check Golden Pocket Touch
                let inGP = currentLivePrice >= setup.gpLow && currentLivePrice <= setup.gpHigh
                if inGP {
                    // Check Cooldown (15 minutes)
                    let shouldAlert: Bool
                    if let last = setup.lastAlertAt {
                        shouldAlert = now.timeIntervalSince(last) >= Self.alertCooldownSeconds
                    } else {
                        shouldAlert = true
                    }

                    if shouldAlert {
                        setup.lastAlertAt = now
                        setup.state = .triggered
                        monitoredSetups[sym] = setup

                        ClickyLogger.success("[WATCHER]", "🔔 ALERT TRIGGERED: \(setup.displaySymbol) entered Golden Pocket at $\(currentLivePrice)")
                        await dispatchAlert(setup: setup, livePrice: currentLivePrice)
                    } else {
                        setup.state = .inCooldown
                        monitoredSetups[sym] = setup
                    }
                } else {
                    setup.state = .active
                    monitoredSetups[sym] = setup
                }
            } catch {
                hadNetworkFailure = true
                ClickyLogger.warning("[WATCHER]", "Market data fetch error for \(sym): \(error.localizedDescription)")
            }
        }

        // 3. Backoff Management
        if hadNetworkFailure {
            currentBackoffSeconds = min(currentBackoffSeconds * 1.5, 600.0)
            ClickyLogger.info("[WATCHER]", "Network backoff increased to \(Int(currentBackoffSeconds))s")
        } else {
            currentBackoffSeconds = Self.basePollIntervalSeconds
        }
    }

    // MARK: - Interactive Alert Delivery (Consent-Driven)

    private func dispatchAlert(setup: MonitoredSetup, livePrice: Double) async {
        let coin = setup.symbol.components(separatedBy: "-").first ?? setup.symbol
        let minGP = FuturesScoutCoreAnalyst.formatPrice(setup.gpLow)
        let maxGP = FuturesScoutCoreAnalyst.formatPrice(setup.gpHigh)
        let priceStr = FuturesScoutCoreAnalyst.formatPrice(livePrice)

        let alertCard = """
        ### 🔔 Sinyal Terpantau: \(setup.displaySymbol) Masuk Golden Pocket
        Harga terkini telah menyentuh area Golden Pocket di **$\(priceStr)**.
        - **Zona Golden Pocket**: $\(minGP) — $\(maxGP)
        - **Status**: Siap untuk verifikasi kandel trigger M5

        > 💡 Tekan tombol di bawah atau ketik `/analisa \(coin.lowercased())` untuk membuka TradingView dan memetakan level lengkap.
        """

        let speech = "\(setup.displaySymbol) telah memasuki Golden Pocket di harga \(priceStr) dolar."

        await MainActor.run {
            ClickySoundEngine.shared.play(.receive)
            NSSound(named: "Glass")?.play()
            Task {
                await CompanionReportPresenterRegistry.shared?.speakAndReportText(alertCard, speechNarrative: speech)
            }
        }
    }
}
