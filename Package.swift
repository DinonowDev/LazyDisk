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
            name: "LazyDiskCore",
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
