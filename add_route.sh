#!/bin/bash
#
# add_route.sh
# Script to setup persistant TEDAPI Routing for Powerwall Dashboard
# Version: 1.0.1
# By Scott Hibbard  - 2024-09-15
#

CRONTAB="/var/spool/cron/crontabs/root"
PW_IP=""
SCRIPT_NAME="TEDAPI_routing"
DIR="/root/scripts"
LINUX_IP="192.168.91.0/24"
TARGET_IP="192.168.91.1"
NETMASK="255.255.255.255"
OS=$(uname -s)

echo "Setup script for persistant Powerall Dashboard TEDAPI Interface network routing"
echo "-------------------------------------------------------------------------------"
echo
echo "This script will require root privileges to read & set a startup cron task."
read -r -p "Do you want to run this script? [Y/n] " response
if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
	echo "Cancel"
	exit 1
fi

while [ "$PW_IP" == "" ]; do
	read -p 'Enter Powerwall IP Address: ' PW_IP
done

# Detect OS and run commands accordingly
if [[ "${OS}" == "Linux" ]]; then
	    # Check if running under WSL
    if grep -qi "microsoft" /proc/version; then
        echo "WSL detected - unable to add route automatically."
        echo "To add the route, open an Administrator Shell in Windows and run:"
        echo "   route -p add ${TARGET_IP} mask ${NETMASK} ${PW_IP}"
        echo ""
        exit 1
    else
        echo "Native Linux detected"
		if $(ip route | grep -qw ${LINUX_IP}); then
			read -r -p "${LINUX_IP} routing already in routing table. Still want to run this? [y/N] " response
			if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				echo "Cancel"
				exit 1
			fi
		fi

		sudo mkdir -p ${DIR}

		if [ -f ${DIR}/${SCRIPT_NAME}.sh ]; then
			echo "Boot script already exists."
		else
		    echo ""
			cat > ${SCRIPT_NAME}.tmp << EOF
#!/bin/bash
declare -i i=0
while (( i < 15 )); do
    RETURN="\$(ip route add ${LINUX_IP} via ${PW_IP} 2>&1)"
    if [ "\$RETURN" != "RTNETLINK answers: File exists" ]; then
        declare -i i=i+1
        sleep 1
    else
        RETURN="Success"
        break
    fi
done

# Uncomment the lines below to log results of executing this script
# NOW="\$(date)"
# echo "\${NOW}: result=\${RETURN}, delay=\${i}" >> ${DIR}/${SCRIPT_NAME}.log

EOF
		chmod 775 ${SCRIPT_NAME}.tmp
		sudo chown 0 ${SCRIPT_NAME}.tmp
		sudo mv ${SCRIPT_NAME}.tmp ${DIR}/${SCRIPT_NAME}.sh
		fi

		if ! (sudo test -f ${CRONTAB})  || ! (sudo grep -qw "${DIR}/${SCRIPT_NAME}.sh" ${CRONTAB}); then
		    (sudo crontab -u root -l 2>/dev/null; echo "@reboot ${DIR}/${SCRIPT_NAME}.sh") | sudo crontab -u root -
	    	echo "Cron entry added."
		else
	    	echo "Cron line already exists."
		fi
		sudo /bin/bash ${DIR}/${SCRIPT_NAME}.sh
		echo "Installation complete."
		exit 0
	fi
elif [[ "${OS}" == "Darwin" ]]; then
    echo "macOS detected - adding permanent route for Wi-Fi"  # TODO: Support for other network interfaces (Ethernet, etc.)
    if sudo networksetup -setadditionalroutes Wi-Fi "${TARGET_IP}" "${NETMASK}" "${PW_IP}"; then
        echo "Route added successfully."
    else
        echo "Failed to add the route. Please check your network configuration or permissions."
        exit 1
    fi
    echo ""
    exit 0
elif [[ "${OS}" =~ MINGW* || "${OS}" =~ CYGWIN* ]]; then
    echo "Windows shell detected - attempting to add route automatically."
    if route -p add "${TARGET_IP}" mask "${NETMASK}" "${PW_IP}"; then
        echo "Route added successfully."
    else
        echo "Failed to add the route. Please ensure you are running as Administrator."
        exit 1
    fi
    echo ""
    exit 0
else
    echo "You are running '$OS', which is not supported in this script."
    echo "Maybe you could add code to support '$OS'!"
    exit 1
fi
