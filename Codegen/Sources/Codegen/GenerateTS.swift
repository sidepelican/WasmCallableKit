import CodableToTypeScript
import Foundation
import SwiftTypeReader
import TypeScriptAST

fileprivate struct SourceEntry {
    var file: URL
    var source: TSSourceFile
}

struct GenerateTS {
    var context: SwiftTypeReader.Context
    var moduleName: String
    var scanResult: ScanResult
    var outDirectory: URL
    var generator: CodeGenerator

    init(context: SwiftTypeReader.Context, moduleName: String, scanResult: ScanResult, outDirectory: URL) {
        self.context = context
        self.moduleName = moduleName
        self.scanResult = scanResult
        self.outDirectory = outDirectory

        let typeMap: TypeMap = {
            var typeMapTable: [String: TypeMap.Entry] = TypeMap.defaultTable
            typeMapTable["URL"] = .identity(name: "string")
            typeMapTable["Date"] = .coding(entityType: "Date", jsonType: "number", decode: "Date_decode", encode: "Date_encode")
            return TypeMap(table: typeMapTable)
        }()
        self.generator = CodeGenerator(
            context: context,
            typeConverterProvider: TypeConverterProvider(typeMap: typeMap)
        )
    }

    private func buildEncodingParam(params: [ParamDecl]) throws -> any TSExpr {
        let fields = try params.enumerated().map { (i, decl: ParamDecl) -> TSObjectExpr.Field in
            let converter = try generator.converter(for: decl.interfaceType)
            let hasEncoder = try converter.hasEncode()
            let argName = decl.argumentName!

            return .named(
                name: "_\(i)",
                value: hasEncoder
                ? try converter.callEncode(entity: TSIdentExpr(argName))
                : TSIdentExpr(argName)
            )
        }

        return TSObjectExpr(fields)
    }

