#!/bin/bash
#This is a script to update CM
#1.Sign a BIN file to BIN_SIGNED file
#2.scp the BIN_SIGNED file to BMC port
#3.ssh to BMC
#4.cp to the BIN_SIGNED file folder
#5.update CM!

PATH=$PATH:/ss:/home/mouchen/VIN DATA:/home/mouchen/PROJECT/F0C_data
export PATH
WORK_DIR=/home/mouchen/PROJECT/F0C_data/
SIGN_SSH_FILE="fb_sign.sh"
PROJECT_NAME="F0C"
BMC_USER="root"
BMC_PASSWORD="0penBmc"
BMC_UPDATE_CMD="fw-util pdb --update cm "
flag=0

echo "-----Update CM shell script-----"
while [ $flag = "0" ]
do
	read -p "-->Choose your mode(0:default, 1:manual): " updateMODE
	if [ $updateMODE = "0" ]
	then
		BIN_FILE="F0C.bin"
		BMC_IP="10.10.12.95"
		T_FILE="/tmp"
		echo "default mode for project ${PROJECT_NAME}."
		echo "*bin name: ${BIN_FILE}"
		echo "*server BMC ip: ${BMC_IP}"
		echo "*target file: ${T_FILE}"
		flag=1

	elif [ $updateMODE = "1" ]
	then
		read -p "-->input your project name: " PROJECT_NAME
		read -p "-->input your sign file name" SIGN_SSH_FILE
		read -p "-->input your bin name: " BIN_FILE
		read -p "-->input your server BMC ip :" BMC_IP
		read -p "-->input your target folder :" T_FILE
		flag=1

	else
		echo "No such command!"

	fi
done


#1
[ -e ${WORK_DIR}${BIN_FILE}"_signed" ] && rm ${WORK_DIR}${BIN_FILE}"_signed"
if [ -f ${WORK_DIR}${BIN_FILE} ] && [ -f ${WORK_DIR}${SIGN_SSH_FILE} ]
then
	${WORK_DIR}${SIGN_SSH_FILE} ${WORK_DIR}${BIN_FILE} ${PROJECT_NAME}
else
	echo "no BIN file!"
	exit 0
fi

echo -n "wait for signing"
while [ ! -f ${WORK_DIR}${BIN_FILE}"_signed" ]
do
	echo -n  "."
	sleep 5
done
echo " "
#read -n 1 -r -s -p $'press enter to continue. . .\n'

#2
sshpass -p ${BMC_PASSWORD} scp ${WORK_DIR}${BIN_FILE}_signed ${BMC_USER}@${BMC_IP}:${T_FILE}
echo "File transfer Success!"
#3
sshpass -p ${BMC_PASSWORD} ssh ${BMC_USER}@${BMC_IP} "cd ${T_FILE};${BMC_UPDATE_CMD}${BIN_FILE}_signed"  
echo "CM update Success from BMC!"




exit 0
