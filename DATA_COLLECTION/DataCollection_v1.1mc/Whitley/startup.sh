#!/bin/bash
echo "------------------------------"
echo "Collect BMC data script       "
echo "------------------------------"
echo
BASE_DIR=$(dirname "$0")
WORKING_DIR=`pwd`

DEBUG=""
if [ ${DEBUG} ]; then
	DEBUG_PRINT="echo -e"
else
	DEBUG_PRINT=":"
fi

LOG="Y"
if [ ${LOG} ]; then
	LOG_PRINT="echo -e"
else
	LOG_PRINT=":"
fi

GENERAL_PRINT_CONTROL=1;
LOG_PRINT_CONTROL=2;
DEBUG_PRINT_CONTROL=4;
##############################
# $1 functional print control
#       bit 0 - general print
#       bit 1 - log print
#       bit 2 - debug print
# $2 string to be printed
# $3 log file if need
##############################
function integrationPrint()
{
	if [ $((${1} & 0x01)) -eq 1 ]; then
		echo -e "${2}"
	fi
	if [ $((${1} & 0x02)) -eq 2 ]; then
		${LOG_PRINT} "${2}" >> "${3}"
	fi
	if [ $((${1} & 0x04)) -eq 4 ]; then
		${DEBUG_PRINT} "${2}"
	fi
}

function printHelp()
{
	echo "Usage:"
	echo "    ${0} \"192.168.0.120\" \"UserName\" \"Password\""
}

