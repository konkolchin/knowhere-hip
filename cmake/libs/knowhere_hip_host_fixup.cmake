# Final pass: strip HIP-only flags from host C++ after all targets exist.

function(knowhere_strip_offload_opts _in _out_var)
  set(_out)
  set(_skip_next FALSE)
  foreach(_item IN LISTS ${_in})
    if(_skip_next)
      set(_skip_next FALSE)
      continue()
    endif()
    if(_item STREQUAL "-x")
      set(_skip_next TRUE)
      continue()
    endif()
    if(_item MATCHES "offload-arch" OR _item MATCHES "cuda-gpu-arch" OR _item STREQUAL "-xhip" OR _item STREQUAL "hip")
      continue()
    endif()
    list(APPEND _out "${_item}")
  endforeach()
  set(${_out_var} "${_out}" PARENT_SCOPE)
endfunction()

foreach(_flag_var IN ITEMS CMAKE_CXX_FLAGS CMAKE_C_FLAGS CMAKE_CXX_FLAGS_RELEASE
    CMAKE_C_FLAGS_RELEASE CMAKE_CXX_FLAGS_DEBUG CMAKE_C_FLAGS_DEBUG)
  if(DEFINED ${_flag_var})
    set(_clean "${${_flag_var}}")
    while(_clean MATCHES "(^| )-?-offload-arch=[^ ]+")
      string(REGEX REPLACE "(^| )-?-offload-arch=[^ ]+" "\\1" _clean "${_clean}")
      string(STRIP "${_clean}" _clean)
    endwhile()
    string(REGEX REPLACE " *-x hip" "" _clean "${_clean}")
    string(REGEX REPLACE " *-xhip" "" _clean "${_clean}")
    string(STRIP "${_clean}" _clean)
    set(${_flag_var} "${_clean}" CACHE STRING "" FORCE)
  endif()
endforeach()

get_property(_dir_opts DIRECTORY PROPERTY COMPILE_OPTIONS)
if(_dir_opts)
  knowhere_strip_offload_opts(_dir_opts _dir_clean)
  set_property(DIRECTORY PROPERTY COMPILE_OPTIONS "${_dir_clean}")
endif()


message(STATUS "KNOWHERE WITH_HIP: faiss uses plain host C++; knowhere keeps raft HIP flags (clang++)")


if(DEFINED ENV{ROCM_PATH})
  set(_knowhere_fixup_rocm "$ENV{ROCM_PATH}")
elseif(DEFINED ENV{HIP_PATH})
  set(_knowhere_fixup_rocm "$ENV{HIP_PATH}")
elseif(EXISTS "/opt/rocm")
  set(_knowhere_fixup_rocm "/opt/rocm")
