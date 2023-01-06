// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MySwiftLib",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "MySwiftLib", targets: ["MySwiftLib"]),
    ],
    dependencies: [
        .package(path: "../"),
        .package(path: "../Codegen"),
    ],
    targets: [
        .target(
            name: "MySwiftLib",
            dependencies: [
                .product(name: "WasmCallableKit", package: "WasmCallableKit"),
            ]
        ),
        .plugin(
            name: "CodegenPlugin",
            capability: .command(
                intent: .custom(verb: "codegen", description: "Generate codes from Sources/APIDefinition"),
                permissions: [.writeToPackageDirectory(reason: "Place generated code")]
            ),
            dependencies: [
                .product(name: "codegen", package: "Codegen"),
            ]
        )
    ]
)
