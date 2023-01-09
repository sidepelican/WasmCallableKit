import Foundation
import SwiftTypeReader

struct ScanResult {
    struct ClassInfo {
        var classID: Int
        var decl: ClassDecl
        var inits: [InitDecl]
        var methods: [FuncDecl]
    }

    struct File {
        var source: SourceFile
        var classes: [ClassInfo]
        var entities: [any TypeDecl]
        var url: URL {
            source.file
        }
        var imports: [ImportDecl] {
            source.imports
        }
    }
    var files: [File]

    var globalFuncs: [FuncDecl]
}

enum SwiftScanner {
    static func scan(sources: [SourceFile]) throws -> ScanResult {
        var globalFuncs: [FuncDecl] = []
        var files: [ScanResult.File] = []

        var classIDs = (0...).makeIterator()

        for source in sources {
            let classInfo = source.types
                .compactMap { $0 as? ClassDecl }
                .filter(\.isPublic)
                .compactMap { classDecl -> ScanResult.ClassInfo? in
                    let inits = classDecl.initializers.filter(\.isPublic)
                    let methods = classDecl.functions.filter(\.isPublic)
                    guard !inits.isEmpty, !methods.isEmpty else {
                        return nil
                    }
                    return .init(
                        classID: classIDs.next()!,
                        decl: classDecl,
                        inits: inits,
                        methods: methods
                    )
                }

            files.append(.init(
                source: source,
                classes: classInfo,
                entities: findEntityTypes(source: source)
            ))

            globalFuncs.append(contentsOf: source.funcs.filter(\.isPublic))
        }

        files.removeAll { f in
            f.classes.isEmpty && f.entities.isEmpty
        }

        return .init(
            files: files.sorted(using: KeyPathComparator(\.url.absoluteString)),
            globalFuncs: globalFuncs
        )
    }

    private static func findEntityTypes(source: SourceFile) -> [any TypeDecl] {
        var stypes: [any TypeDecl] = []
        for type in source.types {
            type.walkTypeDecls { (stype) in
                switch stype {
                case let stype as StructDecl where stype.isPublic:
                    break
                case let stype as EnumDecl where stype.isPublic:
                    break
                case let stype as TypeAliasDecl where stype.isPublic:
                    break
                default:
                    return true
                }

                stypes.append(stype)
                return true
            }
        }
        return stypes
    }
}

extension InitDecl {
    var isPublic: Bool {
        modifiers.contains(.public) || modifiers.contains(.open)
    }
}

extension FuncDecl {
    var isPublic: Bool {
        modifiers.contains(.public) || modifiers.contains(.open)
    }
}

extension ClassDecl {
    var isPublic: Bool {
        modifiers.contains(.public) || modifiers.contains(.open)
    }
}

extension StructDecl {
    var isPublic: Bool {
        modifiers.contains(.public) || modifiers.contains(.open)
    }
}

extension EnumDecl {
    var isPublic: Bool {
        modifiers.contains(.public) || modifiers.contains(.open)
    }
}

extension TypeAliasDecl {
    var isPublic: Bool {
        false // FIXME: unimplemented
//        modifiers.contains(.public) || modifiers.contains(.open)
    }
}

extension Bool {
    var not: Bool { !self }
}
