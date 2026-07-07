import Foundation

struct LiveConnection: Identifiable, Equatable {
    let id: String
    let proto: String
    let remoteEndpoint: String
    let remoteHost: String // remoteEndpoint without the port, for GeoIP lookup
    let interfaceName: String
    let state: String
    var downRate: Double // bytes/sec
    var upRate: Double // bytes/sec
}
