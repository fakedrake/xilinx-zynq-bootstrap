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

HELP_MESSAGE=`cat README.txt`

ROOT_DIR=`pwd`
RESOURCES_DIR=$ROOT_DIR/resources
FILESYSTEM_ROOT=$ROOT_DIR/fs/

if [ ! -d $RESOURCES_DIR ]; then
    mkdir $RESOURCES_DIR
fi

# Git repos
LINUX_GIT="git://git.xilinx.com/linux-xlnx.git"
BUSYBOX_GIT="git://git.busybox.net/busybox"
UBOOT_GIT="git://git.xilinx.com/u-boot-xlnx.git"

# Zip archive
GNU_TOOLS_FTP="ftp://83.212.100.45/Code/zynq_gnu_tools.zip"
SDK_SCRIPTS_FTP="ftp://83.212.100.45/Code/xilinx_scripts/"

# Dropbear download info
DROPBEAR_TAR_URL="http://matt.ucc.asn.au/dropbear/releases/dropbear-0.53.1.tar.gz"
DROPBEAR_TAR=`basename $DROPBEAR_TAR_URL`

DSS_KEY_FTP="ftp://83.212.100.45/Code/xilinx_scripts/dropbear_dss_host_key"
RSA_KEY_FTP="ftp://83.212.100.45/Code/xilinx_scripts/dropbear_rsa_host_key"

# What not to build
BUILD_LINUX="true"
BUILD_DROPBEAR="true"
BUILD_BUSYBOX="true"
BUILD_UBOOT="true"
BUILD_RAMDISK="true"
GET_GNU_TOOLS="true"
GET_SDK_SCRIPTS="true"
ONLY_PART="all"

# Device trees
DTS_TREE=$ROOT_DIR/linux-xlnx/arch/arm/boot/dts/zynq-zc702.dts
DTB_TREE=$RESOURCES_DIR/`basename $DTS_TREE | tr '.dts' '.dtb'`


GNU_TOOLS="`pwd`/GNU_Tools/"

for i in $@; do
    case $i in
	"--no-linux") BUILD_LINUX="false";;
	"--no-dropbear") BUILD_DROPBEAR="false";;
	"--no-busybox") BUILD_BUSYBOX="false";;
	"--no-ramdisk") BUILD_RAMDISK="false";;
	"--no-u-boot") BUILD_UBOOT="false";;
	"--no-gnu-tools") GET_GNU_TOOLS="false";;
	"--no-sdk-scripts") GET_SDK_SCRIPTS="false";;
	"--gnu-tools")
	    shift
	    GNU_TOOLS=`realpath $1`
	    ;;
	"--only")
	    shift
	    ONLY_PART=$1
	    ;;
	"--help")
	    echo "$HELP_MESSAGE"
	    exit 0;;

    esac
done

# Dependent vars
GNU_TOOLS_UTILS=$GNU_TOOLS/arm-xilinx-linux-gnueabi/
GNU_TOOLS_BIN=$GNU_TOOLS/bin
GNU_TOOLS_HOST=arm-xilinx-linux-gnueabi
GNU_TOOLS_PREFIX=$GNU_TOOLS_BIN/arm-xilinx-linux-gnueabi-
export CROSS_COMPILE=$GNU_TOOLS_PREFIX
export PATH=$PATH:$GNU_TOOLS_BIN


function print_info {
    echo "[INFO] $1"
}

function get_project {
    if [ ! -d $1 ]; then
	print_info "Cloning $1: $2"
	git clone $2 $1
	cd "$1"
    else
	print_info "Updating $1"
	cd "$1"
	git pull
    fi
}

function fail {
    echo "[ERROR] $1 failed!"
    exit 0
}

# Gnu toolchain
if ([ ! -d $GNU_TOOLS ] && [ $GET_GNU_TOOLS = "true" ]) && ([ $ONLY_PART = "all" ] || [ $ONLY_PART = "gnu-tools" ]); then
    print_info "Downloading Xilinx configured GNU tools: $GNU_TOOLS_FTP"
    print_info "(You may use --gnu-tools <dirname> to use your own gnu-tools)"

    wget $GNU_TOOLS_FTP || (print_info "Failed to pull from ftp."; exit 0)
    print_info "Extracting GNU tools."
    unzip `basename $GNU_TOOLS_FTP`
fi

 # U-Boot
