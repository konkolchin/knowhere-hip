# Resolve RMM / rapids-logger symbols inside libknowhere.so (HIP cuVS path).
function(knowhere_hip_link_rmm _target)
  set(_knowhere_prefixes ${CMAKE_PREFIX_PATH})
  if(DEFINED ENV{INSTALL_PREFIX})
    set(_knowhere_install_prefix "$ENV{INSTALL_PREFIX}")
    if(_knowhere_install_prefix MATCHES "^~")
      if(DEFINED ENV{HOME})
        string(REPLACE "~" "$ENV{HOME}" _knowhere_install_prefix "${_knowhere_install_prefix}")
      endif()
    endif()
    get_filename_component(_knowhere_install_prefix "${_knowhere_install_prefix}" ABSOLUTE)
    list(PREPEND _knowhere_prefixes "${_knowhere_install_prefix}")
    unset(_knowhere_install_prefix)
  endif()
  list(REMOVE_DUPLICATES _knowhere_prefixes)

  set(_knowhere_librmm "")
  set(_knowhere_librapids_logger "")
  set(_knowhere_libraft "")
  foreach(_prefix IN LISTS _knowhere_prefixes)
    if(NOT _knowhere_librmm)
      find_library(_knowhere_librmm NAMES rmm PATHS "${_prefix}/lib" NO_DEFAULT_PATH)
    endif()
    if(NOT _knowhere_librapids_logger)
      find_library(_knowhere_librapids_logger NAMES rapids_logger PATHS "${_prefix}/lib"
                   NO_DEFAULT_PATH)
    endif()
    if(NOT _knowhere_libraft)
      find_library(_knowhere_libraft NAMES raft PATHS "${_prefix}/lib" NO_DEFAULT_PATH)
    endif()
  endforeach()
  if(_knowhere_librmm)
    target_link_libraries(${_target} PUBLIC "-Wl,--push-state" "-Wl,--no-as-needed"
                          "${_knowhere_librmm}" "-Wl,--pop-state")
    message(STATUS "KNOWHERE WITH_HIP: ${_target} linked ${_knowhere_librmm}")
  endif()
  if(_knowhere_librapids_logger)
    target_link_libraries(${_target} PUBLIC "-Wl,--push-state" "-Wl,--no-as-needed"
                          "${_knowhere_librapids_logger}" "-Wl,--pop-state")
    message(STATUS "KNOWHERE WITH_HIP: ${_target} linked ${_knowhere_librapids_logger}")
  endif()
  if(_knowhere_libraft)
    target_link_libraries(${_target} PUBLIC "-Wl,--push-state" "-Wl,--no-as-needed"
                          "${_knowhere_libraft}" "-Wl,--pop-state")
    message(STATUS "KNOWHERE WITH_HIP: ${_target} linked ${_knowhere_libraft}")
  endif()

  set(_knowhere_legacy_rmm_logger FALSE)
  foreach(_prefix IN LISTS _knowhere_prefixes)
    if(EXISTS "${_prefix}/include/rmm/logger_impl/logger.cpp")
      set(_knowhere_legacy_rmm_logger TRUE)
      break()
    endif()
  endforeach()

  if(NOT _knowhere_legacy_rmm_logger)
    if(NOT TARGET rmm::rmm_logger_impl AND DEFINED rmm_DIR)
      foreach(_targets_file IN ITEMS rmm-targets.cmake RMMTargets.cmake)
        if(EXISTS "${rmm_DIR}/${_targets_file}")
          include("${rmm_DIR}/${_targets_file}")
          message(STATUS "KNOWHERE WITH_HIP: included ${rmm_DIR}/${_targets_file}")
          break()
        endif()
      endforeach()
    endif()
    if(NOT TARGET raft::raft_logger_impl AND DEFINED raft_DIR)
      foreach(_targets_file IN ITEMS raft-targets.cmake RAFTTargets.cmake)
        if(EXISTS "${raft_DIR}/${_targets_file}")
          include("${raft_DIR}/${_targets_file}")
          message(STATUS "KNOWHERE WITH_HIP: included ${raft_DIR}/${_targets_file}")
          break()
        endif()
      endforeach()
    endif()
  else()
    message(STATUS
      "KNOWHERE WITH_HIP: legacy rmm logger.cpp at install prefix; skip logger_impl WHOLE_ARCHIVE targets")
  endif()

  set(_knowhere_logger_resolved FALSE)
  if(NOT _knowhere_legacy_rmm_logger)
    foreach(_logger_impl IN ITEMS rmm::rmm_logger_impl raft::raft_logger_impl)
      if(TARGET ${_logger_impl})
        target_link_libraries(${_target} PRIVATE "-Wl,--push-state"
                              "$<LINK_LIBRARY:WHOLE_ARCHIVE,${_logger_impl}>"
                              "-Wl,--pop-state")
        message(STATUS "KNOWHERE WITH_HIP: ${_target} WHOLE_ARCHIVE ${_logger_impl}")
        set(_knowhere_logger_resolved TRUE)
        break()
      endif()
    endforeach()
  endif()

  foreach(_rmm_dep IN ITEMS rmm::rmm_logger rapids_logger::rapids_logger raft::raft_logger)
    if(TARGET ${_rmm_dep})
      target_link_libraries(${_target} PRIVATE ${_rmm_dep})
      message(STATUS "KNOWHERE WITH_HIP: ${_target} linked ${_rmm_dep}")
    endif()
  endforeach()

  set(_knowhere_logger_cpp_files "")
  if(NOT _knowhere_logger_resolved)
    set(_knowhere_logger_candidates "include/rapids_logger/logger_impl/logger.cpp")
    if(_knowhere_legacy_rmm_logger)
      list(APPEND _knowhere_logger_candidates
           "include/rmm/logger_impl/logger.cpp"
           "include/raft/core/logger_impl/logger.cpp"
           "include/rmm/detail/logger_impl/logger.cpp")
    endif()
    foreach(_prefix IN LISTS _knowhere_prefixes)
      foreach(_candidate IN LISTS _knowhere_logger_candidates)
        if(EXISTS "${_prefix}/${_candidate}")
          list(APPEND _knowhere_logger_cpp_files "${_prefix}/${_candidate}")
        endif()
      endforeach()
    endforeach()
    list(REMOVE_DUPLICATES _knowhere_logger_cpp_files)
    if(_knowhere_logger_cpp_files)
      # knowhere itself is built with -x hip; logger.cpp must stay host C++ or
      # raft::logger / rmm::logger symbols never appear in libknowhere.so.
      set(_knowhere_logger_obj "knowhere_hip_loggers_${_target}")
      string(REPLACE "::" "_" _knowhere_logger_obj "${_knowhere_logger_obj}")
      if(NOT TARGET ${_knowhere_logger_obj})
        add_library(${_knowhere_logger_obj} STATIC ${_knowhere_logger_cpp_files})
        set_target_properties(${_knowhere_logger_obj} PROPERTIES
          POSITION_INDEPENDENT_CODE ON
          LINKER_LANGUAGE CXX)
        # Instantiate spdlog in this TU (matching Knowhere ABI). Avoids runtime
        # lookup into incomplete hipRAFT libspdlog.so.1.14 or ABI-mismatched apt.
        target_compile_definitions(${_knowhere_logger_obj} PRIVATE
          SPDLOG_HEADER_ONLY
          SPDLOG_FMT_EXTERNAL=0)
        foreach(_prefix IN LISTS _knowhere_prefixes)
          if(EXISTS "${_prefix}/include")
            target_include_directories(${_knowhere_logger_obj} PRIVATE "${_prefix}/include")
          endif()
        endforeach()
        # Conan / system spdlog headers only (implementations come from HEADER_ONLY).
        if(TARGET spdlog::spdlog_header_only)
          target_link_libraries(${_knowhere_logger_obj} PRIVATE spdlog::spdlog_header_only)
        elseif(TARGET spdlog::spdlog)
          get_target_property(_knowhere_spdlog_incs spdlog::spdlog INTERFACE_INCLUDE_DIRECTORIES)
          if(_knowhere_spdlog_incs)
            target_include_directories(${_knowhere_logger_obj} PRIVATE ${_knowhere_spdlog_incs})
          endif()
          unset(_knowhere_spdlog_incs)
        else()
          set(_knowhere_spdlog_inc "")
          foreach(_prefix IN LISTS _knowhere_prefixes)
            if(EXISTS "${_prefix}/include/spdlog/spdlog.h")
              set(_knowhere_spdlog_inc "${_prefix}/include")
              break()
            endif()
          endforeach()
          if(NOT _knowhere_spdlog_inc AND EXISTS "/usr/include/spdlog/spdlog.h")
            set(_knowhere_spdlog_inc "/usr/include")
          endif()
          if(_knowhere_spdlog_inc)
            target_include_directories(${_knowhere_logger_obj} PRIVATE "${_knowhere_spdlog_inc}")
            message(STATUS
              "KNOWHERE WITH_HIP: ${_knowhere_logger_obj} spdlog includes ${_knowhere_spdlog_inc}")
          else()
            message(WARNING
              "KNOWHERE WITH_HIP: spdlog headers not found for ${_knowhere_logger_obj}")
          endif()
          find_library(_knowhere_logger_libspdlog NAMES spdlog PATHS ${_knowhere_prefixes}
                       PATH_SUFFIXES lib NO_DEFAULT_PATH)
          if(NOT _knowhere_logger_libspdlog)
            find_library(_knowhere_logger_libspdlog NAMES spdlog)
          endif()
          if(_knowhere_logger_libspdlog)
            target_link_libraries(${_knowhere_logger_obj} PRIVATE
              "-Wl,--push-state" "-Wl,--no-as-needed"
              "${_knowhere_logger_libspdlog}" "-Wl,--pop-state")
            message(STATUS
              "KNOWHERE WITH_HIP: ${_knowhere_logger_obj} linked ${_knowhere_logger_libspdlog}")
          endif()
          unset(_knowhere_spdlog_inc)
          unset(_knowhere_logger_libspdlog)
        endif()
        foreach(_knowhere_logger_cpp IN LISTS _knowhere_logger_cpp_files)
          set_source_files_properties("${_knowhere_logger_cpp}" TARGET_DIRECTORY
            ${_knowhere_logger_obj} PROPERTIES LANGUAGE CXX)
          message(STATUS
            "KNOWHERE WITH_HIP: ${_target} host-compiles logger via ${_knowhere_logger_obj} from ${_knowhere_logger_cpp}")
        endforeach()
      endif()
      target_link_libraries(${_target} PRIVATE "-Wl,--push-state"
                            "$<LINK_LIBRARY:WHOLE_ARCHIVE,${_knowhere_logger_obj}>"
                            "-Wl,--pop-state")
      message(STATUS
        "KNOWHERE WITH_HIP: ${_target} WHOLE_ARCHIVE host logger lib ${_knowhere_logger_obj}")
      message(STATUS
        "KNOWHERE WITH_HIP: ${_knowhere_logger_obj} uses SPDLOG_HEADER_ONLY (embed set_pattern)")
      set(_knowhere_logger_resolved TRUE)
    elseif(_knowhere_legacy_rmm_logger)
      message(WARNING
        "KNOWHERE WITH_HIP: legacy logger headers at install prefix but no logger.cpp found")
    else()
      message(WARNING
        "KNOWHERE WITH_HIP: rmm logger impl not found; libknowhere may have undefined rmm::logger symbols")
    endif()
    unset(_knowhere_logger_candidates)
    unset(_knowhere_logger_obj)
  endif()

  if(_knowhere_logger_resolved OR _knowhere_librapids_logger OR _knowhere_librmm OR _knowhere_libraft)
    # hipRAFT install/lib/libspdlog.so is often incomplete (missing set_pattern etc).
    # Prefer apt static libspdlog.a via WHOLE_ARCHIVE so symbols live inside libknowhere.so.
    unset(_knowhere_libspdlog CACHE)
    unset(_knowhere_libspdlog_sys CACHE)
    unset(_knowhere_libspdlog_a CACHE)

    set(_knowhere_libspdlog_a "")
    foreach(_cand IN ITEMS
        "/usr/lib/x86_64-linux-gnu/libspdlog.a"
        "/usr/lib/libspdlog.a")
      if(NOT _knowhere_libspdlog_a AND EXISTS "${_cand}")
        set(_knowhere_libspdlog_a "${_cand}")
      endif()
    endforeach()
    # Only then consider prefix .a (may still be incomplete).
    if(NOT _knowhere_libspdlog_a)
      foreach(_prefix IN LISTS _knowhere_prefixes)
        if(EXISTS "${_prefix}/lib/libspdlog.a")
          set(_knowhere_libspdlog_a "${_prefix}/lib/libspdlog.a")
          break()
        endif()
      endforeach()
    endif()

    set(_knowhere_libspdlog_sys "")
    foreach(_cand IN ITEMS
        "/usr/lib/x86_64-linux-gnu/libspdlog.so"
        "/usr/lib/libspdlog.so")
      if(NOT _knowhere_libspdlog_sys AND EXISTS "${_cand}")
        set(_knowhere_libspdlog_sys "${_cand}")
      endif()
    endforeach()
    if(NOT _knowhere_libspdlog_sys)
      find_library(_knowhere_libspdlog_sys NAMES spdlog
                   PATHS /usr/lib/x86_64-linux-gnu /usr/lib
                   NO_DEFAULT_PATH)
    endif()
    # Avoid install/lib/libspdlog.so unless nothing else exists.
    if(NOT _knowhere_libspdlog_sys)
      find_library(_knowhere_libspdlog_sys NAMES spdlog PATHS ${_knowhere_prefixes}
                   PATH_SUFFIXES lib NO_DEFAULT_PATH)
    endif()

    if(_knowhere_libspdlog_a)
      # Embed spdlog into the shared lib (survives --hip-link + --no-allow-shlib-undefined).
      target_link_libraries(${_target} PRIVATE
        "-Wl,--whole-archive" "${_knowhere_libspdlog_a}" "-Wl,--no-whole-archive")
      # Also pass via link options so hip-clang does not drop the archive.
      target_link_options(${_target} PRIVATE
        "SHELL:-Wl,--whole-archive ${_knowhere_libspdlog_a} -Wl,--no-whole-archive")
      message(STATUS
        "KNOWHERE WITH_HIP: ${_target} WHOLE_ARCHIVE ${_knowhere_libspdlog_a}")
    elseif(_knowhere_libspdlog_sys)
      target_link_libraries(${_target} PUBLIC "${_knowhere_libspdlog_sys}")
      target_link_options(${_target} PRIVATE "SHELL:${_knowhere_libspdlog_sys}")
      message(STATUS "KNOWHERE WITH_HIP: ${_target} linked ${_knowhere_libspdlog_sys}")
    elseif(TARGET spdlog::spdlog)
      target_link_libraries(${_target} PUBLIC spdlog::spdlog)
      message(STATUS "KNOWHERE WITH_HIP: ${_target} linked spdlog::spdlog")
    else()
      message(WARNING
        "KNOWHERE WITH_HIP: libspdlog not found; install libspdlog-dev")
    endif()
    unset(_knowhere_libspdlog_sys)
    unset(_knowhere_libspdlog_a)
  endif()

  unset(_knowhere_logger_resolved)
  unset(_knowhere_legacy_rmm_logger)
  unset(_knowhere_prefixes)
  unset(_knowhere_librmm)
  unset(_knowhere_librapids_logger)
  unset(_knowhere_libraft)
  unset(_knowhere_logger_cpp_files)
  unset(_knowhere_logger_cpp)
  unset(_prefix)
  unset(_candidate)
  unset(_logger_impl)
  unset(_rmm_dep)
  unset(_targets_file)
  unset(_knowhere_legacy_logger_cpp)
