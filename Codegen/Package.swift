// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Codegen",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "codegen", targets: ["Codegen"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.0"),
        .package(url: "https://github.com/omochi/CodableToTypeScript", from: "2.6.2"),
        .package(url: "https://github.com/omochi/SwiftTypeReader", from: "2.4.2"),
    ],
    targets: [
        .executableTarget(
            name: "Codegen",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "CodableToTypeScript",
                "SwiftTypeReader",
            ],
            resources: [
                .copy("templates"),
            ]
        ),
    ]
)
