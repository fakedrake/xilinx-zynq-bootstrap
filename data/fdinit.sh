#!/bin/sh

mknod /dev/fb0 c 29 0

mount 192.168.1.109:/home/fakedrake/Projects/ThinkSilicon/xilinx-zynq-bootstrap/fs/ /homes/fs/ -o rw,nolock
mount -o bind /proc /homes/fs/proc
mount -o bind /dev /homes/fs/dev

chroot /homes/fs/
