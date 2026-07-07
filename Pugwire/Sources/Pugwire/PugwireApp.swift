import SwiftUI

@main
struct PugwireApp: App {
    @StateObject private var aggregator: BandwidthAggregator
    @StateObject private var historyStore: UsageHistoryStore
    @StateObject private var connectionMonitor: ConnectionActivityMonitor

    init() {
        let savedRetentionDays = UserDefaults.standard.object(forKey: "historyRetentionDays") as? Int ?? 30
        let history = UsageHistoryStore(retentionDays: savedRetentionDays)
        let savedInterval = UserDefaults.standard.object(forKey: "pollingIntervalSeconds") as? Int ?? 1
        let savedDebug = UserDefaults.standard.bool(forKey: "debugNettopLogging")

        let bandwidthAggregator = BandwidthAggregator(historyStore: history)
        bandwidthAggregator.start(intervalSeconds: savedInterval, debugLoggingEnabled: savedDebug)

        // Runs continuously alongside the per-process aggregator (rather than
        // only while the dropdown is open) so it already has a delta
        // baseline — and therefore real numbers, not a first-tick zero — by
        // the time someone actually looks at the Connections tab.
        let liveConnections = ConnectionActivityMonitor()
        liveConnections.start(intervalSeconds: savedInterval)

        _historyStore = StateObject(wrappedValue: history)
        _aggregator = StateObject(wrappedValue: bandwidthAggregator)
        _connectionMonitor = StateObject(wrappedValue: liveConnections)

        // Kicked off at launch (not lazily when the map tab first appears)
        // so the ~700k-range database is already loaded — in practice well
        // under a second — by the time anyone looks at the map.
        GeoIPResolver.shared.loadIfNeeded()

        // Parse the bundled coastline GeoJSON off the main thread so the map
        // renders instantly on first open instead of hitching while it loads.
        DispatchQueue.global().async { _ = WorldMap.shared }
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environmentObject(aggregator)
                .environmentObject(historyStore)
                .environmentObject(connectionMonitor)
        } label: {
            MenuBarLabelView()
                .environmentObject(aggregator)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(aggregator)
                .environmentObject(historyStore)
                .environmentObject(connectionMonitor)
        }
    }
}
