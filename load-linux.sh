#!/bin/bash

if [ ! $SERIAL ]; then
    SERIAL=$( ls -d /dev/* | grep ttyUSB | head -1 )
    echo "Using serial: $SERIAL"
fi

if [ ! -c $SERIAL ]; then
    echo "No serial port found or the provided is invalid."
    exit 0
fi

if [ $1 = "stop" ]; then
    echo -e "connect arm hw\nstop" | xmd
    exit 1
fi

if [[ -d resources/ ]]; then
    cd resources/
    echo "In directory: `pwd`"
else
    echo "No `pwd`/resources/ dir found."
    exit 0
fi

# In order to have interactive output you may want to make a named pipe for this
echo "connect arm hw
source ps7_init.tcl
ps7_init
init_user
source stub.tcl
target 64
dow -data uImage            0x30000000
dow -data uramdisk.img.gz   0x20000000
dow -data zynq-zc702.dtb    0x2A000000
dow u-boot.elf
con
" | xmd && sleep 1 && sudo sh -c "echo -e \"\n\" > $SERIAL" && sleep 2 && sudo sh -c "echo \"bootm 0x30000000 0x20000000 0x2A000000\" > $SERIAL"


if [ "$1" = "minicom" ]; then
    echo "Running sudo minicom -D $SERIAL -b 115200"
fi
