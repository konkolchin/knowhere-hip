/**
 * CUDA runtime shims for knowhere cuVS on ROCm.
 * Uses hip_runtime_api.h (host API only). Knowhere .cc/.cu compile with
 * clang++ -x hip so raft/cuvs headers share one HIP compilation mode.
 */
#pragma once

#ifdef KNOWHERE_WITH_HIP
#include <hip/hip_runtime_api.h>
#include <hip/library_types.h>

#define cudaSuccess hipSuccess
#define cudaGetDeviceCount hipGetDeviceCount
#define cudaGetErrorString hipGetErrorString
#define cudaSetDevice hipSetDevice
#define cudaGetDevice hipGetDevice
#define cudaDeviceSynchronize hipDeviceSynchronize
#define cudaMalloc hipMalloc
#define cudaFree hipFree
#define cudaMemcpy hipMemcpy
#define cudaMemcpyAsync hipMemcpyAsync
#define cudaMemGetInfo hipMemGetInfo
typedef hipError_t cudaError_t;

// cuVS/raft code references CUDA_* hipDataType names; map to HIP equivalents.
#define CUDA_R_32F HIP_R_32F
#define CUDA_R_64F HIP_R_64F
#define CUDA_R_16F HIP_R_16F
#define CUDA_R_8I HIP_R_8I
#define CUDA_C_32F HIP_C_32F
#define CUDA_C_64F HIP_C_64F
#define CUDA_C_16F HIP_C_16F
#define CUDA_C_8I HIP_C_8I
#define CUDA_R_8U HIP_R_8U
#define CUDA_C_8U HIP_C_8U
#define CUDA_R_32I HIP_R_32I
#define CUDA_C_32I HIP_C_32I
#define CUDA_R_16BF HIP_R_16BF
#define CUDA_C_16BF HIP_C_16BF
#define CUDA_R_8F_E4M3 HIP_R_8F_E4M3
#define CUDA_R_8F_E5M2 HIP_R_8F_E5M2

#else
#include <cuda_runtime_api.h>
#include <cuda_fp16.h>
#endif
