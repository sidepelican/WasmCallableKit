import { SwiftRuntime } from "./SwiftRuntime.gen.js";
import { Vec2 } from "./Types.gen.js";

export type MySwiftLibExports = {
    add: (a: number, b: number) => number;
    normalize: (vec: Vec2) => Vec2;
};

export const bindMySwiftLib = (swift: SwiftRuntime): MySwiftLibExports => {
    return {
        add: (a: number, b: number) => swift.send(0, {
            _0: a,
            _1: b
        }) as number,
        normalize: (vec: Vec2) => swift.send(1, {
            _0: vec
        }) as Vec2
    };
};
