#!/bin/sh

GDB=/home/fakedrake/Projects/ThinkSilicon/xilinx-zynq-bootstrap/sources/gnu-tools-archive/GNU_Tools/bin/arm-xilinx-linux-gnueabi-gdb

EXT_IP=$2
CMD_FILE=/tmp/commands.gdb
BOARD_IP=${EXT_IP:-192.168.1.107}
DFB_EX=$1
SYSROOT=/home/fakedrake/Projects/ThinkSilicon/xilinx-zynq-bootstrap/fs

echo "set sysroot $SYSROOT
file $SYSROOT/bin/$DFB_EX
target remote $BOARD_IP:1234" > $CMD_FILE

echo "SYSROOT: $SYSROOT
BOARD_IP: $BOARD_IP
DEBUG FILE: $(cat $CMD_FILE)"


$GDB --fullname -x $CMD_FILE
