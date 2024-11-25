#!/bin/bash
#* Extrai informações do arquivo de configuração de roteador da marca Huawei,
#* Cisco e HP. 
#* 
#* router.sh <OPÇÕES> <ARQUIVO DE CONFIGURAÇÃO>
#*
#* OPÇÕES:
#*      --acl-number=* | --acl=* | -acl
#*          Lista as configurações das regras de controle de acesso, Access   
#*          Control List (ACL). As duas primeira formas mostram as ACLs em
#*          função de uma lista de números inteiros positivos separados por 
#*          vírgula, por exemplo, -acl=2000,3000,2505 ou -acl=all. A opção
#*          -acl lista todas as acls existentes com suas respectivas
#*          lista de regras.
#*
#*      -bgp=* | -bgp
#*          Mostra as configurações de bgp a partir de uma lista de números 
#*          inteiros positivos, por exemplo, -bgp=65192,65190 ou -bgp=all. 
#*          A opção sem  parâmetro, isto é, -bgp lista as configurações de  
#*          todos os bgps existentes.
#*
#*      --help | -h
#*          Lista as formas de uso deste comando
#*
#*      --interfaces=* | -int=* | -int
#*          Lista as configurações de interfaces. As duas primeiras formas 
#*          mostram as informações de configuração das interfaces especificadas
#*           com determinado prefixo, podendo ser uma expressão regular. Por 
#*          exemplo, -int=Ether, -int=.*0/0/12 ou --interfaces=all. A forma
#*          -int lista todas as interfaces existente com sua respectiva
#*          configuração.
#*
#*      --ike-peer=* | -ike=* | -ike
#*          Lista as definições de Internet Key Exchange (IKE), que determina o 
#*          gerenciamento seguro das chaves para um canal de comunicação seguro
#*          e autenticado entre dois dispositivos. As duas primeiras formas 
#*          listam as definições das IKEs cujos os nomes contenham o termo  
#*          informado, por exemplo, -ike=_ctc. As opções -ike, -ike=all e  
#*          --ike-peer=all listam todas IKEs existentes com suas respectivas 
#*          configurações
#*      
#*      --ike-proposal=* | ikp=* | -ikp
#*          Lista as propostas, que são um conjunto de parâmetros de negociação, 
#*          que podem ser utilizadas em uma IKE. As duas primeiras formas  
#*          listam as propostas cujos os nomes contenham o termo informado, por
#*          exemplo, -ikp=vpn. As opções --ike-proposal=all, -ikp=all e -ikp  
#*          listam todas propostas existentes.
#*
#*      --ip-prefix=* | -iprx=* | -iprx
#*	    Lista as regras de bloqueio ou permissão para determinadas  
#*          redes. As duas primeiras formas mostram as regras que contenham
#*          o termo informado, por exemplo -iprx=REDE_AG ou --ip-prefix=BGP_. 
#*          As opções --ip-prefix=all, -iprx=all e -iprx mostram todas as 
#*          regras definidas.
#*
#*      --ip-route-static=* | -iprs=* | -iprs
#*          Lista as regras de rota estática, que estabelece o destino do 
#*          próximo salto. As duas primeira opções filtra a lista em função
#*          de uma REGEX, por exemplo, --ip-route-static=10.122.0.16 ou 
#*          -ikp=vpn-instance. As opções --ip-route-static=all, -iprs=all e
#*	    -iprs listam as rotas definidas.
#*
#*      --ipsec-proposal=* | -ipro=* | -ipro
#*          Lista as propostas para IPSEC. Uma proposta é um conjunto de 
#*          parâmetros que definem como ocorrerá a negociação de associação, 
#*	    isto é, as fases da IPSEC SA. As duas primeiras formas mostram  
#*          as definições de propostas de vpn cujos os nomes contenham o termo 
#*	    informado, por exemplo, --ipsec-proposal=vpn ou -ipro=vpn_2.
#*          O termo pode ser uma expressão regular. As formas -ipro=all,
#*          --ipsec-proposal=all e -ipro mostram todas as propostas definidas
#*          com suas respectivas configurações.
#*
#*      --ipsec-policy=* | -ipol=* | -ipol
#*	    Lista as configurações das políticas de IPSEC SA, isto é, a vpn.
#*          As duas primeiras formas mostram as políticas atribuídas às ipsec
#*          cujos os nomes contenham o termo passado, por exemplo, -ipol=rede2.
#*	    As opções --ipsec-policy=all, -ipol=all e -ipol lista todas as
#*          políticas existentes.
#*
#*      --route-policy=*|-rpol=*|-rpol
#*	    Lista as políticas atribuídas que são usadas para filtrar as 
#*	    rotas e controlar como as rotas serão recebidas e publicadas.
#*          As duas primeiras formas mostram as políticas atribuídas às ipsec
#*          cujos os nomes contenham o termo passado, por exemplo, -ipol=rede2.
#*          O termo pode ser uma expressão regular que servirá como prefixo.
#*	    As formas --route-policy=all, -rpol=all e -rpol mostram todas as 
#*          as políticas às rotas existentes.
#*
#*      --version | -v
#*          Lista as versões deste script
#*
#@ Versão 0.01: 2024-10-17, lista as configurações de interfaces, bem como os 
#@              proposal e as políticas para o ipsec
#@
#@ Versão 0.02: 2024-10-19, criação das opções ajuda, acl, versionamento e 
#@              alerta de erro
#@
#@ Versão 0.03: 2024-10-19, correção de bug nas opções --acl-number, 
#@              --interfaces, --ipsec_policy e ipsec_proposal
#@
#@ Versão 0.04: 2024-10-29, as funcionalidades --interfaces, --ipsec_policy
#@              e --ipsec_proposal foram reescritas como uso de uma 
#@              funcionalidade comum: extrair_dados. De mesma forma, duas outras
#@              funcionalidades: --ike-peer e --ike-proposal
#@
#@ Versão 1.00: 2024-11-01, todas as funcionalidades agora são escritas a 
#@              a partir das funções teste_entrada, que ajusta o parâmetro
#@              informado, e extrair_dados, que captura as informações
#@              referentes a funcionalidade especificada. Agora o script
#@              conta com as seguintes funcionalidades: --acl-number, -bgp,
#@              --interfaces, --ike-peer, --ike-proposal, --ip-prefix
#@              --ip-route-static, --ipsec-policy, --ipsec-proposal,
#@              --route-policy, --help e --version
#
#* Autor: Albert Richard Moraes Lopes, 17 de Outubro, 2024