if [ $BUILD_UBOOT = "true" ] && ([ $ONLY_PART = "all" ] || [ $ONLY_PART = "uboot" ]); then
    if [ ! -e $RESOURCES_DIR/u-boot.elf ]; then
	cd $ROOT_DIR
	get_project u-boot-xlnx $UBOOT_GIT
	print_info "Configuring uboot."
	make zynq_zc70x_config CC="${GNU_TOOLS_PREFIX}gcc" || fail "u-boot configuration"
	print_info "Building uboot."
	# This is quite ugly but I am open to suggestions.
	make  OBJCOPY="${GNU_TOOLS_PREFIX}objcopy" LD="${GNU_TOOLS_PREFIX}ld" AR="${GNU_TOOLS_PREFIX}ar" CC="${GNU_TOOLS_PREFIX}gcc" || fail "u-boot building"

	cp u-boot $RESOURCES_DIR/u-boot.elf
    else
	print_info "Uboot elf exists. Remove $RESOURCES_DIR/u-boot.elf to rebuild."
    fi
    PATH=$PATH:$ROOT_DIR/u-boot-xlnx/tools
fi

# Linux
if [ $BUILD_LINUX = "true" ] && ([ $ONLY_PART = "all" ] || [ $ONLY_PART = "linux" ]); then
    if [ ! -e $RESOURCES_DIR/uImage ]; then
	cd $ROOT_DIR
	get_project linux-xlnx $LINUX_GIT
	print_info "Configuring the Linux Kernel, \$PATH=$PATH"
	make ARCH=arm xilinx_zynq_defconfig || fail "linux configuration"
	print_info "Building the linux kernel."
	make ARCH=arm uImage || fail "linux building"
	print_info "Building device tree"
	scripts/dtc/dtc -I dts -O dtb -o  $DTB_TREE $DTS_TREE
	cp $ROOT_DIR/linux-xlnx/arch/arm/boot/uImage $RESOURCES_DIR
    else
	print_info "Linux uImage exists. Remove $RESOURCES_DIR/uImage to rebuild."
    fi
else
    print_info "Skipping linux compilation."
fi


# Filsystem/Busybox
if [ $BUILD_BUSYBOX = "true" ] && ([ $ONLY_PART = "all" ] || [ $ONLY_PART = "busybox" ]); then
    cd $ROOT_DIR
    if [ ! -d $FILESYSTEM_ROOT ]; then
	mkdir $FILESYSTEM_ROOT
    fi

    get_project busybox $BUSYBOX_GIT

    print_info "Building filesystem"
    make ARCH=arm CROSS_COMPILE=$GNU_TOOLS_PREFIX CONFIG_PREFIX="$FILESYSTEM_ROOT" defconfig || fail "busybox configuration"
    make ARCH=arm CROSS_COMPILE=$GNU_TOOLS_PREFIX CONFIG_PREFIX="$FILESYSTEM_ROOT" install || fail "busybox building"

    cd $FILESYSTEM_ROOT
    mkdir lib
    cp $GNU_TOOLS_UTILS/libc/lib/* lib -r

    # Strip libs of symbols
    $GNU_TOOLS_BIN/arm-xilinx-linux-gnueabi-strip lib/*

    # Some supplied tools
    cp $GNU_TOOLS_UTILS/libc/sbin/* sbin/ -r
    cp $GNU_TOOLS_UTILS/libc/usr/bin/* usr/bin/ -r

    # Create fs structure
    mkdir dev etc etc/dropbear etc/init.d mnt opt proc root sys tmp var var/log var/www

    # Specific files
    echo "LABEL=/     /           tmpfs   defaults        0 0
none        /dev/pts    devpts  gid=5,mode=620  0 0
none        /proc       proc    defaults        0 0
none        /sys        sysfs   defaults        0 0
none        /tmp        tmpfs   defaults        0 0" > etc/fstab

    echo "
# /bin/ash
#
# Start an askfirst shell on the serial ports

ttyPS0::respawn:-/bin/ash

# What to do when restarting the init process

::restart:/sbin/init

# What to do before rebooting

::shutdown:/bin/umount -a -r" > etc/inittab

    echo 'root:$1$qC.CEbjC$SVJyqm.IG.gkElhaeM.FD0:0:0:root:/root:/bin/sh' > etc/passwd

    echo '#!/bin/sh

echo "Starting rcS..."

echo "++ Mounting filesystem"
mount -t proc none /proc
mount -t sysfs none /sys
mount -t tmpfs none /tmp

echo "++ Setting up mdev"

echo /sbin/mdev > /proc/sys/kernel/hotplug
mdev -s

mkdir -p /dev/pts
mkdir -p /dev/i2c
mount -t devpts devpts /dev/pts

echo "++ Starting telnet daemon"
telnetd -l /bin/sh

echo "++ Starting http daemon"
httpd -h /var/www

echo "++ Starting ftp daemon"
tcpsvd 0:21 ftpd ftpd -w /&

echo "++ Starting dropbear (ssh) daemon"
dropbear

echo "Creating RSA keys"
[ ! -f /etc/dropbear/dropbear_dss_host_key ] && dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
[ ! -f /etc/dropbear/dropbear_rsa_host_key ] && dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key

echo "rcS Complete"' > etc/init.d/rcS

    chmod 755 etc/init.d/rcS

    print_info "Do not fear, we are about to 'sudo chown root:root etc/init.d/rcS'..."
    sudo chown root:root etc/init.d/rcS
else
    print_info "Skipping busybox compilation and filesystem creation."
fi

# Dropbear
if [ $BUILD_DROPBEAR = "true" ] && ([ $ONLY_PART = "all" ] || [ $ONLY_PART = "dropbear" ]); then
    cd $ROOT_DIR
    if [ ! -d $ROOT_DIR/dropbear/ ]; then
	mkdir $ROOT_DIR/dropbear
	print_info "Downloading dropbear"
	wget $DROPBEAR_TAR_URL -O $ROOT_DIR/$DROPBEAR_TAR
	echo "Uncompressing: tar xfvz $ROOT_DIR/$DROPBEAR_TAR -C $ROOT_DIR/dropbear/"
	tar xfvz $ROOT_DIR/$DROPBEAR_TAR -C $ROOT_DIR/dropbear/
	rm $ROOT_DIR/$DROPBEAR_TAR
    fi

    print_info "Building dropbear"
    cd $ROOT_DIR/dropbear/*/
    ./configure --prefix=$FILESYSTEM_ROOT --host=$GNU_TOOLS_HOST --disable-zlib  LDFLAGS="-Wl,--gc-sections" CFLAGS="-ffunction-sections -fdata-sections -Os" || fail "dropbear configuration"
    make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" MULTI=1 strip || fail "dropbear building"

    print_info "We are about to 'sudo make install', the reason we need chown is that we will chgrp 0 to some files."
    sudo make install || fail "dropbear installation"		# Thre are some 'chgrp 0' here so we need sudo

    ln -s ../../sbin/dropbear $FILESYSTEM_ROOT/usr/bin/scp

    print_info "Downloading keys"
    wget $DSS_KEY_FTP -O $FILESYSTEM_ROOT/etc/dropbear/ || print_info "Downloading dss key from $DSS_KEY_FTP failed but no biggie, it will be generated."
    wget $RSA_KEY_FTP -O $FILESYSTEM_ROOT/etc/dropbear/ || print_info "Downloading rsa key from $RSA_KEY_FTP failed but no biggie, it will be generated."
