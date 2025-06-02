#!/bin/bash

# FIX HARD-CODED PATHS
${SED_INLINE} 's|git://git.savannah.gnu.org|https://github.com/arthenica|g' "${BASEDIR}"/src/"${LIB_NAME}"/.gitmodules || return 1
ln -s -f $(which aclocal) ${BASEDIR}/.tmp/aclocal-1.16
ln -s -f $(which automake) ${BASEDIR}/.tmp/automake-1.16
PATH="${BASEDIR}/.tmp":$PATH

if [[ ! -d "${BASEDIR}"/src/"${LIB_NAME}"/gnulib ]]; then

  # INIT SUBMODULES
  ./gitsub.sh pull || return 1
  ./gitsub.sh checkout gnulib 485d983b7795548fb32b12fbe8370d40789e88c4 || return 1
fi

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null
echo -e "INFO: Aggressively cleaning build artifacts for ${LIB_NAME} and subdirectories.\n" >> "${BASEDIR}"/build.log 2>&1
find . -name "config.cache" -type f -delete >> "${BASEDIR}"/build.log 2>&1
rm -f config.status config.log Makefile >> "${BASEDIR}"/build.log 2>&1
if [ -d "libcharset" ]; then
  rm -f libcharset/config.status libcharset/config.log libcharset/Makefile libcharset/config.cache >> "${BASEDIR}"/build.log 2>&1
fi

cp -f "${FFMPEG_KIT_TMPDIR}"/source/config/config.guess "${BASEDIR}"/src/"${LIB_NAME}"/config.guess 1>>"${BASEDIR}"/build.log 2>&1 || return 1
cp -f "${FFMPEG_KIT_TMPDIR}"/source/config/config.sub "${BASEDIR}"/src/"${LIB_NAME}"/config.sub 1>>"${BASEDIR}"/build.log 2>&1 || return 1
cp -f "${FFMPEG_KIT_TMPDIR}"/source/config/config.guess "${BASEDIR}"/src/"${LIB_NAME}"/libcharset/config.guess 1>>"${BASEDIR}"/build.log 2>&1 || return 1
cp -f "${FFMPEG_KIT_TMPDIR}"/source/config/config.sub "${BASEDIR}"/src/"${LIB_NAME}"/libcharset/config.sub 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_libiconv} -eq 1 ]]; then
  if [[ -f ./autogen.sh ]]; then
    SAVED_LIBTOOLIZE="${LIBTOOLIZE}"
    SYSTEM_GLIBTOOLIZE_PATH=$(command -v glibtoolize)
    if [[ -n ${SYSTEM_GLIBTOOLIZE_PATH} ]]; then
      export LIBTOOLIZE="${SYSTEM_GLIBTOOLIZE_PATH}"
      echo -e "INFO: Setting LIBTOOLIZE=${LIBTOOLIZE} for ${LIB_NAME}'s autogen.sh call.\n" >> "${BASEDIR}"/build.log 2>&1
    else
      echo -e "INFO: glibtoolize not found. Proceeding without explicitly setting LIBTOOLIZE for ${LIB_NAME}'s autogen.sh.\n" >> "${BASEDIR}"/build.log 2>&1
    fi

    echo -e "INFO: Running ./autogen.sh for ${LIB_NAME}.\n" >> "${BASEDIR}"/build.log 2>&1
    ./autogen.sh >> "${BASEDIR}"/build.log 2>&1 || return 1

    # Restore original LIBTOOLIZE
    export LIBTOOLIZE="${SAVED_LIBTOOLIZE}"
  else
    autoreconf_library "${LIB_NAME}" >> "${BASEDIR}"/build.log 2>&1 || return 1
  fi
fi

./configure \
  --cache-file=/dev/null \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-sysroot="${ANDROID_SYSROOT}" \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-rpath \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_libiconv_package_config "1.17" || return 1
