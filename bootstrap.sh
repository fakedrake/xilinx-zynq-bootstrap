#!/bin/bash
#
# Copyright (C) 2013 by Chris "fakedrake" Perivolaropoulos
# <darksaga2006@gmail.co,>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# TODO:
# - Turn this into a makefile
# - Gnu Toolchain
# - Rest of the code

ROOT_DIR=`pwd`
FILESYSTEM_ROOT=$ROOT_DIR/fs/

# Git repos
LINUX_GIT="git://git.xilinx.com/linux-xlnx.git"
BUSYBOX_GIT="git://git.busybox.net/busybox"

DROPBEAR_TAR_URL="http://matt.ucc.asn.au/dropbear/releases/dropbear-0.53.1.tar.gz"
DROPBEAR_TAR=`basename $DROPBEAR_TAR_URL`


function get_project {
    if [ ! -d $1 ]; then
	echo "#### Cloning $1: $2 ###"
	git clone $2 $1
	cd "$1"
    else
	echo "#### Updating $1 ####"
	cd "$1"
	git pull
    fi
}

# Gnu toolchain

# Linux
cd $ROOT_DIR
get_project linux-xlnx $LINUX_GIT
echo "#### Configuring the Linux Kernel ####"
make ARCH=arm xilinx_zynq_defconfig
echo "#### Building the linux kernel. ####"
make ARCH=arm uImage

echo "#### Building device tree ####"
# scripts/dtc/dtc -I dts -O dtb -o


# Filsystem/Busybox
cd $ROOT_DIR
if [ ! -d $FILESYSTEM_ROOT ]; then
    mkdir $FILESYSTEM_ROOT
fi

get_project busybox $BUSYBOX_GIT

echo "#### Building filesystem ####"
make ARCH=arm CROSS_COMPILE=arm-xilinx-linux-gnueabi- CONFIG_PREFIX="$FILESYSTEM_ROOT" defconfig
make ARCH=arm CROSS_COMPILE=arm-xilinx-linux-gnueabi- CONFIG_PREFIX="$FILESYSTEM_ROOT" install

# Dropbear
cd $ROOT_DIR
if [ ! -d $ROOT_DIR/dropbear/ ]; then
    echo "#### Downloading dropbear ####"
    wget $DROPBEAR_TAR_URL
    tar xfvz $DROPBEAR_TAR $ROOT_DIR/dropbear/
    rm $ROOT_DIR/$DROPBEAR_TAR
fi

echo "#### Building dropbear ####"
cd $ROOT_DIR/dropbear/
./configure --prefix=$FILESYSTEM_ROOT --host=arm-xilinx-linux-gnueabi --disable-zlib CC=arm-xilinx-linux-gnueabi-gcc LDFLAGS="-Wl,--gc-sections" CFLAGS="-ffunction-sections -fdata-sections -Os"
make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" MULTI=1 strip
make install

# ln -s ../../sbin/dropbear $FILESYSTEM_ROOT/usr/bin/scp
