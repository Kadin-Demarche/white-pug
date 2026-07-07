import SwiftUI

private struct MapPin: Identifiable {
    let id: String // ISO country code
    let lat: Double
    let lon: Double
    let connectionCount: Int
    let totalRate: Double
}

/// A stylized (not cartographically precise) world map plotting the
/// resolved country of each active connection. Continents are drawn as soft
/// rounded blobs at roughly their real bounding regions — not traced
/// coastlines — since the point is showing *where connections are*,
/// accurately, not tracing an accurate coastline.
struct WarMapView: View {
    @EnvironmentObject var connectionMonitor: ConnectionActivityMonitor

    // Fractional (0–1) rects in the same equirectangular space as `project`,
    // so they line up with the pins. Each is derived from a continent's real
    // lon/lat bounding box: x = (lon+180)/360, y = (90−lat)/180. Soft rounded
    // blobs, not traced coastlines — enough to read as "that's roughly where
    // the landmasses are" behind the accurately-placed connection pins.
    private static let continentBlobs: [(rect: CGRect, cornerRadius: CGFloat)] = [
        (CGRect(x: 0.03, y: 0.10, width: 0.32, height: 0.33), 40), // North America
        (CGRect(x: 0.27, y: 0.43, width: 0.14, height: 0.38), 30), // South America
        (CGRect(x: 0.47, y: 0.11, width: 0.14, height: 0.19), 18), // Europe
        (CGRect(x: 0.45, y: 0.29, width: 0.19, height: 0.40), 30), // Africa
        (CGRect(x: 0.60, y: 0.09, width: 0.37, height: 0.44), 40), // Asia
        (CGRect(x: 0.79, y: 0.60, width: 0.14, height: 0.16), 18), // Australia
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.85)
                graticule(in: geo.size)
                landmasses(in: geo.size)
                ForEach(pins) { pin in
                    pinView(pin, in: geo.size)
                }
            }
        }
        // A world map in equirectangular projection is 360° of longitude by
        // 180° of latitude — a true 2:1 aspect. Locking the frame to 2:1 (vs.
        // a fixed height that stretched it into a box) makes the linear
        // lon/lat→x/y projection below geographically correct.
        //
        // No border/clip of its own: the dashboard renders this full-bleed as
        // the whole dropdown, so the menu-bar window's own rounded corners do
        // the clipping.
        .aspectRatio(2, contentMode: .fit)
        .overlay {
            if connectionMonitor.connections.isEmpty {
                Text("Waiting for active connections…")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
            } else if pins.isEmpty {
                Text("No locations resolved yet…")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func graticule(in size: CGSize) -> some View {
        Path { path in
            for lonDeg in stride(from: -180, through: 180, by: 30) {
                let x = CGFloat(lonDeg + 180) / 360 * size.width
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for latDeg in stride(from: -90, through: 90, by: 30) {
                let y = CGFloat(90 - latDeg) / 180 * size.height
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
    }

    private func landmasses(in size: CGSize) -> some View {
        ForEach(Array(Self.continentBlobs.enumerated()), id: \.offset) { _, blob in
            RoundedRectangle(cornerRadius: blob.cornerRadius)
                .fill(Color.green.opacity(0.16))
                .frame(width: blob.rect.width * size.width, height: blob.rect.height * size.height)
                .position(
                    x: (blob.rect.minX + blob.rect.width / 2) * size.width,
                    y: (blob.rect.minY + blob.rect.height / 2) * size.height
                )
        }
    }

    private func pinView(_ pin: MapPin, in size: CGSize) -> some View {
        let point = project(lat: pin.lat, lon: pin.lon, in: size)
        return ZStack {
            Circle()
                .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                .frame(width: 14, height: 14)
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
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

    private func project(lat: Double, lon: Double, in size: CGSize) -> CGPoint {
        let x = (lon + 180) / 360 * size.width
        let y = (90 - lat) / 180 * size.height
        return CGPoint(x: x, y: y)
    }
}
