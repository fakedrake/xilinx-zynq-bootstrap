#!/bin/sh

export TLCDML_MODULE=thinklcdml_old

# set_res xres yres
set_res () {
    xres=$1
    yres=$2

    # default line: 88 + 800 + 40 = 928
    lmargin=$(((928 - $xres) * 88 / (40 + 88)))
    rmargin=$(((928 - $xres) * 40 / (40 + 88)))

    if [ $lmargin -lt 0 ]; then
	rmargin=0
	lmargin=0
    fi

    echo "${xres}x${yres} margins: L: ${lmargin}, R: ${rmargin}, line length: $(($lmargin + $rmargin + $xres)) (should be around 928)"
    cmd="fbset -g $xres $yres $xres $yres 32 -left $lmargin -right $rmargin"
    echo -e "\t$cmd"
    eval $cmd
}

tlcdml_load () {
    if [ -n $(cat /proc/modules | grep -F "$TLCDML_MODULE" > /dev/null) ]; then
	depmod
	modprobe $TLCDML_MODULE
    else
	echo "$TLCDML_MODULE is already loaded."
    fi
}

tlcdml_rm () {
    echo 0 > /sys/class/vtconsole/vtcon1/bind
    rmmod $TLCDML_MODULE
}

tlcdml_use () {
    if [ "$1" = "old" ]; then
	export TLCDML_MODULE=thinklcdml_old
    else
	export TLCDML_MODULE=thinklcdml
    fi

    echo "From now on the module is: $TLCDML_MODULE"
}

tlcdml_test () {
    echo "### Modprobing thinklcdml."
    tlcdml_load

    echo "### removing thinklcdml"
    tlcdml_rm

    echo "### Modprobing thinklcdml again."
    tlcdml_load

    echo "### Setting resolution to 800x600"
    set_res 800 600

    # echo "### Setting resolution to 640x480"
    # set_res 640 480

    echo "### Free memory"
    free
}