# Informa os detalhes do script a partir dos comentários iniciados por #*

# Informa o modo de uso e as opções disponíveis
function ajuda(){
    USO="USO: $(basename $0) [OPÇÕES]"
    DESCRICAO="$(
        grep -e "^#\*" $0 | 
        sed -e 's/^#\*//g'
    )"
    echo -e "$USO\n$DESCRICAO"
}

# Informa o uso incorreto do script, encerrando-o
function alerta(){
    echo "Erro: uso incorreto do comando $(basename $0)"
    echo "      Para mais informações, Utilize $(basename $0) -h"
    exit 1
}

function extrair_dados() {
    local OPERACAO="$1"
    local FILTRO="$2"
    local ROTEADOR="$3"
    
    # Como é utilizado expressão regular .*$FILTRO.* para encontrar as
    # interfaces, substui-se all por vazio, resultando na expressão regular
    # .*, isto é, qualquer nome de interface
    test "$FILTRO" == "all" && FILTRO=""
    
    # Captura os ipsec proposals em função do filtro especificado. Caso não 
    # seja especificado, todos os ipsec proposal existentes serão capturados
    NAMES=(
        $(
            egrep -o "^$OPERACAO .*$FILTRO.*" "$ROTEADOR" | 
                sed "s/$OPERACAO //g" | 
                cut -d' ' -f 1 | 
                sort |
                uniq
        )
    )
    
    # Para cada ipsec proposal capturado, lista-se as definições
    #for i in "${#NAMES[@]}"
    for (( i=0; i<${#NAMES[@]}; i++ ));
    do
        DATA="$(
            awk -v var="^$OPERACAO ${NAMES[$i]}" '
                $0 ~ var {
                    print; 
                    f = 1; 
                    next
                }
                f && /^ / {
                    print; 
                    next
                }
                /^#/ {
                    f = 0
                }
                /^[a-z]/ {
                    f = 0
                }
            ' $ROTEADOR)"
        
        test $i -ne 0 && QUEBRADELINHA="\n" || QUEBRADELINHA=""
        
        test ! -z "$DATA" &&
            echo -e "$DATA" | sed "s/^$OPERACAO /$QUEBRADELINHA$OPERACAO /g"
    done
}

# Informa as versões e suas respectivas alterações
function versoes(){
    VERSOES="$(
        grep -e "^#\@" $0 | 
        sed -e "s/^#@//g"

    )"
    echo "$VERSOES"
}

function tratar_entrada(){
    local PARAMETROS="$1"
    local OPERACAO="$2"
    local OPT="$3"
    local ROTEADOR="$4"
    local EH_LISTA="$5"

    # Valida a quantidade de parâmetros
    test $PARAMETROS -ne 2 && alerta
    # Caso exista, trata-se o parâmentro desta opção. Senão, considera-se
    # all como opção passada.
    
    if [ "$OPT" != "$OPERACAO" ] ; then
        optarg="$(echo $OPT | cut -d= -f2 )"
        test -z "$optarg" && alerta
    else
        optarg="all"
    fi
    
    # Se for especificado como lista, então o filtro será a REGEX 
    # (Num1|Num2|...|NumN). Do contrário, a REGEX em optarg será
    # ultilizada.
    if [ "$EH_LISTA" -eq 1 ] && [ "$optarg" != "all" ] ; then
    	FILTRO=$(
    		echo $optarg | 
    		sed 's/^/(/g;
    		     s/,/|/g;
    		     s/$/)/g'
    	)
    else
    	FILTRO=$optarg
    fi
    
    # Verifica se o próximo parâmetro corresponde a um arquivo de 
    # configuração de um router
    test ! -f "$ROTEADOR" && alerta
    
    echo "$FILTRO "$ROTEADOR""
}

