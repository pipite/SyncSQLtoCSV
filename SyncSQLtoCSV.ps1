# SyncSQL-MasterToSlave.ps1

# --------------------------------------------------------
#               Chargement fichier .ini
# --------------------------------------------------------

function LoadIni {
	# initialisation variables liste des logs
	$script:pathfilelog = @()
	$script:pathfileerr = @()
	$script:pathfileina = @()
	$script:pathfiledlt = @()
	$script:pathfilemod = @()
	
	# sections de base du fichier .ini
	$script:cfg = @{
        "start"                   = @{}
        "intf"                    = @{}
        "email"                   = @{}
    }
    # Recuperation des parametres passes au script 
    $script:execok  = $false

    if (-not(Test-Path $($script:cfgFile) -PathType Leaf)) { Write-Host "Fichier de parametrage $script:cfgFile innexistant"; exit 1 }
    Write-Host "Fichier de parametrage $script:cfgFile"

    # Initialisation des sections parametres.
    $script:start    = [System.Diagnostics.Stopwatch]::startNew()
    $script:MailErr  = $false
    $script:WARNING  = 0
    $script:ERREUR   = 0
	
	$script:emailtxt = New-Object 'System.Collections.Generic.List[string]'

	$script:cfg = Add-IniFiles $script:cfg $script:cfgFile

	# Recherche des chemins de tous les fichiers et verification de leur existence
	if (-not ($script:cfg["intf"].ContainsKey("rootpath")) ) {
		$script:cfg["intf"]["rootpath"] = $PSScriptRoot
	}
	$script:cfg["intf"]["pathfilelog"] 	= GetFilePath $script:cfg["intf"]["pathfilelog"]
	$script:cfg["intf"]["pathfileerr"]	= GetFilePath $script:cfg["intf"]["pathfileerr"]
	$script:cfg["intf"]["pathfilemod"]  = GetFilePath $script:cfg["intf"]["pathfilemod"]

	$script:cfg["CSV"]["filepath"]      = GetFilePath $script:cfg["CSV"]["filepath"]

	# Suppression des fichiers One_Shot
	if ((Test-Path $($script:cfg["intf"]["pathfilelog"]) -PathType Leaf)) { Remove-Item -Path $script:cfg["intf"]["pathfilelog"]}    

	# Création des fichiers innexistants
	$null = New-Item -type file $($script:cfg["intf"]["pathfilelog"]) -Force;
	if (-not(Test-Path $($script:cfg["intf"]["pathfileerr"]) -PathType Leaf)) { $null = New-Item -type file $($script:cfg["intf"]["pathfileerr"]) -Force; }
	if (-not(Test-Path $($script:cfg["intf"]["pathfilemod"]) -PathType Leaf)) { $null = New-Item -type file $($script:cfg["intf"]["pathfilemod"]) -Force; }
}

function Query_SQL_SRC {
    $script:SQLSRC = Get-BDDConnectionParams "SQL_SRC"
	$script:BDDMASTER = @{}
	
	# Récupération de la liste des tables à synchroniser
	$keycol = $script:SQLSRC.key -split ','		
	LOG "Query_SQL_SRC" "Traitement de la table Master: $($script:SQLSRC.table)"
	Query_BDDTable -params $script:SQLSRC -functionName "Query_SQL_SRC" -keyColumns $keycol -targetVariable $script:BDDMASTER -UseFrmtDateOUT
}

function ConvertToCSV {
	# creation du header
	if ($script:BDDMASTER.Count -gt 0) {
		# Récupérer les noms des colonnes du premier enregistrement
		$firstRecord = $script:BDDMASTER.Values | Select-Object -First 1
		$header = ($firstRecord.Keys | Sort-Object) -join $script:cfg["CSV"]["Delimiter"]
	} else {
		$header = ""
	}

	# convertir en fichier .csv
	ExportCsv $script:cfg["CSV"]["filepath"] $script:BDDMASTER $header $script:cfg["CSV"]["Delimiter"]
}
function Get-BDDConnectionParams {
    param ($section)
    return @{
        server      = $script:cfg[$section]["server"]
        database    = $script:cfg[$section]["database"]
        login       = $script:cfg[$section]["login"]
        table       = $script:cfg[$section]["table"]
		key         = $script:cfg[$section]["key"]
        password    = Encode $script:cfg[$section]["password"]
        datefrmtout = $script:cfg[$section]["SQLformatDate"]
    }
}

# Fonction utilitaire pour effectuer une requête BDD standard
function Query_BDDTable {
    param(
        [hashtable]$params,
        [string]$functionName,
        [array]$keyColumns,
        [hashtable]$targetVariable,
        [switch]$UseFrmtDateOUT
    )
    
    LOG $functionName "Chargement de la table [$($params.table)] en memoire" -CRLF
    
    # Vider la hashtable cible
    $targetVariable.Clear()
    
    # Paramètres pour QueryTable
    $queryParams = @{
        server = $params.server
        database = $params.database
        table = $params.table
        login = $params.login
        password = $params.password
        keycolumns = $keyColumns
    }
    
    # Ajouter le format de date si demandé
    if ($UseFrmtDateOUT) {
        $queryParams.frmtdateOUT = $params.datefrmtout
    }
    
    # Exécuter la requête et affecter le résultat
    $result = QueryTable @queryParams
    
    # Copier le résultat dans la variable cible
    foreach ($key in $result.Keys) {
        $targetVariable[$key] = $result[$key]
    }
}
# --------------------------------------------------------
#               Main
# --------------------------------------------------------

# --------------------------------------------------------
#               Main
# --------------------------------------------------------
	# Chargement des modules
	$pathmodule = "$PSScriptRoot\Modules"

	if (Test-Path "$pathmodule\Ini.ps1" -PathType Leaf) {
		. "$pathmodule\Ini.ps1" > $null 
	} else {
		Write-Host "Fichier manquant : $pathmodule\Ini.ps1" -ForegroundColor Red
		exit (1)
	}
	. (GetPathScript "$pathmodule\Log.ps1")        > $null
	. (GetPathScript "$pathmodule\Encode.ps1")     > $null
	. (GetPathScript "$pathmodule\StrConvert.ps1") > $null
	. (GetPathScript "$pathmodule\Csv.ps1")        > $null
	. (GetPathScript "$pathmodule\SendEmail.ps1")  > $null

	# Détermination du fichier de configuration
	if ($args.Count -gt 0 -and $args[0]) {
		# Si un paramètre est passé, l'utiliser comme nom du fichier .ini
		$script:cfgFile = "$PSScriptRoot\$($args[0])"
	} else {
		# Sinon, utiliser le nom du script avec l'extension .ini
		$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
		$script:cfgFile = "$PSScriptRoot\$scriptName.ini"
	}
	LoadIni

	# Parametrage console en UFT8 (chcp 65001 ou 850) pour carractères accentués
	SetConsoleToUFT8

	. (GetPathScript "$pathmodule\SQL - Transaction.ps1") > $null
	if ($script:cfg["start"]["TransacSQL"] -eq "AllInOne" ) {
		. (GetPathScript "$pathmodule\SQLServer - TransactionAllInOne.ps1") > $null
	} else {
		. (GetPathScript "$pathmodule\SQLServer - TransactionOneByOne.ps1") > $null
	}

LOG "MAIN" "Synchronisation BDD ADMIN-Master vers ADMIN-Slave" -CRLF...

Query_SQL_SRC
ConvertToCSV

QUIT "MAIN" "Process terminé"


