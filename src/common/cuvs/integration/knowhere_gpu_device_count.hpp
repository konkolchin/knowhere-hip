#pragma once

#ifdef KNOWHERE_WITH_HIP
#include "common/cuvs/integration/cuda_compat.hpp"
#define KNOWHERE_GPU_GET_DEVICE_COUNT(count) \
    do { \
        if (cudaGetDeviceCount(count) != cudaSuccess) { \
            *(count) = 0; \
        } \
    } while (0)
#else
#include <raft/util/cuda_rt_essentials.hpp>
#define KNOWHERE_GPU_GET_DEVICE_COUNT(count) RAFT_CUDA_TRY(cudaGetDeviceCount(count))
#endif
