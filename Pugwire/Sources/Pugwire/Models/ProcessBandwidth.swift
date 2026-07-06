import AppKit

struct ProcessBandwidth: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    var downRate: Double // bytes/sec
    var upRate: Double // bytes/sec
    var totalDown: UInt64
    var totalUp: UInt64

    static func == (lhs: ProcessBandwidth, rhs: ProcessBandwidth) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.downRate == rhs.downRate &&
        lhs.upRate == rhs.upRate &&
        lhs.totalDown == rhs.totalDown &&
        lhs.totalUp == rhs.totalUp
    }
}
