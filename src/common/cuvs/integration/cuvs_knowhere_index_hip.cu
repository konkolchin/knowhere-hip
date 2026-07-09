/**
 * HIP-only explicit instantiations for cuvs_knowhere_index.
 * Keep all template struct exports in one .cu so -fgpu-rdc/--hip-link does not
 * emit duplicate raft::convert_to_device_type device symbols across TUs.
 */
#include "common/cuvs/integration/cuvs_knowhere_index.cuh"
#include "common/cuvs/proto/cuvs_index_kind.hpp"

namespace cuvs_knowhere {

template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::brute_force, knowhere::fp32>;
template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::brute_force, knowhere::fp16>;

template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::ivf_flat, knowhere::fp32>;
template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::ivf_flat, knowhere::int8>;

template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::ivf_pq, knowhere::fp32>;
template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::ivf_pq, knowhere::fp16>;
template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::ivf_pq, knowhere::int8>;

template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::cagra, knowhere::fp32>;
template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::cagra, knowhere::fp16>;
template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::cagra, knowhere::int8>;
template struct cuvs_knowhere_index<cuvs_proto::cuvs_index_kind::cagra, knowhere::bin1>;

}  // namespace cuvs_knowhere
