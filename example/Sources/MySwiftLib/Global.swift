import Foundation

public func add(a: Int, b: Int) -> Int {
    a + b
} 

public func yesterday(now: Date) -> Date {
    now.addingTimeInterval(-60 * 60 * 24 * 1)
}
