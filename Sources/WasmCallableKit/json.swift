import ExtrasJSON

extension WasmCallableKit {
    @inlinable
    public static func encodeJSON(_ object: some Encodable) throws -> [UInt8] {
        return try XJSONEncoder().encode(object)
    }

    @inlinable
    public static func decodeJSON<T: Decodable>(_ type: T.Type, from data: some Collection<UInt8>) throws -> T {
        return try XJSONDecoder().decode(type, from: data)
    }
}
