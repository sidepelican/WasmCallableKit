// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WasmCallableKitCodegen",
    platforms: [.macOS(.v12)],
    products: [
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.0"),
        .package(url: "https://github.com/omochi/CodableToTypeScript", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "Codegen",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "CodableToTypeScript",
            ],
            resources: [
                .copy("templates"),
            ]
        ),
    ]
)
