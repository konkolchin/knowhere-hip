# Link prebuilt hipVS / hipRAFT (ROCm) instead of fetching cuVS via CPM + CUDAToolkit.

add_definitions(-DKNOWHERE_WITH_CUVS)
add_definitions(-DKNOWHERE_WITH_HIP)

# ROCm toolkit (hipRAFT raft-config.cmake calls find_dependency(HIP))
if(DEFINED ENV{ROCM_PATH})
  set(_knowhere_rocm_prefix "$ENV{ROCM_PATH}")
elseif(DEFINED ENV{HIP_PATH})
  set(_knowhere_rocm_prefix "$ENV{HIP_PATH}")
elseif(EXISTS "/opt/rocm")
  set(_knowhere_rocm_prefix "/opt/rocm")
else()
  message(FATAL_ERROR "WITH_HIP: set ROCM_PATH or install ROCm under /opt/rocm")
endif()
list(PREPEND CMAKE_PREFIX_PATH "${_knowhere_rocm_prefix}")
add_compile_definitions(THRUST_DEVICE_SYSTEM=THRUST_DEVICE_SYSTEM_HIP)
add_compile_definitions(THRUST_HOST_SYSTEM=THRUST_HOST_SYSTEM_CPP)
include_directories(SYSTEM "${_knowhere_rocm_prefix}/include/hipcub")

if(EXISTS "${_knowhere_rocm_prefix}/lib/cmake/hip")
  set(hip_DIR "${_knowhere_rocm_prefix}/lib/cmake/hip" CACHE PATH "ROCm hip cmake dir")
endif()

if(DEFINED ENV{INSTALL_PREFIX})
  list(PREPEND CMAKE_PREFIX_PATH "$ENV{INSTALL_PREFIX}")
endif()
if(DEFINED ENV{HIPVS_PREFIX})
  list(PREPEND CMAKE_PREFIX_PATH "$ENV{HIPVS_PREFIX}")
endif()

set(_knowhere_saved_cxx "${CMAKE_CXX_COMPILER}")
find_package(raft CONFIG REQUIRED)
find_package(rmm CONFIG REQUIRED)
find_package(cuvs CONFIG REQUIRED)
set(CMAKE_CXX_COMPILER "${_knowhere_saved_cxx}" CACHE FILEPATH "Host C++ compiler" FORCE)
unset(_knowhere_saved_cxx)

# libcuvs.so is device-built; faiss uses plain clang++, knowhere adds -x hip per-target.
foreach(_knowhere_flag_var IN ITEMS CMAKE_CXX_FLAGS CMAKE_C_FLAGS
    CMAKE_CXX_FLAGS_RELEASE CMAKE_C_FLAGS_RELEASE CMAKE_CXX_FLAGS_DEBUG
    CMAKE_C_FLAGS_DEBUG)
  if(DEFINED ${_knowhere_flag_var})
    string(REGEX REPLACE " *--offload-arch=[^ ]+" "" _knowhere_clean
                         "${${_knowhere_flag_var}}")
    string(REGEX REPLACE " *-x hip" "" _knowhere_clean "${_knowhere_clean}")
    string(REGEX REPLACE " *-xhip" "" _knowhere_clean "${_knowhere_clean}")
    string(STRIP "${_knowhere_clean}" _knowhere_clean)
    set(${_knowhere_flag_var} "${_knowhere_clean}" CACHE STRING "" FORCE)
  endif()
endforeach()
unset(_knowhere_flag_var)
unset(_knowhere_clean)

get_property(_knowhere_dir_opts DIRECTORY PROPERTY COMPILE_OPTIONS)
if(_knowhere_dir_opts)
  set(_knowhere_new_dir_opts)
  set(_knowhere_skip_next FALSE)
  foreach(_opt IN LISTS _knowhere_dir_opts)
    if(_knowhere_skip_next)
      set(_knowhere_skip_next FALSE)
      continue()
    endif()
    if(_opt STREQUAL "-x")
      set(_knowhere_skip_next TRUE)
      continue()
    endif()
    if(_opt MATCHES "^--offload-arch=" OR _opt STREQUAL "-xhip" OR _opt STREQUAL "hip")
      continue()
    endif()
    list(APPEND _knowhere_new_dir_opts "${_opt}")
  endforeach()
  unset(_knowhere_skip_next)
  set_property(DIRECTORY PROPERTY COMPILE_OPTIONS "${_knowhere_new_dir_opts}")
endif()
unset(_knowhere_dir_opts)
unset(_knowhere_new_dir_opts)
unset(_opt)

message(STATUS "KNOWHERE WITH_HIP: ROCm prefix ${_knowhere_rocm_prefix}")
message(STATUS "KNOWHERE WITH_HIP: hip from ${hip_DIR}")
message(STATUS "KNOWHERE WITH_HIP: raft from ${raft_DIR}")
message(STATUS "KNOWHERE WITH_HIP: rmm from ${rmm_DIR}")
message(STATUS "KNOWHERE WITH_HIP: cuvs from ${cuvs_DIR}")

find_program(_knowhere_real_cxx NAMES clang++ g++ c++ REQUIRED)
if(_knowhere_real_cxx MATCHES "clang\\+\\+$")
  set(CMAKE_CXX_COMPILER "${_knowhere_real_cxx}" CACHE FILEPATH "Knowhere HIP host compiler (clang++)" FORCE)
  message(STATUS "KNOWHERE WITH_HIP: host C++ via ${_knowhere_real_cxx} (knowhere target adds -x hip)")
else()
  set(_knowhere_gxx_wrapper "${CMAKE_BINARY_DIR}/knowhere-g++-host.sh")
  file(WRITE "${_knowhere_gxx_wrapper}" "#!/usr/bin/env bash
set -euo pipefail
_real_cxx=\"${_knowhere_real_cxx}\"
args=()
skip=0
for arg in \"\$@\"; do
  if [ \"\$skip\" -eq 1 ]; then
    skip=0
    continue
  fi
  case \"\$arg\" in
    -x) skip=1; continue ;;
    -xhip|--offload-arch=*| -offload-arch=*|--cuda-gpu-arch=*) continue ;;
  esac
  args+=(\"\$arg\")
done
exec \"\${_real_cxx}\" \"\${args[@]}\"
")
  file(CHMOD "${_knowhere_gxx_wrapper}" FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
  set(CMAKE_CXX_COMPILER "${_knowhere_gxx_wrapper}" CACHE FILEPATH "Knowhere host C++ via g++ (strips HIP flags)" FORCE)
  message(STATUS "KNOWHERE WITH_HIP: host C++ via ${_knowhere_gxx_wrapper}")
endif()
unset(_knowhere_real_cxx)
