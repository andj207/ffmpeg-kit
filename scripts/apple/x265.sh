#!/bin/bash

# SET BUILD OPTIONS
case ${ARCH} in
armv7 | armv7s)
  ASM_OPTIONS="-DENABLE_ASSEMBLY=1 -DCROSS_COMPILE_ARM=1"
  ;;
arm64*)
  ASM_OPTIONS="-DENABLE_ASSEMBLY=0 -DCROSS_COMPILE_ARM=1"
  ;;
x86-64-mac-catalyst)
  ASM_OPTIONS="-DENABLE_ASSEMBLY=0 -DCROSS_COMPILE_ARM=0"
  ;;
i386)
  ASM_OPTIONS="-DENABLE_ASSEMBLY=0 -DCROSS_COMPILE_ARM=0"
  ;;
*)
  ASM_OPTIONS="-DENABLE_ASSEMBLY=1 -DCROSS_COMPILE_ARM=0"
  ;;
esac

mkdir -p "${BUILD_DIR}" || return 1
cd "${BUILD_DIR}" || return 1

# fix x86 and x86_64 assembly
${SED_INLINE} 's/win64/macho64 -DPREFIX/g' ${BASEDIR}/src/x265/source/cmake/CMakeASM_NASMInformation.cmake
${SED_INLINE} 's/win/macho/g' ${BASEDIR}/src/x265/source/cmake/CMakeASM_NASMInformation.cmake

# fixing constant shift
${SED_INLINE} 's/lsr 16/lsr #16/g' ${BASEDIR}/src/x265/source/common/arm/blockcopy8.S

# fixing leading underscores
${SED_INLINE} 's/function x265_/function _x265_/g' ${BASEDIR}/src/x265/source/common/arm/*.S
${SED_INLINE} 's/ x265_/ _x265_/g' ${BASEDIR}/src/x265/source/common/arm/pixel-util.S

# fixing relocation errors
${SED_INLINE} 's/sad12_mask:/sad12_mask_bytes:/g' ${BASEDIR}/src/x265/source/common/arm/sad-a.S
${SED_INLINE} 's/g_lumaFilter:/g_lumaFilter_bytes:/g' ${BASEDIR}/src/x265/source/common/arm/ipfilter8.S
${SED_INLINE} 's/g_chromaFilter:/g_chromaFilter_bytes:/g' ${BASEDIR}/src/x265/source/common/arm/ipfilter8.S
${SED_INLINE} 's/\.text/.equ sad12_mask, .-sad12_mask_bytes\
\
.text/g' ${BASEDIR}/src/x265/source/common/arm/sad-a.S
${SED_INLINE} 's/\.text/.equ g_lumaFilter, .-g_lumaFilter_bytes\
.equ g_chromaFilter, .-g_chromaFilter_bytes\
\
.text/g' ${BASEDIR}/src/x265/source/common/arm/ipfilter8.S

# WORKAROUND TO USE A CUSTOM BUILD FILE
overwrite_file "${BASEDIR}"/tools/patch/cmake/x265/CMakeLists.txt "${BASEDIR}"/src/"${LIB_NAME}"/source/CMakeLists.txt || return 1

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
  -DCMAKE_AS="$AS" \
  -DSTATIC_LINK_CRT=1 \
  -DENABLE_PIC=1 \
  -DENABLE_CLI=0 \
  -DHIGH_BIT_DEPTH=1 \
  ${ASM_OPTIONS} \
  -DCMAKE_SYSTEM_PROCESSOR="$(get_target_cpu)" \
  -DENABLE_SHARED=0 "${BASEDIR}"/src/"${LIB_NAME}"/source || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# MANUALLY COPY PKG-CONFIG FILES
# The x265.pc file is installed by 'make install' into the library's specific
# pkgconfig directory, e.g., ${LIB_INSTALL_PREFIX}/lib/pkgconfig/x265.pc.
# This needs to be copied to the common ${INSTALL_PKG_CONFIG_DIR} for other libraries (like ffmpeg) to find it.
INSTALLED_X265_PC_PATH="${LIB_INSTALL_PREFIX}/lib/pkgconfig/x265.pc"

echo "DEBUG: Checking for installed x265.pc at ${INSTALLED_X265_PC_PATH}" 1>>"${BASEDIR}"/build.log

if [ -f "${INSTALLED_X265_PC_PATH}" ]; then
  echo "INFO: Found x265.pc at installed location: ${INSTALLED_X265_PC_PATH}. Copying to ${INSTALL_PKG_CONFIG_DIR}." 1>>"${BASEDIR}"/build.log
  cp "${INSTALLED_X265_PC_PATH}" "${INSTALL_PKG_CONFIG_DIR}" || return 1
else
  echo "ERROR: x265 pkg-config file not found after install at expected location: ${INSTALLED_X265_PC_PATH}" 1>>"${BASEDIR}"/build.log
  echo "ERROR: This is unexpected as 'make install' should have placed it there." 1>>"${BASEDIR}"/build.log
  echo "ERROR: Please check the x265 build and install logs for errors." 1>>"${BASEDIR}"/build.log
  # Optionally, you can try the fallback, but it's less reliable:
  # BUILD_DIR_X265_PC_PATH="${BUILD_DIR}/x265.pc"
  # if [ -f "${BUILD_DIR_X265_PC_PATH}" ]; then
  #   echo "WARN: Falling back to copying x265.pc from build directory: ${BUILD_DIR_X265_PC_PATH}" 1>>"${BASEDIR}"/build.log
  #   cp "${BUILD_DIR_X265_PC_PATH}" "${INSTALL_PKG_CONFIG_DIR}" || return 1
  # else
  #   echo "ERROR: x265.pc also not found in build directory ${BUILD_DIR_X265_PC_PATH}." 1>>"${BASEDIR}"/build.log
  #   return 1
  # fi
  return 1 # Make it a hard error if the installed .pc file is not found
fi

