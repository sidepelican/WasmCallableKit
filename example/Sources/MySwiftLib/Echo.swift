import Foundation

public class Echo {
    private var name: String
    public init(name: String) {
        self.name = name
    }

    public func hello() -> String {
        "Hello, \(name)!"
    }

    public enum UpdateKind {
        case name(String)
    }

    public func update(_ update: UpdateKind) {
        switch update {
        case .name(let name):
            self.name = name
        }
    }

    public func tommorow(now: Date) -> Date {
        now.addingTimeInterval(60 * 60 * 24 * 1)
    }
}
