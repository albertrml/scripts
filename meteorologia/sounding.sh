#!/bin/bash
* ------------------------------------------------------------------------------
#*                            SCRIPT: sounding.sh
#* ------------------------------------------------------------------------------
#* This script retrieves sounding data from the Atmospheric Sciences server at  
#* Wyoming University: http://weather.uwyo.edu. We can execute it as follows:
#*
#* Uso: ./sounding.sh <-s="..."> <-h="..."> <-d=...|-p=...> [-l="..."]         
#* 
#* The options between <> and [] are mandatories and optionals, respectively. 
#* The | symbols points out to exclusives ways for some option. 
#*
#* OPTION          ARGUMENT                 DESCRIPTION
#*
#* -s, --station   =82193 ou =82281         Upper-Air Station ID
#* 
#* -h, --hour      =00 =12 ou ="00 12"      Sounding time in UTC
#* 
#* -d, --date      =AAAA/MM/DD              Specific sounding date
#* 
#* -p, --period    =aaaa/mm/dd-AAAA/MM/DD   Sounding period
#* 
#* -l, --local     ="/PATH/"                A path to retrieve sounding data
#* 
#* -h, --help                               Shows how to use sounding command              
#* 
#* Use case: ./sounding.sh -s=82193 -h="00 12" -p=2016/04/03-2016/06/27
#* 
#* The user will retrieve sounding data from the SBBE station from 2016/04/03 to 
#* 2016/06/27 at 00Z and 12Z. Since no path was specified, the sounding data will 
#* be stored in the current location.
#* 
#* Author: Albert Richard M. L. <albertrml.dev@gmail.com>                      
#* GitHub: github.com/albertrml/scripts/tree/main/meteorologia/sounding.sh
#* Criado em: 2011-11-01
#* ------------------------------------------------------------------------------
#@ Modificado em: 
#@ 	2011-11-01: Flexibilidade para determinar o local onde será armazenado as
#@ 		    	sondagens.
#@ 
#@	2012-04-06: Flexibilidade para: especificar o dia de download ou intervalo de
#@ 				dias; determinar os horário de sondagens, sendo o padrão somente
#@ 				às 00; especificar o conjunto de estações,sendo o padrão: 82244,
#@ 				82281, 82099, 82193, 82022, 82332 e 83065.
#@ 
#@	2012-04-08: Alterações dos nomes das seguintes variáveis
#@				ESTACOES --> ID_ESTACOES
#@				SAIDA    --> ESTACAO
#@				estacao  --> id_estacao
#@ 
#@	2016-11-21: Funcionamento interno: os downloads das sondagens (arquivo
#@  		    temporário) por mês-a-mês ao invés de dia-a-dia. Script não
#@ 		    	está funcionando.
#@ 		  
#@	2016-11-24: Implementação dos novos mecanismos de download de dados brutos
#@				e de extração das sondagens (via função ext_sondagem), ambos
#@	 		    implementados e não testados. Alterações no nome do script de 
#@ 			    get_sounding.sh para dw_sondagem.sh e na estrutura da função 
#@ 			    ajuda. Inserção de opções de segurança nas opções de execução.
#@ 
#@	2016-11-25: Mecanismos ajustados e operacionais: download de dados brutos 
#@ 		  		e extração das sondagens (via função ext_sondagem). Inserção
#@ 		    	do endereço para contribuições e relatar bugs.
#@ 
#@	2024-11-15: Refatoração da função ajuste.
#@ 
#@	2024-11-21: We updated the entire script from scratch and rebuilt it in 
#@				English. Now, we can retrieve a set of sounding data by date 
#@				or period at specific times for a single station.
#@

clear

USO="$0"

# ------------------------- FUNÇÕES DE OPÇÕES -----------------------------------

# It extracts all dates from html sounding file.
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

# It extracts all tables delimited, for example, between #1 and @1, and so forth
# from html sounding file.
function extract_tables(){
    local SOUNDINGFILE="$1" 
        
    TABELAS="$(awk '
        /<H2>/,/<\/H2>/ { 
                tabini++
                print "#" tabini 
        } 
        /<PRE>/,/<\/PRE>/ { 
                print 
        } ; /<\/PRE><H3>/,/<\/H3><PRE>/ {
                tabfim++ 
                print "@" tabfim
        }' $SOUNDINGFILE | sed '/^<.*>/d')"

	echo "$TABELAS"
}

# It extracts the station name from sounding file.
function extract_station(){
    local SOUNDING_FILE="$1" 
    TITLES="$(
		egrep -o "<H2>.*</H2>" $SOUNDING_FILE | 
		sed -E 's/<\/?H2>//g'
	)"
	
	STATION_NAME="$(cut -d' ' -f 2 <<< $TITLES | uniq)"
    
    echo $STATION_NAME
}

# Staring from an array of dates, it filters the dates that fall between FIRST_DAY
# and LAST_DAY.
function filter_dates(){
	local FIRST_DAY="${1//\//}"
	local LAST_DAY="${2//\//}"
	shift 2
	local -a DATES=("$@")

	for i in ${!DATES[@]}
	do
		CURRENTDAY="${DATES[$i]:0:8}"
		if [[ "$CURRENTDAY" -ge "$FIRST_DAY" && "$CURRENTDAY" -le "$LAST_DAY" ]]
        then 
            echo "$(($i+1));${DATES[$i]}"
        fi
	done
}

