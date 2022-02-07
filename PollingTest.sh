#!/bin/bash

LOG_LOOP_TIME=5
LOG_LOOP_SLEEP=5

RES_FILE="/dre/aa.txt"
DES_FILE="/conf/gg.txt"

loopTime=0
flag=0

echo "<<< Task start >>>"
while (( $flag == 0 )); do
	if (( $loopTime > LOG_LOOP_TIME)); then
		echo "Task finish!"
		break
	fi
	echo
	echo "loop[ $loopTime ] - copy to conf"

	# copy
	cp $RES_FILE $DES_FILE
	
	let loopTime+=1
	sleep "$LOG_LOOP_SLEEP"
	
done

start=$(date +%s)
# dd /conf to mount shared folder
dd if=/dev/mtdblock7 of=/var/MC_share/conf_dump
end=$(date +%s)

timming=$(echo "$end - $start" | bc)
echo 'dd timming: '$seconds' sec' > /var/MC_share/conf_dump_timming.txt

echo "<<< End Task >>>"
