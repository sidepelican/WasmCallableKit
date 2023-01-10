import { readFile } from 'node:fs/promises';
import { WASI } from 'wasi';
import { argv, env } from 'node:process';
import { SwiftRuntime } from './Gen/SwiftRuntime.gen.js';
import { bindMySwiftLib } from './Gen/global.gen.js';
import { Echo } from './Gen/Echo.gen.js';

// setup wasm instance
const wasi = new WASI({ args: argv, env });
const wasm = await WebAssembly.compile(
  await readFile(new URL('../.build/release/MySwiftLib.wasm', import.meta.url)),
);
const swift = new SwiftRuntime();
const instance = await WebAssembly.instantiate(wasm, {
  wasi_snapshot_preview1: wasi.wasiImport,
  ...swift.callableKitImports,
});
swift.setInstance(instance);
wasi.initialize(instance);
const { main } = instance.exports as any;
main();

const globals = bindMySwiftLib(swift);

// play swift!
console.log(globals.add(40, 2));

(function() {
  const foo = new Echo("TypeScript");
  console.log(foo.hello());
  foo.update({ kind: "name", name: { _0: "Swift" }});
  foo.sayHello();
  
  console.log(foo.tommorow(new Date()).toDateString());
})();
(global as any).gc();

console.log(globals.yesterday(new Date()).toDateString());
console.log(globals.normalize({ x: 2, y: 1 }));
