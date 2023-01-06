import ArgumentParser
import Foundation
import SwiftTypeReader

enum CodegenError: Error {
    case moduleNameNotFound
}

struct ValidationError: Error, CustomStringConvertible {
    init(_ description: String) {
        self.description = description
    }
    var description: String
}

@main struct Codegen: ParsableCommand {
    @Argument(help: "target module directory", completion: .directory)
    var module_dir: URL

    @Option(help: "generate typescript runtime", completion: .directory)
    var ts_out: URL?

    @Option(help: "generate swift adapter", completion: .directory)
    var swift_out: URL?

    @Option(name: .shortAndLong, help: "module name")
    var module: String?

    mutating func run() throws {
        let moduleName = module_dir
            .resolvingSymlinksInPath()
            .pathComponents
            .eachPairs()
            .first { (f, s) in
                f == "Sources"
            }
            .map(\.1)
        guard let moduleName = module ?? moduleName else {
            throw CodegenError.moduleNameNotFound
        }

        // scan

        let context = SwiftTypeReader.Context()
        let module = SwiftTypeReader.Reader(
            context: context,
            module: context.getOrCreateModule(name: moduleName)
        )
        let sources = try module.read(directory: module_dir)
        let scanResult = try SwiftScanner.scan(sources: sources)

        // validations

//        guard let exportsProtocol = source.find(name: "WasmExports", options: .init(type: true))?.asProtocol else {
//            throw ValidationError("'WasmExports' protocol not found")
//        }
//        guard exportsProtocol.associatedTypes.isEmpty else {
//            throw ValidationError("'WasmExports' protocol cannot have associated types")
//        }
//        guard exportsProtocol.inheritedTypeReprs.isEmpty else {
//            throw ValidationError("'WasmExports' protocol cannot have inherited types")
//        }
//        guard exportsProtocol.functions.allSatisfy({ f in
//            f.isStatic && !f.isAsync && !f.isReasync
//        }) else {
//            throw ValidationError("all requirements should be static and not be async")
//        }

        // generate

        if let swift_out = swift_out {
            try GenerateSwift(
                moduleName: moduleName,
                scanResult: scanResult,
                outDirectory: swift_out
            ).run()
        }

        if let ts_out = ts_out {
            try GenerateTS(
                context: context,
                moduleName: moduleName,
                scanResult: scanResult,
                outDirectory: ts_out
            ).run()
        }

        withExtendedLifetime(context) {}
    }
}

extension Sequence {
    func eachPairs() -> AnySequence<(Element, Element)> {
        AnySequence(
            zip(self, self.dropFirst())
        )
    }
}

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        self = URL(fileURLWithPath: argument)
    }
}

extension FuncDecl {
    var isStatic: Bool {
        modifiers.contains(.static)
    }

    var isAsync: Bool {
        modifiers.contains(.async) || modifiers.contains(.reasync)
    }
}
