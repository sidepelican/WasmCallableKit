import Foundation

func buildGlobals() -> [(Data) throws -> Data] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    let empty = Data("{}".utf8)
    var ret: [(Data) throws -> Data] = []
    ret.append { argData in
        struct Params: Decodable {
            var _0: Int
            var _1: Int
        }
        let args = try decoder.decode(Params.self, from: argData)
        let ret = add(
            a: args._0,
            b: args._1
        )
        return try encoder.encode(ret)
    }
    return ret
}