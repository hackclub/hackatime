// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "HackatimeDesktop",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "HackatimeDesktop", targets: ["HackatimeDesktop"]),
        .library(name: "HackatimeDesktopCore", targets: ["HackatimeDesktopCore"]),
    ],
    targets: [
        .target(name: "HackatimeDesktopCore"),
        .executableTarget(name: "HackatimeDesktop", dependencies: ["HackatimeDesktopCore"]),
        .testTarget(
            name: "HackatimeDesktopCoreTests",
            dependencies: ["HackatimeDesktopCore"],
            resources: [.copy("test-vectors.json")]
        ),
        .testTarget(name: "HackatimeDesktopTests", dependencies: ["HackatimeDesktop", "HackatimeDesktopCore"]),
    ]
)
