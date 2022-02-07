#!/bin/bash
# Program:
#	Program shows the script name, parameters...
# History:
# 2015/07/16	VBird	First release
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

echo "The script name is        ==> ${0}"
echo "Total parameter number is ==> $#"
[ "$#" -lt 2 ] && echo "The number of parameter is less than 2.  Stop here." && exit 0
echo "Your whole parameter is   ==> '$@'"

count=0
for p in $@ 
do
	echo "The ${count}st parameter = ${p}"
	let count+=1
done

