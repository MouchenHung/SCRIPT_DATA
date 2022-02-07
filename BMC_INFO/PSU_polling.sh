#!/bin/bash

BMC_IP="10.10.14.111"
BMC_USER="root"
BMC_PWD="12345678"

PSU_REG_ST_WORD="0x79"
READ_BYTE_ST_WORD="0x02"
PSU_REG_ST_VOUT="0x7A"
READ_BYTE_ST_VOUT="0x01"
PSU_REG_ST_IOUT="0x7B"
READ_BYTE_ST_IOUT="0x01"
PSU_REG_ST_INPUT="0x7C"
READ_BYTE_ST_INPUT="0x01"
PSU_REG_ST_TEMP="0x7D"
READ_BYTE_ST_TEMP="0x01"
PSU_REG_ST_FAN_12="0x81"
READ_BYTE_ST_FAN_12="0x01"

CMD_REG_LIST="$PSU_REG_ST_WORD $PSU_REG_ST_INPUT"
CMD_READ_LIST="$READ_BYTE_ST_WORD $READ_BYTE_ST_INPUT"
#for item in $CMD_LIST; do
#    echo $item
#done


PSU0_BUS="7"
PSU1_BUS="7"
PSU0_ADDR="0xb0"
PSU1_ADDR="0xb2"



CHANNEL="0"
LOG_FILE="PSU_REG_LOG.txt"
LOOP_TIME=150

RunTime(){
	dt=$(($2 - $1))
	dd=$(($dt/86400))
	dt2=$(($dt-86400*$dd))
	dh=$(($dt2/3600))
	dt3=$(($dt2-3600*$dh))
	dm=$(($dt3/60))
	ds=$(($dt3-60*$dm))

	LC_NUMERIC=C printf "Total runtime: %d:%02d:%02d:%02.1f\n" $dd $dh $dm $ds
}

echo "Start checking by looping $LOOP_TIME"> $LOG_FILE
RUN_start=$(date +%s)
loopT=1
while (( $LOOP_TIME > 0 )); do
    curtime=$(date +"%T")
    echo "-------------------< TEST time" $loopT " at " $curtime " >-------------------">> $LOG_FILE
    echo "collecting time left: " $LOOP_TIME 

    # PSU0
    CMD_PSU_BUS=$PSU0_BUS
    CMD_PSU_ADDR=$PSU0_ADDR
    STATUS_WORD="ipmitool -H ${BMC_IP} -P ${BMC_PWD} -U ${BMC_USER} -I lanplus i2c bus=${CMD_PSU_BUS} chan=${CHANNEL} ${CMD_PSU_ADDR} ${READ_BYTE_ST_WORD} ${PSU_REG_ST_WORD}"
    STATUS_INPUT="ipmitool -H ${BMC_IP} -P ${BMC_PWD} -U ${BMC_USER} -I lanplus i2c bus=${CMD_PSU_BUS} chan=${CHANNEL} ${CMD_PSU_ADDR} ${READ_BYTE_ST_INPUT} ${PSU_REG_ST_INPUT}"
    
    echo "#command: PSU0 "$PSU_REG_ST_WORD >> $LOG_FILE
    $STATUS_WORD >> $LOG_FILE
    echo "#command: PSU0 "$PSU_REG_ST_INPUT >> $LOG_FILE
    $STATUS_INPUT >> $LOG_FILE
    
    # PSU1
    CMD_PSU_BUS=$PSU1_BUS
    CMD_PSU_ADDR=$PSU1_ADDR
    STATUS_WORD="ipmitool -H ${BMC_IP} -P ${BMC_PWD} -U ${BMC_USER} -I lanplus i2c bus=${CMD_PSU_BUS} chan=${CHANNEL} ${CMD_PSU_ADDR} ${READ_BYTE_ST_WORD} ${PSU_REG_ST_WORD}"
    STATUS_INPUT="ipmitool -H ${BMC_IP} -P ${BMC_PWD} -U ${BMC_USER} -I lanplus i2c bus=${CMD_PSU_BUS} chan=${CHANNEL} ${CMD_PSU_ADDR} ${READ_BYTE_ST_INPUT} ${PSU_REG_ST_INPUT}"
    
    echo "#command: PSU1 "$PSU_REG_ST_WORD >> $LOG_FILE
    $STATUS_WORD >> $LOG_FILE
    echo "#command: PSU1 "$PSU_REG_ST_INPUT >> $LOG_FILE
    $STATUS_INPUT >> $LOG_FILE
    #echo $($STATUS_WORD)

    
    

    let LOOP_TIME-=1
    let loopT+=1
done

RUN_end=$(date +%s)
RunTime $RUN_start $RUN_end
