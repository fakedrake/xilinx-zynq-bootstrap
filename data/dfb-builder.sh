#!/bin/bash
CONFIGURE_THINK2D="--with-gfxdrivers=think2d"

# BIN_PATH=~/x-tools/sparc-unknown-linux-gnu/bin/
# FD_TARGET=sparc-unknown-linux-gnu
FD_TARGET=arm-xilinx-linux-gnueabi

SOURCE_DIR=`pwd`
BUILD_DIR=.
BOOTSTRAP_ROOT=~/Projects/ThinkSilicon/xilinx-zynq-bootstrap/
HELP_MESSAGE="--no-think2d will build without think2d support."
JUST="none"
MAKE="make"

while [ $# -gt 0 ]; do
    case "$1" in
	"--make-cmd")
	    shift;
	    MAKE="$1";;
	"--bsroot")
	    shift;
	    BOOTSTRAP_ROOT="$1";;
	"--sysroot")
	    shift;
	    TARGET_FS="$1";;
	"--disable-debugging")
	    DEBUGGING="--disable-debug";;
	"--enable-debug")
	    DEBUGGING="--enable-debug";;
	"--disable-think2d")
	    CONFIGURE_THINK2D="";;
	"--enable-think2d")
	    CONFIGURE_THINK2D="--with-gfxdrivers=think2d";;
	"--just") shift; JUST="$JUST:$1";;
	"--make-args") shift; MAKE_ARGS="$1";;
	"--help")
	    echo "$HELP_MESSAGE"
	    exit 0;;
	*)
	    echo "Unrecognized option '$1'"
	    exit 1;;
    esac
    shift
done

TARGET_FS=$BOOTSTRAP_ROOT/fs
BIN_PATH=$BOOTSTRAP_ROOT/sources/gnu-tools-archive/GNU_Tools/bin
FD_TARGET_PATH=$BIN_PATH/$FD_TARGET

if [[ $JUST = "none" ]]; then
    JUST="all"
fi
echo "will compile: $JUST"

function fail {
    echo "[FAIL] $1"
    exit 2
}

function should_do {
    if test $(echo "$JUST" | grep "$1") || [[ "$JUST" = "all" ]]; then
	echo "Gonna $1 ($JUST)"
	return 0
    else
	echo "Skipping $1 ($JUST)"
	return 1
    fi
}

export CC=$FD_TARGET_PATH-gcc
export CCLD=$FD_TARGET_PATH-ld
export CXXLD=$FD_TARGET_PATH-ld
export CPP=$FD_TARGET_PATH-cpp
export CXX=$FD_TARGET_PATH-g++
export FDFLAGS="-L${TARGET_FS}/lib -L${TARGET_FS}/usr/lib -L${TARGET_FS}/usr/local/lib/"
export LIBS='-ljpeg -lz -lpng -lpthread'
export CPPFLAGS="-I${TARGET_FS}/usr/include -I${TARGET_FS}/include -I${TARGET_FS}/include/freetype2 -I${TARGET_FS}/usr/include"
export CXXFLAGS="${FDFLAGS} -Wl,--sysroot,$TARGET_FS --sysroot=$TARGET_FS ${CPPFLAGS} -g"
export CFLAGS="$FDFLAGS -g"
export LDFLAGS="$FDFLAGS --sysroot=$TARGET_FS"
export PKG_CONFIG_PATH="${TARGET_FS}/usr/lib/pkgconfig:${TARGET_FS}/lib/pkgconfig"
CONFIG_ARGS="--host=$FD_TARGET --with-sysroot=${TARGET_FS}  --prefix=${TARGET_FS} $CONFIGURE_THINK2D --with-inputdrivers=keyboard,ps2mouse --enable-static --enable-shared --enable-zlib --disable-devmem --disable-linotype --disable-x11 --disable-wayland --disable-mesa --disable-drmkms --disable-x11vdpau --disable-osx --disable-tiff --disable-webp --enable-fbdev $DEBUGGING --enable-dynload=yes --enable-freetype"

echo "Check my config."
for e in $CC $CPP $CXX ; do
    echo "Checking $e"
    [ -x $e ] || fail "Cant open $e"
done

[ -d $BUILD_DIR ] || ( mkdir $BUILD_DIR || fail "Making builddir" )

echo "CWD: $BUILD_DIR"
echo "Config params: $CONFIG_ARGS"

# if should_do "autogen"; then
#     $SOURCE_DIR/autogen.sh $CONFIG_ARGS || fail "Autogening"
# fi

cd $BUILD_DIR

if should_do "config"; then
    $SOURCE_DIR/configure $CONFIG_ARGS || fail "Configuring"
fi

if should_do "compile"; then
    $MAKE $MAKE_ARGS || fail "Compilation"
fi

if should_do "install"; then
    make install || fail "Installation"
fi
echo "Great success!"
