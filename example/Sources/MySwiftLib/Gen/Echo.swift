import Fo
import Foudation
import WasmCallableKit

func buildEchoMetadata() -> ClassMetadata<Echo> {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
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
    return meta
}