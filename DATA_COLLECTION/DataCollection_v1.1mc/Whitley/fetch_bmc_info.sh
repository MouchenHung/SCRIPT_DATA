#!/bin/bash
echo "-------------------------------"
echo "Fetch BMC Information Script   "
echo "-------------------------------"
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

COOKIE_FILE="cookies_information.txt"

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
	BmcPrime=`echo ${BmcMacAddress} | sed -n 's/:/_/gp'`
else
	IPv6=$(echo "${BmcIpAddress}" | grep -c ":")
	if [ ${IPv6} -gt 0 ]; then
		# Replacing ':' with '_'
		BmcPrime=$(echo ${BmcIpAddress} | sed -n 's/:/_/gp' | tr -d '\\[]')
	else
		# Replacing '.' with '_'
		BmcPrime=`echo ${BmcIpAddress} | sed -n 's/\./_/gp'`
	fi
fi

LOGFOLDER="../log/${BmcPrime}/"

# Create the folder for storing log file.
if [ ! -d ${LOGFOLDER} ]; then
	mkdir -p ${LOGFOLDER}
fi

# For Redfish service command
RedFishCMD="curl -k -X GET -u ${BmcUserName}:${BmcUserPassword} -H \"Content-type:application/json\" \"https://${BmcIpAddress}/redfish/v1"
RestFulCMD="curl -k -b ${COOKIE_FILE} -X GET -H \"X-CSRFTOKEN: ${csrfToken}\" -H \"Cache-Control: no-cache\" \"https://${BmcIpAddress}/api/"
jsonTool=" | python -m json.tool"

# Invalid API Call
eval "${RestFulCMD}fru\"${jsonTool}" > ${LOGFOLDER}Fru_Print_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get FRU information wrong!"
else
	echo "Complete get FRU information"
fi

# Hex format SEL Log
eval "${RestFulCMD}logs/event-file\"" > ${LOGFOLDER}WebUI_SEL_HEX_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get WebUI SEL HEX wrong!"
else
	echo "Complete get WebUI SEL HEX"
fi

# Text format SEL Log
eval "${RestFulCMD}logs/event\"${jsonTool}" > ${LOGFOLDER}WebUI_SEL_TEXT_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get WebUI SEL wrong!"
else
	echo "Complete get WebUI SEL"
fi

# Text format SEL Log without error message
#eval "${RestFulCMD}logs/event\"${jsonTool}" > ${LOGFOLDER}WebUI_SEL_TEXT.json
#if [ $? == 1 ];then
#	echo "Get WebUI SEL1 wrong!"
#else
#	echo "Complete get WebUI SEL1"
#	# MCADDCODE: Add SEL TEXT TRANSFER TASK
#	echo "Transfer SEL jason file to SEL text file. . ."
#	orig="./log/${BmcPrime}/WebUI_SEL_TEXT.json"
#	new="./log/${BmcPrime}/SEL_TEXT.txt"
#	cd ..
#	node ./SEL_transfer.js $orig $new
#	rm -rf $orig
#	cd Whitley
#fi

# Sensors
eval "${RestFulCMD}sensors\"${jsonTool}" > ${LOGFOLDER}Sensor_List_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get sensor list wrong!"
else
	echo "Complete get sensor list"
fi

# Network setting
eval "${RestFulCMD}settings/network\"${jsonTool}" > ${LOGFOLDER}Network_Settings_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get network settings wrong!"
else
	echo "Complete get network setting"
fi

# BMC Mc Info (BMC Version)
eval "${RedFishCMD}/Managers/Self\"${jsonTool}" > ${LOGFOLDER}McInfo_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get MC information wrong!"
else
	echo "Complete get MC information"
fi

# System Info (Bios Version)
eval "${RedFishCMD}/Systems/Self\"${jsonTool}" > ${LOGFOLDER}System_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get System information wrong!"
else
	echo "Complete get System information"
fi

# PSU Info (PSU Version)
eval "${RedFishCMD}/Chassis/Self/Power\"${jsonTool}" > ${LOGFOLDER}PSU_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get PSU information wrong!"
else
	echo "Complete get PSU information"
