#!/bin/bash

# export LD_LIBRARY_PATH=/tools/Xilinx/ISE-SE_Viv-SE/14.4/ISE_DS/EDK/lib/lin64:/tools/Xilinx/ISE-SE_Viv-SE/14.4/ISE_DS/ISE/lib/lin64
# export XILINX=/tools/Xilinx/ISE-SE_Viv-SE/14.4/ISE_DS/ISE
# export XILINX_EDK=/tools/Xilinx/ISE-SE_Viv-SE/14.4/ISE_DS/EDK
# export XILINXD_LICENSE_FILE=/tools/licenses/Xilinx_Zynq-7000_EPP_ZC702_IMAGEON_gray.lic

# XLNX=/tools/Xilinx/ISE-SE_Viv-SE/14.4
# # /tools/Xilinx/ISE/13.2
# export XILINX=$XLNX/ISE_DS/ISE
# export XILINX_EDK=$XLNX/ISE_DS/EDK
# XILINX_BIN_PATH=$XLNX/ISE_DS/EDK/bin/lin
# XILINX_BIN_PATH64=$XLNX/ISE_DS/EDK/bin/lin64

REMOTE_XMD="ssh cperivol@grey"
XMD=/opt/Xilinx/SDK/2013.3/bin/lin64/xmd

function fail {
    echo "[ERROR] Error while $1"
    exit 1
}

read -d '' HELP_MESSAGE <<EOF

This program loads your software to the board. I assume the current
directory is at the root of the project and bootstrap.sh was run
successfully.

OPTIONS:
--reset		Reset the device

--minicom	Only run minicom.

--xmd-shell 	Run an xmd shell. Try to have readline with rlwrap.  It is
recommended to run xmd from here anyway as it will try
to correct your xmd executable aswell

EOF

LOG_FILE="load-linux.log"


function setup_xmd {
    # Get the xmd executable

    open_xmd="$($REMOTE_XMD pgrep xmd)"
    if [ -n "$open_xmd" ]; then
	fail "Looks like another xmd is running with pid=$open_xmd. Try: $REMOTE_XMD kill $open_xmd"
    fi

    if [ -n "$XMD" ]; then
	echo "Override any xmd detection with '$XMD'";
    elif [ -d $XILINX_BIN_PATH64 ] && [ $(uname -p) = 'x86_64' ]; then
	XMD=$XILINX_BIN_PATH64/xmd
    elif [ -d $XILINX_BIN_PATH ]; then
	XMD=$XILINX_BIN_PATH/xmd
    else
	echo "Failed to find xmd at $XILINX_BIN_PATH64 and $XILINX_BIN_PATH, trying \$PATH"
	# Try the PATH
	XMD=$(which xmd)
    fi

    if [ -n "$REMOTE_XMD" ]; then
	XMD="$REMOTE_XMD $XMD"
    fi


    if [ -z "$XMD" ]; then
	echo "No xmd found."
	exit 0
    fi
    echo "XMD: $XMD"
}

function setup_serial
{
    if [ ! $SERIAL ]; then
	SERIAL=$( ls -d /dev/* | grep ttyUSB | head -1 )
	echo "Using serial: $SERIAL"
    fi


    if [ ! $SERIAL ] || [ ! -c $SERIAL ]; then
	echo "No serial port found or the provided is invalid."
	exit 0
    fi

    [ ! -w $SERIAL ] && echo "Serial $SERIAL is not writeable. Try 'sudo chmod a+w $SERIAL'" && exit 0
    [ ! -r $SERIAL ] && [ "$RUN_MINICOM" = "true" ] && \
    echo "Serial $SERIAL is not readable. Cannot open minicom on it. Try 'sudo chmod a+rw $SERIAL'" && exit 0
}

function xmd_shell
{
    if [ $(command -v rlwrap) ]; then
	echo "Using rlwrap for history and completion, you are welcome."
	rlwrap $XMD
    else
	echo "rlwrap not found, running plain xmd"
	$XMD
    fi
}


function reset_device
{
    echo "echo \"Device reset commanded by $(whoami)!\"" > $SERIAL
    echo -e "connect arm hw\ntarget 64\nrst" | $XMD
}

ramdisk_addr='use print_xmd_commands'
function print_xmd_commands
{
    resources=$(pwd)/resources
    if ! [[ -d $resources ]]; then
	fail "No `pwd`/resources/ dir found."
    fi

    uimage=$resources/uImage
    ramdisk=$resources/uramdisk.img.gz
    dtb=$resources/zynq-zc702.dtb
    ubootelf=$resources/u-boot.elf
    ps7_init_tcl=$resources/ps7_init.tcl
    stub_tcl=$resources/stub.tcl

    echo "connect arm hw
source $ps7_init_tcl
ps7_init
init_user
source $stub_tcl
target 64

dow $ubootelf

dow -data $uimage	0x30000000
"

    if ! [ "$ramdisk_addr" = '-' ]; then
	echo "dow -data $ramdisk	0x20000000"
    fi

    echo "
dow -data $dtb		0x2A000000
con
"
}

function boot_linux {
    if [ "$no_ramdisk" = "y" ]; then
	ramdisk_addr='-'
    fi

    # In order to have interactive output you may want to make a named pipe for this
    print_xmd_commands | tee -a $LOG_FILE | $XMD || fail "sending images to device"

    sleep 5
    if ! [ "$no_boot" = 'y' ];  then
	echo "bootm 0x30000000 $ramdisk_addr 0x2A000000" | tee $SERIAL
    fi
}

function minicom {
    MINICOM_CMD="/usr/bin/minicom -D $SERIAL -b 115200"
    echo "Running $MINICOM_CMD"
    $MINICOM_CMD
}


function main
{
    echo "Beginning Script" > $LOG_FILE
    setup_serial
    setup_xmd
    boot_linux
    echo "Ending Script" > $LOG_FILE

    [ -z "$no_minicom" ] && minicom || true
}

while [[ $# -gt 0 ]]; do
    case $1 in
	'--reset')
	    setup_serial;
	    setup_xmd;
	    reset_device;
	    exit 0;;
	'--minicom')
	    setup_serial;
	    minicom;
	    exit 0;;
	'--which-serial')
	    setup_serial;
	    echo "$SERIAL"
	    exit 0;;
	'--which-xmd')
	    setup_xmd;
	    echo "$XMD"
	    exit 0;;
	'--xmd-shell')
	    setup_xmd;
	    xmd_shell;
	    exit 0;;
	'--xmd-commands')
	    print_xmd_commands;
	    exit 0;;
	'--no-minicom')
	    no_minicom="y";;
	'--no-ramdisk')
	    no_ramdisk="y";;
	'--no-boot')
	    no_boot="y";;
	'--help')
	    echo "$HELP_MESSAGE"
	    exit 0;;
	*)
	    echo "Unrecognized option \"$1\"";
	    exit 1;;
    esac
    shift
done

main
