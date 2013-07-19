Use this single script to download and configure all components needed
to have a functional xilinx zynq linux image and the means to load it.

Create an executable file by the name overrides.sh to override the
initial variables of the script instead of forking/editing just for
that.

OPTIONS:
--no-gnu-tools: Do not pull/build gnu-tools
--no-sdk-scripts: Do not pull/build sdk scripts
--no-u-boot:    Do not pull/build uboot
--no-linux:	Do not pull/build linux
--no-ramdisk:	Do not pull/build ramdisk
--no-busybox:	Do not pull/build busybox/filesystem

--gnu-tools <path>: Define a path for the xilinx configured gnu-tools

--only <module>: Pull/build only module. Available modules are linux,
       		 u-boot, gnu-tools, ramdisk, dropbear, busybox, sdk-scripts


NOTES:

If you want to make the ramdisk smaller, just move the old fs folder
and use the --no-ssh option
