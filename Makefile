# Definable

MAKETHREADS=4
MAKE:=$(MAKE) -j$(MAKETHREADS)

# My directories
ROOT_DIR=$(PWD)
DATA_DIR=$(ROOT_DIR)/data
SOURCES_DIR=$(ROOT_DIR)/sources
RESOURCES_DIR?=/var/lib/tftpboot
# RESOURCES_DIR=/var/lib/tftpboot
DRAFTS_DIR=$(ROOT_DIR)/drafts
TOOLS_DIR=$(ROOT_DIR)/tools
LAZY_DIR=$(ROOT_DIR)/lazy
MODULES_DIR=$(FILESYSTEM_ROOT)/lib/modules/$(shell cat $(SOURCES_DIR)/linux-git/include/config/kernel.release)

DEBUG_LIBS=y

GNU_TOOLS_FTP="ftp://83.212.100.45/Code/zynq_gnu_tools.tar.gz"
GNU_TOOLS_ZIP=$(shell basename $(GNU_TOOLS_FTP))
GNU_TOOLS_DIR=GNU_Tools

FILESYSTEM_ROOT=$(ROOT_DIR)/fs


ifneq ($(REMOTE_SERVER),)
remote-maybe=echo "==== Running on $(REMOTE_SERVER) ====" && ssh -t $(REMOTE_SERVER) 'PATH=$(PATH) && $1'
else
remote-maybe=$1
endif

.PHONY: test_remote
test_remote:
	$(call remote-maybe, "hostname")


force: ;

# Targets
DIRECTORIES = $(SOURCES_DIR) $(DRAFTS_DIR) $(RESOURCES_DIR) $(TOOLS_DIR) $(LAZY_DIR) $(FILESYSTEM_ROOT)
$(DIRECTORIES):
	[ -d $@ ] || mkdir -p $@

include ./Makefile.gnutools
include ./Makefile.kernel
include ./Makefile.ramdisk
include ./Makefile.xilinx-sdk
include ./Makefile.ssh.def
include ./Makefile.android
include ./Makefile.dfb
include ./Makefile.qemu
include ./Makefile.tsi
include ./Makefile.projects
include ./Makefile.lazy
include ./Makefile.serials
include ./Makefile.vars

# Entry Points

# Build everything board related
.PHONY:
board-ready: linux-build ramdisk-board uboot-build sdk

# Build everything Qemu related
.PHONY:
qemu-ready: qemu-linux-build qemu-ramdisk qemu-build

.PHONY:
show:
	@echo "resources: $(RESOURCES_DIR)"
