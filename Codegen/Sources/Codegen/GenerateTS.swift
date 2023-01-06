//import CodableToTypeScript
//import Foundation
//import SwiftTypeReader
//import TypeScriptAST
//
//struct GenerateTS {
//    var context: SwiftTypeReader.Context
//    var moduleName: String
//    var scanResult: ScanResult
//    var outDirectory: URL
//
//    private let typeMap: TypeMap = {
//        var typeMapTable: [String: TypeMap.Entry] = TypeMap.defaultTable
//        typeMapTable["URL"] = .identity(name: "string")
//        typeMapTable["Date"] = .coding(entityType: "Date", jsonType: "number", decode: "Date_decode", encode: "Date_encode")
//        return TypeMap(table: typeMapTable)
//    }()
//
//    func generatePartialSwiftRuntime() -> some ASTNode {
//        TSTypeDecl(name: "PartialSwiftRuntime", type: TSObjectType([
//            .field(name: "callSwiftFunction", type: TSFunctionType(params: [
//                .init(name: "functionID", type: TSIdentType.number),
//                .init(name: "argument", type: TSIdentType.any),
//            ], result: TSIdentType.any)),
//        ]))
//    }
//
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
//
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
//
//    func generateEntityTypes(generator: CodeGenerator) throws -> [any TSDecl] {
//        var codes: [any TSDecl] = []
//        try exportsProtocol.moduleContext.walkTypeDecls { (stype) in
//            guard stype is StructDecl
//                    || stype is EnumDecl
//                    || stype is TypeAliasDecl
//            else {
//                return true
//            }
//
//            let converter = try generator.converter(for: stype.declaredInterfaceType)
//            codes += try converter.ownDecls().decls
//            return true
//        }
//        return codes
//    }
//
//    func run() throws {
//        let generator = CodeGenerator(
//            context: context,
//            typeConverterProvider: TypeConverterProvider(typeMap: typeMap)
//        )
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
//
//        if let resourceURL = Bundle.module.resourceURL.map({ $0.appendingPathComponent("templates") }) {
//            do {
//                let templates = try FileManager.default.contentsOfDirectory(atPath: resourceURL.path)
//                for template in templates {
//                    try? FileManager.default.removeItem(at: outDirectory.appendingPathComponent(template))
//                    try FileManager.default.copyItem(
//                        at: resourceURL.appendingPathComponent(template),
//                        to: outDirectory.appendingPathComponent(template)
//                    )
//                }
//            } catch {
//                print(error)
//            }
//        }
//    }
//}
//
//fileprivate enum DateConvertDecls {
//    static func decodeDecl() -> TSFunctionDecl {
//        TSFunctionDecl(
//            modifiers: [.export],
//            name: "Date_decode",
//            params: [ .init(name: "unixMilli", type: TSIdentType("number"))],
//            body: TSBlockStmt([
//                TSReturnStmt(TSNewExpr(callee: TSIdentType("Date"), args: [TSIdentExpr("unixMilli")]))
//            ])
//        )
//    }
//
//    static func encodeDecl() -> TSFunctionDecl {
//        TSFunctionDecl(
//            modifiers: [.export],
//            name: "Date_encode",
//            params: [.init(name: "d", type: TSIdentType("Date"))],
//            body: TSBlockStmt([
//                TSReturnStmt(TSCallExpr(callee: TSMemberExpr(base: TSIdentExpr("d"), name: "getTime"), args: []))
//            ])
//        )
//    }
//}
//
//extension [ParamDecl] {
//    func toTSParams(generator: CodeGenerator) throws -> [TSFunctionType.Param] {
//        try enumerated().map { i, paramDecl in
//            TSFunctionType.Param(
//                name: paramDecl.argumentName ?? "_\(i)",
//                type: try generator.converter(for: paramDecl.interfaceType).type(for: .entity)
//            )
//        }
//    }
//}
//
//extension TSObjectType.Field {
//    static func field(
//        name: String, isOptional: Bool = false, type: any TSType
//    ) -> TSObjectType.Field {
//        let decl = TSFieldDecl(name: name, isOptional: isOptional, type: type)
//        return .field(decl)
//    }
//}