# Starting from a specific date, it fetchs a month's sounding data from a 
# station in an HTML file.
function fetch_html(){
    local STATION_ID="$1"
    local DATE="$2"
    local HTML_FILE="$3"
    local YEAR="$(date -d "$DATE" +"%Y")"
    local MONTH="$(date -d "$DATE" +"%m")"
    local LAST_DAY=$(date -d "$YEAR-$MONTH-01 +1 month -1 day" +"%d")
    local LINK="http://weather.uwyo.edu/cgi-bin/sounding?region=samer&TYPE=TEXT%3ALIST&"
    LINK+="YEAR=$YEAR&MONTH=$MONTH&FROM=0100&TO="$LAST_DAY"18&STNM=$STATION_ID"

    wget -c "$LINK" -O "$HTML_FILE"
}

# It shows how to use this scripts
function help() {
    DESCRIPTION="$(
        grep -e "^#\*" $0 | 
        sed -e 's/^#\*//g'
    )"
    echo -e "$DESCRIPTION"
	exit
}

# It retrieves a single sounding file from the month's sounding data extracted by
# extract_tables and saves it in a TXT file, named after the station name and the 
# corresponding date, for instance, SBBE-2024111900.txt.
function retrieve_sounding(){
    local STATION_NAME="$1"
    local TABLES="$2"
    local SOUNDING_PATH="$3"
    shift 3
    local -a SELECTED_DATES=("$@")
    
    for ITEM in "${SELECTED_DATES[@]}"
    do
        local OLD_IFS="$IFS"
        IFS=';' read -r NUMTAB DATE <<< $ITEM
        IFS="$IFS"

        local CONTENT
        CONTENT="$(awk -v ini="#$NUMTAB" -v fim="@$NUMTAB" '
            $0 ~ini, $0 ~ fim {
                print
            }' <<< $TABLES
        )"
        echo "$CONTENT" | 
             sed -e '/^[#@][0-9]*/d' > "$SOUNDING_PATH/$STATION_NAME-${DATE}.txt"

    done
}

# It validates the input based on a REGEX. If it doesn't match, it sends an error
# message and stops the script.
function validate_format(){
    local PAR="$1"
    local REGEX="$2"
    local ERR_MSG="$3"

    test ! $(egrep "$REGEX" <<< "$PAR" ) && 
        echo $ERR_MSG && 
        exit
}

# It validates the path to the sounding data and sends an error message if the
# directory doesn't exist or can't be created.
function validate_path(){
    local SOUNDING_PATH="$1"
    local ERR_MSG="$2"

    test ! -d "$SOUNDING_PATH" && ! mkdir -p "$SOUNDING_PATH" &>/dev/null && 
        echo $ERR_MSG &&
        exit
}

# It checks if initial variables are set.
function validate_execution(){
    local STATION_ID="$1"
    local FIRST_DAY="$2"
    local LAST_DAY="$3"

    test -z "$STATION_ID" &&
        echo "The station wasn't informed!" &&
        exit

    test -z "$FIRST_DAY" &&
        echo "The initial day wasn't informed!" &&
        exit

    test -z "$FIRST_DAY" &&
        echo "The last day wasn't informed!" &&
        exit
}

while test $# -gt 0 ; do
	optarg="$(echo $1 | cut -d '=' -f 2)"
	case "${1}" in
	    -d=*|--date=*)
		    FIRST_DAY=$optarg
		    LAST_DAY="$FIRST_DAY"
            ERR_MSG="Invalid date format"
            validate_format "$FIRST_DAY" "[0-9]{4}(/[0-9]{2}){2}" "$ERR_MSG"
	    ;;
	    -h|--help)
		    help
	    ;;
	    -l=*|--local=*)
            SOUNDING_PATH=$optarg
            ERR_MSG="The directory for sounding doesn't exist or it can't be "
            ERR_MSG+="created"
    		validate_path "$SOUNDING_PATH" "$ERR_MSG"
	    ;;
	    -p=*|--period=*)
            OLD_IFS="$IFS"
            IFS='-' read -r FIRST_DAY LAST_DAY <<< "$optarg"
            IFS="$IFS"
            ERR_MSG="Invalid date format for first day"
            validate_format "$FIRST_DAY" "[0-9]{4}(/[0-9]{2}){2}" "$ERR_MSG"
            ERR_MSG="Invalid date format for last day"
            validate_format "$LAST_DAY" "[0-9]{4}(/[0-9]{2}){2}" "$ERR_MSG"
	    ;;
        -s=*|--station=*)
		    STATION_ID=$optarg
            ERR_MSG="Invalid id station format"
            validate_format "$STATION_ID" "[0-9]{5}" "$ERR_MSG"
    	;;
	    *)
            echo "Use $USO --help or $USO -h for more information"
            exit
	    ;;	
	esac
	shift
done

test -z "$SOUNDING_PATH" && SOUNDING_PATH="$(pwd)"
validate_execution "$STATION_ID" "$FIRST_DAY" "$LAST_DAY"

CURRENTDAY=$(date -d "$FIRST_DAY" +"%Y-%m-01")
while [[ "${CURRENTDAY//\//}" -le "${LAST_DAY//\//}" ]]
do
    
    HTML_FILE="$SOUNDING_PATH/.$STATION_ID-$(date -d "$CURRENTDAY" +"%Y%m").html"

    fetch_html "$STATION_ID" "$CURRENTDAY" "$HTML_FILE"
    
    if [ ! -z "$HTML_FILE" ]
    then
        DATES=($(extract_dates "$HTML_FILE"))
        SELECTED_DATES=("$(filter_dates $FIRST_DAY $LAST_DAY ${DATES[@]})")

        STATION=$(extract_station "$HTML_FILE")
        TABLES="$(extract_tables "$HTML_FILE")"
        retrieve_sounding "$STATION" "$TABLES" "$SOUNDING_PATH" ${SELECTED_DATES[@]}

        rm $HTML_FILE
    fi

    CURRENTDAY=$(date -d "$CURRENTDAY +1 month" +"%Y/%m/%d")
done