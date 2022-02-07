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

# v1.2 add - LogServices(SEL Info)
eval "${RedFishCMD}/Managers/Self/LogServices/SEL/Entries\"${jsonTool}" > ${LOGFOLDER}LS_SEL_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get LogServices(SEL) information wrong!"
else
	echo "Complete get LogServices(SEL) information"
fi

# v1.2 add - LogServices(OEMSEL Info)
eval "${RedFishCMD}/Managers/Self/LogServices/OEMSEL/Entries\"${jsonTool}" > ${LOGFOLDER}LS_OEMSEL_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get LogServices(OEMSEL) information wrong!"
else
	echo "Complete get LogServices(OEMSEL) information"
fi

# v1.2 add - LogServices(EventLog Info)
eval "${RedFishCMD}/Managers/Self/LogServices/EventLog/Entries\"${jsonTool}" > ${LOGFOLDER}LS_EventLog_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get LogServices(EventLog) information wrong!"
else
	echo "Complete get LogServices(EventLog) information"
fi

# v1.2 add - LogServices(BIOS Info)
eval "${RedFishCMD}/Systems/Self/LogServices/BIOS/Entries\"${jsonTool}" > ${LOGFOLDER}LS_BIOS_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get LogServices(BIOS) information wrong!"
else
	echo "Complete get LogServices(BIOS) information"
fi

# v1.2 add - LogServices(ChassisLogs Info)
eval "${RedFishCMD}/Chassis/Self/LogServices/Logs/Entries\"${jsonTool}" > ${LOGFOLDER}LS_ChassisLogs_${BmcPrime} 2>&1
if [ $? == 1 ];then
	echo "Get LogServices(ChassisLogs) information wrong!"
else
	echo "Complete get LogServices(ChassisLogs) information"
fi

# v1.1 add - New folder to save "System_Inventory" info
INTF_FILEHEADER="INTF/System_Inventory"

# v1.1 add - Add INTF header folder
mkdir ${LOGFOLDER}INTF

# v1.01 add - System Inventory - System
eval "${RestFulCMD}/host_inventory/host_interface_system_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_System".txt" 2>&1
if [ $? == 1 ];then
	echo "Get System Inventory - System wrong!"
else
	echo "Complete get System Inventory - System"
fi

# v1.1 add - System Inventory - Processor
eval "${RestFulCMD}/host_inventory/host_interface_processor_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Process".txt" 2>&1
if [ $? == 1 ];then
	echo "Get System Inventory - Processor wrong!"
else
	echo "Complete get System Inventory - Processor"
fi

# v1.1 add - System Inventory - Memory
eval "${RestFulCMD}/host_inventory/host_interface_memory_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Memory".txt" 2>&1
if [ $? == 1 ];then
	echo "Get System Inventory - Memory wrong!"
else
	echo "Complete get System Inventory - Memory"
fi

# v1.1 add - System Inventory - Baseboard
eval "${RestFulCMD}/host_inventory/host_interface_baseboard_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Baseboard".txt" 2>&1
if [ $? == 1 ];then
	echo "Get System Inventory - Baseboard wrong!"
else
	echo "Complete get System Inventory - Baseboard"
fi

# v1.1 add - System Inventory - Power
eval "${RestFulCMD}/host_inventory/host_interface_power_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Power".txt" 2>&1
if [ $? == 1 ];then
	echo "Get System Inventory - Power wrong!"
else
	echo "Complete get System Inventory - Power"
fi

# v1.1 add - System Inventory - Thermal
eval "${RestFulCMD}/host_inventory/host_interface_thermal_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Thermal".txt" 2>&1
if [ $? == 1 ];then
	echo "Get System Inventory - Thermal wrong!"
else
	echo "Complete get System Inventory - Thermal"
fi

# v1.1 add - System Inventory - PCIE Function
eval "${RestFulCMD}/host_inventory/host_interface_pcie_device_function_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_PCIE_Funciton".txt" 2>&1
if [ $? == 1 ];then
	echo "Get System Inventory - PCIE Function wrong!"
else
	echo "Complete get System Inventory - PCIE Function"
fi

# v1.1 add - System Inventory - Storage
eval "${RestFulCMD}/host_inventory/host_interface_storage_info\"${jsonTool}" > ${LOGFOLDER}${INTF_FILEHEADER}_Storage".txt" 2>&1
if [ $? == 1 ];then
	echo "Get System Inventory - Storage wrong!"
else
	echo "Complete get System Inventory - Storage"
fi

echo "Completed!"

# Delete the session.
commandString="curl -k -b ${COOKIE_FILE} -X DELETE -H \"X-CSRFTOKEN: ${csrfToken}\" -H \"Cache-Control: no-cache\" -H content-type:application/json \"https://${BmcIpAddress}/api/session\" 2>&1"
	integrationPrint ${DEBUG_PRINT_CONTROL} "${commandString}"
sessionResult=$(eval ${commandString})
	integrationPrint ${GENERAL_PRINT_CONTROL} "Session Result: ${sessionResult}"

rm -rf ${COOKIE_FILE}

