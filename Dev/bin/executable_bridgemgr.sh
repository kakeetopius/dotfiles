#!/usr/bin/env bash

main() {
    if [[ "$#" -gt "3" ]]; then
	printMessage
	exit 1
    fi

    if [[ "$EUID" -ne "0" && "$1" != "-h" ]]; then 
	echo "This script must be run with root priviledges"
	exit 1
    fi

    case "$1" in
	"create")
	    createBridge "$2" "$3"
	    ;;
	"remove")
	    removeBridge "$2" "$3"
	    ;;
	"-h")
	    printMessage
	    exit 1
	    ;;
	"")
	    printMessage
	    exit 1
	    ;;
	*)
	    echo "Unknown command: $1"
	    echo "Use ./bridgemgr.sh -h for more info"
	    exit 1
	    ;;
    esac
}

createBridge() {
    local iface
    local addtap=0
    #if -t is given
    if [[ "$1" == "-t" ]]; then
	addtap=1
	iface="$2"
    else
	iface="$1"
    fi
    
    if [ -n "$iface" ]; then
	echo -e "Interface given: $iface\n"
	if [[ ! "$iface" =~ ^(enp[0-9].+|eth[0-9]{1,2})$ ]]; then
	    echo "$iface is not a valid ethernet interface"
	    exit 1
	fi
    else
	echo "No interface specified"
	echo "Searching for ethernet interfaces................."
	iface=$(searchIface)
	if [[ -z "$iface" ]]; then
	    echo "Could not detect any ethernet interfaces."
	    exit 1
	fi

	echo -e "Found interface: $iface\n"
    fi

    echo "Deleting nmcli connections related to $iface"
    nmcli_con=$(nmcli con show | grep "$iface" | awk '{print $(NF-2)}')
    nmcli con del $nmcli_con

    echo -e "\nCreating Bridge br0.............."
    nmcli con add type bridge con-name bridge_br0 ifname br0
    echo -e "Attaching $ifname to bridge br0....."
    local conname="br0-con1"
    nmcli con add type bridge-slave con-name "$conname" ifname "$ifname" master br0

    if [ "$addtap" -eq 1 ]; then
	echo -e "\nCreating tap interface tap0........."
	echo "Make sure to pass -t again when removing the bridge to delete this tap0 interface"
	ip tuntap add tap0 mode tap
	echo "Attaching tap0 to br0......"
	ip link set dev tap0 master br0
	ip link set dev tap0 up
    fi

    echo "Bringing bridge up.........."
    nmcli con up "$conname"

    echo -e "\nAttempting to start dhcp client on br0. Press Ctrl-C to abort........"
    dhclient -r br0
    dhclient -v br0
}

removeBridge() {
    local iface
    local deltap=0
    local message
    #if -t is given
    if [[ "$1" == "-t" ]]; then
	deltap=1
	iface="$2"
	message="Make sure the bridge br0 was created by this script with the specified ethernet interface and -t was passed during creation of bridge"
    else
	iface="$1"
	message="Make sure the bridge br0 was created by this script with the specified ethernet interface"
    fi
    
    echo $message
    read -p "Proceed(y|n): " opt
    if [[ "$opt" != "y" ]]; then
	exit 1
    fi


    if [ -n "$iface" ]; then
	echo -e "Interface given: $iface\n"
	if [[ ! "$iface" =~ ^(enp[0-9].+|eth[0-9]{1,2})$ ]]; then
	    echo "$iface is not a valid ethernet interface"
	    exit 1
	fi
    else
	echo "No interface specified"
	echo "Searching for ethernet interfaces................."
	iface=$(searchIface)
	if [[ -z "$iface" ]]; then
	    "Could not detect any ethernet interfaces."
	    exit 1
	fi

	echo -e "Found interface: $iface\n"
    fi

    echo "Deleting bridge and its connections........."
    nmcli con del bridge_br0 br0-con1
    
    if [ "$deltap" -eq 1 ]; then
	echo "Deleting tap0............."
	ip link del tap0
    fi

    echo "Attempting to restore connection on $iface. Press Ctrl-C to abort"
    nmcli con add type ethernet ifname "$iface"
}

searchIface() {
    local iface=$(ip link show | grep -E 'enp[0-9].+|eth[0-9]{1,2}.+' | awk '{print $2}' | tr -d ":" | head -1)
    echo $iface
}

printMessage() {
    echo -e "Usage: ./bridgemgr.sh [COMMAND] [OPTIONS] <interface>\n"
    echo "DESCRIPTION:"
    echo -e "This script creates a bridge and attaches the specified etherent interface to it and optionally a tap interface\n"
    echo "COMMANDS:"
    echo "create:  creates a bridge interface called br0"
    echo -e "remove:  removes a bridge interface called br0\n"
    echo "OPTIONS:"
    echo "-t: If COMMAND is create, option tells the script to create a tap interface and attach to the bridge"
    echo "    If COMMAND is remove, option tells the script to also remove the tap interface that was created"
    echo -e "-h: Show this help message\n"
    echo "NOTE:"
    echo "1. The script only works for ethernet interfaces"
    echo "2. If no interface is supplied the script attempts to find an ethernet interface and uses the first it finds."
    echo "3. If -t is specified a tap interface tap0 is created and attached to the bridge"
    echo "4. If no -t is specified only a bridge is created. This is the default behavior."
    echo "5. If specified COMMAND is remove make sure that the br0 was created by this very script because it uses custom connection names to delete the bridge"
    echo "6. Also if COMMAND is remove make sure to specify the interface to which the bridge was attached on creation. "
    echo "   If no interface is specified the script will try to remove the first ethernet interface it detects. It is safer to pass interface when removing."
}

main "$@"
