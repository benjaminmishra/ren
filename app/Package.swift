// swift-tools-version: 5.7
import PackageDescription

let coreReleaseDir = "\(Context.packageDirectory)/../core/target/release"

let package = Package(
    name: "Ren",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Ren", targets: ["RenApp"])
    ],
    targets: [
        .target(
            name: "RenKit",
            path: "Sources/RenKit",
            linkerSettings: [
                .unsafeFlags([
                    "-L", coreReleaseDir,
                    "-lcleaner_core",
                    "-Xlinker", "-rpath",
                    "-Xlinker", coreReleaseDir
                ])
            ]
        ),
        .executableTarget(
            name: "RenApp",
            dependencies: ["RenKit"],
            path: "Sources/RenApp"
        ),
        .testTarget(
            name: "RenTests",
            dependencies: ["RenKit"],
            path: "Tests/RenTests"
        )
    ]
)