endfunction()

function(knowhere_hip_link_ut_logger_deps _target)
  if(NOT WITH_HIP OR NOT WITH_CUVS)
    return()
  endif()

  set(_knowhere_prefixes ${CMAKE_PREFIX_PATH})
  if(DEFINED ENV{INSTALL_PREFIX})
    set(_knowhere_install_prefix "$ENV{INSTALL_PREFIX}")
    if(_knowhere_install_prefix MATCHES "^~")
      if(DEFINED ENV{HOME})
        string(REPLACE "~" "$ENV{HOME}" _knowhere_install_prefix "${_knowhere_install_prefix}")
      endif()
    endif()
    get_filename_component(_knowhere_install_prefix "${_knowhere_install_prefix}" ABSOLUTE)
    list(PREPEND _knowhere_prefixes "${_knowhere_install_prefix}")
    unset(_knowhere_install_prefix)
  endif()
  list(REMOVE_DUPLICATES _knowhere_prefixes)

  # Prefer apt libspdlog over incomplete install/lib/libspdlog.so.
  if(EXISTS "/usr/lib/x86_64-linux-gnu/libspdlog.so")
    target_link_libraries(${_target} PRIVATE "/usr/lib/x86_64-linux-gnu/libspdlog.so")
    message(STATUS
      "KNOWHERE WITH_HIP: ${_target} linked /usr/lib/x86_64-linux-gnu/libspdlog.so")
  elseif(EXISTS "/usr/lib/x86_64-linux-gnu/libspdlog.a")
    target_link_libraries(${_target} PRIVATE
      "-Wl,--whole-archive" "/usr/lib/x86_64-linux-gnu/libspdlog.a" "-Wl,--no-whole-archive")
  endif()

  foreach(_lib IN ITEMS raft rapids_logger rmm)
    set(_knowhere_lib "")
    foreach(_prefix IN LISTS _knowhere_prefixes)
      if(NOT _knowhere_lib)
        find_library(_knowhere_lib NAMES "${_lib}" PATHS "${_prefix}/lib" NO_DEFAULT_PATH)
      endif()
    endforeach()
    if(_knowhere_lib)
      target_link_libraries(${_target} PRIVATE "${_knowhere_lib}")
      message(STATUS "KNOWHERE WITH_HIP: ${_target} linked ${_knowhere_lib}")
    endif()
    unset(_knowhere_lib)
  endforeach()

  unset(_knowhere_prefixes)
endfunction()