else
    print_info "Skipping dropbear compilation"
fi

# Build ramdisk image
if [ $BUILD_RAMDISK = "true" ] && ([ $ONLY_PART = "all" ] || [ $ONLY_PART = "ramdisk" ]); then
    cd $RESOURCES_DIR
    # Build ramdisk image
    print_info "Ramdisk blocks: $((`du -b ../fs| grep 'fs$'|awk '{print $1}'`/1024)) (we use 8193)"
    dd if=/dev/zero of=ramdisk.img bs=1024 count=8193
    mke2fs -F ramdisk.img -L "ramdisk" -b 1024 -m 0
    tune2fs ramdisk.img -i 0
    chmod 777 ramdisk.img

    mkdir ramdisk
    sudo mount -o loop ramdisk.img ramdisk/
    sudo cp -R $FILESYSTEM_ROOT/* ramdisk
    sudo umount ramdisk/

    gzip -9 ramdisk.img

    # U-Boot ready image
    $ROOT_DIR/u-boot-xlnx/tools/mkimage -A arm -T ramdisk -C gzip -d $RESOURCES_DIR/ramdisk.img.gz $RESOURCES_DIR/uramdisk.img.gz
#   $ROOT_DIR/u-boot-xlnx/tools/mkimage -A arm –T ramdisk –C gzip –d $RESOURCES_DIR/uramdisk.img.gz $RESOURCES_DIR/ramdisk.img.gz # this was copy-pasted from the wiki. It doesn't work due to the dashes.
else
    print_info "Skipping ramdisk creation."
fi

# SDK scripts
if [ $GET_SDK_SCRIPTS = "true" ] && ([ $ONLY_PART = "all" ] || [ $ONLY_PART = "sdk-scripts" ]); then
    print_info "Pulling sdk scripts from $SDK_SCRIPTS_FTP"
    cd $RESOURCES_DIR
    [ ! -f ps7_init.tcl ] && (wget $SDK_SCRIPTS_FTP/ps7_init.tcl || (print_info "Failed to pull $SDK_SCRIPTS_FTP/ps7_init.tcl"; exit 0))
    [ ! -f stub.tcl ] && (wget $SDK_SCRIPTS_FTP/stub.tcl || (print_info "Failed to pull $SDK_SCRIPTS_FTP/ps7_init.tcl"; exit 0))
fi

print_info "Great success."
