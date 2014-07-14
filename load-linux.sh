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

REMOTE_XMD=${REMOTE_XMD:-"ssh cperivol@grey"}
XMD=${XMD:-/opt/Xilinx/SDK/2013.3/bin/lin64/xmd}

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

# Select and run xmd, with --print show the command.
function ll_xmd {
    mode="$1"

    # Get the xmd executable
    if [ -n "$REMOTE_XMD" ]; then
	open_xmd="$($REMOTE_XMD -n pgrep xmd)"
    else
	open_xmd="$(pgrep xmd)"
    fi

    if [ -n "$open_xmd" ]; then
    	fail "Looks like another xmd is running with pid=$open_xmd. Try: $REMOTE_XMD kill $open_xmd"
    fi

    # Find a proper xmd
    if [ -n "$XMD" ]; then
    	[ ! "$mode" == "--print" ] && echo "Xmd already setup to '$XMD'";
    elif [ -d $XILINX_BIN_PATH64 ] && [ $(uname -p) = 'x86_64' ]; then
    	XMD=$XILINX_BIN_PATH64/xmd
    elif [ -d $XILINX_BIN_PATH ]; then
    	XMD=$XILINX_BIN_PATH/xmd
    else
    	echo "Failed to find xmd at $XILINX_BIN_PATH64 and $XILINX_BIN_PATH, trying \$PATH"
    	# Try the PATH
    	XMD=$(which xmd)
    fi

    if [ -z "$XMD" ]; then
	fail "No xmd found."
    fi

    case "$mode" in
	"--print")
	    echo "$REMOTE_XMD $XMD";;
	"--interactive")
	    eval "$REMOTE_XMD $XMD";;
	*)
	    mkfifo /tmp/pipe
	    tee pipe
	    cat pipe | eval "$REMOTE_XMD $XMD"
	    rm /tmp/pipe;;
    esac;
}

# Pipe here what you need in the serial, with --print just show the device
function ll_serial
{
    print_p="$1"

    if [ ! $SERIAL ]; then
	SERIAL=$( ls -d /dev/* | grep ttyUSB | head -1 )
    fi


    if [ ! $SERIAL ] || [ ! -c $SERIAL ]; then
	fail "No serial port found or the provided is invalid."
    fi

    [ ! -w $SERIAL ] && fail "Serial $SERIAL is not writeable. Try 'sudo chmod a+rw $SERIAL'"

    if [ "$print_p" = "--print" ]; then
	echo "$SERIAL"
    else
	tee "$SERIAL"
    fi
}

function xmd_shell
{
    if [ $(command -v rlwrap) ]; then
	echo "Using rlwrap for history and completion, you are welcome."
	eval rlwrap $(ll_xmd --print)
    else
	echo "rlwrap not found, running plain xmd"
	ll_xmd --interactive
    fi
}

function reset_device
{
    echo "echo \"Device reset commanded by $(whoami)!\""  | ll_serial
    echo -e "connect arm hw\ntarget 64\nrst" | ll_xmd
    echo  "Device reset!"
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
    dtb=$resources/devicetree.dtb
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
$extra_xmd
con
"
}

function load_linux {
    if [ "$no_ramdisk" = "y" ]; then
	ramdisk_addr='-'
    fi

    # In order to have interactive output you may want to make a named pipe for this
    print_xmd_commands | ll_xmd || fail "sending images to device"
}

function boot_linux {
    if [ -n "$bootargs" ]; then
	echo "setenv bootargs $bootargs" | ll_serial
    fi

    echo "bootm 0x30000000 $ramdisk_addr 0x2A000000" | ll_serial
}

function minicom {
    MINICOM_CMD="/usr/bin/minicom -D $(ll_serial --print) -b 115200"
    echo "Running $MINICOM_CMD"
    $MINICOM_CMD
}


function main
{
    echo "Beginning Script" > $LOG_FILE
    if ! [ "$no_load" = 'y' ];  then
        load_linux
    fi

    if ! [ "$no_boot" = 'y' ];  then
	sleep 5
	boot_linux
    fi
    echo "Ending Script" > $LOG_FILE

    if ! [ "$no_minicom" = 'y' ]; then
	minicom
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
	'--reset')
	    reset_device;
	    exit 0;;
	'--minicom')
	    setup_serial;minicom;
	    exit 0;;
	'--which-serial')
	    ll_serial --print;
	    exit 0;;
	'--which-xmd')
	    ll_xmd --print
	    exit 0;;
	'--xmd-shell')
	    xmd_shell;
	    exit 0;;
	'--show-xmd-commands')
	    print_xmd_commands;
	    exit 0;;
	'--bootargs')
	    shift; bootargs="$1";;
	'--xmd-extra')
	    shift; extra_xmd="$1";;
	'--no-minicom')
	    no_minicom="y";;
	'--no-ramdisk')
	    no_ramdisk="y";;
	'--no-load')
	    no_load="y";;
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
