#include "CWasmCallableKit.h"

int ck_send_impl(int functionID, int argumentBufferLength);
int ck_class_init_impl(int classID, int initilizerID, int argumentBufferLength);
int ck_class_send_impl(int instanceID, int functionID, int argumentBufferLength);

ck_wasm_export("ck_send")
int ck_send(int functionID, int argumentBufferLength) {
    return ck_send_impl(functionID, argumentBufferLength);
}

ck_wasm_export("ck_class_init")
int ck_class_init(int classID, int initilizerID, int argumentBufferLength) {
    return ck_class_init_impl(classID, initilizerID, argumentBufferLength);
}

ck_wasm_export("ck_class_send")
int ck_class_send(int instanceID, int functionID, int argumentBufferLength) {
    return ck_class_send_impl(instanceID, functionID, argumentBufferLength);
}
