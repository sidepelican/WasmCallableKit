#include "CWasmCallableKit.h"

#ifndef __wasm32__
void receive_arg(unsigned char* buf) {};
void write_ret(const unsigned char* buf, int length) {};
#endif
