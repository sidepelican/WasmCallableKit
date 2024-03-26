import WasmCallableKit

func buildGlobals() -> [([UInt8]) throws -> [UInt8]] {
    var ret: [([UInt8]) throws -> [UInt8]] = []
    ret.append { argData in
        struct Params: Decodable {
            var _0: Int
            var _1: Int
        }
        let args = try WasmCallableKit.decodeJSON(Params.self, from: argData)
        let ret = add(
            a: args._0,
            b: args._1
        )
        return try WasmCallableKit.encodeJSON(ret)
    }
    ret.append { argData in
        struct Params: Decodable {
            var _0: Vec2
        }
        let args = try WasmCallableKit.decodeJSON(Params.self, from: argData)
        let ret = normalize(
            args._0
        )
        return try WasmCallableKit.encodeJSON(ret)
    }
    return ret
}