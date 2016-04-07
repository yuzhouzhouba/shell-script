#!/bin/bash -x
route del default
route del -net 10.239.156.1 netmask 255.255.255.255 dev eth0
route add default gw 10.239.156.1
