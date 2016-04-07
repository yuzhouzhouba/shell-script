#!/bin/bash -x

tmp=`ls`
x=123
echo $tmp
if [ ! -n "$tmp" ];then
	echo "null"
else 
	echo "not null"
fi
