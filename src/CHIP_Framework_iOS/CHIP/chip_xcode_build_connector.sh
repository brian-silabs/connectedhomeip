#!/usr/bin/env bash

here=$(cd "${0%/*}" && pwd)
me=${0##*/}

die() {
    echo "$me: *** ERROR: $*"
    exit 1
}

export >"$TEMP_DIR/env.sh"

set -ex

if [[ ${ARCHS} = arm64 ]]; then
    target=aarch64-apple-darwin
else
    target=$ARCHS-apple-darwin
fi

# these should be set by the Xcode project
CHIP_ROOT=${CHIP_ROOT:-"$SRCROOT/../../.."}
CHIP_ROOT=$(cd "$CHIP_ROOT" && pwd)
CHIP_PREFIX=${CHIP_PREFIX:-"$BUILT_PRODUCTS_DIR"}

[[ -d ${CHIP_ROOT} ]] || die Please set CHIP_ROOT to the location of the CHIP directory

# lots of environment variables passed by xcode to this script
if [[ ${CONFIGURATION} == Debug ]]; then
    configure_OPTIONS+=(--enable-debug)
    DEFINES+="-DDEBUG=1 -UNDEBUG"
else
    DEFINES+="-DNDEBUG=1 -UDEBUG"
fi

ARCH_FLAGS="-arch $ARCHS"
SYSROOT_FLAGS="-isysroot $SDK_DIR"
COMPILER_FLAGS="$ARCH_FLAGS $SYSROOT_FLAGS $DEFINES"

configure_OPTIONS+=(
    CPP="cc -E"
    CPPFLAGS="$COMPILER_FLAGS"
    CFLAGS="$COMPILER_FLAGS"
    CXXFLAGS="$COMPILER_FLAGS"
    OBJCFLAGS="$COMPILER_FLAGS"
    OBJCXXFLAGS="$COMPILER_FLAGS"
    LDFLAGS="$ARCH_FLAGS"
)

[[ ${PLATFORM_NAME} == iphoneos ]] && {
    configure_OPTIONS+=(--with-chip-project-includes="$CHIP_ROOT"/config/ios --with-logging-style=external)
}

[[ ${PLATFORM_NAME} == macosx ]] && configure_OPTIONS+=(--with-chip-project-includes=no)

configure_OPTIONS+=(
    --prefix="$CHIP_PREFIX"
    --target="$target"
    --host="$target"
    --disable-docs
    --disable-java
    --disable-python
    --disable-shared
    --disable-tests
    --disable-tools
    --with-chip-system-project-includes=no
    --with-chip-inet-project-includes=no
    --with-chip-ble-project-includes=no
    --with-chip-warm-project-includes=no
    --with-chip-device-project-includes=no
)

(
    cd "$TEMP_DIR"

    if [[ ! -x config.status || ${here}/${me} -nt config.status ]]; then
        "$CHIP_ROOT"/bootstrap-configure -C "${configure_OPTIONS[@]}"
    else
        for makefile_am in "$(find "$CHIP_ROOT" -name Makefile.am)"; do
            [[ ${makefile_am} -ot ${makefile_am/.am/.in} ]] || {
                "$CHIP_ROOT"/bootstrap -w make
                break
            }
        done
    fi

    make V=1 install
)