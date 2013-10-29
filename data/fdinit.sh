#!/bin/sh

mknod /dev/fb0 c 29 0

mount -o bind /proc /homes/fs/proc
mount -o bind /dev /homes/fs/dev

chroot /homes/fs/

modprobe thinklcdml
insmod /lib/modules/3.9.0-xilinx/think2d.ko
