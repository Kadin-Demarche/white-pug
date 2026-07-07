import SwiftUI

struct ConnectionRow: View {
    let connection: LiveConnection

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(connection.remoteEndpoint)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detailLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("↓\(ByteFormatter.rate(connection.downRate))")
                Text("↑\(ByteFormatter.rate(connection.upRate))")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var detailLine: String {
        var parts = [connection.proto.uppercased()]
        if !connection.interfaceName.isEmpty { parts.append(connection.interfaceName) }
        if !connection.state.isEmpty { parts.append(connection.state) }
        return parts.joined(separator: " · ")
    }
}
