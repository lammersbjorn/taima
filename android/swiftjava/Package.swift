// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "TaimaGenerated",
    products: [.library(name: "TaimaGenerated", type: .dynamic, targets: ["TaimaGenerated"])],
    dependencies: [
        .package(path: "../../Packages/TaimaCore"),
        .package(url: "https://github.com/swiftlang/swift-java.git", revision: "301e3da710ede7af93e798f1ce1c7950715a5748")
    ],
    targets: [.target(name: "TaimaGenerated", dependencies: [
        .product(name: "TaimaBridge", package: "TaimaCore"),
        .product(name: "SwiftJava", package: "swift-java")
    ])]
)
