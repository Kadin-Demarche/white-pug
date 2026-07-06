import Foundation

enum ByteFormatter {
    /// e.g. 1_234_000 -> "1.2 MB"
    static func total(_ bytes: UInt64) -> String {
        format(Double(bytes), suffix: "")
    }

    /// e.g. 128_000 -> "125 KB/s"
    static func rate(_ bytesPerSecond: Double) -> String {
        format(bytesPerSecond, suffix: "/s")
    }

    private static func format(_ value: Double, suffix: String) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = max(value, 0)
        var unitIndex = 0
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        let precision = unitIndex == 0 ? 0 : 1
        return String(format: "%.\(precision)f %@%@", value, units[unitIndex], suffix)
    }
}
