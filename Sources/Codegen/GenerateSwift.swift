import Foundation
import SwiftTypeReader

struct GenerateSwift {
    var moduleName: String
    var scanResult: ScanResult
    var outDirectory: URL

    private func buildParamsEntity(params: [FuncParamDecl]) -> String {
        return """
struct Params: Decodable {
\(params.enumerated().map({ """
    var _\($0.offset): \($0.element.interfaceType.description)
""" }).joined(separator: "\n"))
}
"""
    }

    private func buildCallArguments(params: [FuncParamDecl]) -> String {
        return params.enumerated().map { (i, decl: FuncParamDecl) in
            if let interfaceName = decl.interfaceName {
                return "\(interfaceName): args._\(i)"
            } else {
                return "args._\(i)"
            }
        }.joined(separator: ",\n")
    }

    private func process(file: ScanResult.File) throws -> String {
        let enums = file.classes.map { classInfo in
            let className = classInfo.decl.name

            let inits = classInfo.inits.map { (decl: InitDecl) in
                let tryToken = decl.isThrows ? "try " : ""
                if decl.parameters.isEmpty {
                    return """
meta.inits.append { _ in
    return \(tryToken)\(className)()
}
"""
                } else {
                    return """
meta.inits.append { argData in
\(buildParamsEntity(params: decl.parameters).withIndent(1))
    let args = try WasmCallableKit.decodeJSON(Params.self, from: argData)
    return \(tryToken)\(className)(
\(buildCallArguments(params: decl.parameters).withIndent(2))
    )
}
"""
                }
            }

            let methods = classInfo.methods.map { (decl: FuncDecl) in
                let tryToken = decl.isThrows ? "try " : ""
                let returnReceiver = decl.hasOutput ? "ret" : "_"
                let returnStmt = "return \(decl.hasOutput ? "try WasmCallableKit.encodeJSON(ret)" : "[]")"
                if decl.parameters.isEmpty {
                    return """
meta.methods.append { `self`, _ in
    let \(returnReceiver) = \(tryToken)self.\(decl.name)()
    \(returnStmt)
}
"""
                } else {
                    return """
meta.methods.append { `self`, argData in
\(buildParamsEntity(params: decl.parameters).withIndent(1))
    let args = try WasmCallableKit.decodeJSON(Params.self, from: argData)
    let \(returnReceiver) = \(tryToken)self.\(decl.name)(
\(buildCallArguments(params: decl.parameters).withIndent(2))
    )
    \(returnStmt)
}
"""
                }
            }

            return """
func build\(className)Metadata() -> ClassMetadata<\(className)> {
    var meta = ClassMetadata<\(className)>()
\(inits.joined(separator: "\n").withIndent(1))
\(methods.joined(separator: "\n").withIndent(1))
    return meta
}
"""
        }

        let imports = Set(["WasmCallableKit"])
            .union(file.imports.map(\.moduleName))

        return """
\(imports.sorted().map { "import \($0)" }.joined(separator: "\n"))

\(enums.joined(separator: "\n\n"))
"""
    }

    private func process(globalFuncs: [FuncDecl], allImports: [ImportDecl]) throws -> String {
        let methods = globalFuncs.map { (decl: FuncDecl) in
            let tryToken = decl.isThrows ? "try " : ""
            let returnReceiver = decl.hasOutput ? "ret" : "_"
            let returnStmt = "return \(decl.hasOutput ? "try WasmCallableKit.encodeJSON(ret)" : "[]")"
            if decl.parameters.isEmpty {
                return """
ret.append { _ in
    let \(returnReceiver) = \(tryToken)\(decl.name)()
    \(returnStmt)
}
"""
            } else {
                return """
ret.append { argData in
\(buildParamsEntity(params: decl.parameters).withIndent(1))
    let args = try WasmCallableKit.decodeJSON(Params.self, from: argData)
    let \(returnReceiver) = \(tryToken)\(decl.name)(
\(buildCallArguments(params: decl.parameters).withIndent(2))
    )
    \(returnStmt)
}
"""
            }
        }

        let imports = Set(["WasmCallableKit"])
            .union(allImports.map(\.moduleName))

        return """
\(imports.sorted().map { "import \($0)" }.joined(separator: "\n"))

func buildGlobals() -> [([UInt8]) throws -> [UInt8]] {
    var ret: [([UInt8]) throws -> [UInt8]] = []
\(methods.joined(separator: "\n").withIndent(1))
    return ret
}
"""
    }

    private func process(classes: [ScanResult.ClassInfo], hasGlobal: Bool) throws -> String {
        let installGlobal = hasGlobal ? "setFunctionList(buildGlobals())" : ""
        let installClass = classes
            .sorted(using: KeyPathComparator(\.classID))
            .map { "build\($0.decl.name)Metadata()," }
            .joined(separator: "\n")

return """
import WasmCallableKit

extension WasmCallableKit {
    static func install() {
        \(installGlobal)
        registerClassMetadata(meta: [
\(installClass.withIndent(3))
        ])
    }
}
"""
    }

    func run() throws {
        try DirectoryWriter(
            dstDirectory: outDirectory,
            isOutputFileName: { $0.hasSuffix(".gen.swift") }
        ).run { sink in
            for file in scanResult.files {
                let source = try process(file: file)
                try sink(file: .init(relativeURL: file.url.rewritingExtension("gen.swift"), content: source))
            }

            if !scanResult.globalFuncs.isEmpty {
                let global = try process(
                    globalFuncs: scanResult.globalFuncs,
                    allImports: scanResult.files.flatMap(\.imports)
                )
                try sink(file: .init(relativeURL: URL(fileURLWithPath: "\(moduleName)Globals.gen.swift"), content: global))
            }

            try sink(file: .init(
                relativeURL: URL(fileURLWithPath: "Install.gen.swift"),
                content: try process(
                    classes: scanResult.files.flatMap { $0.classes },
                    hasGlobal: !scanResult.globalFuncs.isEmpty
                )
            ))
        }
    }
}

extension InitDecl {
    var isThrows: Bool {
        modifiers.contains(.throws)
    }
}

extension FuncDecl {
    var hasOutput: Bool {
        resultTypeRepr != nil
    }

    var isThrows: Bool {
        modifiers.contains(.throws)
    }
}

extension String {
    fileprivate func withIndent(_ indent: Int) -> String {
        self.split(separator: "\n")
            .map { String(repeating: "    ", count: indent) + $0 }
            .joined(separator: "\n")
    }
}