fi


# Get API on WEB [System Inventory] by RestFulCMD
INTF_FILEHEADER="INTF/System_Inventory"

function CHECKFILE() {
	if [ -d $1 ];then
		sudo rm -rf $1
		echo "--> [${1}] deleted complete!"
	else
		mkdir $1
	fi
}
CHECKFILE ${LOGFOLDER}"INTF"

# [System] - https://10.10.11.56/api/host_inventory/host_interface_system_info
eval "${RestFulCMD}/host_inventory/host_interface_system_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_System".txt" 2>&1
if [ $? == 1 ];then
	echo "Get interface [System] information wrong!"
else
	echo "Complete get interface [System] information"
fi

# [Processor] - https://10.10.11.56/api/host_inventory/host_interface_processor_info
eval "${RestFulCMD}/host_inventory/host_interface_processor_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Process".txt" 2>&1
if [ $? == 1 ];then
	echo "Get interface [Processor] information wrong!"
else
	echo "Complete get interface [Processor] information"
fi

# [Memory Controller] - https://10.10.11.56/api/host_inventory/host_interface_memory_info
eval "${RestFulCMD}/host_inventory/host_interface_memory_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Memory".txt" 2>&1
if [ $? == 1 ];then
	echo "Get interface [Memory] information wrong!"
else
	echo "Complete get interface [Memory] information"
fi

# [Baseboard] - https://10.10.11.56/api/host_inventory/host_interface_baseboard_info
eval "${RestFulCMD}/host_inventory/host_interface_baseboard_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Baseboard".txt" 2>&1
if [ $? == 1 ];then
	echo "Get interface [Baseboard] information wrong!"
else
	echo "Complete get interface [Baseboard] information"
fi

# [Power] - https://10.10.11.56/api/host_inventory/host_interface_power_info
eval "${RestFulCMD}/host_inventory/host_interface_power_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Power".txt" 2>&1
if [ $? == 1 ];then
	echo "Get interface [Power] information wrong!"
else
	echo "Complete get interface [Power] information"
fi

# [Thermal] - https://10.10.11.56/api/host_inventory/host_interface_thermal_info
eval "${RestFulCMD}/host_inventory/host_interface_thermal_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Thermal".txt" 2>&1
if [ $? == 1 ];then
	echo "Get interface [Thermal] information wrong!"
else
	echo "Complete get interface [Thermal] information"
fi

# [PCIE Device] - https://10.10.11.56/api/host_inventory/host_interface_pcie_device_info
#eval "${RestFulCMD}/host_inventory/host_interface_pcie_device_function_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_PCIE_Device".txt" 2>&1
#if [ $? == 1 ];then
#	echo "Get interface [PCIE Device] information wrong!"
#else
#	echo "Complete get interface [PCIE Device] information"
#fi

# [PCIE Function] - https://10.10.11.56/api/host_inventory/host_interface_pcie_device_function_info
eval "${RestFulCMD}/host_inventory/host_interface_pcie_device_function_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_PCIE_Funciton".txt" 2>&1
if [ $? == 1 ];then
	echo "Get interface [PCIE Function] information wrong!"
else
	echo "Complete get interface [PCIE Function] information"
fi

# [Storage] - https://10.10.11.56/api/host_inventory/host_interface_storage_info
eval "${RestFulCMD}/host_inventory/host_interface_storage_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Storage".txt" 2>&1
if [ $? == 1 ];then
	echo "Get interface [Storage] information wrong!"
else
	echo "Complete get interface [Storage] information"
fi

echo "Completed!"

# Delete the session.
commandString="curl -k -b ${COOKIE_FILE} -X DELETE -H \"X-CSRFTOKEN: ${csrfToken}\" -H \"Cache-Control: no-cache\" -H content-type:application/json \"https://${BmcIpAddress}/api/session\" 2>&1"
	integrationPrint ${DEBUG_PRINT_CONTROL} "${commandString}"
sessionResult=$(eval ${commandString})
	integrationPrint ${GENERAL_PRINT_CONTROL} "Session Result: ${sessionResult}"

rm -rf ${COOKIE_FILE}

