import Combine
import Foundation

/// Persists coarse (1-minute resolution) bandwidth totals to a
/// human-readable JSON Lines file so history survives app restarts and
/// anyone can open the file in a text editor to see exactly what Pugwire
/// has recorded. Nothing here ever leaves this file — there is no network
/// call anywhere in this codebase.
final class UsageHistoryStore: ObservableObject {
    @Published private(set) var recentPoints: [HistoryPoint] = []

    private let queue = DispatchQueue(label: "pugwire.history.store")
    private let fileURL: URL
    private let retention: TimeInterval

    private var minuteBucketStart: Date?
    private var minuteDownSum: Double = 0
    private var minuteUpSum: Double = 0
    private var minuteSampleCount: Int = 0

    init(retentionDays: Int = 30) {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Pugwire", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.fileURL = supportDir.appendingPathComponent("history.jsonl")
        self.retention = TimeInterval(retentionDays * 24 * 60 * 60)
        loadRecentHistory()
    }

    func record(at date: Date, downBytesPerSec: Double, upBytesPerSec: Double) {
        queue.async { [weak self] in
            self?.recordOnQueue(at: date, down: downBytesPerSec, up: upBytesPerSec)
        }
    }

    func clearHistory() {
        queue.async { [weak self] in
            guard let self else { return }
            try? FileManager.default.removeItem(at: self.fileURL)
            self.minuteBucketStart = nil
            self.minuteDownSum = 0
            self.minuteUpSum = 0
            self.minuteSampleCount = 0
            DispatchQueue.main.async {
                self.recentPoints.removeAll()
            }
        }
    }

    private func recordOnQueue(at date: Date, down: Double, up: Double) {
        let bucket = Calendar.current.dateInterval(of: .minute, for: date)?.start ?? date

        if minuteBucketStart == nil {
            minuteBucketStart = bucket
        } else if bucket != minuteBucketStart {
            flushBucket()
            minuteBucketStart = bucket
        }

        minuteDownSum += down
        minuteUpSum += up
        minuteSampleCount += 1
    }

    private func flushBucket() {
        guard let bucketStart = minuteBucketStart, minuteSampleCount > 0 else { return }
        let point = HistoryPoint(
            timestamp: bucketStart,
            downBytesPerSec: minuteDownSum / Double(minuteSampleCount),
            upBytesPerSec: minuteUpSum / Double(minuteSampleCount)
        )
        appendToFile(point)

        let cutoff = Date().addingTimeInterval(-retention)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.recentPoints.append(point)
            self.recentPoints.removeAll { $0.timestamp < cutoff }
        }

        minuteDownSum = 0
        minuteUpSum = 0
        minuteSampleCount = 0
    }

    private func appendToFile(_ point: HistoryPoint) {
        guard let data = try? JSONEncoder().encode(point) else { return }
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: fileURL.path) else { return }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(data)
        handle.write("\n".data(using: .utf8)!)
    }

    private func loadRecentHistory() {
        queue.async { [weak self] in
            guard let self else { return }
            guard let data = try? Data(contentsOf: self.fileURL) else { return }
            let cutoff = Date().addingTimeInterval(-self.retention)
            let decoder = JSONDecoder()
            var loaded: [HistoryPoint] = []
            for line in data.split(separator: UInt8(ascii: "\n")) {
                guard let point = try? decoder.decode(HistoryPoint.self, from: Data(line)) else { continue }
                if point.timestamp >= cutoff {
                    loaded.append(point)
                }
            }
            DispatchQueue.main.async {
                self.recentPoints = loaded
            }
        }
    }
}
