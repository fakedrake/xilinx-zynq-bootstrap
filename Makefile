# Definable

MAKETHREADS=4
MAKE=make -j$(MAKETHREADS)

# My directories
ROOT_DIR=$(PWD)
DATA_DIR=$(ROOT_DIR)/data
SOURCES_DIR=$(ROOT_DIR)/sources
RESOURCES_DIR=$(ROOT_DIR)/resources
DRAFTS_DIR=$(ROOT_DIR)/drafts
TOOLS_DIR=$(ROOT_DIR)/tools
LAZY_DIR=$(ROOT_DIR)/lazy
MODULES_DIR=$(FILESYSTEM_ROOT)/lib/modules/3.9.0-xilinx/

DEBUG_LIBS=y

GNU_TOOLS_FTP="ftp://83.212.100.45/Code/zynq_gnu_tools.tar.gz"
GNU_TOOLS_ZIP=$(shell basename $(GNU_TOOLS_FTP))
GNU_TOOLS_DIR=GNU_Tools

FILESYSTEM_ROOT=$(ROOT_DIR)/fs


ifneq ($(REMOTE_SERVER),)
remote-maybe=echo "==== Running on $(REMOTE_SERVER) ====" && ssh $(REMOTE_SERVER) 'PATH=$(PATH) && $1'
else
remote-maybe=$1
endif

force: ;

board-ready: linux-build ramdisk-board uboot-build sdk

# Targets
DIRECTORIES = $(SOURCES_DIR) $(DRAFTS_DIR) $(RESOURCES_DIR) $(TOOLS_DIR) $(LAZY_DIR) $(MODULES_DIR)
$(DIRECTORIES):
	[ -d $@ ] || mkdir -p $@

# GNU Tools
GNU_TOOLS=$(SOURCES_DIR)/gnu-tools-archive/$(GNU_TOOLS_DIR)
GNU_TOOLS_UTILS=$(GNU_TOOLS)/arm-xilinx-linux-gnueabi/
GNU_TOOLS_BIN=$(GNU_TOOLS)/bin
GNU_TOOLS_HOST=arm-xilinx-linux-gnueabi
GNU_TOOLS_PREFIX=$(GNU_TOOLS_BIN)/arm-xilinx-linux-gnueabi-
export CROSS_COMPILE := $(GNU_TOOLS_PREFIX)
export PATH := ${PATH}:$(GNU_TOOLS_BIN):$(SOURCES_DIR)/uboot-git/tools/

gnu-tools-tar-url=$(GNU_TOOLS_FTP)
TAR_PROJECTS += gnu-tools
gnu-tools:
	@echo "Getting GNU Tools"

gnu-tools-clean: gnu-tools-archive-clean

# GIT PROJECTS
# To define a project provide a dir name, a repo url and register it
uboot-git-repo="git://git.xilinx.com/u-boot-xlnx.git"
GIT_PROJECTS += uboot

uboot-build: uboot $(RESOURCES_DIR)/u-boot.elf
	@echo "UBoot built successfully!"

$(RESOURCES_DIR)/u-boot.elf: gnu-tools | $(RESOURCES_DIR)
	@echo "Building U-Boot"
	$(call remote-maybe, $(call)cd $(SOURCES_DIR)/uboot-git ; \
	$(MAKE) zynq_zc70x_config CC="$(GNU_TOOLS_PREFIX)gcc"; \
	$(MAKE)  OBJCOPY="$(GNU_TOOLS_PREFIX)objcopy" LD="$(GNU_TOOLS_PREFIX)ld" AR="$(GNU_TOOLS_PREFIX)ar" CC="$(GNU_TOOLS_PREFIX)gcc")
	cp $(SOURCES_DIR)/uboot-git/u-boot $(RESOURCES_DIR)/u-boot.elf

linux-git-repo=git://github.com/Xilinx/linux-xlnx.git
linux-git-commit=3f7c2d54957e950b3a36a251578185bfd374562c
GIT_PROJECTS += linux

