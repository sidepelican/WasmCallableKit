// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "WasmCallableKit",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "WasmCallableKit", targets: ["WasmCallableKit"]),
        .executable(name: "codegen", targets: ["Codegen"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.0"),
        .package(url: "https://github.com/omochi/CodableToTypeScript", from: "2.6.2"),
        .package(url: "https://github.com/omochi/SwiftTypeReader", from: "2.4.3"),
    ],
    targets: [
        .target(name: "WasmCallableKit", dependencies: ["CWasmCallableKit"]),
        .target(name: "CWasmCallableKit"),
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
