# Copyright (C) 2019-2023 Zilliz. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License

cmake_minimum_required(VERSION 3.26.4 FATAL_ERROR)

# Early WITH_HIP before project(): Conan injects WITH_CUVS at project() time.
# Default OFF. Enable HIP only via explicit opt-in (never auto from INSTALL_PREFIX:
# that path also exists for CUDA cuVS and breaks NVIDIA CI / clean CUDA builds).
# Opt-in: -DWITH_HIP=ON  or  KNOWHERE_WITH_HIP=1|ON|TRUE|YES
if(NOT DEFINED WITH_HIP)
  set(_knowhere_want_hip OFF)
  if(DEFINED ENV{KNOWHERE_WITH_HIP})
    string(TOUPPER "$ENV{KNOWHERE_WITH_HIP}" _knowhere_hip_env)
    if(_knowhere_hip_env STREQUAL "1"
       OR _knowhere_hip_env STREQUAL "ON"
       OR _knowhere_hip_env STREQUAL "TRUE"
       OR _knowhere_hip_env STREQUAL "YES")
      set(_knowhere_want_hip ON)
    endif()
    unset(_knowhere_hip_env)
  endif()
  set(WITH_HIP ${_knowhere_want_hip} CACHE BOOL
      "Link prebuilt hipVS/hipRAFT (ROCm) instead of CUDA cuVS")
  message(STATUS "KNOWHERE: early WITH_HIP=${WITH_HIP} (explicit opt-in only; INSTALL_PREFIX ignored)")
  unset(_knowhere_want_hip)
endif()
if(WITH_HIP)
  include(cmake/libs/libhipcuvs_preproject.cmake)
endif()

project(knowhere CXX C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules/")
include(GNUInstallDirs)
include(ExternalProject)
include(cmake/utils/utils.cmake)
include(cmake/utils/compile_flags.cmake)
include(cmake/utils/platform_check.cmake)

knowhere_option(WITH_CUVS "Build with CUVS indexes" OFF)
knowhere_option(WITH_HIP "Link prebuilt hipVS/hipRAFT (ROCm) instead of CUDA cuVS" OFF)
message(STATUS "KNOWHERE: WITH_CUVS=${WITH_CUVS} WITH_HIP=${WITH_HIP}")
if(WITH_HIP AND NOT WITH_CUVS)
  message(FATAL_ERROR
    "WITH_HIP=ON but WITH_CUVS=OFF. Re-run: conan install .. -o with_cuvs=True ; cmake -DWITH_CUVS=ON")
endif()
if(WITH_CUVS AND WITH_HIP)
  include(cmake/libs/libhipcuvs.cmake)
elseif(WITH_CUVS)
  find_program(_knowhere_nvcc nvcc)
  if(NOT _knowhere_nvcc)
    message(FATAL_ERROR
      "WITH_CUVS=ON but nvcc not found. For AMD ROCm / hipVS builds set\n"
      "  export KNOWHERE_WITH_HIP=1\n"
      "  export INSTALL_PREFIX=$HOME/rocmds_check_gfx1100/install   # hipVS/hipRAFT only\n"
      "  cmake ... -DWITH_HIP=ON -DWITH_CUVS=ON\n"
      "CUDA builds: leave WITH_HIP=OFF (default). Do not set KNOWHERE_WITH_HIP.")
  endif()
  unset(_knowhere_nvcc)
  set(CMAKE_CUDA_ARCHITECTURES RAPIDS)
  include(cmake/libs/librapids.cmake)
  project(knowhere CXX C CUDA)
  include(cmake/libs/libcuvs.cmake)
endif()

knowhere_option(WITH_UT "Build with UT test" OFF)
knowhere_option(WITH_ASAN "Build with ASAN" OFF)
knowhere_option(WITH_DISKANN "Build with diskann index" OFF)
knowhere_option(WITH_BENCHMARK "Build with benchmark" OFF)
knowhere_option(WITH_COVERAGE "Build with coverage" OFF)
knowhere_option(WITH_CCACHE "Build with ccache" ON)
knowhere_option(WITH_PROFILER "Build with profiler" OFF)
knowhere_option(WITH_FAISS_TESTS "Build with Faiss unit tests" OFF)
knowhere_option(WITH_LIGHT "Build with light weight version" OFF)

# cardinal is an enterprise vector search engine and can only be enabled for
# cloud environment
knowhere_option(WITH_CARDINAL "Build with cardinal" OFF)
knowhere_option(CARDINAL_VERSION_FORCE_CHECKOUT
                "Force checkout cardinal version" OFF)
# this is needed for clang on ubuntu:20.04, otherwise the linked fails with
# 'undefined reference' error. fmt v9 was used by the time the error was
# encountered. clang on ubuntu:22.04 seems to be unaffected. gcc seems to be
# unaffected.
add_definitions(-DFMT_HEADER_ONLY)

# this is needed for clang on ubuntu:20.04, otherwise the linked fails with
# 'undefined reference' error. fmt v9 was used by the time the error was
# encountered. clang on ubuntu:22.04 seems to be unaffected. gcc seems to be
# unaffected.
add_definitions(-DFMT_HEADER_ONLY)

if(KNOWHERE_VERSION)
  message(STATUS "Building KNOWHERE version: ${KNOWHERE_VERSION}")
  add_definitions(-DKNOWHERE_VERSION=${KNOWHERE_VERSION})
endif()

if(WITH_CCACHE)
  find_program(CCACHE_FOUND ccache)
  if(CCACHE_FOUND)
    message(STATUS "Using ccache: ${CCACHE_FOUND}")
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ${CCACHE_FOUND})
    set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ${CCACHE_FOUND})
    # let ccache preserve C++ comments, because some of them may be meaningful
    # to the compiler
    set(ENV{CCACHE_COMMENTS} "1")
  endif()
