#ifndef TENSORFLOW_LITE_CORE_C_TYPES_H_
#define TENSORFLOW_LITE_CORE_C_TYPES_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ----------------------------------------------------------------------------
// TensorFlow Lite element type
// ----------------------------------------------------------------------------
typedef enum {
  kTfLiteNoType   = 0,
  kTfLiteFloat32  = 1,
  kTfLiteInt32    = 2,
  kTfLiteUInt8    = 3,
  kTfLiteInt64    = 4,
  kTfLiteString   = 5,
  kTfLiteBool     = 6,
  kTfLiteInt16    = 7,
  kTfLiteComplex64= 8,
  kTfLiteInt8     = 9,
  kTfLiteFloat16  = 10,
  kTfLiteFloat64  = 11,
  kTfLiteUInt64   = 12,
  kTfLiteResource = 13,
  kTfLiteVariant  = 14,
  kTfLiteUInt32   = 15,
  kTfLiteUInt16   = 16
} TfLiteType;

// ----------------------------------------------------------------------------
// Legacy quantization params (still referenced from common.h / c_api.h)
// ----------------------------------------------------------------------------
typedef struct {
  float   scale;
  int32_t zero_point;
} TfLiteQuantizationParams;

// ----------------------------------------------------------------------------
// Dimension encoding type (referenced by common.h as TfLiteDimensionType)
// ----------------------------------------------------------------------------
typedef enum TfLiteDimensionType {
  // Dense (regular) dimension.
  kTfLiteDimDense = 0,

  // Sparse CSR encoding of a dimension.
  kTfLiteDimSparseCSR = 1,

  // Sparse COO encoding of a dimension.
  kTfLiteDimSparseCOO = 2,
} TfLiteDimensionType;

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // TENSORFLOW_LITE_CORE_C_TYPES_H_
