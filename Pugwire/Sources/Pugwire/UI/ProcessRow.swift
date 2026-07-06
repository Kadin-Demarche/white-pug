import SwiftUI

struct ProcessRow: View {
    let process: ProcessBandwidth

    var body: some View {
        HStack {
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app.dashed")
                    .frame(width: 16, height: 16)
            }

            Text(process.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("↓\(ByteFormatter.rate(process.downRate))")
                Text("↑\(ByteFormatter.rate(process.upRate))")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
