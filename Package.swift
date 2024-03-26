// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WasmCallableKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WasmCallableKit", targets: ["WasmCallableKit"]),
        .executable(name: "codegen", targets: ["Codegen"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.2"),
        .package(url: "https://github.com/omochi/CodableToTypeScript.git", exact: "2.11.0"),
        .package(url: "https://github.com/omochi/SwiftTypeReader.git", exact: "2.7.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-json.git", .upToNextMajor(from: "0.6.0")),
    ],
    targets: [
        .target(
            name: "WasmCallableKit",
            dependencies: [
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
                "CWasmCallableKit",
            ]
        ),
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
