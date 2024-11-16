#!/bin/bash
#* ------------------------------------------------------------------------------
#*                            SCRIPT: sounding.sh
#* ------------------------------------------------------------------------------
#* Baixa as radiossondagens armazenadas nos servidores do departamento de 
#* ciências atmosféricas da Universidade de Wyoming: http://weather.uwyo.edu
#* 
#* Uso: ./sounding.sh <-e="..."> <-h="..."> <-d=...|-p=...> [-l="..."]         
#* 
#* As opções entre <> e [] são obrigatórias e facultativas, respectivamente. O
#* O simbolo | indica que somente umas das opções entre <> pode ser utilizada 
#* por vez.
#* 
#*      OPÇÃO           ARGUMENTO                     DESCRIÇÃO
#* -e, --estation  ="ID1 ID2 ... IDn"       IDs das estações meteorológicas
#* 
#* -h, --hour      =00 =12 ou ="00 12"      Horário UTC da radiossondagem
#* 
#* -d, --date      =AAAA/MM/DD              Data da radiossondagem desejada
#* 
#* -p, --period    =aaaa/mm/dd-AAAA/MM/DD   Período das radiossondagens: 
#*                                          início-fim
#* 
#* -l, --local     ="/PATH/"                Local para armazenamento
#* 
#* -h, --help                               Opção de ajuda               
#* 
#* Alguns exemplos de ids de estações meteorológicas:                        
#*	ESTAÇÃO 	ID   
#*	Belém   	82193
#* 	Boa Vista	82022
#* 	Manaus   	82332
#* 	Santarém	82244
#* 	São Luiz	82281
#* 
#* Exemplo de uso: ./sounding.sh -e=82193 -h="00 12" -p=2016/04/03-2016/06/27
#*   Baixa as radiossondagens realizadas em Belém no período entre 2016/04/03 e
#*   2016/06/27 nos horários de 00Z e 12Z. As radiossodagens serão armazenadas no
#*   diretório corrente por padrão.
#* 
#* Autor: Albert Richard M. L. <albert.richard@gmail.com>                      
#* GitHub: github.com/albertrml/scripts/tree/main/meteorologia/sounding.sh
#* Criado em: 01/11/2011
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
#% Sintaxe: ./sounding.sh [-v=<val> | --valor=<val>]
#% Para mais detalhes use: ./sounding.sh --help 

clear

USO="$0"
LINK="http://weather.uwyo.edu/cgi-bin/sounding?region=samer&TYPE=TEXT%3ALIST"

function collect_sounding(){
    local STATION="$1"
    local YEAR="$2"
    local MONTH="$3"
    local LAST_DAY=$(date -d "$YEAR-$MONTH-01 +1 month -1 day" +"%d")
    local LINK="http://weather.uwyo.edu/cgi-bin/sounding?region=samer&TYPE=TEXT%3ALIST&YEAR=$YEAR&MONTH=$MONTH&FROM=0100&TO="$LAST_DAY"18&STNM=$STATION"

    wget -c "$LINK" -O "$STATION-$YEAR$MONTH.html"
}

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

function extract_station(){
    local SOUNDINGFILE="$1" 
    TITLES="$(
		egrep -o "<H2>.*</H2>" $SOUNDINGFILE | 
		sed -E 's/<\/?H2>//g'
	)"
	
	STATION="$(cut -d' ' -f 2 <<< $TITLES | uniq)"
    
    echo $STATION
}

function filter_sounding(){
    local STATION="$1"
    local TABLES="$2"
    shift 2
    local -a DATES=("$@")
    
    for INDEX in "${!DATES[@]}"
    do
        NUMTAB=$(expr $INDEX + 1)
        CONTENT="$(awk -v ini="#$NUMTAB" -v fim="@$NUMTAB" '
            $0 ~ini, $0 ~ fim {
                print
            }' <<< $TABLES
        )"
        echo "$CONTENT" | sed -e '/^[#@][0-9]*/d' > "$STATION-${DATES[$INDEX]}.txt"
    done
}

#collectHTML 83378 2024 11
#DATES=($(extract_dates 83378-202411.html))
#TABLES="$(extract_tables 83378-202411.html)"
#filter_sounding 83378 "$TABLES" ${DATES[@]}

# -------------------------------------------------------------------------------

# ------------------------- FUNÇÕES DE OPÇÕES -----------------------------------

# MOSTRA AS OPÇÕES UTILIZAVÉIS DO COMANDO
ajuda() {
    DESCRICAO="$(
        grep -e "^#\*" $0 | 
        sed -e 's/^#\*//g'
    )"
    echo -e "$DESCRICAO"
	exit
}

