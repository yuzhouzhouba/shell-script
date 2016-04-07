#!/bin/bash 
c=0
for file in `ls /sys/kernel/vgt|grep vm`

do 
  vm[$c]=$file
  c=`expr $c + 1 `
done



echo ${vm[0]}
echo ${vm[1]}
