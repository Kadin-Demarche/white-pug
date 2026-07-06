import SwiftUI

@main
struct PugwireApp: App {
    @StateObject private var aggregator: BandwidthAggregator
    @StateObject private var historyStore: UsageHistoryStore

    init() {
        let history = UsageHistoryStore()
        let savedInterval = UserDefaults.standard.object(forKey: "pollingIntervalSeconds") as? Int ?? 1
        let savedDebug = UserDefaults.standard.bool(forKey: "debugNettopLogging")

        let bandwidthAggregator = BandwidthAggregator(historyStore: history)
        bandwidthAggregator.start(intervalSeconds: savedInterval, debugLoggingEnabled: savedDebug)

        _historyStore = StateObject(wrappedValue: history)
        _aggregator = StateObject(wrappedValue: bandwidthAggregator)
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environmentObject(aggregator)
                .environmentObject(historyStore)
        } label: {
            MenuBarLabelView()
                .environmentObject(aggregator)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(aggregator)
                .environmentObject(historyStore)
        }
    }
}
