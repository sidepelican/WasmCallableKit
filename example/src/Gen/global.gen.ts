import { SwiftRuntime } from "./SwiftRuntime.gen.js";

export type MySwiftLibExports = {
    add: (a: number, b: number) => number;
};

export const bindMySwiftLib = (swift: SwiftRuntime): MySwiftLibExports => {
    return {
        add: (a: number, b: number) => swift.callSwiftFunction(0, {
            _0: a,
            _1: b
        })
    };
};
