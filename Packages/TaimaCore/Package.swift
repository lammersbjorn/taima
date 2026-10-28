// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TaimaCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TaimaCore", targets: ["TaimaCore"])
    ],
    targets: [
        .target(name: "TaimaCore"),
        .testTarget(name: "TaimaCoreTests", dependencies: ["TaimaCore"], resources: [.copy("LabelFixtures")])
    ]
)
