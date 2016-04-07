#!/bin/bash -x
route del default
route del -net 10.239.156.0 netmask 255.255.255.0 dev eth0
route add default gw 10.239.156.1
