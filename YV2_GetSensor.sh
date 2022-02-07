#!/bin/bash
#This is a script to update CM
#1.Sign a BIN file to BIN_SIGNED file
#2.scp the BIN_SIGNED file to BMC port
#3.ssh to BMC
#4.cp to the BIN_SIGNED file folder
#5.update CM!

declare -A tmp_list
senDev=()
senName=()
senCmd=()
senEn=()
EnableSensor=()
i=0;j=0
flag=0

CFG_FILE=./config/YV2_GetSensor_cfg.txt
ReadFile1() {
        tmp_list=()
        readFlag=0; i=0; j=0
	readpoint=$1
	keyword=$2
	cfg_file=$3
        while IFS=" " read -r line; do
		if [[ "$line" == *"$readpoint"* ]] && [[ "$line" == *"$keyword"* ]] && [[ "$line" == *"DISABLE"* ]] && [[ $readFlag == 0 ]]; then
			echo "-----CONFIG ISSUE-----"
			echo "!!!The [ $keyword ] config is not available!!!"
			readFlag=2
			break

		elif [[ "$line" == *"$readpoint"* ]] && [[ "$line" == *"$keyword"* ]] && [[ "$line" == *"ENABLE"* ]] && [[ $readFlag == 0 ]]; then
                        readFlag=1
                        continue


                elif [[ $line ]] && [[ $readFlag = 1 ]] ; then
                        j=0
                        for ele in $line; do
                                tmp_list[$i,$j]=$ele
                                #echo $i $j ${tmp_list[$i,$j]}
                                let j+=1
                        done
                        let i+=1

                elif [[ !$line ]] && [[ $readFlag = 1 ]]; then
                        break
		
                fi
        done < $cfg_file

	if [[ $readFlag = 0 ]]; then
		echo "-----CONFIG ISSUE-----}"
		echo "!!!no such [ $readpoint ] or [ $keyword ] config!!!"
	fi
}

ReadFile2() {
        tmp_list=()
        readFlag=0; i=0; j=0
        readpoint=$1
        keyword=$2
        cfg_file=$3
        while IFS=" " read -r line; do
                if [[ "$line" == *"$readpoint"* ]] && [[ "$line" == *"$keyword"* ]] && [[ "$line" == *"DISABLE"* ]] && [[ $readFlag == 0 ]]; then
                        echo "-----CONFIG ISSUE-----"
                        echo "!!!The [ $keyword ] config is not available!!!"
                        readFlag=2

                elif [[ "$line" == *"$readpoint"* ]] && [[ "$line" == *"$keyword"* ]] && [[ "$line" == *"ENABLE"* ]] && [[ $readFlag == 0 ]]; then
                        readFlag=1
                        continue


                elif [[ $line ]] && [[ $readFlag = 1 ]] ; then
                        j=0
                        for ele in $line; do
                                tmp_list[$i,$j]=$ele
                                #echo $i $j ${tmp_list[$i,$j]}
                                let j+=1
                        done
                        let i+=1

                elif [[ !$line ]] && [[ $readFlag = 1 ]]; then
                        readFlag=0

                fi
        done < $cfg_file

        #if [[ $readFlag = 0 ]]; then
        #        echo "-----CONFIG ISSUE-----}"
        #        echo "!!!no such [ $readpoint ] or [ $keyword ] config!!!"
        #fi
}


SensorAppend(){
	let i+=-1; let j+=-1
	for col in $(seq 0 $i); do
        	senDev+=(${tmp_list[$col,0]})
        	senName+=(${tmp_list[$col,1]})
        	senCmd+=(${tmp_list[$col,2]})
        	senEn+=(${tmp_list[$col,3]})
	done
}

ReadFile1 ITEM NOW_TIME $CFG_FILE
_NOW="${tmp_list[0,0]} ${tmp_list[0,1]}"
NOW=$($_NOW)

ReadFile1 ITEM ENV_PATH $CFG_FILE
ENV_PATH=${tmp_list[0,0]}
export ENV_PATH

ReadFile1 ITEM BMC_IP $CFG_FILE
BMC_IP="${tmp_list[0,0]}.${tmp_list[0,1]}.${tmp_list[0,2]}.${tmp_list[0,3]}"

ReadFile1 ITEM BMC_USER $CFG_FILE
BMC_USER=${tmp_list[0,0]}

ReadFile1 ITEM BMC_PASSWORD $CFG_FILE
BMC_PASSWORD=${tmp_list[0,0]}

ReadFile1 ITEM PROJECT_NAME $CFG_FILE
PROJECT_NAME=${tmp_list[0,0]}

ReadFile1 ITEM LOG_FILE $CFG_FILE
LOG_FILE=${tmp_list[0,0]}

