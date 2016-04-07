#!/bin/bash
set -x
cd /home/chenghy/
./basic 3072 1 /home/chenghy/ubuntu1.qcow 00:00:00:00:00:01 384 128 4 /home/chenghy/perf.qcow >ubuntu.log 2>&1 &
#./basic 2048 1 /home/chenghy/ubuntu1.qcow 00:00:00:00:00:01 384 128 4 /home/chenghy/linux_perf-new.qcow >ubuntu.log 2>&1 &
#./basic 2048 1 /home/chenghy/ubuntu2.qcow 00:00:00:00:00:02 384 128 4 /home/chenghy/linux_perf-new.qcow1 >ubuntu.log 2>&1 &
#./basic 2048 1 /home/chenghy/ubuntu1.qcow 00:00:00:00:00:01 384 128 4 /home/chenghy/opencl.qcow
#./basic 1024 2 /home/chenghy/ubuntu2.qcow 00:00:00:00:00:02 384 128 4 >ubuntu.log 2>&1 &
#./basic 1024 3 /home/chenghy/ubuntu3.qcow 00:00:00:00:00:03 384 128 4 >ubuntu.log 2>&1 &
#./basic 1024 4 /home/chenghy/ubuntu4.qcow 00:00:00:00:00:04 384 128 4 >ubuntu.log 2>&1 &
#./basic 1024 5 /home/chenghy/ubuntu5.qcow 00:00:00:00:00:05 384 128 4 >ubuntu.log 2>&1 &
#./basic 1024 6 /home/chenghy/ubuntu6.qcow 00:00:00:00:00:06 384 128 4 >ubuntu.log 2>&1 &
#./basic 1024 7 /home/chenghy/ubuntu7.qcow 00:00:00:00:00:07 384 128 4 >ubuntu.log 2>&1 &
#./basic 512 7 /home/chenghy/win7.qcow 00:00:00:00:00:07 384 128 4 >ubuntu.log 2>&1 &
#./basic 2048 7 /home/ubuntu-64-new.img 00:00:00:00:00:07 384 128 4 >ubuntu.log 2>&1 &
