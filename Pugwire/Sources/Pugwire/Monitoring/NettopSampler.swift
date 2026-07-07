import Foundation

struct NettopRawSample {
    let processLabel: String
    let pid: pid_t
    let cumulativeBytesIn: UInt64
    let cumulativeBytesOut: UInt64
}

/// Polls the system `nettop` tool for per-process network byte counters.
///
/// `nettop` is used instead of a Network Extension / packet-filter kernel
/// driver because it needs no special entitlements, no Apple Developer
/// Program membership, and no kernel/system extension approval flow — it
/// ships with macOS and any local user can read it. The tradeoff is that
/// its per-process byte counters are cumulative (since nettop started),
/// not deltas, and its own text framing isn't something we can rely on
/// being identical across macOS versions, so this sampler treats its own
/// wall-clock timer as the source of truth for "when a tick ends" and
/// just accumulates whatever rows arrived from nettop during that window.
final class NettopSampler {
    typealias TickHandler = (_ samples: [NettopRawSample], _ flushedAt: Date) -> Void

    private let intervalSeconds: Int
    private let debugLoggingEnabled: Bool
    private let onTick: TickHandler

    private let queue = DispatchQueue(label: "pugwire.nettop.sampler")
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var flushTimer: DispatchSourceTimer?

    private var lineBuffer = Data()
    private var currentHeader: [String]?
    private var pendingRows: [NettopRawSample] = []

    init(intervalSeconds: Int, debugLoggingEnabled: Bool, onTick: @escaping TickHandler) {
        self.intervalSeconds = max(1, intervalSeconds)
        self.debugLoggingEnabled = debugLoggingEnabled
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
            "-P", // aggregate connections by owning process
            "-x", // extended: raw byte counts instead of human-readable suffixes (MiB, etc.)
            "-L", "0", // logging mode, comma-separated (CSV) output; run indefinitely
            "-s", "\(intervalSeconds)",
            "-J", "bytes_in,bytes_out"
        ]

        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe() // discard; nettop's stderr chatter isn't useful to us

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
            NSLog("Pugwire: failed to launch nettop (\(error)). Is it installed at /usr/bin/nettop?")
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

        if debugLoggingEnabled, let data = (line + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }

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

    // Takes the header/fields arrays directly rather than zipping into a
    // [String: String]: nettop's CSV framing has an unnamed leading column
    // (the process label) and an unnamed trailing column (from the trailing
    // comma), so both header slots are "" — collapsing them into a
    // dictionary keyed by column name silently drops the process label.
    private func parseRow(header: [String], fields: [String]) -> NettopRawSample? {
        var bytesIn: UInt64?
        var bytesOut: UInt64?
        for (key, value) in zip(header, fields) {
            if key.caseInsensitiveCompare("bytes_in") == .orderedSame {
                bytesIn = UInt64(value)
            } else if key.caseInsensitiveCompare("bytes_out") == .orderedSame {
                bytesOut = UInt64(value)
            }
        }
        guard let bytesIn, let bytesOut else { return nil }

        // nettop -P labels the process column "name.pid" (e.g. "Safari.482").
        // We scan every field for that shape instead of trusting a fixed
        // column name/position, since nettop's header naming for that
        // particular column is inconsistent across macOS versions.
        for value in fields {
            if let (name, pid) = splitProcessLabel(value) {
                return NettopRawSample(
                    processLabel: name,
                    pid: pid,
                    cumulativeBytesIn: bytesIn,
                    cumulativeBytesOut: bytesOut
                )
            }
        }
        return nil
    }

    private func splitProcessLabel(_ value: String) -> (String, pid_t)? {
        guard let dotRange = value.range(of: ".", options: .backwards) else { return nil }
        let namePart = value[value.startIndex..<dotRange.lowerBound]
        let pidPart = value[dotRange.upperBound...]
        guard !namePart.isEmpty, let pid = pid_t(pidPart) else { return nil }
        return (String(namePart), pid)
    }

    private func flush() {
        let rows = pendingRows
        pendingRows = []
        onTick(rows, Date())
    }
}
