#!/bin/bash

# Get Tool version and build date
VERSION=$(cat VERSION | awk '{print$1}')
BUILD=$(cat VERSION | awk '{print$3}')

echo "-------------------------------------------------------"
echo "Collect BMC data script (Version ${VERSION}) - ${BUILD}    "
echo "-------------------------------------------------------"
BASE_DIR=$(dirname "$0")
WORKING_DIR=$(pwd)

DEBUG=""
if [ ${DEBUG} ]; then
	DEBUG_PRINT="echo -e"
else
	DEBUG_PRINT=":"
fi

function printHelp() {
	echo "Usage:"
	echo "    ${0} '192.168.0.120' 'UserName' 'Password'"
}

# Do not accept invalid argument.
if [ ${#} -ne 0 ] && [ ${#} -ne 3 ]; then
	printHelp
	exit 1
fi

# Permission Check.
if ! [ -w . ]; then
	echo "Permission denied - Cannot write in $(pwd)."
	exit 1
fi

Interface="lanplus"
CipherSuite=3
BmcIpAddress="${1}"
BmcUserName="${2}"
BmcUserPassword="${3}"

IPv6=$(echo "${BmcIpAddress}" | grep -c ":")
if [ ${IPv6} -gt 0 ]; then
	BmcIpAddress="\[${1}\]"
fi

if [ ${#} -eq 0 ]; then
	echo "This script cannot support in-band"
	exit 1
else
	echo "Running via out of band."
fi

# Check cURL Version
CurlVersion=$(curl -V | grep "curl")
echo "Current curl Version: $CurlVersion"

maximunRetryTimes=3
COOKIE_FILE="cookies_.txt"

# Creating CSRF token first.
commandString="curl -k -c ${COOKIE_FILE} -X POST -F \"username=${BmcUserName}\" -F \"password=${BmcUserPassword}\" \"https://${BmcIpAddress}/api/session\" 2>&1"
${DEBUG_PRINT} "${commandString}"
for ((i = 0; i <= ${maximunRetryTimes}; i++)); do
	if [ ${i} -gt 0 ]; then
		echo -e "##### Retry ${i} #####"
	fi
	sessionResult=$(eval ${commandString})
	csrf=$(echo "${sessionResult}" | grep -c "CSRFToken")
	if [ ${csrf} -ne 0 ]; then
		break
	fi
done

if [ ${i} -gt ${maximunRetryTimes} ]; then
	echo -e "\n\n\nPlease make sure that the BMC IP address is valid, BMC is alive, user name, and user password are correct."
	printHelp
	# Delete the session.
	commandString="curl -k -b ${COOKIE_FILE} -X DELETE -H \"X-CSRFTOKEN: ${csrfToken}\" -H \"Cache-Control: no-cache\" -H content-type:application/json \"https://${BmcIpAddress}/api/session\" 2>&1"
	
	${DEBUG_PRINT} "${commandString}"
	sessionResult=$(eval ${commandString})
	${DEBUG_PRINT} "Session Result: ${sessionResult}"

	rm -rf ${COOKIE_FILE}
	exit 1
fi

# Removing prefix
csrfToken=${sessionResult#*CSRFToken\": \"}
${DEBUG_PRINT} "CSRF token: ${csrfToken}"
# Removing suffix
csrfToken=${csrfToken%\"*}
${DEBUG_PRINT} "CSRF token: ${csrfToken}"

commandString="curl -k -b ${COOKIE_FILE} -X POST -H \"X-CSRFTOKEN: ${csrfToken}\" -H \"Cache-Control: no-cache\" -H content-type:application/json -d '{\"request\":\"0x06 0x01\"}' \"https://${BmcIpAddress}/api/rest_bmc_bridge\" 2>&1"

${DEBUG_PRINT} "${commandString}"
response=$(eval ${commandString})
${DEBUG_PRINT} "${response}"

# Removing prefix
return=${response#*return\": \"}
${DEBUG_PRINT} "return: ${return}"
# Removing suffix
return=${return% \"*}
${DEBUG_PRINT} "return: ${return}"

ProductID_LSB=${return:52:2}
ProductID_MSB=${return:57:2}
${DEBUG_PRINT} "ProductID_LSB: ${ProductID_LSB}"
${DEBUG_PRINT} "ProductID_MSB: ${ProductID_MSB}"


if [ "${ProductID_LSB}" == "58" ] && [ "${ProductID_MSB}" == "35" ]; then # Yavin
	echo "Collecting data on Yavin"
	cd Whitley/
	./startup.sh "${BmcIpAddress}" "${BmcUserName}" "${BmcUserPassword}"
	cd - >/dev/null
else
	echo "The script could not support this platform."
	exit 1
fi

# Delete the session.
commandString="curl -k -b ${COOKIE_FILE} -X DELETE -H \"X-CSRFTOKEN: ${csrfToken}\" -H \"Cache-Control: no-cache\" -H content-type:application/json \"https://${BmcIpAddress}/api/session\" 2>&1"
sessionResult=$(eval ${commandString})

rm -rf ${COOKIE_FILE}
