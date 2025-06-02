#!/bin/bash

# ---------------------------------------------------------------------------------
# START: LAME-specific fixes for M1 Mac build (AM_ICONV and config.sub)
#
# These fixes address issues with autoreconf and configure on M1 Macs,
# specifically related to finding gettext macros and using outdated config files.
# ---------------------------------------------------------------------------------
echo "INFO: Applying special pre-configuration for lame on M1 Mac." 1>>"${BASEDIR}"/build.log

# 1. Fix AM_ICONV macro issue for autoreconf by ensuring gettext's m4 macros are found.
#    Temporarily modify ACLOCAL_FLAGS specifically for lame's autoreconf.
#    Need to find the correct path for gettext's aclocal macros on M1 Homebrew
ACLOCAL_GETTEXT_PATH="/opt/homebrew/opt/gettext/share/aclocal"
original_aclocal_flags="${ACLOCAL_FLAGS:-}" # Store original ACLOCAL_FLAGS, default to empty if unset

if [ -d "$ACLOCAL_GETTEXT_PATH" ]; then
    export ACLOCAL_FLAGS="-I $ACLOCAL_GETTEXT_PATH ${original_aclocal_flags}"
    echo "INFO: Prepended $ACLOCAL_GETTEXT_PATH to ACLOCAL_FLAGS for lame autoreconf." 1>>"${BASEDIR}"/build.log
else
    echo "WARNING: gettext aclocal directory not found at $ACLOCAL_GETTEXT_PATH. AM_ICONV might still be an issue for lame." 1>>"${BASEDIR}"/build.log
fi

# 2. Copy updated config.sub and config.guess to lame source directory
#    run_configure will do this again, but doing it before autoreconf is safer
CONFIG_SOURCE_DIR="${FFMPEG_KIT_TMPDIR}/source/config" # FFMPEG_KIT_TMPDIR is defined in variable.sh
LAME_SOURCE_DIR="${BASEDIR}/src/lame/lame" # Confirm this path based on your build.log

if [ -d "${LAME_SOURCE_DIR}" ] && [ -f "${CONFIG_SOURCE_DIR}/config.sub" ] && [ -f "${CONFIG_SOURCE_DIR}/config.guess" ]; then
    echo "INFO: Preemptively updating config.sub and config.guess for lame from ${CONFIG_SOURCE_DIR} to ${LAME_SOURCE_DIR}" 1>>"${BASEDIR}"/build.log
    cp -f "${CONFIG_SOURCE_DIR}/config.sub" "${LAME_SOURCE_DIR}/"
    cp -f "${CONFIG_SOURCE_DIR}/config.guess" "${LAME_SOURCE_DIR}/"
    chmod +x "${LAME_SOURCE_DIR}/config.sub" "${LAME_SOURCE_DIR}/config.guess"
else
    echo "WARNING: Could not preemptively update config.sub/config.guess for lame. GNU config files not found in ${CONFIG_SOURCE_DIR} or lame source dir not found at ${LAME_SOURCE_DIR}" 1>>"${BASEDIR}"/build.log
fi
# ---------------------------------------------------------------------------------
# END: LAME-specific fixes
# ---------------------------------------------------------------------------------

cd "${LIB_NAME}" || return 1

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_lame} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-sysroot="${SDK_PATH}" \
  --with-libiconv-prefix="${SDK_PATH}"/usr \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-maintainer-mode \
  --disable-frontend \
  --disable-efence \
  --disable-gtktest \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_libmp3lame_package_config "3.100" || return 1
