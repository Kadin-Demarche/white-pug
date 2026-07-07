import CoreGraphics
import Foundation

/// Loads the bundled Natural Earth 110m land outlines once and caches them as
/// rings of unit-space points (x,y in 0…1, equirectangular) ready to scale to
/// any view size. Everything is local — the GeoJSON ships in the app bundle,
/// no map tiles are fetched.
final class WorldMap {
    static let shared = WorldMap()

    /// Each ring is a closed polygon in unit space: x = (lon+180)/360,
    /// y = (90−lat)/180 — the same projection WarMapView uses for pins.
    private(set) var rings: [[CGPoint]] = []

    private init() {
        load()
    }

    private func load() {
        guard let url = Bundle.module.url(forResource: "ne_110m_land", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = obj["features"] as? [[String: Any]]
        else {
            NSLog("Pugwire: world-map GeoJSON not found in bundle; map will show pins only.")
            return
        }

        var result: [[CGPoint]] = []
        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String else { continue }
            if type == "Polygon", let coords = geometry["coordinates"] as? [[[Double]]] {
                appendRings(coords, into: &result)
            } else if type == "MultiPolygon", let polys = geometry["coordinates"] as? [[[[Double]]]] {
                for poly in polys { appendRings(poly, into: &result) }
            }
        }
        rings = result
    }

    private func appendRings(_ coords: [[[Double]]], into result: inout [[CGPoint]]) {
        for ring in coords {
            var points: [CGPoint] = []
            points.reserveCapacity(ring.count)
            for pair in ring where pair.count >= 2 {
                let lon = pair[0], lat = pair[1]
                points.append(CGPoint(x: (lon + 180) / 360, y: (90 - lat) / 180))
            }
            if points.count > 1 { result.append(points) }
        }
    }
}