# ALGORITMO DE EXTRAÇÃO DAS RADIOSSONDAGENS
# 1) Recebe o endereço completo do arquivo de dados brutos e o conjunto de horários das radiossondagens que o usuário deseja.
# 2) Filtra os cabeçalhos de todas as sondagens
# 3) Armazena todas as posições iniciais e finais das sondagens
# 4) Extrai as radiossondagens se o horário descrito no cabeçalho da radiossondagem coincidir com alguns dos horários deseja 
#    pelo usuário.
# 5) Armazena as sondagem nos arquivos com o seguinte formato: <Nome da Estação>-<ANO><MES><DIA><HORÁRIO>.txt
ext_sondagem(){

	ARQUIVO="$1"
	shift
	HORAS=("$@")
	
	CAMINHO=$(
   		echo $ARQUIVO | 
   		awk -F "/" '{for(i=1;i<NF;i++){printf "/%s",$i}; printf "\n"}'
   	)
   	
   	TITULO=(
   		$(
   			grep '<H2>[^H2>].*[^</H2]</H2>' "$ARQUIVO" | 
   			sed 's/<\/*H2>//g' | 
   			awk '{print $1":"$2":"$(NF-1)":"$(NF-2)":"$(NF-3)":"$NF}' | 
   			sed 's/Z//g'
   		)
   	)
   	
   	LINI=(
   		$(
   			grep -n "^<PRE>" "$ARQUIVO" | 
   			awk -F: '{print $1}'
   		)
   	)
   	
   	LFIM=(
   		$(
   			grep -n "^</PRE><H3>" "$ARQUIVO" | awk -F: '{print $1}'
   		)
   	)
   	
   	LTAM=${#TITULO[@]}
   	for i in $(seq $LTAM)
   	do
   		
   		read ESTACAO_NOME <<< $(
   			echo ${TITULO[$(expr $i-1)]} | awk -F ":" '{print $2}'
   		)
   		
   		read ANO MES DIA HORA <<< $(
   			date -d "$(echo ${TITULO[$(expr $i-1)]} | 
   			awk -F ':' '{print $(NF-3),$(NF-2),$(NF-1),$NF}')" +'%Y %m %d %H'
   		)
   		
   		for h in ${HORAS[*]}; 
   		do
   			test "$h" -eq "$HORA"  && (
   				head -$(expr ${LFIM[$(expr $i-1)]} - 1) "$ARQUIVO" | 
   				tail -$(expr ${LFIM[$(expr $i-1)]} - ${LINI[$(expr $i-1)]} - 1) > "$CAMINHO/$ESTACAO_NOME-$ANO$MES$DIA$HORA.txt"
   			)
   		done
   	done
   	
   	rm $ARQUIVO

}

# -------------------------------------------------------------------------------

# -------- FILTRO DE OPÇÕES ----------

while test $# -gt 0 ; do
	optarg=`echo $1 | cut -d= -f2 `
	case "${1}" in
	-d=*|--date=*)
		DATAINICIAL=$(date -I -d "$optarg") || 
			    (echo "Data inicial inválida" && exit)
		DATAFINAL=$DATAINICIAL
	;;
	-e=*|--estation=*)
		# Remove repetições
		optarg=$(echo $optarg | 
			 tr ' ' '\n' | 	# Transforma colunas em linhas
			 sort -u ) 	# Ordena e remove duplicações
		ID_ESTACOES=$optarg
	;;
	-h=*|--hour=*)

		# Remove repetições
		optarg=$(echo $optarg | 
			 tr ' ' '\n' | 	# Transforma colunas em linhas
			 sort -u | 	# Ordena e remove duplicações
			 tr '\n' ' ') 	# Transforma linhas em colunas			 

		for h in $optarg;
		do
			( test $h = "00" || test $h = "12" ) && 
				HORARIOS+="$h "
 		done
	
		HORARIOS=$(echo $HORARIOS | tr ' ' '\n')
	;;
	-h|--help)
		ajuda
	;;
	-l=*|--local=*)
		test ! -d "$optarg" && 
			echo "Local de armazenamento inacessível!" &&
			exit
		LOCAL=$optarg
	;;
	-p=*|--period=*)
		DATAINICIAL=$(date -I -d "$(echo $optarg | cut -d- -f1)") || 
			    (echo "Data inicial inválida" && exit)

		DATAFINAL=$(date -I -d "$(echo $optarg | cut -d- -f2)") || 
			    (echo "Data final inválida" && exit)
	;;
	-*)
		echo "Argumento $1 inválido."
		echo "Use a opção $USO --help!"
		exit	
	;;
	*)
		echo "Argumento $1 inválido."
                echo "Use a opção $USO--help!"
                exit
	;;	
	esac
	shift
