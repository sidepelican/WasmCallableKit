# WasmCallableKit

Use Swift library in TypeScript through WebAssembly!

## Example

A Swift class 

```swift
public enum FenceOrientation: String, Codable {
    case horizontal
    case vertical
}

public struct FencePoint: Codable {
    public var x: Int
    public var y: Int
    public var orientation: FenceOrientation
}

public struct Board: Codable {
    ...
    public var fences: [FencePoint]
}

public class QuoridorGame {
    private var state: ...
    public init() {}

    public func putFence(position: FencePoint) throws { ... }
    public func currentBoard() -> Board { ... }
}
```

Can be used in TypeScript using WasmCallableKit.

```ts
const game = new QuoridorGame();
game.putFence({
    x: 1, y: 4, orientation: "horizontal"
});
const board = game.currentBoard();
board.fences.map(...);
```

## Setup

It is recommended to undestand SwiftWasm book deeply.
https://book.swiftwasm.org


🚧 WIP 🚧

You can see [example](https://github.com/sidepelican/WasmCallableKit/tree/main/example) project to understand basic usage.
