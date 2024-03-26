#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

public struct Vec2: Codable {
    public var x: Float
    public var y: Float
}

public func normalize(_ vec: Vec2) -> Vec2 {
    let l = hypot(vec.x, vec.y)
    return .init(x: vec.x / l,
                 y: vec.y / l)
}
