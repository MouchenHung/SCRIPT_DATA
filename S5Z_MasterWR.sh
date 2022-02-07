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

CFG_FILE=./config/F0C_GetSensor_cfg.txt
ReadFile1() {
        tmp_list=()
        readFlag=0; i=0; j=0
        while IFS=" " read -r line; do
		if [[ "$line" == *"ITEM"* ]] && [[ "$line" == *"$1"* ]] && [[ "$line" == *"DISABLE"* ]] && [[ $readFlag == 0 ]]; then
			echo "-----CONFIG ISSUE-----"
			echo "!!!The [ $1 ] config is not available!!!"
			readFlag=2
			break

		elif [[ "$line" == *"ITEM"* ]] && [[ "$line" == *"$1"* ]] && [[ "$line" == *"ENABLE"* ]] && [[ $readFlag == 0 ]]; then
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
        done < $CFG_FILE

	if [[ $readFlag = 0 ]]; then
		echo "-----CONFIG ISSUE-----}"
		echo "!!!no such [ $1 ] config!!!"
	fi
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

ReadFile1 NOW_TIME
_NOW="${tmp_list[0,0]} ${tmp_list[0,1]}"
NOW=$($_NOW)

ReadFile1 ENV_PATH
ENV_PATH=${tmp_list[0,0]}
export ENV_PATH

ReadFile1 BMC_IP
BMC_IP="${tmp_list[0,0]}.${tmp_list[0,1]}.${tmp_list[0,2]}.${tmp_list[0,3]}"

ReadFile1 BMC_USER
BMC_USER=${tmp_list[0,0]}

ReadFile1 BMC_PASSWORD
BMC_PASSWORD=${tmp_list[0,0]}

ReadFile1 PROJECT_NAME
PROJECT_NAME=${tmp_list[0,0]}

ReadFile1 LOG_FILE
LOG_FILE=${tmp_list[0,0]}

ReadFile1 LOG_LOOP_TIME
LOG_LOOP_TIME=${tmp_list[0,0]}

ReadFile1 LOG_LOOP_SLEEP
LOG_LOOP_SLEEP=${tmp_list[0,0]}

ReadFile1 SlaveCommand
SlaveCommand="${tmp_list[0,0]} ${tmp_list[0,1]} ${tmp_list[0,2]} ${tmp_list[0,3]} ${tmp_list[0,4]}"

ReadFile1 SensorCommand_OEM
SensorCommand_OEM="${tmp_list[0,0]} ${tmp_list[0,1]}"

ReadFile1 SensorCommand_IPMI
SensorCommand_IPMI="${tmp_list[0,0]} ${tmp_list[0,1]}"

ReadFile1 Sensor_HSC; SensorAppend
ReadFile1 Sensor_OEMEXTEND; SensorAppend
ReadFile1 Sensor_Voltage; SensorAppend
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
                echo sshpass -p ${BMC_PASSWORD} ssh ${BMC_USER}@${BMC_IP} "${SlaveCommand} ${SensorCommand_OEM} ${senCmd[${EnableSensor[$e]}]}" >> $LOG_FILE
        done

}


ReadFile() {
while IFS=" " read -r f1 f2; 
do
        echo "hi $f1 $f2"
	senName+=($f1)
	senCmd+=($f2)
done < $1
}


SensorStore() {
case $1 in
	0)
		#echo "REG_READ_VIN"
		senName=REG_READ_VIN; senCmd=0xC0
	       	;;
	1)
		#echo "REG_OUT_CURR"
		senName=REG_OUT_CURR; senCmd=0xC1
		;;
	2)
		#echo "REG_READ_TEMPERATURE_1"
		senName=REG_READ_TEMPERATURE_1; senCmd=0xC2
	esac
}

while [ $flag = 0 ]; do
	read -p "Enter all the sensors you want to chase('exit' to end section.): " sensors
	echo "${sensors}"
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

	elif [ $sensors = exit ]; then
		break
	else 
		echo "No sensor given!"
		
	fi
done

#3
loopTime=1
chmod +x $LOG_FILE
[ -f $LOG_FILE ] && read -n 1 -r -s -p $"press enter to delete exist LOG or Leave the section. . ." && rm "$LOG_FILE"

if [ $EnableSensor ] && (( !$flag )); then
	echo 
	echo "Connect to BMC and Reading the sensors. . ."
	while (( $flag == 0 )); do
		if (( $loopTime > LOG_LOOP_TIME)); then
			echo "|| End Task ||"
			break
		fi
		echo
		echo "loop[ $loopTime ] - sensor reading"
		echo "loop[ $loopTime ] --- sensor reading --- $NOW" >> $LOG_FILE
		SensorReadLoop
		echo  >> $LOG_FILE
		let loopTime+=1
		sleep "$LOG_LOOP_SLEEP"
		
	done
fi
#echo "CM update Success from BMC!"

time CM_GetSensor_config.sh

exit 0
