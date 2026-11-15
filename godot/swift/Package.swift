// swift-tools-version: 6.0
import PackageDescription

#if os(macOS)
let swiftGodotDep: Package.Dependency = .package(
    url: "https://github.com/migueldeicaza/SwiftGodotBinary", exact: "0.99.2"
)
let swiftGodotRuntimeDep: Target.Dependency = .product(
    name: "SwiftGodotRuntime", package: "SwiftGodotBinary"
)
#else
let swiftGodotDep: Package.Dependency = .package(
    url: "https://github.com/migueldeicaza/SwiftGodot", exact: "0.99.2"
)
let swiftGodotRuntimeDep: Target.Dependency = .product(
    name: "SwiftGodotRuntime", package: "SwiftGodot"
)
#endif

let package = Package(
    name: "GezGodot",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GezGodot", type: .dynamic, targets: ["GezGodot"])
    ],
    dependencies: [
        .package(path: "../../Packages/GezCore"),
        swiftGodotDep
    ],
    targets: [
        .target(
            name: "GezGodot",
            dependencies: [
                .product(name: "GezCore", package: "GezCore"),
                swiftGodotRuntimeDep
            ],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "$ORIGIN"], .when(platforms: [.linux]))
            ]
        ),
        .testTarget(
            name: "GezGodotTests",
            dependencies: ["GezGodot"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
