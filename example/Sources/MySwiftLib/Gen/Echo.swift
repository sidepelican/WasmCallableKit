import Foundation
import WasmCallableKit

func buildEchoMetadata() -> ClassMetadata<Echo> {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    let empty = Data("{}".utf8)
    var meta = ClassMetadata<Echo>()
    meta.inits.append { argData in
        struct Params: Decodable {
            var _0: String
        }
        let args = try decoder.decode(Params.self, from: argData)
        return Echo(
            name: args._0
        )
    }
    meta.methods.append { `self`, _ in
        let ret = self.hello()
        return try encoder.encode(ret)
    }
    meta.methods.append { `self`, argData in
        struct Params: Decodable {
            var _0: Echo.UpdateKind
        }
        let args = try decoder.decode(Params.self, from: argData)
        let _ = self.update(
            _: args._0
        )
        return empty
    }
    meta.methods.append { `self`, argData in
        struct Params: Decodable {
            var _0: Date
        }
        let args = try decoder.decode(Params.self, from: argData)
        let ret = self.tommorow(
            now: args._0
        )
        return try encoder.encode(ret)
    }
    return meta
}