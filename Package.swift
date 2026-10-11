// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CommonsCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "CommonsCore", targets: ["CommonsCore"])],
    targets: [
        .target(name: "CommonsCore", path: "Commons/Core"),
        .testTarget(name: "CommonsCoreTests", dependencies: ["CommonsCore"], path: "CommonsTests",
                    exclude: ["MenuStoreTests.swift"], resources: [.copy("Fixtures")])
    ]
)