DTB_TREE=$(RESOURCES_DIR)/zynq-zc702.dtb
DTS_TREE=$(SOURCES_DIR)/linux-git/arch/arm/boot/dts/zynq-zc702.dts

linux-build: $(RESOURCES_DIR)/uImage $(DTB_TREE)

$(DTB_TREE):
	$(call remote-maybe, $(SOURCES_DIR)/linux-git/scripts/dtc/dtc -I dts -O dtb -o $(DTB_TREE) $(DTS_TREE))

$(RESOURCES_DIR)/uImage: linux uboot-build gnu-tools | $(RESOURCES_DIR)
	@echo "Building Linux..."
	$(call remote-maybe, \
	cd $(SOURCES_DIR)/linux-git; \
	$(MAKE) ARCH=arm CROSS_COMPILE=$(GNU_TOOLS_PREFIX) xilinx_zynq_defconfig ; \
	$(MAKE) ARCH=arm CROSS_COMPILE=$(GNU_TOOLS_PREFIX) LOADADDR=0x8000 uImage; \
	cp $(SOURCES_DIR)/linux-git/arch/arm/boot/uImage $(RESOURCES_DIR)/uImage)


# Busybox
busybox-git-repo="git://git.busybox.net/busybox"
GIT_PROJECTS += busybox

busybox-build: busybox $(FS_DIRS) gnu-tools
	@echo "Building Busybox..."
	$(call remote-maybe, cd $(SOURCES_DIR)/busybox-git; \
	$(MAKE) ARCH=arm CROSS_COMPILE=$(GNU_TOOLS_PREFIX) CONFIG_PREFIX="$(FILESYSTEM_ROOT)" defconfig && \
	$(MAKE) ARCH=arm CROSS_COMPILE=$(GNU_TOOLS_PREFIX) CONFIG_PREFIX="$(FILESYSTEM_ROOT)" install)

FS_DIRS = $(FILESYSTEM_ROOT) $(FILESYSTEM_ROOT)/lib $(FILESYSTEM_ROOT)/dev $(FILESYSTEM_ROOT)/etc $(FILESYSTEM_ROOT)/etc/dropbear $(FILESYSTEM_ROOT)/etc/init.d $(FILESYSTEM_ROOT)/mnt $(FILESYSTEM_ROOT)/opt $(FILESYSTEM_ROOT)/proc $(FILESYSTEM_ROOT)/root $(FILESYSTEM_ROOT)/sys $(FILESYSTEM_ROOT)/tmp $(FILESYSTEM_ROOT)/var $(FILESYSTEM_ROOT)/var/log $(FILESYSTEM_ROOT)/var/www $(FILESYSTEM_ROOT)/sbin $(FILESYSTEM_ROOT)/usr/ $(FILESYSTEM_ROOT)/usr/bin

$(FS_DIRS):
	[ ! -d $@ ] && mkdir -p $@ || echo "$@ is there!"

$(FILESYSTEM_ROOT)/init.sh:
	cp $(DATA_DIR)/fdinit.sh $@
	chmod a+x $@

