#!/bin/bash

# We are already in the soxr source directory: ${BASEDIR}/src/soxr

mkdir -p "${BUILD_DIR}" || return 1
cd "${BUILD_DIR}" || return 1

# WORKAROUND TO USE A CUSTOM BUILD FILE (CMakeLists.txt)
# This copies your patched CMakeLists.txt into the soxr source directory
if [ -f "${BASEDIR}/tools/patch/cmake/soxr/CMakeLists.txt" ]; then
  overwrite_file "${BASEDIR}/tools/patch/cmake/soxr/CMakeLists.txt" "${BASEDIR}/src/${LIB_NAME}/CMakeLists.txt" || return 1
  echo "INFO: Applied patched CMakeLists.txt for soxr." 1>>"${BASEDIR}"/build.log
else
  echo "WARNING: Patched CMakeLists.txt for soxr not found at ${BASEDIR}/tools/patch/cmake/soxr/CMakeLists.txt. Using original." 1>>"${BASEDIR}"/build.log
fi

cmake -Wno-dev \
  -DCMAKE_VERBOSE_MAKEFILE=0 \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
  -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
  -DCMAKE_SYSROOT="${SDK_PATH}" \
  -DCMAKE_FIND_ROOT_PATH="${SDK_PATH}" \
  -DCMAKE_OSX_SYSROOT="$(get_sdk_name)" \
  -DCMAKE_OSX_ARCHITECTURES="$(get_cmake_osx_architectures)" \
  -DCMAKE_SYSTEM_NAME="${CMAKE_SYSTEM_NAME}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${LIB_INSTALL_PREFIX}" \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_LINKER="$LD" \
  -DCMAKE_AR="$(xcrun --sdk $(get_sdk_name) -f ar)" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DWITH_OPENMP=OFF \
  -DWITH_LSR_BINDINGS=OFF \
  "${BASEDIR}/src/${LIB_NAME}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# MANUALLY COPY PKG-CONFIG FILES
# The soxr.pc file is installed by 'make install' into the library's specific
# pkgconfig directory, e.g., ${LIB_INSTALL_PREFIX}/lib/pkgconfig/soxr.pc.
# This needs to be copied to the common ${INSTALL_PKG_CONFIG_DIR} for other libraries (like ffmpeg) to find it.
# The current directory at this point is ${BUILD_DIR}.
INSTALLED_SOXR_PC_PATH="${LIB_INSTALL_PREFIX}/lib/pkgconfig/soxr.pc"
if [ -f "${INSTALLED_SOXR_PC_PATH}" ]; then
  cp "${INSTALLED_SOXR_PC_PATH}" "${INSTALL_PKG_CONFIG_DIR}" || return 1
else
  echo "ERROR: Soxr pkg-config file not found after install at expected location: ${INSTALLED_SOXR_PC_PATH}" 1>>"${BASEDIR}"/build.log
  return 1
fi