    private func process(file: ScanResult.File) throws -> [any ASTNode] {
        let runtime = TSIdentType("SwiftRuntime")
        let this = TSIdentExpr.this
        return try file.classes.map { classInfo -> any ASTNode in
            let className = classInfo.decl.name

            let constructors = try classInfo.inits.enumerated().map { (initializerID: Int, decl: InitDecl) -> any ASTNode in

                return TSMethodDecl(
                    name: "constructor",
                    params: try decl.parameters.toTSParams(generator: generator)
                    + [.init(name: "runtime", isOptional: true, type: runtime)],
                    body: TSBlockStmt([
                        TSAssignExpr(TSMemberExpr(base: this, name: "#runtime"), TSInfixOperatorExpr(TSIdentExpr("runtime"), "??", TSIdentExpr("globalRuntime"))),
                        TSAssignExpr(
                            TSMemberExpr(base: this, name: "#id"),
                            TSCallExpr(callee: TSMemberExpr(base: this, names: "#runtime", "classInit"), args: [
                                TSNumberLiteralExpr(classInfo.classID),
                                TSNumberLiteralExpr(initializerID),
                                try buildEncodingParam(params: decl.parameters),
                            ])
                        ),
                    ])
                )
            }

            let methods = try classInfo.methods.enumerated().map { (functionID, decl: FuncDecl) -> any ASTNode in
                let runtimeCall = TSCallExpr(callee: TSMemberExpr(base: this, names: "#runtime", "classSend"), args: [
                    TSMemberExpr(base: this, name: "#id"),
                    TSNumberLiteralExpr(functionID),
                    try buildEncodingParam(params: decl.parameters),
                ])

                let resultConverter = try generator.converter(for: decl.resultInterfaceType)

                return TSMethodDecl(
                    name: decl.name,
                    params: try decl.parameters.toTSParams(generator: generator),
                    result: try resultConverter.type(for: .entity),
                    body: TSBlockStmt([
                        TSReturnStmt(try resultConverter.callDecode(
                            json: TSAsExpr(runtimeCall, resultConverter.type(for: .json))
                        ))
                    ])
                )
            }

            return TSClassDecl(
                modifiers: [.export],
                name: className,
                body: TSBlockStmt([
                    TSFieldDecl(name: "#runtime", type: runtime),
                    TSFieldDecl(name: "#id", type: TSIdentType.number),
                ] + constructors + methods)
            )
        }
    }

//    func generatePartialSwiftRuntime() -> some ASTNode {
//        TSTypeDecl(name: "PartialSwiftRuntime", type: TSObjectType([
//            .field(name: "callSwiftFunction", type: TSFunctionType(params: [
//                .init(name: "functionID", type: TSIdentType.number),
//                .init(name: "argument", type: TSIdentType.any),
//            ], result: TSIdentType.any)),
//        ]))
//    }

//    func generateExportsType(generator: CodeGenerator) throws -> some ASTNode {
//        TSTypeDecl(
//            modifiers: [.export],
//            name: "\(moduleName)Exports",
//            type: TSObjectType(try exportsProtocol.functions.map { funcDecl in
//                TSObjectType.Field(
//                    name: funcDecl.name,
//                    type: TSFunctionType(
//                        params: try funcDecl.parameters.toTSParams(generator: generator),
//                        result: try generator.converter(for: funcDecl.resultInterfaceType).type(for: .entity)
//                    )
//                )
//            })
//        )
//    }

//    func generateBindFunc(generator: CodeGenerator) throws -> some ASTNode {
//        TSVarDecl(
//            modifiers: [.export],
//            kind: .const,
//            name: "bind\(moduleName)",
//            initializer: TSClosureExpr(
//                params: [.init(name: "swift", type: TSIdentType("PartialSwiftRuntime"))],
//                result: TSIdentType("\(moduleName)Exports"),
//                body: TSBlockStmt([
//                    TSReturnStmt(TSObjectExpr(try exportsProtocol.functions.enumerated().map { i, funcDecl in
//                        TSObjectExpr.Field.named(
//                            name: funcDecl.name,
//                            value: TSClosureExpr(
//                                params: try funcDecl.parameters.toTSParams(generator: generator),
//                                body: TSCallExpr(
//                                    callee: TSMemberExpr(base: TSIdentExpr("swift"), name: "callSwiftFunction"),
//                                    args: [
//                                        TSNumberLiteralExpr(i),
//                                        TSObjectExpr(funcDecl.parameters.enumerated().map { i, paramDecl in
//                                            TSObjectExpr.Field.named(name: "_\(i)", value: TSIdentExpr(paramDecl.argumentName ?? "_\(i)"))
//                                        }),
//                                    ]
//                                )
//                            )
//                        )
//                    })),
//                ])
//            )
//        )
//    }

    private func generateEntityTypes(source: SourceFile) throws -> [any TSDecl] {
        var codes: [any TSDecl] = []
        for type in source.types {
            try type.walkTypeDecls { (stype) in
                guard stype is StructDecl
                        || stype is EnumDecl
                        || stype is TypeAliasDecl
                else {
                    return true
                }

                let converter = try generator.converter(for: stype.declaredInterfaceType)
                codes += try converter.ownDecls().decls
                return true
            }
        }
        return codes
    }

