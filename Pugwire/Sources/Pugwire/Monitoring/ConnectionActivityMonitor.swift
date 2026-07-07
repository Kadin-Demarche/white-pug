import Foundation

/// Turns raw per-connection nettop samples into live per-second rates.
/// Mirrors BandwidthAggregator's delta math, but keyed by connection
/// descriptor instead of pid, and with no history persistence — this is a
/// live-only view of what's happening right now, not something to save.
final class ConnectionActivityMonitor: ObservableObject {
    @Published private(set) var connections: [LiveConnection] = []

    private var sampler: NettopConnectionSampler?

    private struct PreviousReading {
        var bytesIn: UInt64
        var bytesOut: UInt64
        var lastSeen: Date
    }

    private var previousReadings: [String: PreviousReading] = [:]
    private var lastFlushDate: Date?

    /// How long to keep a connection's previous-reading baseline around
    /// after we stop seeing it, before dropping it from bookkeeping.
    private let staleTimeout: TimeInterval = 5

    func start(intervalSeconds: Int = 1) {
        stop()
        let sampler = NettopConnectionSampler(intervalSeconds: intervalSeconds) { [weak self] samples, flushedAt in
            self?.handleTick(samples: samples, flushedAt: flushedAt)
        }
        sampler.start()
        self.sampler = sampler
    }

    func stop() {
        sampler?.stop()
        sampler = nil
        previousReadings.removeAll()
        lastFlushDate = nil
        DispatchQueue.main.async { [weak self] in
            self?.connections = []
        }
    }

    private func handleTick(samples: [ConnectionRawSample], flushedAt: Date) {
        let elapsed: TimeInterval
        if let last = lastFlushDate {
            elapsed = max(flushedAt.timeIntervalSince(last), 0.001)
        } else {
            elapsed = 1
        }
        lastFlushDate = flushedAt

        var updated: [LiveConnection] = []
        for sample in samples {
            let previous = previousReadings[sample.id]
            let deltaIn = delta(from: previous?.bytesIn, to: sample.cumulativeBytesIn)
            let deltaOut = delta(from: previous?.bytesOut, to: sample.cumulativeBytesOut)

            previousReadings[sample.id] = PreviousReading(
                bytesIn: sample.cumulativeBytesIn,
                bytesOut: sample.cumulativeBytesOut,
                lastSeen: flushedAt
            )

            updated.append(LiveConnection(
                id: sample.id,
                proto: sample.proto,
                remoteEndpoint: sample.remoteEndpoint,
                remoteHost: sample.remoteHost,
                interfaceName: sample.interfaceName,
                state: sample.state,
                downRate: Double(deltaIn) / elapsed,
                upRate: Double(deltaOut) / elapsed
            ))
        }

        previousReadings = previousReadings.filter { flushedAt.timeIntervalSince($0.value.lastSeen) < staleTimeout }

        let sorted = updated.sorted { ($0.downRate + $0.upRate) > ($1.downRate + $1.upRate) }

        DispatchQueue.main.async { [weak self] in
            self?.connections = sorted
        }
    }

    private func delta(from previous: UInt64?, to current: UInt64) -> UInt64 {
        guard let previous else { return 0 }
        guard current >= previous else { return 0 }
        return current - previous
    }
}
