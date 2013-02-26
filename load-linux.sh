#!/bin/bash

function fail {
    echo "[ERROR] Error while $1"
    exit 0
}

RUN_MINICOM='false'
BOOT_LINUX='true'
RESET_DEVICE='false'
read -d '' HELP_MESSAGE <<EOF

This program loads your software to the board. I assume the current
directory is at the root of the project and bootstrap.sh was run
successfully.

OPTIONS:
--reset		Reset the device

--no-minicom	Do not run minicom connected to the serial.

--with-minicom	Run minicom at the end. [default]

--no-boot-linux	Do not boot linux, only u-boot.

--boot-linux	Make u-boot boot linux [default]

--serial DEVICE	Override serial device autodetection.

--which-serial	Show which serial we would use. The script is not run.

--xmd FILE	Override xmd executable autodetection.

--which-xmd	Show which xmd we would use. The script is not run.

--xmd-shell 	Run an xmd shell. Try to have readline with rlwrap.  It is
		recommended to run xmd from here anyway as it will try
		to correct your xmd executable aswell

EOF

XILINX_BIN_PATH=/opt/Xilinx/14.4/ISE_DS/EDK/bin/lin
XILINX_BIN_PATH64=${XILINX_BIN_PATH}64

# Get the xmd executable
if [ -d $XILINX_BIN_PATH64 ] && [ $(uname -p) = 'x86_64' ]; then
    XMD=$XILINX_BIN_PATH64/xmd
elif [ -d $XILINX_BIN_PATH ]; then
    XMD=$XILINX_BIN_PATH/xmd
else
    # Try the PATH
    XMD=$(which xmd)
fi

if [ ! $SERIAL ]; then
    SERIAL=$( ls -d /dev/* | grep ttyUSB | head -1 )
    echo "Using serial: $SERIAL"
fi


while [[ $# -gt 0 ]]; do
    case $1 in
	'--reset')
	    RESET_DEVICE='true';;
	'--no-minicom')
	    RUN_MINICOM='false';;
	'--with-minicom')
	    RUN_MINICOM='true';;
	'--boot-linux')
	    BOOT_LINUX='true';;
	'--no-boot-linux')
	    BOOT_LINUX='false';;
	'--serial')
	    shift
	    [ $1 ] && [ -c $1 ] && SERIAL="$1" || echo "Invalid serial device: $1";;
	'--xmd')
	    shift
	    [ $1 ] && [ -x $1 ] && XMD='$1' || echo "Invalid xmd: $1";;
	'--which-serial')
	    echo "$SERIAL"
	    exit 1;;
	'--which-xmd')
	    echo "$XMD"
	    exit 1;;
	'--xmd-shell')
	    XMD_SHELL='true';;
	'--help')
	    echo "$HELP_MESSAGE"
	    exit 1;;
	*)
	    echo "Unrecognized option \"$1\"";
	    exit 0;;
    esac
    shift
done


if [ ! $XMD ] || [ ! -x $XMD ]; then
    echo "I couldnt locate xmd at $XMD or is not executable"
    exit 0
fi
echo "XMD executable: $XMD"

if  [ "$XMD_SHELL" = 'true' ]; then
    if [ $(command -v rlwrap) ]; then
	echo "Using rlwrap for history and completion, you are welcome."
	rlwrap $XMD
	exit 1
    else
	echo "rlwrap not found, running plain xmd"
	$XMD
	exit 1
    fi
fi

if [ ! $SERIAL ] || [ ! -c $SERIAL ]; then
    echo "No serial port found or the provided is invalid."
    exit 0
fi

[ ! -w $SERIAL ] && echo "Serial $SERIAL is not writeable." && exit 0

if [ "$RESET_DEVICE" = 'true' ]; then
    echo "echo \"Device reset commanded by $(whoami)!\"" > $SERIAL
    echo -e "connect arm hw\nrst" | $XMD
    exit
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
" | $XMD || fail "sending images to device"
sleep 1
echo -e "\n" > $SERIAL

if [ "$BOOT_LINUX" = 'true' ]; then
    sleep 2
    echo "bootm 0x30000000 0x20000000 0x2A000000" > $SERIAL
fi

if [ "$RUN_MINICOM" = "true" ]; then

    MINICOM_CMD="minicom -D $SERIAL -b 115200"
    echo "Running $MINICOM_CMD"
    $MINICOM_CMD
fi
