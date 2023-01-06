import Foundation
import SwiftTypeReader

struct GenerateSwift {
    var moduleName: String
    var scanResult: ScanResult
    var outDirectory: URL

    private func buildParamsEntity(params: [ParamDecl]) -> String {
        return """
struct Params: Decodable {
\(params.enumerated().map({ """
    var _\($0.offset): \($0.element.interfaceType.description)
""" }).joined(separator: "\n"))
}
"""
    }

    private func buildCallArguments(params: [ParamDecl]) -> String {
        return params.enumerated().map({ """
\($0.element.argumentName!): args._\($0.offset)
""" }).joined(separator: ",\n")
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
    let args = try decoder.decode(Params.self, from: argData)
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
                let returnStmt = "return \(decl.hasOutput ? "try encoder.encode(ret)" : "empty")"
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
    let args = try decoder.decode(Params.self, from: argData)
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
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    let empty = Data("{}".utf8)
    var meta = ClassMetadata<\(className)>()
\(inits.joined(separator: "\n").withIndent(1))
\(methods.joined(separator: "\n").withIndent(1))
    return meta
}
"""
        }

        let imports = Set(["Foundation", "WasmCallableKit"])
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
            let returnStmt = "return \(decl.hasOutput ? "try encoder.encode(ret)" : "empty")"
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
    let args = try decoder.decode(Params.self, from: argData)
    let \(returnReceiver) = \(tryToken)\(decl.name)(
\(buildCallArguments(params: decl.parameters).withIndent(2))
    )
    \(returnStmt)
}
"""
            }
        }

        let imports = Set(["Foundation"])
            .union(allImports.map(\.moduleName))

        return """
\(imports.sorted().map { "import \($0)" }.joined(separator: "\n"))

func buildGlobals() -> [(Data) throws -> Data] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    let empty = Data("{}".utf8)
    var ret: [(Data) throws -> Data] = []
\(methods.joined(separator: "\n").withIndent(1))
    return ret
}
"""
    }

    private func process(classes: [ScanResult.ClassInfo], hasGlobal: Bool) throws -> String {
        let installGlobal = hasGlobal ? "setFunctionList(buildGlobals())" : ""
        let installClass = classes
            .sorted(using: KeyPathComparator(\.classID))
            .map { "build\($0)Medadata()," }
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
            isOutputFileName: { $0.hasSuffix(".swift") }
        ).run { sink in
            for file in scanResult.files {
                let source = try process(file: file)
                try sink(file: .init(relativeURL: file.url, content: source))
            }

            if !scanResult.globalFuncs.isEmpty {
                let global = try process(
                    globalFuncs: scanResult.globalFuncs,
                    allImports: scanResult.files.flatMap(\.imports)
                )
                try sink(file: .init(relativeURL: URL(fileURLWithPath: "\(moduleName)Globals.swift"), content: global))
            }

            try sink(file: .init(
                relativeURL: URL(fileURLWithPath: "Install.swift"),
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
        self.splitLines()
            .map { String(repeating: "    ", count: indent) + $0 }
            .joined()
    }
}
