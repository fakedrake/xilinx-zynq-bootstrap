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
# - Gnu Toolchain: either ask for a path to the gnu tools
# - Rest of the code

ROOT_DIR=`pwd`
FILESYSTEM_ROOT=$ROOT_DIR/fs/

# Git repos
LINUX_GIT="git://git.xilinx.com/linux-xlnx.git"
BUSYBOX_GIT="git://git.busybox.net/busybox"

DROPBEAR_TAR_URL="http://matt.ucc.asn.au/dropbear/releases/dropbear-0.53.1.tar.gz"
DROPBEAR_TAR=`basename $DROPBEAR_TAR_URL`

BUILD_LINUX="true"
BUILD_DROPBEAR="true"
BUILD_BUSYBOX="true"
CODE_SOURCERY="none"

for i in $@; do
    case $i in
	"--no-linux") BUILD_LINUX="false";;
	"--no-dropbear") BUILD_dropbear="false";;
	"--no-busybox") BUILD_BUSYBOX="false";;
	"--gnu-tools")
	    shift
	    CODE_SOURCERY=$1;;
	"--help")
	    echo $HELP_MESSAGE
	    exit 0;;
    esac
done

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
if [ $BUILD_LINUX == "true" ]; then
    cd $ROOT_DIR
    get_project linux-xlnx $LINUX_GIT
    echo "#### Configuring the Linux Kernel ####"
    make ARCH=arm xilinx_zynq_defconfig
    echo "#### Building the linux kernel. ####"
    make ARCH=arm uImage
    echo "#### Building device tree ####"
    # scripts/dtc/dtc -I dts -O dtb -o
else
    echo "#### Skipping linux compilation. ####"
fi


# Filsystem/Busybox
if [ $BUILD_BUSYBOX == "true" ]; then
    cd $ROOT_DIR
    if [ ! -d $FILESYSTEM_ROOT ]; then
	mkdir $FILESYSTEM_ROOT
    fi

    get_project busybox $BUSYBOX_GIT

    echo "#### Building filesystem ####"
    make ARCH=arm CROSS_COMPILE=arm-xilinx-linux-gnueabi- CONFIG_PREFIX="$FILESYSTEM_ROOT" defconfig
    make ARCH=arm CROSS_COMPILE=arm-xilinx-linux-gnueabi- CONFIG_PREFIX="$FILESYSTEM_ROOT" install
else
    echo "#### Skipping busybox compilation ####"
fi
# Dropbear
if [ $BUILD_DROPBEAR == "true" ]; then
    cd $ROOT_DIR
    if [ ! -d $ROOT_DIR/dropbear/ ]; then
	mkdir $ROOT_DIR/dropbear
	echo "#### Downloading dropbear ####"
	wget $DROPBEAR_TAR_URL -O $ROOT_DIR/$DROPBEAR_TAR
	echo "Uncompressing: tar xfvz $ROOT_DIR/$DROPBEAR_TAR -C $ROOT_DIR/dropbear/"
	tar xfvz $ROOT_DIR/$DROPBEAR_TAR -C $ROOT_DIR/dropbear/
	rm $ROOT_DIR/$DROPBEAR_TAR
    fi

    echo "#### Building dropbear ####"
    cd $ROOT_DIR/dropbear/*/
    ./configure --prefix=$FILESYSTEM_ROOT --host=arm-xilinx-linux-gnueabi --disable-zlib CC=arm-xilinx-linux-gnueabi-gcc LDFLAGS="-Wl,--gc-sections" CFLAGS="-ffunction-sections -fdata-sections -Os"
    make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" MULTI=1 strip
    sudo make install;		# Thre are some `chgrp 0' here so we need sudo

# ln -s ../../sbin/dropbear $FILESYSTEM_ROOT/usr/bin/scp
else
    echo "#### Skipping dropbear compilation ####"
fi
