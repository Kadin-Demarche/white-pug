import SwiftUI

private struct MapPin: Identifiable {
    let id: String // ISO country code
    let lat: Double
    let lon: Double
    let connectionCount: Int
    let totalRate: Double
}

/// A real world map (Natural Earth 110m coastlines, bundled offline) plotting
/// the resolved country of each active connection — the Little Snitch–style
/// "where is my Mac talking to" view. Land geometry and pins share one
/// equirectangular projection, so pins sit on the correct coastlines.
struct WarMapView: View {
    @EnvironmentObject var connectionMonitor: ConnectionActivityMonitor

    private static let ocean = Color(red: 0.06, green: 0.08, blue: 0.11)
    private static let landFill = Color(red: 0.16, green: 0.22, blue: 0.28)
    private static let landStroke = Color(red: 0.30, green: 0.42, blue: 0.50)

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.ocean))

                var land = Path()
                for ring in WorldMap.shared.rings {
                    guard let first = ring.first else { continue }
                    land.move(to: scaled(first, size))
                    for point in ring.dropFirst() {
                        land.addLine(to: scaled(point, size))
                    }
                    land.closeSubpath()
                }
                ctx.fill(land, with: .color(Self.landFill))
                ctx.stroke(land, with: .color(Self.landStroke), lineWidth: 0.5)
            }

            GeometryReader { geo in
                ForEach(pins) { pin in
                    pinView(pin, in: geo.size)
                }
            }
        }
        // Equirectangular world maps are 360° lon × 180° lat — a true 2:1.
        // Rendered full-bleed by the dashboard, so no border/clip of its own.
        .aspectRatio(2, contentMode: .fit)
        .overlay {
            if connectionMonitor.connections.isEmpty {
                caption("Waiting for active connections…")
            } else if pins.isEmpty {
                caption("No locations resolved yet…")
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.35), in: Capsule())
    }

    private func pinView(_ pin: MapPin, in size: CGSize) -> some View {
        let point = project(lat: pin.lat, lon: pin.lon, in: size)
        return ZStack {
            Circle().fill(Color.red.opacity(0.25)).frame(width: 16, height: 16)
            Circle().fill(Color.red).frame(width: 7, height: 7)
            Circle().stroke(Color.white.opacity(0.85), lineWidth: 1).frame(width: 7, height: 7)
        }
        .position(point)
        .help("\(pin.id) — \(pin.connectionCount) connection(s), \(ByteFormatter.rate(pin.totalRate))")
    }

    private var pins: [MapPin] {
        var grouped: [String: (count: Int, rate: Double)] = [:]
        for connection in connectionMonitor.connections {
            guard let country = GeoIPResolver.shared.countryCode(forHost: connection.remoteHost) else { continue }
            var entry = grouped[country] ?? (count: 0, rate: 0)
            entry.count += 1
            entry.rate += connection.downRate + connection.upRate
            grouped[country] = entry
        }
        return grouped.compactMap { code, value in
            guard let coord = CountryCoordinates.centroids[code] else { return nil }
            return MapPin(id: code, lat: coord.lat, lon: coord.lon, connectionCount: value.count, totalRate: value.rate)
        }
    }

    // WorldMap rings are unit-space (0…1); scale to the view.
    private func scaled(_ point: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func project(lat: Double, lon: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: (lon + 180) / 360 * size.width, y: (90 - lat) / 180 * size.height)
    }
}