# ------------------------------ Main Script ------------------------------- #

while test $# -gt 0
do
    case "${1}" in
        --acl-number=*|-acl=*|-acl)
           # Informa as configurações de acl a partir de uma lista
            PARMS=($(tratar_entrada $# "-acl" $1 $2 1))
            shift
            test ${#PARMS[@]} -eq 2 && 
                extrair_dados "acl number" ${PARMS[@]} || alerta
        ;;
        -bgp=*|-bgp)
           # Informa as configurações de bgp a partir de uma lista
            PARMS=($(tratar_entrada $# "-bgp" $1 $2 1))
            shift
            test ${#PARMS[@]} -eq 2 && 
               extrair_dados "bgp" ${PARMS[@]} || alerta
        ;;
        --interfaces=*|-int=*|-int)
            # Informa as configurações das interfaces a partir de uma Regex
            PARMS=($(tratar_entrada $# "-int" $1 $2 0))
            shift
            test ${#PARMS[@]} -eq 2 && 
                extrair_dados "interface" ${PARMS[@]} || alerta
        ;;
        --ike-peer=*|-ike=*|-ike)
            # Informa as ike peers a partir de uma regex
            PARMS=($(tratar_entrada $# "-ike" $1 $2 0))
            shift
            test ${#PARMS[@]} -eq 2 && 
                extrair_dados "ike peer" ${PARMS[@]} || alerta
        ;;
        --ike-proposal=*|-ikp=*|-ikp)
            # Informa as ike proposals a partir de uma regex
            PARMS=($(tratar_entrada $# "-ikp" $1 $2 0))
            shift
            test ${#PARMS[@]} -eq 2 && 
                extrair_dados "ike proposal" ${PARMS[@]} || alerta
        ;;
        --ip-prefix=*|-iprx=*|-iprx)
            PARMS=($(tratar_entrada $# "-iprx" $1 $2 0))
            shift
            test ${#PARMS[@]} -eq 2 && 
                extrair_dados "ip ip-prefix" ${PARMS[@]} | sed -e '/^$/d' || alerta
        ;;
        --ip-route-static=*|-iprs=*|-iprs)
            PARMS=($(tratar_entrada $# "-iprs" $1 $2 0))
            shift
            test ${#PARMS[@]} -eq 2 && 
                extrair_dados "ip route-static" ${PARMS[@]} | sed -e '/^$/d' || alerta
        ;;
        --ipsec-policy=*|-ipol=*|-ipol)
            # Informa as ipsec policies a partir de uma regex
            PARMS=($(tratar_entrada $# "-ipol" $1 $2 0))
            shift
            test ${#PARMS[@]} -eq 2 && 
                extrair_dados "ipsec policy" ${PARMS[@]} || alerta
        ;;
        --ipsec-proposal=*|-ipro=*|-ipro)
            # Informa as ipsec proposals a partir de uma regex
            PARMS=($(tratar_entrada $# "-ipro" $1 $2 0))
            shift
            test ${#PARMS[@]} -eq 2 && 
                extrair_dados "ipsec proposal" ${PARMS[@]} || alerta
        ;;
        --route-policy=*|-rpol=*|-rpol)
            PARMS=($(tratar_entrada $# "-rpol" $1 $2 0))
            shift
            test ${#PARMS[@]} -eq 2 && 
                extrair_dados "route-policy" ${PARMS[@]} || alerta
        ;;
        --help|-h)
            test $# -ne 1 && alerta
            ajuda
            exit
        ;;
        --version|-v)
            test $# -ne 1 && alerta
            versoes
            exit
        ;;
        *)
            alerta
            exit
        ;;
    esac
    shift
done
