import AppKit
import SwiftUI

private enum ActivityViewMode: String, CaseIterable {
    case byProcess = "By process"
    case connections = "Connections"
    case map = "Map"
}

struct DashboardView: View {
    @EnvironmentObject var aggregator: BandwidthAggregator
    @EnvironmentObject var connectionMonitor: ConnectionActivityMonitor
    @Environment(\.openSettings) private var openSettings

    // @State's macro-based implementation needs a compiler plugin that
    // isn't resolving under plain `swift build` on this SDK; @AppStorage
    // sidesteps it (and remembers the last-selected tab as a bonus).
    @AppStorage("dashboardViewMode") private var viewMode: ActivityViewMode = .map

    // Height the map occupies (2:1 at this width) — lists match it so the
    // window doesn't resize when switching tabs.
    private static let windowWidth: CGFloat = 440
    private static let contentHeight: CGFloat = windowWidth / 2
    // Vertical inset the lists need so their first row clears the floating bar.
    private static let barInset: CGFloat = 36

    var body: some View {
        ZStack(alignment: .top) {
            contentView
            controlBar
        }
        .frame(width: Self.windowWidth)
    }

    @ViewBuilder private var contentView: some View {
        switch viewMode {
        case .map:
            WarMapView()
        case .byProcess:
            processList
        case .connections:
            connectionList
        }
    }

    // A single thin, frosted strip floating over the top of the map: live
    // totals on the left, the view switcher in the middle, app controls on
    // the right. Keeps the map itself edge-to-edge as the whole view.
    private var controlBar: some View {
        HStack(spacing: 8) {
            totals
            Spacer(minLength: 4)
            modePicker
            Spacer(minLength: 4)
            controlButtons
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
    }

    private var totals: some View {
        HStack(spacing: 8) {
            Label(ByteFormatter.rate(aggregator.totalDownRate), systemImage: "arrow.down")
            Label(ByteFormatter.rate(aggregator.totalUpRate), systemImage: "arrow.up")
        }
        .font(.caption.monospacedDigit())
        .lineLimit(1)
    }

    private var modePicker: some View {
        Picker("", selection: $viewMode) {
            Image(systemName: "list.bullet").tag(ActivityViewMode.byProcess)
            Image(systemName: "network").tag(ActivityViewMode.connections)
            Image(systemName: "globe.americas.fill").tag(ActivityViewMode.map)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private var controlButtons: some View {
        HStack(spacing: 6) {
            Button {
                // SettingsLink alone doesn't reliably open the Settings window
                // for an LSUIElement (accessory) app with no other window ever
                // active — there's nothing for the new window to key/front
                // itself against. Activating the app first fixes it.
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit Pugwire")
        }
        .buttonStyle(.borderless)
    }

    private var processList: some View {
        Group {
            if aggregator.processes.isEmpty {
                emptyState(aggregator.isRunning ? "Waiting for traffic…" : "Not running")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(aggregator.processes.prefix(20)) { process in
                            ProcessRow(process: process)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, Self.barInset)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: Self.windowWidth, height: Self.contentHeight)
    }

    private var connectionList: some View {
        Group {
            if connectionMonitor.connections.isEmpty {
                emptyState("Waiting for active connections…")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(connectionMonitor.connections.prefix(20)) { connection in
                            ConnectionRow(connection: connection)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, Self.barInset)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: Self.windowWidth, height: Self.contentHeight)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
