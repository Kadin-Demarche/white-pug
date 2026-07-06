import AppKit
import Combine
import Darwin
import Foundation

/// Turns raw nettop samples (cumulative byte counters) into per-second
/// rates, resolves each pid to a display name/icon, and forwards rolled-up
/// totals to the history store.
final class BandwidthAggregator: ObservableObject {
    @Published private(set) var processes: [ProcessBandwidth] = []
    @Published private(set) var totalDownRate: Double = 0
    @Published private(set) var totalUpRate: Double = 0
    @Published private(set) var isRunning = false

    private let historyStore: UsageHistoryStore
    private var sampler: NettopSampler?

    private struct PreviousReading {
        var bytesIn: UInt64
        var bytesOut: UInt64
        var lastSeen: Date
    }

    private var previousReadings: [pid_t: PreviousReading] = [:]
    private var displayInfoCache: [pid_t: (name: String, icon: NSImage?)] = [:]
    private var lastFlushDate: Date?

    /// How long to keep a pid's previous-reading baseline around after we
    /// stop seeing it in nettop's output, before treating it as gone.
    private let staleProcessTimeout: TimeInterval = 8

    init(historyStore: UsageHistoryStore) {
        self.historyStore = historyStore
    }

    func start(intervalSeconds: Int = 1, debugLoggingEnabled: Bool = false) {
        stop()
        let sampler = NettopSampler(intervalSeconds: intervalSeconds, debugLoggingEnabled: debugLoggingEnabled) { [weak self] samples, flushedAt in
            self?.handleTick(samples: samples, flushedAt: flushedAt)
        }
        sampler.start()
        self.sampler = sampler
        isRunning = true
    }

    func stop() {
        sampler?.stop()
        sampler = nil
        isRunning = false
    }

    private func handleTick(samples: [NettopRawSample], flushedAt: Date) {
        let elapsed: TimeInterval
        if let last = lastFlushDate {
            elapsed = max(flushedAt.timeIntervalSince(last), 0.001)
        } else {
            elapsed = 1
        }
        lastFlushDate = flushedAt

        var updated: [pid_t: ProcessBandwidth] = [:]

        for sample in samples {
            let previous = previousReadings[sample.pid]
            let deltaIn = delta(from: previous?.bytesIn, to: sample.cumulativeBytesIn)
            let deltaOut = delta(from: previous?.bytesOut, to: sample.cumulativeBytesOut)

            previousReadings[sample.pid] = PreviousReading(
                bytesIn: sample.cumulativeBytesIn,
                bytesOut: sample.cumulativeBytesOut,
                lastSeen: flushedAt
            )

            let info = displayInfo(for: sample.pid, fallbackName: sample.processLabel)

            if var existing = updated[sample.pid] {
                existing.downRate += Double(deltaIn) / elapsed
                existing.upRate += Double(deltaOut) / elapsed
                existing.totalDown += deltaIn
                existing.totalUp += deltaOut
                updated[sample.pid] = existing
            } else {
                updated[sample.pid] = ProcessBandwidth(
                    id: sample.pid,
                    name: info.name,
                    icon: info.icon,
                    downRate: Double(deltaIn) / elapsed,
                    upRate: Double(deltaOut) / elapsed,
                    totalDown: deltaIn,
                    totalUp: deltaOut
                )
            }
        }

        // Drop bookkeeping for pids we haven't seen in a while so this
        // dictionary doesn't grow unbounded over a long uptime.
        previousReadings = previousReadings.filter { flushedAt.timeIntervalSince($0.value.lastSeen) < staleProcessTimeout }

        let sorted = updated.values.sorted { ($0.downRate + $0.upRate) > ($1.downRate + $1.upRate) }
        let totalDown = sorted.reduce(0.0) { $0 + $1.downRate }
        let totalUp = sorted.reduce(0.0) { $0 + $1.upRate }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.processes = sorted
            self.totalDownRate = totalDown
            self.totalUpRate = totalUp
        }

        historyStore.record(at: flushedAt, downBytesPerSec: totalDown, upBytesPerSec: totalUp)
    }

    private func delta(from previous: UInt64?, to current: UInt64) -> UInt64 {
        guard let previous else { return 0 }
        // A negative delta means the counter reset (e.g. the pid was
        // recycled by a brand-new process); treat it as "no data yet"
        // rather than underflowing into a huge UInt64.
        guard current >= previous else { return 0 }
        return current - previous
    }

    private func displayInfo(for pid: pid_t, fallbackName: String) -> (name: String, icon: NSImage?) {
        if let cached = displayInfoCache[pid] {
            return cached
        }

        var name = fallbackName
        var icon: NSImage?

        if let app = NSRunningApplication(processIdentifier: pid) {
            name = app.localizedName ?? name
            icon = app.icon
        } else {
            var buffer = [Int8](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
            let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
            if length > 0 {
                let path = String(cString: buffer)
                icon = NSWorkspace.shared.icon(forFile: path)
                name = (path as NSString).lastPathComponent
            }
        }

        let info = (name: name, icon: icon)
        displayInfoCache[pid] = info
        return info
    }
}