filesystem-nossh: $(FS_DIRS) $(FILESYSTEM_ROOT)/init.sh busybox-build
	@echo "Building filesystem"
	$(call remote-maybe, cp $(GNU_TOOLS_UTILS)/libc/lib/* $(FILESYSTEM_ROOT)/lib/)
	$(call remote-maybe, cp -R $(GNU_TOOLS_UTILS)/libc/sbin/* $(FILESYSTEM_ROOT)/sbin/)
	$(call remote-maybe, cp -R $(GNU_TOOLS_UTILS)/libc/usr/* $(FILESYSTEM_ROOT)/usr/)

# Strip debug symbols
ifneq ($(DEBUG_LIBS),y)
	$(call remote-maybe, for i in $(FILESYSTEM_ROOT)/lib/*; do \
		if ([ -f "$$i" ] && [ ! "`file -b $$i`" = "ASCII text" ]); then $(GNU_TOOLS_PREFIX)strip $$i; fi; \
	done)
endif

	$(call remote-maybe, cp $(DATA_DIR)/fstab $(FILESYSTEM_ROOT)/etc/fstab)
	$(call remote-maybe, cp $(DATA_DIR)/inittab $(FILESYSTEM_ROOT)/etc/inittab)
	$(call remote-maybe, cp $(DATA_DIR)/passwd $(FILESYSTEM_ROOT)/etc/passwd)

	$(call remote-maybe, if [ ! -f $(FILESYSTEM_ROOT)/etc/init.d/rcS ] ; then \
		cp $(DATA_DIR)/rcS $(FILESYSTEM_ROOT)/etc/init.d/rcS; \
		chmod 755 $(FILESYSTEM_ROOT)/etc/init.d/rcS; \
	fi)

	@echo "I am about to 'sudo chown root:root $(FILESYSTEM_ROOT)/etc/init.d/rcS'. No need to worry."
	$(call remote-maybe, [ "$(stat --format '%U:%G' $(FILESYSTEM_ROOT)/etc/init.d/rcS)" = "root:root" ] || sudo chown root:root $(FILESYSTEM_ROOT)/etc/init.d/rcS)

filesystem: filesystem-nossh openssh-build

filesystem-clean:
	rm -rf $(FILESYSTEM_ROOT)

ramdisk: ramdisk-board ramdisk-qemu
ramdisk-board: $(RESOURCES_DIR)/uramdisk.img.gz


$(RESOURCES_DIR)/ramdisk.img: filesystem | $(DRAFTS_DIR) $(RESOURCES_DIR)
	@echo "Building ramdisk..."
	$(call remote-maybe, dd if=/dev/zero of=$(RESOURCES_DIR)/ramdisk.img bs=1024 count=$$((`du -s $(FILESYSTEM_ROOT) | awk '{print $$1}'`+1000)))
	$(call remote-maybe, mke2fs -F $(RESOURCES_DIR)/ramdisk.img -L "ramdisk" -b 1024 -m 0)
	$(call remote-maybe, tune2fs $(RESOURCES_DIR)/ramdisk.img -i 0)

	$(call remote-maybe, mkdir $(DRAFTS_DIR)/ramdisk)
	@echo "Sudo is used to mount ramdisk..."
	$(call remote-maybe, sudo mount -o loop $(RESOURCES_DIR)/ramdisk.img $(DRAFTS_DIR)/ramdisk/)
	$(call remote-maybe, sudo cp -R $(FILESYSTEM_ROOT)/* $(DRAFTS_DIR)/ramdisk/)
	$(call remote-maybe, sudo umount $(DRAFTS_DIR)/ramdisk/)
	$(call remote-maybe, rmdir $(DRAFTS_DIR)/ramdisk/)

ramdisk-clean:
	$(call remote-maybe, [ "`mount -l | grep $(DRAFTS_DIR)/ramdisk`" ] && echo "Sudo to unmount ramdisk..." && sudo umount $(DRAFTS_DIR)/ramdisk/)
	$(call remote-maybe, rm -rf $(DRAFTS_DIR)/ramdisk)
	$(call remote-maybe, rm -rf $(RESOURCES_DIR)/ramdisk.img)

$(RESOURCES_DIR)/ramdisk.img.gz: $(RESOURCES_DIR)/ramdisk.img
	$(call remote-maybe, gzip -9 $(RESOURCES_DIR)/ramdisk.img -c > $(RESOURCES_DIR)/ramdisk.img.gz)

$(RESOURCES_DIR)/uramdisk.img.gz: $(RESOURCES_DIR)/ramdisk.img.gz
	$(call remote-maybe, $(SOURCES_DIR)/uboot-git/tools/mkimage -A arm -T ramdisk -C gzip -d $(RESOURCES_DIR)/ramdisk.img.gz $(RESOURCES_DIR)/uramdisk.img.gz)

sdk: $(RESOURCES_DIR)/stub.tcl $(RESOURCES_DIR)/ps7_init.tcl

$(RESOURCES_DIR)/%.tcl :
	$(call remote-maybe, cp $(DATA_DIR)/$*.tcl $@)

include ./Makefile.ssh.def
include ./Makefile.android
include ./Makefile.dfb
include ./Makefile.qemu
include ./Makefile.tsi

show-projects:
	@echo "Git Projects: $(GIT_PROJECTS)"
	@echo "Archive Projects: $(TAR_PROJECTS)"

# Have repositories
.SECONDEXPANSION :
$(GIT_PROJECTS) : $(SOURCES_DIR)/$$@-git

$(SOURCES_DIR)/%-git : force
	$(call remote-maybe, if [ ! -d $@ ] || [ -z "$(force-$*-clone)" ]; then \
		git clone --depth 20 $($*-git-repo) $@ ; \
		[ -z "$($*-git-commit)" ] && git checkout $($*-git-commit) || echo "Nothing to checkout"; \
	fi)
	$(call remote-maybe, cd $@ && git pull)

%-git-purge:
	$(call remote-maybe, rm -rf $(SOURCES_DIR)/$*-git)

%-clean:
	$(call remote-maybe, cd $(SOURCES_DIR)/$*-git && $(MAKE) clean)

%-distclean:
	$(call remote-maybe, cd $(SOURCES_DIR)/$*-git && $(MAKE) distclean)

print-vars:
	@echo "GNU_TOOLS_FTP=$(GNU_TOOLS_FTP)"
	@echo "GNU_TOOLS_ZIP=$(GNU_TOOLS_ZIP)"
	@echo "GNU_TOOLS_DIR=$(GNU_TOOLS_DIR)"
	@echo "GNU_TOOLS=$(GNU_TOOLS)"
	@echo "GNU_TOOLS_UTILS=$(GNU_TOOLS_UTILS)"
	@echo "GNU_TOOLS_BIN=$(GNU_TOOLS_BIN)"
	@echo "GNU_TOOLS_HOST=$(GNU_TOOLS_HOST)"
	@echo "GNU_TOOLS_PREFIX=$(GNU_TOOLS_PREFIX)"
	@echo "CROSS_COMPILE=$(CROSS_COMPILE)"
	@echo "PATH=$(PATH)"
	@echo "uboot-git-repo=$(uboot-git-repo)"
	@echo "linux-git-repo=$(linux-git-repo)"
	@echo "busybox-git-repo=$(busybox-git-repo)"
	@echo "openssh-zip-url=$(openssh-zip-url)"

# For zip archives we need a url to the zip archive an the path from
# the zip root to the project root.
.SECONDEXPANSION :
$(TAR_PROJECTS) :  $(SOURCES_DIR) $(SOURCES_DIR)/$$@-archive

.SECONDARY:
$(DRAFTS_DIR)/%.tar.gz: | $(DRAFTS_DIR)
	echo "Pulling $*."
	wget $($*-tar-url) -O $(DRAFTS_DIR)/$*.tar.gz

.SECONDEXPANSION :
$(SOURCES_DIR)/%-archive : | $(DRAFTS_DIR)/$$*.tar.gz
	mkdir $@
	cd $@ && tar xvzf $(DRAFTS_DIR)/$*.tar.gz

%-clean-archive:
	rm -rf $(SOURCES_DIR)/$*-archive $(DRAFTS_DIR)/$*.tar.gz

# Lazies
#
# So that we do not configure everything over and over, I touch
# something in lazy/ and you want to remove it to run lazy
# dependencies.
#
# I will just do lazies locally for no particular reasons
.SECONDEXPANSION:
$(LAZY_DIR)/%: $(LAZY_DIR) $$*-build
	touch $@

.SECONDEXPANSION:
%-lazy: $(LAZY_DIR)/$$*
	echo "Lazy $@, createing $(LAZY_DIR)/$*"

.SECONDEXPANSION:
%-shallow-lazy:
	echo "Avoiding build, just creating $^"
	touch $(LAZY_DIR)/$*

%-clean-lazy:
	rm -rf $(LAZY_DIR)/$*

all-clean-lazy:
	rm -rf $(LAZY_DIR)

.PHONY: test_remote
test_remote:
	$(call remote-maybe, "hostname")

.PHONY: $(GIT_PROJECTS)
