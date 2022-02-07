#!/bin/bash
BMCIP="10.10.11.26"
USERNAME="root"
PASSWD="123456789"
IPMI_CMD="ipmitool -H $BMCIP -U $USERNAME -P $PASSWD -I lanplus"

# SEL Logs file update and delete 1000 loop
i=1
while [ $i -le 1000 ]; do   
        echo -e "\n******************** SEL Logs Update and Delete test: $i **********************\n"
        echo -e "\n ##### Step #1: sel save logs ######\n"
        $IPMI_CMD sel save sel_log.txt
        if [[ $? -ne 0 ]]; then
		echo "[info] error1"
                exit 1
        fi
        echo -e "\n ##### Step #2: sel clean logs ######\n"
        $IPMI_CMD sel clear
        if [[ $? -ne 0 ]]; then
		echo "[info] error2"
                exit 1
        fi
        echo -e "\n ##### Step #3: sel list logs ######\n"
        $IPMI_CMD sel elist
        if [[ $? -ne 0 ]]; then
		echo "[info] error3"
                exit 1
        fi
        echo -e "\n ##### Step #4: sel add logs ######\n"
        $IPMI_CMD sel add sel_log.txt
        if [[ $? -ne 0 ]]; then
		echo "[info] error4"
                exit 1
        fi
        rm -f sel_log.txt
        echo -e "\n******************** Test: $i complete **********************\n"
        i=$(( $i + 1 ))
done
