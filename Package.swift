// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "lindongdao",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "lindongdao", targets: ["DynamicIsland"])
    ],
    targets: [
        .executableTarget(
            name: "DynamicIsland",
            path: "Sources/DynamicIsland"
        ),
        .testTarget(
            name: "DynamicIslandTests",
            dependencies: ["DynamicIsland"],
            path: "Tests/DynamicIslandTests"
        ),
    ]
)
