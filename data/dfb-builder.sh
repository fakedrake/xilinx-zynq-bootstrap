CONFIGURE_THINK2D="--with-gfxdrivers=think2d"

# BIN_PATH=~/x-tools/sparc-unknown-linux-gnu/bin/
# FD_TARGET=sparc-unknown-linux-gnu
TARGET_FS="$HOME/Projects/ThinkSilicon/xilinx-zynq-bootstrap/fs/"
BIN_PATH=~/Projects/ThinkSilicon/xilinx-zynq-bootstrap/sources/gnu-tools-archive/GNU_Tools/bin/
FD_TARGET=arm-xilinx-linux-gnueabi

SOURCE_DIR=`pwd`
BUILD_DIR=.

HELP_MESSAGE="--no-think2d will build without think2d support."
JUST="none"

while [[ $# -gt 0 ]]; do
    case "$1" in
	"--sysroot")
	    shift;
	    TARGET_FS="$1";;
	"--disable-think2d")
	    CONFIGURE_THINK2D="";;
	"--enable-think2d")
	    CONFIGURE_THINK2D="--with-gfxdrivers=think2d";;
	"--just") shift; JUST="$JUST:$1";;
	"--make-args") MAKE_ARGS="$1";;
	"--help")
	    echo "$HELP_MESSAGE"
	    exit 0;;
	*)
	    echo "Unrecognized option '$1'"
	    exit 1;;
    esac
    shift
done
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
export CPP=$FD_TARGET_PATH-cpp
export CXX=$FD_TARGET_PATH-g++
export _LDFLAGS="-L${TARGET_FS}/lib -L${TARGET_FS}/usr/lib -L${TARGET_FS}/usr/local/lib/"
export LIBS='-ljpeg -lpthread -lz -lpng'
export CPPFLAGS="-I${TARGET_FS}/usr/include -I${TARGET_FS}/include -I${TARGET_FS}/usr/include"
export CFLAGS="$_LDFLAGS"
export PKG_CONFIG_PATH="${TARGET_FS}/usr/lib/pkgconfig"

CONFIG_ARGS="--host=$FD_TARGET --prefix=${TARGET_FS}/usr $CONFIGURE_THINK2D --with-inputdrivers=keyboard,ps2mouse --enable-static --enable-shared --enable-zlib --disable-devmem --disable-x11 --disable-wayland --with-sysroot=${TARGET_FS} --disable-mesa --disable-drmkms --disable-x11vdpau --disable-osx --disable-tiff --disable-webp"

echo "Check my config."
for e in $CC $CPP $CXX ; do
    echo "Checking $e"
    [ -x $e ] || fail "Cant open $e"
done

[ -d $BUILD_DIR ] || ( mkdir $BUILD_DIR || fail "Making builddir" )

echo "CWD: $BUILD_DIR"
echo "Config params: $CONFIG_ARGS"

if should_do "autogen"; then
    $SOURCE_DIR/autogen.sh $CONFIG_ARGS || fail "Autogening"
fi

cd $BUILD_DIR

if should_do "config"; then
    $SOURCE_DIR/configure $CONFIG_ARGS || fail "Configuring"
fi

if should_do "compile"; then
    make $MAKE_ARGS || fail "Compilation"
fi

if should_do "install"; then
    make install || fail "Installation"
fi
echo "Great success!"