ReadFile1 ITEM pLOG_FILE $CFG_FILE
pLOG_FILE=${tmp_list[0,0]}

ReadFile1 ITEM LOG_LOOP_TIME $CFG_FILE
LOG_LOOP_TIME=${tmp_list[0,0]}

ReadFile1 ITEM LOG_LOOP_SLEEP $CFG_FILE
LOG_LOOP_SLEEP=${tmp_list[0,0]}

ReadFile1 ITEM SensorCommand_PATH $CFG_FILE
SensorCommand_PATH=${tmp_list[0,0]}

ReadFile1 ITEM SensorCommand_OBMC $CFG_FILE
SensorCommand_OBMC="${tmp_list[0,0]} ${tmp_list[0,1]}"

ReadFile1 ITEM Sensor_TMP $CFG_FILE; SensorAppend
ReadFile1 ITEM Sensor_RPM $CFG_FILE; SensorAppend
ReadFile1 ITEM Sensor_Voltage $CFG_FILE; SensorAppend
#echo "Name: "${senName[*]} 
#echo "Cmd: "${senCmd[*]}

echo
echo "-----PDB.Get Sensor Record shell script-----"
echo "{ Sensor Status config }"
for c in ${!senDev[@]}; do
	echo "No.["$c"] "${senDev[$c]}" --- "${senName[$c]}" "${senCmd[$c]}" --- "${senEn[$c]}
done
echo 

SensorReadLoop(){
        for e in ${EnableSensor[@]}; do
                echo "read sensor No."$e
		echo "read sensor No."$e >> $LOG_FILE
		#sshpass -p ${BMC_PASSWORD} ssh ${BMC_USER}@${BMC_IP} "/usr/local/bin/sensor-util spb 0x91" >> $LOG_FILE
                FB="sshpass -p ${BMC_PASSWORD} ssh ${BMC_USER}@${BMC_IP} ${SensorCommand_PATH}${SensorCommand_OBMC} ${senCmd[$e]}"
		$FB >> $LOG_FILE
		result=$($FB)
		IFS=' ' read -ra ifs_list <<< $result
		
		echo -n "${ifs_list[3]} " >> $pLOG_FILE
		
        done
	echo  >> $pLOG_FILE
}


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


while [ $flag = 0 ]; do
	read -p "Enter all the sensors you want to chase('exit' to end section.): " sensors
	echo "${sensors}"
	[ $sensors = exit ] && flag=1 && break
	IFS=' ' read -ra ifs_sensor <<< "$sensors"
	if [ $ifs_sensor ]; then
		echo "Your choice of sensors:"
		for sensor in ${ifs_sensor[@]}; do	
			if [ ${senEn[$sensor]} = "enable" ] && (( $sensor < ${#senDev[@]} )); then
				echo "*SensorNo.${sensor} -- ${senName[$sensor]} -- ${senCmd[$sensor]}"
				EnableSensor+=($sensor)
				#echo ${EnableSensor[@]}
			elif (( $sensor >= ${#senDev[@]} )); then
				echo "It contains non-defined sensor number!"
				flag=1
			fi
		done
		[ -z "$EnableSensor" ] && echo "No Enable sensors!"
		break

	else 
		echo "No sensor given!"
		
	fi
done

#3
RUN_start=$(date +%s)
if [ $EnableSensor ] && (( !$flag )); then
	loopTime=1
	chmod +x $LOG_FILE
	[ -f $LOG_FILE ] && read -n 1 -r -s -p $"press enter to delete exist LOG or Leave the section. . ." && rm "$LOG_FILE"
	[ -f $pLOG_FILE ] && read -n 1 -r -s -p $"press enter to delete exist pLOG or Leave the section. . ." && rm "$pLOG_FILE"
	echo 
	echo "Connect to BMC and Reading the sensors. . ."
	while (( $flag == 0 )); do
		if (( $loopTime > LOG_LOOP_TIME)); then
			echo "|| End Task ||"
			break
		fi
		echo
		echo "loop[ $loopTime ] - sensor reading"
		echo "LOG --- GET_SENSORS_READING --- ENABLE" >> $LOG_FILE
		echo "loop[ $loopTime ] --- sensor reading --- $NOW" >> $LOG_FILE
		SensorReadLoop
		echo  >> $LOG_FILE
		let loopTime+=1
		sleep "$LOG_LOOP_SLEEP"
		
	done
	echo "Sensor Reading Task Complete!"
fi
RUN_end=$(date +%s)
RunTime $RUN_start $RUN_end



for loop in $(seq 0 $(($LOG_LOOP_TIME-1))); do
	ReadFile2 LOG GET_SENSORS_READING $LOG_FILE
	L=${tmp_list[0,1]}
	echo $loop $L
done

exit 0
