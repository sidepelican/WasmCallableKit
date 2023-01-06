import Fo

public class Echo {
    private let name: String
    public init(name: String) {
        self.name = name
    }

    public func hello() -> String {
        "Hello, \(name)!"
    }
}
