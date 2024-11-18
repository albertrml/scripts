#!/bin/bash

function extract_dates() {
    local SOUNDINGFILE="$1"
    local TITLES="$(
		egrep -o "<H2>.*</H2>" $SOUNDINGFILE | 
		sed -E 's/<\/?H2>//g'
	)"
    
    # Extrai as informações sobre data
    local DATA="$(sed 's/.*at //' <<< $TITLES)"
    
    local DATES=()
    while read -r line; do 
        # Converter para o formato desejado com 'date'
        formatted_date=$(date -d "$line" -u +"%Y%m%d%H")
        DATES+=("$formatted_date")
    done <<< "$DATA"
    
    echo "${DATES[@]}"
}

function filter_dates(){
	local FIRSTDAY="$1"
	local LASTDAY="$2"
	shift 2
	local -a DATES=("$@")

	for i in ${!DATES[@]}
	do
		CURRENTDAY="${DATES[$i]:0:8}"
        echo "$FIRSTDAY -- $CURRENTDAY -- $LASTDAY"
		if [[ "$CURRENTDAY" -ge "$FIRSTDAY" && "$CURRENTDAY" -le "$LASTDAY" ]]
        then 
            echo "$i;${DATES[$i]}"
        fi
	done
}

DATES=($(extract_dates saida.html))
filter_dates "2024-11-09" "2024-11-11" ${DATES[@]}