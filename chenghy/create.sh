#!/bin/bash -x
qemu-img create -b $1 -f qcow2 $2
