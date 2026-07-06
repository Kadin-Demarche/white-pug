import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject var aggregator: BandwidthAggregator

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "network")
            Text("↓\(ByteFormatter.rate(aggregator.totalDownRate)) ↑\(ByteFormatter.rate(aggregator.totalUpRate))")
                .font(.system(size: 11, design: .monospaced))
        }
    }
}
