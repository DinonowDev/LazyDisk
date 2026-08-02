// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LazyDisk",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LazyDisk", targets: ["LazyDisk"]),
    ],
    targets: [
        .target(
            name: "LazyDiskFS",
            path: "Sources/LazyDiskFS",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),
        .target(
            name: "LazyDiskCore",
            dependencies: ["LazyDiskFS"],
            path: "Sources/LazyDiskCore"
        ),
        .executableTarget(
            name: "LazyDisk",
            dependencies: ["LazyDiskCore"],
            path: "Sources/LazyDisk"
        ),
        .testTarget(
            name: "LazyDiskTests",
            dependencies: ["LazyDiskCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
