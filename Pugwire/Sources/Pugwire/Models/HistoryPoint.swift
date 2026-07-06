import Foundation

struct HistoryPoint: Codable, Equatable {
    let timestamp: Date
    let downBytesPerSec: Double
    let upBytesPerSec: Double
}
