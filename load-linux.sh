#!/bin/bash

if [ $1 = "stop" ]; then
    echo -e "connect arm hw\nstop" | xmd
    exit 1
fi

if [[ -d "resources/" ]]; then
    cd resources/
else
    echo "No `pwd`/resources/ dir found."
    exit 0
fi

echo "connect arm hw
source ps7_init.tcl
ps7_init
init_user
source stub.tcl
target 64
dow -data uImage            0x30000000
dow -data uramdisk.img.gz   0x20000000
dow -data zynq-zc702.dtd    0x2A000000
dow u-boot.elf
con
" | xmd && echo -e "\n" > /dev/ttyUSB0 && echo "bootm 0x3000000 0x2000000 0x2A00000" > /dev/ttyUSB0


if [ $1 = "minicom" ]; then
    echo "Running sudo minicom -D /dev/ttyUSB0 -b 115200"
fi