endif()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_BINARY_DIR}/)

add_definitions(-DNOT_COMPILE_FOR_SWIG)

if(WITH_LIGHT)
  add_definitions(-DKNOWHERE_WITH_LIGHT)
endif()

include(cmake/utils/platform_check.cmake)
include(cmake/utils/compile_flags.cmake)

find_package(OpenMP REQUIRED)

include(cmake/libs/libfaiss.cmake)
include(cmake/libs/libhnsw.cmake)

include_directories(thirdparty/faiss)

find_package(Boost REQUIRED)
include_directories(${Boost_INCLUDE_DIRS})

find_package(folly REQUIRED)
include_directories(${folly_INCLUDE_DIRS})

find_package(nlohmann_json REQUIRED)
find_package(glog REQUIRED)
find_package(prometheus-cpp REQUIRED)
find_package(fmt REQUIRED)

if(NOT WITH_LIGHT)
  find_package(opentelemetry-cpp REQUIRED)
endif()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_OSX_DEPLOYMENT_TARGET
    "10.15"
    CACHE STRING "Minimum OS X deployment version" FORCE)

if(OpenMP_FOUND)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
  set(CMAKE_SHARED_LINKER_FLAGS
      "${CMAKE_SHARED_LINKER_FLAGS} ${OpenMP_EXE_LINKER_FLAGS}")
endif()

if(WITH_COVERAGE)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fprofile-arcs -ftest-coverage")
endif()

