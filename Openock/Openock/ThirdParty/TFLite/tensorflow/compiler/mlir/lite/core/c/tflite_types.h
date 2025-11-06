#ifndef TENSORFLOW_COMPILER_MLIR_LITE_CORE_C_TFLITE_TYPES_H_
#define TENSORFLOW_COMPILER_MLIR_LITE_CORE_C_TFLITE_TYPES_H_

#ifdef __cplusplus
extern "C" {
#endif

/* Minimal stub for MLIR C types (we don't actually use MLIR). */
typedef struct MlirContext { void *ptr; } MlirContext;
typedef struct MlirType    { void *ptr; } MlirType;

#ifdef __cplusplus
}
#endif

#endif /* TENSORFLOW_COMPILER_MLIR_LITE_CORE_C_TFLITE_TYPES_H_ */
