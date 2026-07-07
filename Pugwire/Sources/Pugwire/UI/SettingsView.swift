import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var aggregator: BandwidthAggregator
    @EnvironmentObject var historyStore: UsageHistoryStore
    @EnvironmentObject var connectionMonitor: ConnectionActivityMonitor

    @AppStorage("pollingIntervalSeconds") private var pollingIntervalSeconds: Int = 1
    @AppStorage("launchAtLogin") private var launchAtLoginEnabled: Bool = false
    @AppStorage("debugNettopLogging") private var debugNettopLogging: Bool = false
    @AppStorage("menuBarShowsRates") private var menuBarShowsRates: Bool = true
    @AppStorage("historyRetentionDays") private var historyRetentionDays: Int = 30

    var body: some View {
        Form {
            Section("Monitoring") {
                Picker("Update every", selection: $pollingIntervalSeconds) {
                    Text("1 second").tag(1)
                    Text("2 seconds").tag(2)
                    Text("5 seconds").tag(5)
                }
                .onChange(of: pollingIntervalSeconds) { _, newValue in
                    aggregator.start(intervalSeconds: newValue, debugLoggingEnabled: debugNettopLogging)
                    connectionMonitor.start(intervalSeconds: newValue)
                }

                Toggle("Launch at login", isOn: $launchAtLoginEnabled)
                    .onChange(of: launchAtLoginEnabled) { _, newValue in
                        LaunchAtLogin.isEnabled = newValue
                    }

                Toggle("Log raw nettop output to Console", isOn: $debugNettopLogging)
                    .onChange(of: debugNettopLogging) { _, newValue in
                        aggregator.start(intervalSeconds: pollingIntervalSeconds, debugLoggingEnabled: newValue)
                    }
            }

            Section("Menu Bar") {
                Toggle("Show download/upload speeds", isOn: $menuBarShowsRates)
            }

            Section("Data") {
                Picker("Keep history for", selection: $historyRetentionDays) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .onChange(of: historyRetentionDays) { _, newValue in
                    historyStore.updateRetention(days: newValue)
                }

                Button("Clear saved history") {
                    historyStore.clearHistory()
                }
            }

            Section("About") {
                Text("Pugwire is free, open-source software. It makes no network requests of its own and stores everything locally in ~/Library/Application Support/Pugwire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
        }
    }
}
