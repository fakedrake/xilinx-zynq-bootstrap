#!/bin/sh

echo "### Modprobing thinklcdml."
modprobe thinklcdml

echo "### removing thinklcdml"
echo 0 > /sys/class/vtconsole/vtcon1/bind
rmmod thinklcdml

echo "### Modprobing thinklcdml again."
modprobe thinklcdml

echo "### Setting resolution to 800x600"
fbset -g 800 600 800 600 32
echo "#### syslog"
dmesg | tail

echo "### Setting resolution to 640x480"
fbset -g 640 480 640 480 32
echo "#### syslog"
dmesg | tail
