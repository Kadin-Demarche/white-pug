import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var aggregator: BandwidthAggregator
    @EnvironmentObject var historyStore: UsageHistoryStore

    @AppStorage("pollingIntervalSeconds") private var pollingIntervalSeconds: Int = 1
    @AppStorage("launchAtLogin") private var launchAtLoginEnabled: Bool = false
    @AppStorage("debugNettopLogging") private var debugNettopLogging: Bool = false

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

            Section("Data") {
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
