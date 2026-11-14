// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GezGodot",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GezGodot", type: .dynamic, targets: ["GezGodot"])
    ],
    dependencies: [
        .package(path: "../../Packages/GezCore"),
        .package(url: "https://github.com/migueldeicaza/SwiftGodotBinary", exact: "0.99.2")
    ],
    targets: [
        .target(
            name: "GezGodot",
            dependencies: [
                .product(name: "GezCore", package: "GezCore"),
                .product(name: "SwiftGodotRuntime", package: "SwiftGodotBinary")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "GezGodotTests",
            dependencies: ["GezGodot"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
