#!/bin/bash

# It retrieves network names from BGP
function bgp_names(){
    local CFG_FILE="$1"
    local NAMES=$(
        ( 
            ./router.sh -bgp "$CFG_FILE" | 
                tr -d '\r' |
                grep -o "group .* external" |
                cut -d' ' -f 2
        )
    )

    echo "${NAMES[@]}"
}

# It retrieves the remote IP linked to a specific network from BGP.
function bgp_ips(){
    local NAME_VPN="$1"
    local CFG_FILE="$2"

    local IPS=(
        $(
            ./router.sh -bgp "$CFG_FILE"| 
                tr -d '\r' |
                grep -o "peer .* group $NAME_VPN" | 
                sort | 
                uniq | 
                cut -d ' ' -f 2
        )
    )

    echo "${IPS[@]}"
}

# It retrieves the interface linked to a specific network from BGP. This can be 
# done using the remote IP or the network name.
function bgp_connect_interface(){
    local NAME_VPN="$1"
    local IP_VPN="$2"
    local CFG_FILE="$3"
    
    local CONNECT_INTERFACE=$(
        ./router.sh -bgp "$CFG_FILE" | 
            tr -d '\r' |
            egrep -o "peer ($NAME_VPN|$IP_VPN) connect-interface .*" | 
            cut -d ' ' -f 4
    )

    echo "$CONNECT_INTERFACE"
}

# It retrieves the description and IP address of a specific interface
function interface(){
    local CONNECT_INTERFACE="$1"
    local CFG_FILE="$2" 

    local CONTENT="$(
        ./router.sh -int=$CONNECT_INTERFACE "$CFG_FILE" | 
            tr -d '\r'  | 
            awk -v var="^interface $CONNECT_INTERFACE$" '
                $0 ~ var { 
                    print
                    f=1
                    next 
                } 
                f && /^ / { 
                    print
                    next 
                }
                /^$/ { 
                    f = 0 
                }'
    )"

    local IP=$(
        grep -o "ip address .*" <<< "$CONTENT" | 
        cut -d ' ' -f 3
    )

    local DESCRIPTION="$(
        grep -o "description .*" <<< "$CONTENT" | 
        sed 's/description //g'
    )"

    echo "$IP;$DESCRIPTION"
}

# It checks if the router configuration directory was passed.
# The script will stop if it wasn't.
[[ ! -z "$1" && -d "$1" ]] && CFG_DIR="$1" || exit

# It extracts all files in the array
CFG_FILES=("$(ls -1 $CFG_DIR)")

for FILE in ${CFG_FILES[@]}; 
do 
    # It puts complete path    
    CFG_FILE="$CFG_DIR/$FILE"

    # First, it retrieves the router name and all network names from BGP
    ROUTER=$(cut -d '.' -f 1 <<< $FILE)
    BGP_NAMES=($(bgp_names "$CFG_FILE"))
    
    # For each network name, it retrieves the IP remote linked to it
    for NAME_NETWORK in "${BGP_NAMES[@]}"
    do
        IPS=($(bgp_ips $NAME_NETWORK $CFG_FILE))

        # For each remote IP linked, it retrieves the associated interface.
        for IP_REMOTE in "${IPS[@]}"
        do
            CONNECT_INTERFACE=$(bgp_connect_interface $NAME_NETWORK $IP_REMOTE "$CFG_FILE")

            # If an interface is founded, it retrieves its description and the
            # IP address of it. Otherwise, it will be considered as empty
            # columns
            test ! -z "$CONNECT_INTERFACE" &&
                INFO_INTERFACE="$(interface $CONNECT_INTERFACE "$CFG_FILE")" || 
                INFO_INTERFACE=";"

            # It shows the results
            echo "$ROUTER;$NAME_NETWORK;$IP_REMOTE;$CONNECT_INTERFACE;$INFO_INTERFACE;"

            # It cleans variables
            CONNECT_INTERFACE=""
            INFO_INTERFACE=""
        done
    done
done