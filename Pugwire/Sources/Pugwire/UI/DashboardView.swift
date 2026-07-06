import AppKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var aggregator: BandwidthAggregator
    @EnvironmentObject var historyStore: UsageHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            HistoryChartView(points: historyStore.recentPoints)
                .frame(height: 120)
            Divider()
            processList
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 380)
    }

    private var header: some View {
        HStack(spacing: 24) {
            statColumn(label: "Download", value: ByteFormatter.rate(aggregator.totalDownRate), systemImage: "arrow.down")
            statColumn(label: "Upload", value: ByteFormatter.rate(aggregator.totalUpRate), systemImage: "arrow.up")
        }
    }

    private func statColumn(label: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit())
                .bold()
        }
    }

    private var processList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("By process")
                .font(.caption)
                .foregroundStyle(.secondary)

            if aggregator.processes.isEmpty {
                Text(aggregator.isRunning ? "Waiting for traffic…" : "Not running")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(aggregator.processes.prefix(20)) { process in
                            ProcessRow(process: process)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private var footer: some View {
        HStack {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            Spacer()
            Button("Quit Pugwire") {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.caption)
    }
}
