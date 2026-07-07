import Darwin
import Foundation

/// A 128-bit unsigned value for comparing IPv6 addresses/ranges. Swift's
/// native `UInt128` needs macOS 15+ at runtime; Pugwire still supports
/// macOS 14, so this is a minimal (high, low) stand-in — only comparison
/// and decimal parsing, nothing else, since that's all a range lookup needs.
private struct UInt128Compat: Comparable {
    var high: UInt64
    var low: UInt64

    static func < (lhs: UInt128Compat, rhs: UInt128Compat) -> Bool {
        if lhs.high != rhs.high { return lhs.high < rhs.high }
        return lhs.low < rhs.low
    }

    static func parseDigits(_ field: UnsafeBufferPointer<UInt8>) -> UInt128Compat? {
        var high: UInt64 = 0
        var low: UInt64 = 0
        for byte in field {
            guard byte >= 48, byte <= 57 else { return nil }
            let digit = UInt64(byte - 48)
            let (mulHigh, mulLow) = low.multipliedFullWidth(by: 10)
            let (newLow, carry) = mulLow.addingReportingOverflow(digit)
            high = high &* 10 &+ mulHigh &+ (carry ? 1 : 0)
            low = newLow
        }
        return UInt128Compat(high: high, low: low)
    }
}

/// Resolves an IP address to a two-letter country code using a bundled,
/// offline database (see Sources/Pugwire/GeoData/) — never a network call.
/// Loading ~700k ranges takes real time, so it happens once on a background
/// queue; lookups before loading finishes just return nil.
final class GeoIPResolver {
    static let shared = GeoIPResolver()

    private struct Range<T: Comparable> {
        let start: T
        let end: T
        let country: String
    }

    private var ipv4Ranges: [Range<UInt32>] = []
    private var ipv6Ranges: [Range<UInt128Compat>] = []
    private let loadQueue = DispatchQueue(label: "pugwire.geoip.load")
    private var hasLoaded = false

    private init() {}

    func loadIfNeeded() {
        loadQueue.async { [weak self] in
            guard let self, !self.hasLoaded else { return }
            self.hasLoaded = true
            self.loadFromBundle()
        }
    }

    private func loadFromBundle() {
        guard let url = Bundle.module.url(forResource: "dbip-country-num", withExtension: "csv"),
              let data = FileManager.default.contents(atPath: url.path)
        else {
            NSLog("Pugwire: GeoIP database not found in bundle; map will show no locations.")
            return
        }

        var v4: [Range<UInt32>] = []
        var v6: [Range<UInt128Compat>] = []
        v4.reserveCapacity(450_000)
        v6.reserveCapacity(250_000)

        // ~700k lines of "start,end,XX" — parsing raw UTF8 bytes instead of
        // going through String/Character (enumerateLines + Character-based
        // digit parsing) cuts load time roughly in half; this runs once on a
        // background queue at launch, but a multi-second load is still worth
        // avoiding when it's this cheap to avoid.
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            let comma = UInt8(ascii: ",")
            let newline = UInt8(ascii: "\n")
            var lineStart = 0
            for i in 0..<bytes.count where bytes[i] == newline {
                Self.parseLine(bytes, lineStart, i, comma: comma, v4: &v4, v6: &v6)
                lineStart = i + 1
            }
            if lineStart < bytes.count {
                Self.parseLine(bytes, lineStart, bytes.count, comma: comma, v4: &v4, v6: &v6)
            }
        }

        // Source file is already sorted ascending by range start.
        self.ipv4Ranges = v4
        self.ipv6Ranges = v6
    }

    private static func parseLine(
        _ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int, comma: UInt8,
        v4: inout [Range<UInt32>], v6: inout [Range<UInt128Compat>]
    ) {
        guard end > start else { return }
        var comma1 = -1
        var comma2 = -1
        for i in start..<end {
            if bytes[i] == comma {
                if comma1 == -1 { comma1 = i } else { comma2 = i; break }
            }
        }
        guard comma1 != -1, comma2 != -1, end - (comma2 + 1) == 2 else { return }

        let country = String(decoding: UnsafeBufferPointer(rebasing: bytes[(comma2 + 1)..<end]), as: UTF8.self)

        let startField = UnsafeBufferPointer(rebasing: bytes[start..<comma1])
        let endField = UnsafeBufferPointer(rebasing: bytes[(comma1 + 1)..<comma2])

        if let s32 = parseUInt32Digits(startField), let e32 = parseUInt32Digits(endField) {
            v4.append(Range(start: s32, end: e32, country: country))
        } else if let s128 = UInt128Compat.parseDigits(startField), let e128 = UInt128Compat.parseDigits(endField) {
            v6.append(Range(start: s128, end: e128, country: country))
        }
    }

    private static func parseUInt32Digits(_ field: UnsafeBufferPointer<UInt8>) -> UInt32? {
        var value: UInt64 = 0
        for byte in field {
            guard byte >= 48, byte <= 57 else { return nil }
            value = value * 10 + UInt64(byte - 48)
            if value > UInt64(UInt32.max) { return nil }
        }
        return UInt32(value)
    }

    /// `host` may be an IPv4 or IPv6 literal (with an optional "%scope" zone
    /// suffix on IPv6 link-local addresses); anything else returns nil.
    func countryCode(forHost host: String) -> String? {
        if let value = parseIPv4(host) {
            return binarySearch(ipv4Ranges, value: value)
        }
        if let value = parseIPv6(host) {
            return binarySearch(ipv6Ranges, value: value)
        }
        return nil
    }

    private func binarySearch<T: Comparable>(_ ranges: [Range<T>], value: T) -> String? {
        var lo = 0
        var hi = ranges.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let range = ranges[mid]
            if value < range.start {
                hi = mid - 1
            } else if value > range.end {
                lo = mid + 1
            } else {
                return range.country
            }
        }
        return nil
    }

    private func parseIPv4(_ s: String) -> UInt32? {
        var addr = in_addr()
        guard inet_pton(AF_INET, s, &addr) == 1 else { return nil }
        return UInt32(bigEndian: addr.s_addr)
    }

    private func parseIPv6(_ s: String) -> UInt128Compat? {
        let withoutScope = s.split(separator: "%", maxSplits: 1).first.map(String.init) ?? s
        var addr = in6_addr()
        guard inet_pton(AF_INET6, withoutScope, &addr) == 1 else { return nil }
        var high: UInt64 = 0
        var low: UInt64 = 0
        withUnsafeBytes(of: addr) { buffer in
            for (index, byte) in buffer.enumerated() {
                if index < 8 {
                    high = (high << 8) | UInt64(byte)
                } else {
                    low = (low << 8) | UInt64(byte)
                }
            }
        }
        return UInt128Compat(high: high, low: low)
    }
}