done
# --------------------------------------------------------------------------------------------


# ---------------------------------- CODIGO PRINCIPAL ----------------------------------------
# GARANTE QUE AS VARIÁVEIS DE ENTRADA NÃO ESTÃO VAZIAS E, POR CONSEQUÊNCIA, O FUNCIONAMENTO
# DO SCRIPT.
test -z "$LOCAL" && 
	echo "Armazenando no diretório $PWD" &&
	LOCAL=$(pwd)

test -z "$ID_ESTACOES" && 
	echo "Informe o(s) ID(s) da(s) estação(ões)" && 
	echo "Para mais informações use: $USO --help" &&
	exit

test -z "$HORARIOS"&& 
	echo "Informe o(s) horário(s) das radiossondagens" && 
	echo "Para mais informações use: $USO --help" &&
	exit

test -z "$DATAINICIAL"&& 
	echo "Informe a data ou o período das radiossondagens" && 
	echo "Para mais informações use: $USO --help" &&
	exit

test -z "$DATAFINAL"&& 
	echo "Informe a data ou o período das radiossondagens" && 
	echo "Para mais informações use: $USO --help" &&
	exit

HORA_INICIAL=$(echo "$HORARIOS" | head -1)	# Determina a menor hora UTC informada
HORA_FINAL=$(echo "$HORARIOS" |  tail -1)	# Determina a maior hora UTC informada

# Algoritmo para o download dos dados brutos.
# 1) Entra com uma data inicial no formato AAAA/MM/DD.
# 2) Enquanto a data inicial (sem '\') for menor ou igual a data final ('sem '\''), faça:
#	a) Estabele o inicío e o fim do período no mês:
#		- No primeiro ciclo, o inicío coincide com a data inicial.
#		- O fim do ciclo coincide com o fim do mês, caso não seja superior a data final. 
#		      Se for, a data final será o fim.
#	b) Efetua o download da radiossondagens no período determinado no passo 2.a:
#		- O download é armazenado em um arquivo temporário no diretórío $LOCAL.
#	c) Chama a função ext_sondagem para separar as sondagens desejadas pelo usuário.
D_INICIAL="$DATAINICIAL"
while [ "$(date -d "$D_INICIAL" +'%Y%m%d')" -le "$(date -d "$DATAFINAL" +'%Y%m%d')" ] 
do
	TEMP=$(date -d "$D_INICIAL" +'%Y-%m-01')
	D_FINAL=$(date -I -d "$TEMP + 1 month yesterday")
	if [ "$(date -d "$D_FINAL" +'%Y%m%d')" -le "$(date -d "$DATAFINAL" +'%Y%m%d')" ]
	   then 
		echo "$D_INICIAL --- $D_FINAL"
		for ESTACAO in $ID_ESTACOES; do
			read IANO IMES IDIA IHORA <<< $(date -d "$D_INICIAL $HORA_INICIAL" +'%Y %m %d %H')
			read FANO FMES FDIA FHORA <<< $(date -d "$D_FINAL $HORA_FINAL" +'%Y %m %d %H')
			wget -c "$LINK&YEAR=$IANO&MONTH=$IMES&FROM=$IDIA$IHORA&TO=$FDIA$FHORA&STNM=$ESTACAO" -O "$LOCAL/$ESTACAO-$IANO$IMES.txt"
			VET=($(echo "$HORARIOS"))
			ARQ="$LOCAL/$ESTACAO-$IANO$IMES.txt"
			ext_sondagem "${ARQ}" "${VET[@]}" 
		done
	   else 
		echo "$D_INICIAL --- $DATAFINAL"
		for ESTACAO in $ID_ESTACOES; do
			read IANO IMES IDIA IHORA <<< $(date -d "$D_INICIAL $HORA_INICIAL" +'%Y %m %d %H')
			read FANO FMES FDIA FHORA <<< $(date -d "$DATAFINAL $HORA_FINAL" +'%Y %m %d %H')
			wget -c "$LINK&YEAR=$IANO&MONTH=$IMES&FROM=$IDIA$IHORA&TO=$FDIA$FHORA&STNM=$ESTACAO" -O "$LOCAL/$ESTACAO-$IANO$IMES.txt"
			VET=($(echo "$HORARIOS"))
			ARQ="$LOCAL/$ESTACAO-$IANO$IMES.txt"
			ext_sondagem "${ARQ}" "${VET[@]}"
		done
	fi
	D_INICIAL=$(date -I -d "$TEMP + 1 month")
done
