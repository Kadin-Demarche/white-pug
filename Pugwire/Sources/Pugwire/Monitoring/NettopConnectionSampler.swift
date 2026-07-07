import Foundation

struct ConnectionRawSample {
    let id: String // the raw "proto local<->remote" descriptor; used as identity across ticks
    let proto: String
    let localEndpoint: String
    let remoteEndpoint: String
    let remoteHost: String // remoteEndpoint with the ":port"/".port" suffix stripped, for GeoIP lookup
    let interfaceName: String
    let state: String
    let cumulativeBytesIn: UInt64
    let cumulativeBytesOut: UInt64
}

/// Polls `nettop` for individual socket connections (as opposed to
/// `NettopSampler`'s per-process totals via `-P`). Dropping `-P` makes nettop
/// emit both a process summary row and one row per connection it owns; we
/// only care about the latter here; the process totals are already covered
/// by `NettopSampler`.
final class NettopConnectionSampler {
    typealias TickHandler = (_ samples: [ConnectionRawSample], _ flushedAt: Date) -> Void

    private let intervalSeconds: Int
    private let onTick: TickHandler

    private let queue = DispatchQueue(label: "pugwire.nettop.connection-sampler")
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var flushTimer: DispatchSourceTimer?

    private var lineBuffer = Data()
    private var currentHeader: [String]?
    private var pendingRows: [ConnectionRawSample] = []

    init(intervalSeconds: Int, onTick: @escaping TickHandler) {
        self.intervalSeconds = max(1, intervalSeconds)
        self.onTick = onTick
    }

    func start() {
        queue.async { [weak self] in
            self?.startOnQueue()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopOnQueue()
        }
    }

    private func startOnQueue() {
        stopOnQueue()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [
            "nettop",
            "-x", // raw byte counts instead of human-readable suffixes
            "-n", // disable address-to-name resolution — GeoIP lookup needs
                  // the literal IP, not a resolved hostname, and this also
                  // avoids nettop making its own DNS lookups on our behalf
            "-L", "0", // logging mode, CSV output, run indefinitely
            "-s", "\(intervalSeconds)",
            "-J", "bytes_in,bytes_out,interface,state"
        ]

        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async {
                self?.consume(data)
            }
        }

        do {
            try task.run()
        } catch {
            NSLog("Pugwire: failed to launch nettop for connection sampling (\(error)).")
            return
        }

        process = task
        stdoutPipe = outPipe

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(intervalSeconds), repeating: .seconds(intervalSeconds))
        timer.setEventHandler { [weak self] in
            self?.flush()
        }
        timer.resume()
        flushTimer = timer
    }

    private func stopOnQueue() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        stdoutPipe = nil
        flushTimer?.cancel()
        flushTimer = nil
        lineBuffer.removeAll()
        currentHeader = nil
        pendingRows.removeAll()
    }

    private func consume(_ data: Data) {
        lineBuffer.append(data)
        while let newlineIndex = lineBuffer.firstIndex(of: 0x0A) {
            let lineData = lineBuffer[..<newlineIndex]
            lineBuffer.removeSubrange(...newlineIndex)
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            parse(line: line.trimmingCharacters(in: .whitespaces))
        }
    }

    private func parse(line: String) {
        guard !line.isEmpty else { return }

        let fields = line.components(separatedBy: ",")

        if fields.contains(where: { $0.caseInsensitiveCompare("bytes_in") == .orderedSame }) {
            currentHeader = fields
            return
        }

        guard let header = currentHeader, header.count == fields.count else { return }

        if let sample = parseRow(header: header, fields: fields) {
            pendingRows.append(sample)
        }
    }

    private func parseRow(header: [String], fields: [String]) -> ConnectionRawSample? {
        var bytesIn: UInt64?
        var bytesOut: UInt64?
        var interfaceName = ""
        var state = ""
        for (key, value) in zip(header, fields) {
            if key.caseInsensitiveCompare("bytes_in") == .orderedSame {
                bytesIn = UInt64(value)
            } else if key.caseInsensitiveCompare("bytes_out") == .orderedSame {
                bytesOut = UInt64(value)
            } else if key.caseInsensitiveCompare("interface") == .orderedSame {
                interfaceName = value
            } else if key.caseInsensitiveCompare("state") == .orderedSame {
                state = value
            }
        }
        // Idle/listening sockets report blank counters; skip them the same
        // way a missing bytes_in/out naturally filters them out below.
        guard let bytesIn, let bytesOut else { return nil }

        // Process summary rows look like "name.pid" (no "<->"); connection
        // rows look like "tcp6 2605:...:55568<->2620:...:5223". We scan every
        // field for the connection shape rather than trusting a fixed
        // position, matching NettopSampler's approach to nettop's unstable
        // column framing.
        //
        // Rows with a wildcard remote ("*:*"/"*.*") are nettop's catch-all
        // bucket for not-yet-resolved/multiplexed flows — multiple distinct
        // flows can share that exact descriptor within a single tick, which
        // breaks using it as a stable per-connection identity (delta math
        // against the wrong baseline produces huge bogus rates). They're
        // also not useful to show since there's no real remote host to see.
        for value in fields {
            if let descriptor = parseConnectionDescriptor(value), !descriptor.remote.hasPrefix("*") {
                return ConnectionRawSample(
                    id: value,
                    proto: descriptor.proto,
                    localEndpoint: descriptor.local,
                    remoteEndpoint: descriptor.remote,
                    remoteHost: hostOnly(descriptor.remote, proto: descriptor.proto),
                    interfaceName: interfaceName,
                    state: state,
                    cumulativeBytesIn: bytesIn,
                    cumulativeBytesOut: bytesOut
                )
            }
        }
        return nil
    }

    // IPv6 endpoints use "." to separate the port (its address already has
    // colons); IPv4 endpoints use ":". `-n` guarantees this is a literal IP,
    // never a hostname, so this split is unambiguous.
    private func hostOnly(_ endpoint: String, proto: String) -> String {
        let separator: Character = proto.hasSuffix("6") ? "." : ":"
        guard let lastSeparator = endpoint.lastIndex(of: separator) else { return endpoint }
        return String(endpoint[endpoint.startIndex..<lastSeparator])
    }

    private func parseConnectionDescriptor(_ value: String) -> (proto: String, local: String, remote: String)? {
        guard let arrowRange = value.range(of: "<->") else { return nil }
        let beforeArrow = value[value.startIndex..<arrowRange.lowerBound]
        let remote = String(value[arrowRange.upperBound...])
        guard let spaceRange = beforeArrow.range(of: " ") else { return nil }
        let proto = String(beforeArrow[beforeArrow.startIndex..<spaceRange.lowerBound])
        let local = String(beforeArrow[spaceRange.upperBound...])
        guard !proto.isEmpty, !local.isEmpty, !remote.isEmpty else { return nil }
        return (proto, local, remote)
    }

    private func flush() {
        let rows = pendingRows
        pendingRows = []
        onTick(rows, Date())
    }
}