    func run() throws {
        var sources: [SourceEntry] = []

        try DirectoryWriter(
            dstDirectory: outDirectory,
            isOutputFileName: { $0.hasSuffix(".ts") }
        ).run { sink in
            if let resURL = Bundle.module.resourceURL.map({ $0.appendingPathComponent("templates") }) {
                do {
                    let templates = try FileManager.default.contentsOfDirectory(atPath: resURL.path)
                    for template in templates {
                        try sink(file: .init(
                            relativeURL: URL(fileURLWithPath: template),
                            content: try String(contentsOf: resURL.appendingPathComponent(template, isDirectory: false))
                        ))
                    }
                } catch {
                    print(error)
                }
            }

            for file in scanResult.files {
                let source = TSSourceFile(try process(file: file))
                source.elements += try generateEntityTypes(source: file.source)
                sources.append(.init(file: file.url.rewritingExtension("ts"), source: source))
            }

            let common = TSSourceFile([])
            common.elements.append(contentsOf: generator.generateHelperLibrary().elements)
            common.elements.append(DateConvertDecls.encodeDecl())
            common.elements.append(DateConvertDecls.decodeDecl())
            sources.append(.init(file: URL(fileURLWithPath: "common.ts"), source: common))

            // collect all symbols
            var symbolTable = SymbolTable(
                standardLibrarySymbols: SymbolTable.standardLibrarySymbols.union([
                ])
            )
            symbolTable.add(symbol: "globalRuntime", file: .file(URL(fileURLWithPath: "SwiftRuntime.ts")))
            symbolTable.add(symbol: "SwiftRuntime", file: .file(URL(fileURLWithPath: "SwiftRuntime.ts")))
            for source in sources {
                for symbol in source.source.memberDeclaredNames {
                    if let _ = symbolTable.find(symbol){
                        throw MessageError("Duplicated symbol: \(symbol). Using the same name in multiple modules is not supported.")
                    }
                    symbolTable.add(symbol: symbol, file: .file(source.file))
                }
            }

            // generate imports
            for source in sources {
                let imports = try source.source.buildAutoImportDecls(
                    from: outDirectory.deletingLastPathComponent(),
                    symbolTable: symbolTable,
                    fileExtension: .js
                )
                source.source.replaceImportDecls(imports)
            }

            // write
            for source in sources {
                try sink(file: .init(
                    relativeURL: source.file,
                    content: source.source.print()
                ))
            }
        }

//        let source = TSSourceFile([])
//        source.elements.append(generatePartialSwiftRuntime())
//        source.elements.append(try generateExportsType(generator: generator))
//        source.elements.append(try generateBindFunc(generator: generator))
//        source.elements.append(contentsOf: try generateEntityTypes(generator: generator))
//        source.elements.append(contentsOf: generator.generateHelperLibrary().elements)
//        source.elements.append(DateConvertDecls.encodeDecl())
//        source.elements.append(DateConvertDecls.decodeDecl())
//
//        try? FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)
//        try source.print().data(using: .utf8)!
//            .write(to: outDirectory.appendingPathComponent("\(moduleName)Exports.ts"), options: .atomic)

    }
}

fileprivate enum DateConvertDecls {
    static func decodeDecl() -> TSFunctionDecl {
        TSFunctionDecl(
            modifiers: [.export],
            name: "Date_decode",
            params: [ .init(name: "unixMilli", type: TSIdentType("number"))],
            body: TSBlockStmt([
                TSReturnStmt(TSNewExpr(callee: TSIdentType("Date"), args: [TSIdentExpr("unixMilli")]))
            ])
        )
    }

    static func encodeDecl() -> TSFunctionDecl {
        TSFunctionDecl(
            modifiers: [.export],
            name: "Date_encode",
            params: [.init(name: "d", type: TSIdentType("Date"))],
            body: TSBlockStmt([
                TSReturnStmt(TSCallExpr(callee: TSMemberExpr(base: TSIdentExpr("d"), name: "getTime"), args: []))
            ])
        )
    }
}

extension [ParamDecl] {
    func toTSParams(generator: CodeGenerator) throws -> [TSFunctionType.Param] {
        try enumerated().map { i, paramDecl in
            TSFunctionType.Param(
                name: paramDecl.argumentName ?? "_\(i)",
                type: try generator.converter(for: paramDecl.interfaceType).type(for: .entity)
            )
        }
    }
}

extension TSObjectType.Field {
    static func field(
        name: String, isOptional: Bool = false, type: any TSType
    ) -> TSObjectType.Field {
        let decl = TSFieldDecl(name: name, isOptional: isOptional, type: type)
        return .field(decl)
    }
}

extension TSMemberExpr {
    convenience init(
        base: any TSExpr,
        names: String...
    ) {
        self.init(base: base, names: names[...])
    }

    private convenience init(
        base: any TSExpr,
        names: ArraySlice<String>
    ) {
        switch names.count {
        case 0:
            preconditionFailure()
        case 1:
            self.init(base: base, name: names[names.startIndex])
        default:
            self.init(base: TSMemberExpr(base: base, name: names[names.startIndex]), names: names[names.index(after: names.startIndex)])
        }
    }
}

extension URL {
    func rewritingExtension(_ ext: String) -> URL {
        self.deletingPathExtension()
            .appendingPathExtension(ext)
    }
}
