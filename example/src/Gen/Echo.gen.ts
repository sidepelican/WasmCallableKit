import { SwiftRuntime, globalRuntime } from "./SwiftRuntime.gen.js";
import { TagRecord } from "./common.gen.js";

export class Echo {
    #runtime: SwiftRuntime;
    #id: number;

    constructor(name: string, runtime?: SwiftRuntime) {
        this.#runtime = runtime ?? globalRuntime;
        this.#id = this.#runtime.classInit(0, 0, {
            _0: name
        });
        this.#runtime.autorelease(this, this.#id);
    }

    hello(): string {
        return this.#runtime.classSend(this.#id, 0, {}) as string;
    }

    sayHello(): void {
        return this.#runtime.classSend(this.#id, 1, {}) as void;
    }

    update(update: Echo_UpdateKind): void {
        return this.#runtime.classSend(this.#id, 2, {
            _0: update
        }) as void;
    }
}

export type Echo_UpdateKind = {
    kind: "name";
    name: {
        _0: string;
    };
} & TagRecord<"Echo_UpdateKind">;

export type Echo_UpdateKind_JSON = {
    name: {
        _0: string;
    };
};

export function Echo_UpdateKind_decode(json: Echo_UpdateKind_JSON): Echo_UpdateKind {
    if ("name" in json) {
        const j = json.name;
        const _0 = j._0;
        return {
            kind: "name",
            name: {
                _0: _0
            }
        };
    } else {
        throw new Error("unknown kind");
    }
}