# Do not accept invalid argument.
if [ ${#} -ne 3 ]; then
	printHelp
	exit 1
fi

# Permission Check.
if ! [ -w . ]; then
	echo "Permission denied - Cannot write in `pwd`."
	exit 1
fi

BmcIpAddress="${1}"
BmcUserName="${2}"
BmcUserPassword="${3}"

maximunRetryTimes=3

COOKIE_FILE="cookies_startup.txt"

# Creating CSRF token first.
commandString="curl -k -c ${COOKIE_FILE} -X POST -F \"username=${BmcUserName}\" -F \"password=${BmcUserPassword}\" \"https://${BmcIpAddress}/api/session\" 2>&1"
integrationPrint ${DEBUG_PRINT_CONTROL} "${commandString}"
for ((i=0; i<=${maximunRetryTimes}; i++)) do
	if [ ${i} -gt 0 ]; then
		integrationPrint ${GENERAL_PRINT_CONTROL} "##### Retry ${i} #####"
	fi
	sessionResult=$(eval ${commandString})
	csrf=$(echo "${sessionResult}" | grep -c "CSRFToken")
	if [ ${csrf} -ne 0 ]; then
		break
	fi
	integrationPrint ${GENERAL_PRINT_CONTROL} "Session Result: ${sessionResult}"
done

if [ ${i} -gt ${maximunRetryTimes} ]; then
	integrationPrint ${GENERAL_PRINT_CONTROL} "\n\n\nPlease make sure that the BMC IP address is valid, BMC is alive, user name, and user password are correct."
	printHelp
	exit 1
fi

# Removing prefix
csrfToken=${sessionResult#*CSRFToken\": \"};
	integrationPrint ${DEBUG_PRINT_CONTROL} "CSRF token: ${csrfToken}"
# Removing suffix
csrfToken=${csrfToken%\"*}
	integrationPrint ${DEBUG_PRINT_CONTROL} "CSRF token: ${csrfToken}"

# Using Redfish command to retrieve the BMC MAC address.
commandString="curl -k -X GET -u ${BmcUserName}:${BmcUserPassword} \"https://${BmcIpAddress}/redfish/v1/Managers/Self/EthernetInterfaces/bond0\" 2>&1"
	integrationPrint ${DEBUG_PRINT_CONTROL} "${commandString}"
bond0=$(eval ${commandString})
mac=$(echo "${bond0}" | grep -c "MACAddress")
	integrationPrint ${DEBUG_PRINT_CONTROL} "bond0: ${bond0}"
if [ ${mac} -ne 0 ]; then
	# Removing prefix
	BmcMacAddress=${bond0#*\"MACAddress\":\"};
		integrationPrint ${DEBUG_PRINT_CONTROL} "BMC Mac Address: ${BmcMacAddress}"
	# Removing suffix
	BmcMacAddress=${BmcMacAddress%%\"*}
		integrationPrint ${DEBUG_PRINT_CONTROL} "BMC Mac Address: ${BmcMacAddress}"

	# Replacing ':' with '_'
	BmcMacPrime=`echo ${BmcMacAddress} | sed -n 's/:/_/gp'`
	LOGFOLDER="../log/${BmcMacPrime}/"
else
	IPv6=$(echo "${BmcIpAddress}" | grep -c ":")
	if [ ${IPv6} -gt 0 ]; then
		# Replacing ':' with '_'
		BmcIpPrime=$(echo ${BmcIpAddress} | sed -n 's/:/_/gp' | tr -d '\\[]')
		LOGFOLDER="../log/${BmcIpPrime}/"
	else
		# Replacing '.' with '_'
		BmcIpPrime=`echo ${BmcIpAddress} | sed -n 's/\./_/gp'`
		LOGFOLDER="../log/${BmcIpPrime}/"
	fi
fi

# Create the folder for storing log file.
if [ ! -d ${LOGFOLDER} ]; then
	mkdir -p ${LOGFOLDER}
else
	rm -rf ${LOGFOLDER}*
fi

#VERSION_FILE="${LOGFOLDER}VERSION"
EXSTR_FILE="${LOGFOLDER}execute_startup.log"
EXMSG_FILE="${LOGFOLDER}execute_fetch_bmc_mesg.log"
EXINF_FILE="${LOGFOLDER}execute_fetch_bmc_info.log"
EXFIL_FILE="${LOGFOLDER}execute_fetch_bmc_file.log"

#cat /dev/null > ${VERSION_FILE}
cat /dev/null > ${EXSTR_FILE}
cat /dev/null > ${EXMSG_FILE}
cat /dev/null > ${EXINF_FILE}
cat /dev/null > ${EXFIL_FILE}

VERSION=$(cat ../VERSION | awk '{print$1}')
BUILD=$(cat ../VERSION | awk '{print$3}')

integrationPrint ${LOG_PRINT_CONTROL} "Collect BMC data script (Version $VERSION) - $BUILD" $EXSTR_FILE

integrationPrint $((${GENERAL_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "Start to collection data, please wait about 5 minutes." "${EXSTR_FILE}"

integrationPrint $((${GENERAL_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "Dump BMC console." "${EXSTR_FILE}"
# Calling external shell script to collect information we need.
commandString="${BASE_DIR}/fetch_bmc_mesg.sh \"${BmcIpAddress}\" ${BmcUserName} ${BmcUserPassword} 2>&1"
	integrationPrint ${DEBUG_PRINT_CONTROL} "${commandString}"
response=$(eval ${commandString})
	integrationPrint $((${DEBUG_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "${response}" "${EXMSG_FILE}"
	integrationPrint $((${GENERAL_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "Done." "${EXSTR_FILE}"

sleep 1

integrationPrint $((${GENERAL_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "Dump BMC configuration." "${EXSTR_FILE}"
# Calling external shell script to collect information we need.
commandString="${BASE_DIR}/fetch_bmc_info.sh \"${BmcIpAddress}\" ${BmcUserName} ${BmcUserPassword} 2>&1"
	integrationPrint ${DEBUG_PRINT_CONTROL} "${commandString}"
response=$(eval ${commandString})
	integrationPrint $((${DEBUG_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "${response}" "${EXINF_FILE}"
	integrationPrint $((${GENERAL_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "Done." "${EXSTR_FILE}"

sleep 1

integrationPrint $((${GENERAL_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "Dump BMC syslog" "${EXSTR_FILE}"
# Calling external shell script to collect information we need.
commandString="${BASE_DIR}/fetch_bmc_file.sh \"${BmcIpAddress}\" ${BmcUserName} ${BmcUserPassword} 2>&1"
	integrationPrint ${DEBUG_PRINT_CONTROL} "${commandString}"
response=$(eval ${commandString})
	integrationPrint $((${DEBUG_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "${response}" "${EXFIL_FILE}"
	integrationPrint $((${GENERAL_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "Done." "${EXSTR_FILE}"

sleep 1

# Delete the session.
commandString="curl -k -b ${COOKIE_FILE} -X DELETE -H \"X-CSRFTOKEN: ${csrfToken}\" -H \"Cache-Control: no-cache\" -H content-type:application/json \"https://${BmcIpAddress}/api/session\" 2>&1"
	integrationPrint ${DEBUG_PRINT_CONTROL} "${commandString}"
sessionResult=$(eval ${commandString})
	integrationPrint ${DEBUG_PRINT_CONTROL} "Session Result: ${sessionResult}"

rm -rf ${COOKIE_FILE}

# To compress the log folder.
commandString="tar -zcvf ../BMCCLLOG.tgz ../log/ 2>&1"
	integrationPrint $((${DEBUG_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "${commandString}" "${EXSTR_FILE}"
response=$(eval ${commandString})
	integrationPrint $((${DEBUG_PRINT_CONTROL} + ${LOG_PRINT_CONTROL})) "${response}" "${EXSTR_FILE}"

echo "Please send the \"BMCCLLOG.tgz\" to provider for investigating, thanks."

