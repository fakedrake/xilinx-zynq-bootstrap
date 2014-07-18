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

# Defaults
load_bitstream='y'
load_uimage='y'
load_ramdisk=''
no_boot=''
run_minicom='y'

iface="eth0"
clientip="192.168.1.50"



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
	while read cmd; do
	    echo "$cmd" | tr '\n' '; ' | tee > "$SERIAL"
	    sleep 0.5;
	done
	echo -e "\n" > "$SERIAL"
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
    hdmi_setup_tcl=$resources/hdmi_setup.tcl


    if [ -n "$load_bitstream" ]; then
	bitstream=$resources/bitstream.bit
	echo "fpga -f $bitstream"
    fi

    echo "connect arm hw
source $ps7_init_tcl
ps7_init
ps7_post_config
"
    echo "source $hdmi_setup_tcl
adv7511_init
init_user
source $stub_tcl
target 64

dow $ubootelf
"

    if [ -n "$load_uimage" ]; then
	echo "dow -data $uimage	0x30000000"
    fi

    if [ -n "$load_ramdisk" ]; then
	echo "dow -data $ramdisk	$ramdisk_addr"
    fi

    if [ -n "$load_devtree" ]; then
	echo "dow -data $dtb		0x2A000000"
    fi

    echo -e "$extra_xmd\ncon";
}

function minicom {
    MINICOM_CMD="/usr/bin/minicom -D $(ll_serial --print) -b 115200"
    echo "Running $MINICOM_CMD"
    $MINICOM_CMD
}

if [ -n "$load_ramdisk" ]; then
    ramdisk_addr="0x20000000"
else
    ramdisk_addr="-"
fi


function load_linux {
    # In order to have interactive output you may want to make a named pipe for this
    print_xmd_commands | ll_xmd || fail "sending images to device"
}

function uboot_commands {
    echo ""
    echo "env default -a"
    echo "setenv autoload no"			# Stop a possible autoboot
    if [ -n "$bootargs" ]; then
	echo "setenv bootargs $bootargs"
    fi

    if [ -n "$tftp_load" ]; then
	hostip=$(ifconfig $iface | awk '($1=="inet"){split($2, ip, ":"); print ip[2]}')

	echo "setenv ipaddr $clientip"
	echo "setenv serverip $hostip"
	echo "tftpboot 0x30000000 uImage"
	echo "tftpboot 0x2a000000 devicetree.dtb"
    fi

    echo "bootm 0x30000000 $ramdisk_addr 0x2A000000"
}

function main
{
    echo "Beginning Script" > $LOG_FILE
    load_linux

    if [ -z "$no_boot" ];  then
	#	sleep 5
	uboot_commands | ll_serial
    fi
    echo "Ending Script" > $LOG_FILE

    if [ -n "$run_minicom" ]; then
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
	'--no-boot')
	    no_boot="y";;
	'--no-bitstream')
	    load_bitstream='';;
	'--no-minicom')
	    run_minicom="";;
	'--no-ramdisk')
	    load_ramdisk="";;
	'--no-linux')
	    load_linux='';;
	"--no-devtree")
	    load_devtree='';;
	'--with-minicom')
	    run_minicom="y";;
	'--with-ramdisk')
	    load_ramdisk="y";;
	'--with-linux')
	    load_uimage='y';;
	"--with-devtree")
	    load_devtree='y';;
	"--tftp")
	    tftp_load="y";
	    load_devtree="";
	    load_uimage="";
	    load_ramdisk="";;
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
