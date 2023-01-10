#ifndef __CWasmCallableKit_h__
#define __CWasmCallableKit_h__

#include <stdio.h>

#if __wasm32__
#define ck_wasm_import(MODULE, NAME) __attribute__((__import_module__(MODULE),__import_name__(NAME)))
#define ck_wasm_export(NAME) __attribute__((export_name(NAME)))
#else
#define ck_wasm_import(MODULE, NAME)
#define ck_wasm_export(NAME)
#endif

ck_wasm_import("callable_kit", "receive_arg")
extern void receive_arg(unsigned char* buf);

ck_wasm_import("callable_kit", "write_ret")
extern void write_ret(const unsigned char* buf, int length);

#endif /* __CWasmCallableKit_h__ */