endif()
if(TARGET knowhere AND _knowhere_fixup_rocm)

  find_package(OpenMP REQUIRED)
  if(OpenMP_CXX_FLAGS)
    target_compile_options(knowhere PRIVATE "SHELL:${OpenMP_CXX_FLAGS}")
  endif()
  if(TARGET OpenMP::OpenMP_CXX)
    target_link_libraries(knowhere PUBLIC OpenMP::OpenMP_CXX)
  elseif(OpenMP_CXX_LIBRARIES)
    target_link_libraries(knowhere PUBLIC ${OpenMP_CXX_LIBRARIES})
  else()
    target_link_libraries(knowhere PUBLIC gomp)
  endif()
  target_compile_definitions(knowhere PRIVATE
    KNOWHERE_WITH_HIP
    THRUST_DEVICE_SYSTEM=THRUST_DEVICE_SYSTEM_HIP
    THRUST_HOST_SYSTEM=THRUST_HOST_SYSTEM_CPP
    _LIBCUDACXX_ALLOW_UNSUPPORTED_ARCHITECTURE)
  if(EXISTS "${_knowhere_fixup_rocm}/include/hipcub")
    target_include_directories(knowhere SYSTEM PRIVATE "${_knowhere_fixup_rocm}/include/hipcub")
  endif()
  message(STATUS "KNOWHERE WITH_HIP: Thrust/HIP + hipcub from ${_knowhere_fixup_rocm}")
  set(_knowhere_gfx "gfx1100")
  if(DEFINED ENV{HIP_ARCH})
    set(_knowhere_gfx "$ENV{HIP_ARCH}")
  endif()
  foreach(_prop COMPILE_OPTIONS INTERFACE_COMPILE_OPTIONS)
    get_target_property(_opts knowhere ${_prop})
    if(_opts)
      knowhere_strip_offload_opts(_opts _opts_clean)
      set_target_properties(knowhere PROPERTIES ${_prop} "${_opts_clean}")
    endif()
  endforeach()
  target_compile_options(knowhere PRIVATE "SHELL:-x hip --offload-arch=${_knowhere_gfx}")
  message(STATUS "KNOWHERE WITH_HIP: knowhere SHELL:-x hip --offload-arch=${_knowhere_gfx}")

  # Single .cu TU: -fgpu-rdc + --hip-link deduplicates raft device templates once.
  set(_knowhere_cuvs_cu
    "${CMAKE_CURRENT_SOURCE_DIR}/src/common/cuvs/integration/cuvs_knowhere_index_hip.cu")
  if(_knowhere_cuvs_cu)
    add_library(knowhere_cuvs_hip STATIC ${_knowhere_cuvs_cu})
    set_source_files_properties(${_knowhere_cuvs_cu} PROPERTIES LANGUAGE CXX)
    set_target_properties(knowhere_cuvs_hip PROPERTIES
      POSITION_INDEPENDENT_CODE ON
      LINKER_LANGUAGE CXX)
    target_compile_definitions(knowhere_cuvs_hip PRIVATE
      KNOWHERE_WITH_CUVS
      KNOWHERE_WITH_HIP
      THRUST_DEVICE_SYSTEM=THRUST_DEVICE_SYSTEM_HIP
      THRUST_HOST_SYSTEM=THRUST_HOST_SYSTEM_CPP
      _LIBCUDACXX_ALLOW_UNSUPPORTED_ARCHITECTURE)
    target_include_directories(knowhere_cuvs_hip PRIVATE
      "${CMAKE_CURRENT_SOURCE_DIR}/src"
      "${CMAKE_CURRENT_SOURCE_DIR}/include")
    if(EXISTS "${_knowhere_fixup_rocm}/include/hipcub")
      target_include_directories(knowhere_cuvs_hip SYSTEM PRIVATE
        "${_knowhere_fixup_rocm}/include/hipcub")
    endif()
    foreach(_hip_dep raft::raft cuvs::cuvs rmm::rmm)
      if(TARGET ${_hip_dep})
        get_target_property(_hip_inc ${_hip_dep} INTERFACE_INCLUDE_DIRECTORIES)
        if(_hip_inc)
          target_include_directories(knowhere_cuvs_hip PRIVATE ${_hip_inc})
        endif()
        target_link_libraries(knowhere_cuvs_hip PUBLIC ${_hip_dep})
      endif()
    endforeach()
    target_compile_options(knowhere_cuvs_hip PRIVATE
      "SHELL:-x hip --offload-arch=${_knowhere_gfx} -fgpu-rdc")
    target_link_libraries(knowhere PRIVATE
      "$<LINK_LIBRARY:WHOLE_ARCHIVE,knowhere_cuvs_hip>")
    target_link_options(knowhere PRIVATE "SHELL:--hip-link -fgpu-rdc")
    message(STATUS "KNOWHERE WITH_HIP: knowhere_cuvs_hip WHOLE_ARCHIVE (${_knowhere_cuvs_cu})")
  endif()
  unset(_knowhere_cuvs_cu)
  unset(_hip_dep)
  unset(_hip_inc)
  unset(_rmm_dep)
  unset(_knowhere_gfx)
endif()
unset(_knowhere_fixup_rocm)
