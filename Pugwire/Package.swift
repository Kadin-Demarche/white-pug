// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pugwire",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pugwire",
            path: "Sources/Pugwire",
            resources: [
                .copy("GeoData/dbip-country-num.csv"),
                .copy("GeoData/ne_110m_land.json")
            ]
        )
    ]
)
