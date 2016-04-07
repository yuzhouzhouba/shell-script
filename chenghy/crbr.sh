#!/bin/bash
# filename : crbr.sh
# version : 1.0
# description: create bridge shell scripts

#set -x
# variable define

ifnum=${ifnum:-$(echo $1 | awk '/^sw/ { print $NF }' | sed 's/^sw//' )}
dev=$(ip addr show|grep inet| grep global|awk '{print $NF;}')
if [ ${ifnum}"0" = "0" ]; then
    echo "argument fortmat is sw[0-9]"
fi

# function define
# crbr.sh use method



method() {
    echo "usage: $0 arguments"
    echo "argument must be sw+number"
    echo "example: $0 sw0 add/del/help "
    echo "create switch device name sw0 default use eth0 "
}

create_switch() {
    local switch=$1

    if [ ! -e "/sys/class/net/${switch}/bridge" ]; then
        brctl addbr ${switch} >/dev/null 2>&1
        brctl stp ${switch} off >/dev/null 2>&1
        brctl setfd ${switch} 0.1 >/dev/null 2>&1
    fi
    ip link set ${switch} up >/dev/null 2>&1
}

add_to_switch () {
    local switch=$1
    local dev=$2

    if [ ! -e "/sys/class/net/${switch}/brif/${dev}" ]; then
        brctl addif ${switch} ${dev} >/dev/null 2>&1
    fi

    ip link set ${dev} up >/dev/null 2>&1
}

add() {
    echo "adding!"
    switch=sw${ifnum}
        pif=$dev
        create_switch ${switch}
        add_to_switch ${switch} ${pif}
        change_ips ${pif} ${switch}
    kmod=`lsmod | grep kvm`
    if [ "${kmod}0" = "0" ]; then
        add_kvmmod
    fi
}


del() {
    echo "deleting!"
    switch=sw${ifnum}
        pif=$dev
        change_ips ${switch} ${pif}
        ip link set ${switch} down
        brctl delbr ${switch}



}

change_ips() {
    local src=$1
    local dst=$2
    get_ip_info ${src}
        ifconfig ${src} 0.0.0.0
        do_ifup ${dst}
        ip route add default via  ${gateway} dev ${dst}
}

get_ip_info() {
    addr=`ip addr show dev $1 | egrep '^ *inet' | sed -e 's/ *inet //' -e 's/ .*//'`
    gateway=$(ip route list | awk '/^default / { print $3 }')
    broadcast=$(/sbin/ip addr show dev $1 | grep inet | awk '/brd / { print $4 }')
}

do_ifup() {
     if [ ${addr} ] ; then
        ip addr flush $1
        ip addr add ${addr} broadcast ${broadcast} dev $1
        ip link set dev $1 up
     fi
}

add_kvmmod() {
        grep -q GenuineIntel /proc/cpuinfo && /sbin/modprobe kvm-intel
            grep -q AuthenticAMD /proc/cpuinfo && /sbin/modprobe kvm-amd
}

# main scripts

if [ $# != 2 ];then
    method
fi

case "$2" in
    add)
        echo -n $"Add swicth $1"
        add
            echo
            ;;
    del)
        echo -n $"Delete swicth $1"
        del
            echo
            ;;
    *)
        echo -n $"Manual list"
        method
            echo
        ;;
esac