if(NOT WITH_LIGHT)
  knowhere_file_glob(
    GLOB_RECURSE
    KNOWHERE_SRCS
    src/common/*.cc
    src/index/*.cc
    src/cluster/*.cc
    src/io/*.cc
    src/common/*.cu
    src/index/*.cu
    src/io/*.cu)
endif()

if(WITH_LIGHT)
  knowhere_file_glob(
    GLOB_RECURSE
    KNOWHERE_SRCS
    src/common/*.cc
    src/index/ivf/ivf.cc
    src/index/index_node_data_mock_wrapper.cc
    src/index/index_static.cc
    src/index/index.cc
    src/index/interrupt.cc
    src/index/sparse/*.cc
    src/io/*.cc
    src/index/index_factory.cc)
  knowhere_file_glob(GLOB_RECURSE KNOWHERE_TRACER_SRCS src/common/tracer.cc)
  list(REMOVE_ITEM KNOWHERE_SRCS ${KNOWHERE_TRACER_SRCS})
endif()

set(KNOWHERE_LINKER_LIBS "")

if(WITH_CARDINAL)
  add_definitions(-DKNOWHERE_WITH_CARDINAL)
  include(cmake/libs/libcardinal.cmake)
endif()

if(WITH_DISKANN)
  add_definitions(-DKNOWHERE_WITH_DISKANN)
  include(cmake/libs/libdiskann.cmake)
else()
  knowhere_file_glob(GLOB_RECURSE KNOWHERE_DISKANN_SRCS src/index/diskann/*.cc)
  list(REMOVE_ITEM KNOWHERE_SRCS ${KNOWHERE_DISKANN_SRCS})
endif()

knowhere_file_glob(GLOB_RECURSE KNOWHERE_GPU_SRCS src/index/gpu/flat_gpu/*.cc
                   src/index/gpu/ivf_gpu/*.cc)
list(REMOVE_ITEM KNOWHERE_SRCS ${KNOWHERE_GPU_SRCS})

if(NOT WITH_CUVS)
  knowhere_file_glob(GLOB_RECURSE KNOWHERE_CUVS_SRCS src/common/cuvs/*.cu
                     src/common/cuvs/*.cc src/index/gpu_cuvs/*.cc)
  list(REMOVE_ITEM KNOWHERE_SRCS ${KNOWHERE_CUVS_SRCS})
elseif(WITH_HIP)
  knowhere_file_glob(GLOB_RECURSE KNOWHERE_CUVS_CU_SRCS src/common/cuvs/*.cu)
  if(KNOWHERE_CUVS_CU_SRCS)
    list(REMOVE_ITEM KNOWHERE_SRCS ${KNOWHERE_CUVS_CU_SRCS})
  endif()
  unset(KNOWHERE_CUVS_CU_SRCS)
endif()

include_directories(src)
include_directories(include)

list(APPEND KNOWHERE_LINKER_LIBS Boost::boost)
list(APPEND KNOWHERE_LINKER_LIBS faiss)
list(APPEND KNOWHERE_LINKER_LIBS glog::glog)
list(APPEND KNOWHERE_LINKER_LIBS nlohmann_json::nlohmann_json)
list(APPEND KNOWHERE_LINKER_LIBS prometheus-cpp::core prometheus-cpp::push)
list(APPEND KNOWHERE_LINKER_LIBS fmt::fmt-header-only)
list(APPEND KNOWHERE_LINKER_LIBS Folly::folly)
if(NOT WITH_LIGHT)
  list(APPEND KNOWHERE_LINKER_LIBS opentelemetry-cpp::opentelemetry_trace)
  list(APPEND KNOWHERE_LINKER_LIBS
       opentelemetry-cpp::opentelemetry_exporter_ostream_span)
  list(APPEND KNOWHERE_LINKER_LIBS
       opentelemetry-cpp::opentelemetry_exporter_jaeger_trace)
  list(APPEND KNOWHERE_LINKER_LIBS
       opentelemetry-cpp::opentelemetry_exporter_otlp_grpc)
  list(APPEND KNOWHERE_LINKER_LIBS
       opentelemetry-cpp::opentelemetry_exporter_otlp_http)
endif()

add_library(knowhere SHARED ${KNOWHERE_SRCS})
add_dependencies(knowhere ${KNOWHERE_LINKER_LIBS})
if(WITH_CUVS)
  if(NOT WITH_HIP)
    list(
      APPEND
      KNOWHERE_LINKER_LIBS
      raft::raft
      cuvs::cuvs
      CUDA::cublas
      CUDA::cusparse
      CUDA::cusolver)
  endif()
endif()
target_link_libraries(knowhere PUBLIC ${KNOWHERE_LINKER_LIBS})
if(WITH_CUVS AND WITH_HIP)
  foreach(_hip_dep raft::raft cuvs::cuvs rmm::rmm)
    get_target_property(_hip_inc ${_hip_dep} INTERFACE_INCLUDE_DIRECTORIES)
    if(_hip_inc)
      target_include_directories(knowhere PRIVATE ${_hip_inc})
    endif()
  endforeach()
  target_link_libraries(knowhere PUBLIC raft::raft cuvs::cuvs rmm::rmm)
  include(cmake/libs/knowhere_hip_link.cmake)
  knowhere_hip_link_rmm(knowhere)
endif()
unset(_hip_dep)
unset(_hip_inc)
target_include_directories(knowhere PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

if(WITH_UT)
  add_subdirectory(tests/ut)
endif()

if(WITH_BENCHMARK)
  add_subdirectory(benchmark)
endif()

if(WITH_FAISS_TESTS)
  add_subdirectory(tests/faiss)
endif()

if(WITH_CUVS AND WITH_HIP)
  include(cmake/libs/knowhere_hip_host_fixup.cmake)
endif()

install(TARGETS knowhere
        DESTINATION ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR})
install(DIRECTORY "${PROJECT_SOURCE_DIR}/include/knowhere"
        DESTINATION "${CMAKE_INSTALL_PREFIX}/include")
