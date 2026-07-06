import Charts
import SwiftUI

struct HistoryChartView: View {
    let points: [HistoryPoint]

    var body: some View {
        Chart {
            ForEach(points, id: \.timestamp) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Bytes/sec", point.downBytesPerSec)
                )
                .foregroundStyle(by: .value("Series", "Download"))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Bytes/sec", point.upBytesPerSec)
                )
                .foregroundStyle(by: .value("Series", "Upload"))
                .interpolationMethod(.monotone)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3))
        }
        .chartLegend(position: .bottom, spacing: 4)
    }
}
