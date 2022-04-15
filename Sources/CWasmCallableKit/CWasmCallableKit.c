#include "CWasmCallableKit.h"

int ck_send_impl(int functionID, int argumentBufferLength);

ck_wasm_export("ck_send")
int ck_send(int functionID, int argumentBufferLength) {
    return ck_send_impl(functionID, argumentBufferLength);
}
