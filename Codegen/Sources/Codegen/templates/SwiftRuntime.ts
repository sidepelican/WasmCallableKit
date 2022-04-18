class Memory {
  readonly rawMemory: WebAssembly.Memory;
  constructor(exports: WebAssembly.Exports) {
      this.rawMemory = exports.memory as WebAssembly.Memory;
  }
  bytes(): Uint8Array {
    return new Uint8Array(this.rawMemory.buffer);
  }
  writeBytes(ptr: number, bytes: Uint8Array): void {
    this.bytes().set(bytes, ptr);
  }
}

type WasmCallableKitExported = {
  ck_send: (functionID: number, argumentBufferLength: number) => number,
}

export class SwiftRuntime {
  private _instance: WebAssembly.Instance | null = null;
  private _memory: Memory | null = null;

  private _nextArgument: Uint8Array | null = null;
  private _nextReturn: string | null = null;

  private textDecoder = new TextDecoder("utf-8");
  private textEncoder = new TextEncoder();

  setInstance(instance: WebAssembly.Instance) {
    this._instance = instance;
  }

  private get instance() {
    if (!this._instance)
        throw new Error("WebAssembly instance is not set yet");
    return this._instance;
  }

  private get memory() {
    if (!this._memory) {
        this._memory = new Memory(this.instance.exports);
    }
    return this._memory;
  }

  get callableKitImports(): WebAssembly.Imports {
    return {
      callable_kit: {
        receive_arg: (buffer: number) => {
          this.memory.writeBytes(buffer, this._nextArgument!!);
          this._nextArgument = null;
        },
        write_ret: (buffer: number, length: number) => {
          const bytes = this.memory.bytes().subarray(buffer, buffer + length);
          this._nextReturn = this.textDecoder.decode(bytes);
        },
      }
    };
  }

  callSwiftFunction(functionID: number, argument: any): any {
    const exports = this.instance.exports as WasmCallableKitExported;

    const argJsonString = JSON.stringify(argument) + '\0';
    const argBytes = this.textEncoder.encode(argJsonString);
    this._nextArgument = argBytes;
    const out = exports.ck_send(functionID, argBytes.length);
    const returnValue = this._nextReturn!!;
    this._nextReturn = null;

    switch (out) {
      case 0:
        return JSON.parse(returnValue);
      case 1:
        throw new Error(returnValue);
    }
  }
}
