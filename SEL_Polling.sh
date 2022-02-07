#!/bin/bash

LOG_LOOP_TIME=3000
LOG_LOOP_SLEEP=1

loopTime=0
flag=0

BMCIP="10.10.11.26"
USERNAME="root"
PASSWD="123456789"
IPMITOOL_CMD="raw 0x0a 0x44"
IPMITOOL_DATA="0x01 0x2b 0xc6 0x60 0xa7 0x1d 0x10 0x4c 0x1c 0x00 0x00 0x00 0x08 0x00 0x00 0x12"
IPMITOOL_CMD1="sel clear"
MAX_SEL_NUM=500

start=$(date +%s)
echo "<<< Task start >>>"
while (( $flag == 0 )); do
	if (( $loopTime > LOG_LOOP_TIME)); then
		echo "Task finish!"
		break
	fi
	echo
	echo "loop[ $loopTime ]"

	# do task here - add sel
	local SelCounter=0
        for ((SelCounter=0; SelCounter < MAX_SEL_NUM; SelCounter++)); do
		echo "add sel " $SelCounter " in loop[ $loopTime ]"
		ipmitool -H $BMCIP -U $USERNAME -P $PASSWD -I lanplus $IPMITOOL_CMD $IPMITOOL_DATA
	
	# do task here - clear sel
	echo "clear sel..."
	ipmitool -H $BMCIP -U $USERNAME -P $PASSWD -I lanplus $IPMITOOL_CMD1

	
	
	let loopTime+=1
	if (() $loopTime)
	#sleep "$LOG_LOOP_SLEEP"
	
done
end=$(date +%s)

timming=$(echo "$end - $start" | bc)
echo 'task timming: '$timming' sec'

echo "<<< End Task >>>"
