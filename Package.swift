// swift-tools-version: 6.0
import PackageDescription

let packageRoot = Context.packageDirectory

let package = Package(
    name: "LazyDisk",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LazyDisk", targets: ["LazyDisk"]),
        .executable(name: "LazyDiskPrivilegedHelper", targets: ["LazyDiskPrivilegedHelper"]),
    ],
    targets: [
        .target(
            name: "LazyDiskFS",
            path: "Sources/LazyDiskFS",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("."),
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
        .executableTarget(
            name: "LazyDiskPrivilegedHelper",
            dependencies: ["LazyDiskCore"],
            path: "Sources/LazyDiskPrivilegedHelper",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "\(packageRoot)/Scripts/AdminHelper-Info.plist",
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__launchd_plist",
                    "-Xlinker", "\(packageRoot)/Scripts/LaunchDaemons/com.lazydisk.app.AdminHelper.plist",
                ], .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "LazyDiskTests",
            dependencies: ["LazyDiskCore", "LazyDiskFS"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
