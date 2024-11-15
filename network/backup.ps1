# Propósito: realiza o backup dos arquivos de configurações dos roteadores 
#            da marca Huawei e HP.
#
# USO: .\backup_router.ps1 -entrada <PATH\ARQUIVO> -ip <X.Y.Z.W>
#
# <PATH\ARQUIVO> Precedido de seu caminho, o arquivo contém a lista de roteadores
#           que se deseja obter o backup.  
#
# <X.Y.Z.W> Endereço IP do host que abrigará o backup da configuração do 
#           roteador  
#
# Pré-requisito: 
#           1) Configurar e executar previamente o programa tftp, definindo
#              ip da máquina host e da localização raiz para armazenar os 
#              backups. Não confundir com <PATH\ARQUIVO>, que é o caminho que 
#              tem como raiz o caminho configurado no tftp. 
#           2) Instalar o SSH
#           3) Instalar o plink, que permitirá o login diretamente via linha
#              de comando
#
# Definição: Script escrito em PowerShell, backup_router realiza o backup de
#            um conjunto de roteadores. De posse da lista de nomes lógicos dos
#            roteadores e do endereço de host destino, o script irá pedir o
#            as credenciais de acesso aos roteadores (login e senha) para
#            realizar o backup dos equipamentos. O acesso a cada roteador se 
#            dará por túnel ssh via plink, que permite transmissão das
#            credenciais via linha de comando. Por razão de segurança, a senha
#            é ocultada durante a inserção inicial. Recomenda-se, previamente a 
#            comunicação com cada roteador a fim de que o host já possua as
#            chaves criptográficas necessárias para a comunicação, evitando, 
#            assim, processos manuais de confirmação. O backup será armazenado 
#            na pasta nomeada com o data yyyy-mm-dd corrente, localizada no 
#            diretório especificado no tftp 


# Caminho do arquivo com a lista de nomes de roteadores
param=(
    [string]$entrada,
    [string]$ip
)

if (-not (Test-Path $entrada)) {
    Write-Host "Arquivos com a lista de roteadores não foi informada!"
    exit
}

if (-not $ip){
    Write-Host "Ip do host onde será armazenado o backup não foi informado!"
    exit
}

# Lê a conta do usuário
$conta = Read-Host -Prompt "Login"

# Lê a senha do usuário de forma oculta
$senha = Read-Host -Prompt "Senha" -AsSecureString

# Converte a senha segura para o texto plano
$senhaTxT = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($senha))

# Diretório base onde serão armazenados os resultados, usando a data atual. Criar o diretório base se não existir
$data = (Get-Date -Format "yyyy-MM-dd")
$baseDir = "$PSScriptRoot\$data"
if (!(Test-Path -Path $baseDir)) {
    New-Item -ItemType Directory -Path $baseDir | Out-Null
}

# Itera sobre cada roteador informado no arquivo de entrada
Get-Content $entrada | ForEach-Object {
    $item = $_

    Write-Output "Roteador: $item"

    # Dado o nome lógico, aplicar a estrutura mais adequada de diretório para 
    # armazenar o backup. Neste exemplo, irei armazenar o backup no $baseDir
    $nameFileOutput = $item.Replace('.','_')
    $fileOutPut = "$baseDir\$nameFileOutput.zip"
    

    # Configura a túnel ssh com logon via linha de comando
    $session = New-Object -TypeName System.Diagnostics.Process
    $session.StartInfo.Filename = "plink"
    $session.StartInfo.Arguments = "-ssh -pw $senhaTexto $conta@item"
    $session.StartInfo.RedirectStandardInput = $true
    $session.StartInfo.RedirectStandardOutput = $true
    $session.StartInfo.UseShellExecute = $false
    $session.StartInfo.CreateNoWindow = $true
    $session.Start()

    # Realiza a transferência do backup para a estação desejada, imprimindo o 
    # comando no console. O arquivo vrpcfg.zip geralmente é o arquivo de backup
    # em roteador huawei. Algumas vezes o arquivo não está em .zip, mas em cfg.
    # No caso de roteadores HP, o arquivo é backupftp.cfg. O mais prudente é
    # estudar como estão sendo armazenado o backup e, se for o caso, substituir
    # o vrpcfg.zip pelo que for.
    $session.StandardInput.WriteLine("tftp $ip put vrpcfg.zip $fileOutPut")
    $session.StandardOutput.ReadToEnd() | Write-Output
    $session.StandardInput.WriteLine("quit")

}
