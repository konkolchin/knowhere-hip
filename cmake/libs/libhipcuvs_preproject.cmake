# Must run before project(): host g++ wrapper strips HIP-only flags.
find_program(_knowhere_real_cxx NAMES clang++ g++ c++ REQUIRED)
if(_knowhere_real_cxx MATCHES "clang\\+\\+$")
  set(CMAKE_CXX_COMPILER "${_knowhere_real_cxx}" CACHE FILEPATH "Knowhere HIP host compiler (clang++)" FORCE)
  message(STATUS "KNOWHERE WITH_HIP: pre-project CXX=${CMAKE_CXX_COMPILER}")
else()
  set(_knowhere_gxx_wrapper "${CMAKE_CURRENT_BINARY_DIR}/knowhere-g++-host.sh")
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
  message(STATUS "KNOWHERE WITH_HIP: pre-project CXX=${CMAKE_CXX_COMPILER}")
endif()
unset(_knowhere_real_cxx)
