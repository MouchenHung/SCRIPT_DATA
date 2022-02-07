#!/bin/bash

BMCIP="10.10.11.26"
USERNAME="root"
PASSWD="123456789"
IPMI_CMD="ipmitool -H $BMCIP -U $USERNAME -P $PASSWD -I lanplus"

#if [ -z ${1} ]; then
#    IPMI_CMD="/usr/local/bin/ipmitool"
#else
#    IPMI_CMD="/usr/local/bin/ipmitool -H ${1} -U root -P calvin"
#fi

Counter=0
LOG_FILE="$(date +'%m%d')_SEL_Stress.log"
MAX_SEL_NUM=500
EXPECTED_SEL_NUM=504

function SignalInterruptHandler() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Test terminated!" | tee -a ${LOG_FILE}
    exit ${CC_SUCC}
}

function Main {
    cat /dev/null >${LOG_FILE}
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SEL Stress start..." | tee -a ${LOG_FILE}

    while [ 1 ]; do
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Cycle ${Counter}" | tee -a ${LOG_FILE}

        ${IPMI_CMD} sel clear 2>&1 | tee -a ${LOG_FILE}
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Send Clear SEL failed!" | tee -a ${LOG_FILE}
            exit 1
        fi

        local SelCounter=0
        for ((SelCounter=0; SelCounter < MAX_SEL_NUM; SelCounter++)); do
            ${IPMI_CMD} raw 0x0A 0x44 0x00 0x00 0x02 0x00 0x00 0x00 0x00 0x20 0x00 0x04 0x10 0x70 0x6f 0x02 0xff 0xff 2>&1 | tee -a ${LOG_FILE}
            if [ ${PIPESTATUS[0]} -ne 0 ]; then
                echo "[$(date +'%Y-%m-%d %H:%M:%S')] Add SEL failed!" | tee -a ${LOG_FILE}
                exit 1
            fi
        done

        local SelCount=$(${IPMI_CMD} sel info | grep "Entries" | grep -Po "\d*")
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Add SEL failed!" | tee -a ${LOG_FILE}
            exit 1
        fi

        if [ "${SelCount}" != "${EXPECTED_SEL_NUM}" ]; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Current SEL number is not 2. SelCount: ${SelCount}" | tee -a ${LOG_FILE}
            exit 1
        fi

        Counter=$((${Counter} + 1))
        sleep 10
    done
}

# trap ctrl-c and call ctrl_c()
trap SignalInterruptHandler INT

Main

