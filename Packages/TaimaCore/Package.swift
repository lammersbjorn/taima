// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TaimaCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TaimaCore", targets: ["TaimaCore"]),
        .library(name: "TaimaBridge", type: .dynamic, targets: ["TaimaBridge"])
    ],
    dependencies: [
        // Only for Android and Linux: Apple platforms use CryptoKit and CommonCrypto.
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"5.0.0")
    ],
    targets: [
        .target(
            name: "TaimaCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.android, .linux])),
                .product(name: "_CryptoExtras", package: "swift-crypto", condition: .when(platforms: [.android, .linux])),
            ],
            resources: [.process("Resources")]
        ),
        .target(name: "TaimaBridge", dependencies: ["TaimaCore"]),
        .testTarget(name: "TaimaCoreTests", dependencies: ["TaimaCore",
            .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.android, .linux]))
        ], resources: [.copy("LabelFixtures")])
    ]
)
