@testable import CodableToTypeScript
import Foundation
import SwiftTypeReader
import TSCodeModule

class ImportMap {
    typealias Def = (typeName: String, fileName: String)
    init(defs: [Def]) {
        self.defs = defs
    }

    var defs: [Def] = []
    func insert(type: SType, file: String) {
        if type.enum != nil {
            defs.append((type.name + "Decode", file))
        }
        defs.append((type.name, file))
    }

    func file(for typeName: String) -> String? {
        defs.first(where: { $0.typeName == typeName })?.fileName
    }

    func typeNames(for file: String) -> [String] {
        defs.filter { $0.fileName == file }.map(\.typeName)
    }

    func importDecls(forTypes types: [String], for file: String) -> [String] {
        var filesTypesTable: [String: [String]] = [:]
        for type in types {
            guard let typefile = self.file(for: type), typefile != file else { continue }
            filesTypesTable[typefile, default: []].append(type)
        }

        return filesTypesTable.sorted(using: KeyPathComparator(\.key)).map { (file: String, types: [String]) in
            let file = file.replacingOccurrences(of: ".ts", with: "")
            return "import { \(types.sorted().joined(separator: ", ")) } from \"./\(file)\";"
        }
    }
}

struct GenerateTS {
    var exportsProtocol: ProtocolType
    var outDirectory: URL

    private let typeMap: TypeMap = {
        var typeMapTable: [String: String] = TypeMap.defaultTable
        typeMapTable["URL"] = "string"
        typeMapTable["Date"] = "number"
        return TypeMap(table: typeMapTable)
    }()

    func run() throws {
        let content = """
type PartialSwiftRuntime = {
  callSwiftFunction(functionID: number, argument: any): any
}

export type CallableKitExports = {
\(try exportsProtocol.functionRequirements.map({ f in
"""
  \(f.name): (\(try f.parameters.map({ "\($0.name): \(try typeMap.tsName(stype: $0.type()))" }).joined(separator: ", "))) => \(try f.outputType().map(typeMap.tsName(stype:)) ?? "void"),
""" }).joined(separator: "\n"))
};

export const bindCallableKitExports = (swift: PartialSwiftRuntime): CallableKitExports => {
  return {
\(try exportsProtocol.functionRequirements.enumerated().map({ (i, f) in
"""
    \(f.name): (\(try f.parameters.map({ "\($0.name): \(try typeMap.tsName(stype: $0.type()))" }).joined(separator: ", "))): \(try f.outputType().map(typeMap.tsName(stype:)) ?? "void") => swift.callSwiftFunction(\(i), {
\(f.parameters.enumerated().map({ i, p in
"""
      _\(i): \(p.name),
"""
}).joined(separator: "\n"))
    }),
""" }).joined(separator: "\n"))
  };
};
"""
        try content.data(using: .utf8)!
            .write(to: outDirectory.appendingPathComponent("CallableKitExports.ts"), options: .atomic)
    }
}

extension TypeMap {
    fileprivate func tsName(stype: SType) throws -> String {
        let printer = PrettyPrinter()
        try StructConverter.transpile(typeMap: self, type: stype).print(printer: printer)
        var output =  printer.output
        if stype.enum != nil, output.contains("JSON") {
            output = output.replacingOccurrences(of: "JSON", with: "") // CodableResultJSON<foo, bar> など、Genericな場合はJSONがまちまちに出現しうるので雑に全部消す
        }
        return output
    }
}

fileprivate func unwrapGenerics(typeName: String) -> [String] {
    typeName
        .components(separatedBy: .whitespaces.union(.init(charactersIn: "<>,")))
        .filter { !$0.isEmpty }
}

fileprivate func findTypes(in tsType: TSType) -> [String] {
    switch tsType {
    case .array(let array):
        return findTypes(in: array.element)
    case .dictionary(let dictionary):
        return findTypes(in: dictionary.element)
    case .named(let named):
        return [named.name]
    case .record(let record):
        return record.fields.flatMap { findTypes(in: $0.type) }
    case .stringLiteral:
        return []
    case .union(let union):
        return union.items.flatMap { findTypes(in: $0) }
    }
}
