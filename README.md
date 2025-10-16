# Vue d'ensemble

**SyncSQLtoCSV.ps1** est un script PowerShell d'exportation de données SQL Server vers fichier CSV

Le script exporte les données d'une table SQL Server vers un fichier CSV avec un délimiteur configurable.

* Source de données provenant de bases de données **SQL Server**
* Exporte une table spécifiée vers un fichier CSV
* Gère le formatage des dates et le délimiteur personnalisé

## Comment installer ce script

* PowerShell 7 ou supérieur
* Accès à la base de données SQL Server

Recuperer le script sur GitLAB, et déposer les fichiers dans un répertoire du serveur de Script.

### Modules externes

Recuperer les modules nécessaire sur GitLAB, et les déposer dans le répertoire Modules du script.

* **Ini.ps1** : Gestion des fichiers de configuration .ini
* **Log.ps1** : Gestion des logs et messages (LOG, ERR, WRN, DBG, MOD)
* **Encode.ps1** : Encodage/décodage des mots de passe
* **CSV.ps1** : Lecture et traitement des fichiers CSV
* **SendEmail.ps1** : Envoi d'emails de notification
* **StrConvert.ps1** : Conversion de chaînes de caractères et encodage UTF-8
* **SQLServer - TransactionOneByOne.ps1** : Module de transaction SQL (mode OneByOne)
* **SQLServer - TransactionAllInOne.ps1** : Module de transaction SQL (mode AllInOne)
* **SQL - Transaction.ps1**

Paramétrer le fichier SyncSQLtoCSV.ini

## Sources des données  

|                   Paramètres .ini                   |                    Description                     |
| --------------------------------------------------- | -------------------------------------------------- |
| [**SQL_SRC**]                                       | Base de données source (SQL Server)               |
| [**CSV**]                                           | Configuration du fichier CSV de destination       |


## Table exportée

La table à exporter est définie dans les paramètres de configuration :

|                   Paramètres .ini                   |            Description            |
| --------------------------------------------------- | --------------------------------- |
| [SQL_SRC][table]                                    | Nom de la table à exporter        |
| [SQL_SRC][key]                                      | Colonne(s) clé(s) de la table     |


## Principe du traitement

Le script effectue une **exportation des données d'une table SQL Server vers un fichier CSV**.

* Charge les données depuis la **base SQL Server source**
* Convertit les données en format CSV avec le délimiteur spécifié
* Génère automatiquement l'en-tête du fichier CSV à partir des colonnes de la table
* Applique le formatage de date défini dans la configuration
* Écrit le fichier CSV dans le chemin spécifié

**Nota important** : *L'exportation utilise la clé primaire définie dans [SQL_SRC][key] pour indexer les données en mémoire.*

# Traitements

* LoadIni
* Query_SQL_SRC
* ConvertToCSV

### LoadIni

Charge et initialise les paramètres de configuration depuis le fichier .ini.

* Charge le fichier de configuration via le module **Ini.ps1** (fonction `Add-IniFiles`)
* Initialise les variables de log et d'erreur
* Résout les chemins des fichiers via la fonction `GetFilePath`
* Crée les fichiers de log nécessaires
* Supprime le fichier de log One-Shot de l'exécution précédente

**Modules appelés** :
* `Add-IniFiles` : Charge et parse le fichier .ini
* `GetFilePath` : Résout les chemins de fichiers avec substitution de variables

### Query_SQL_SRC

Charge en mémoire le contenu de la **table source SQL Server** et la convertit en hash table.

* Récupère les paramètres de connexion via `Get-BDDConnectionParams`
* Se connecte à la base SQL Server définie dans [**SQL_SRC**]
* Récupère toutes les données de la table spécifiée dans [SQL_SRC][table]
* Utilise la clé définie dans [SQL_SRC][key] pour indexer les données
* Applique le formatage de date défini dans [SQL_SRC][SQLformatDate]
* Stocke les données dans la variable `$script:BDDMASTER`

**Modules appelés** :
* `QueryTable` : Exécute la requête SQL et retourne les données sous forme de hash table

### ConvertToCSV

Convertit les données chargées en mémoire vers un fichier CSV.

* Génère automatiquement l'en-tête CSV à partir des noms de colonnes du premier enregistrement
* Utilise le délimiteur défini dans [CSV][Delimiter]
* Exporte les données vers le fichier spécifié dans [CSV][filepath]
* Trie les colonnes par ordre alphabétique dans l'en-tête

**Modules appelés** :
* `ExportCsv` : Écrit les données au format CSV dans le fichier de destination

# Fichiers de LOGS

## SyncSQLtoCSV-OneShot.log

Contient les logs du dernier traitement d'exportation.

**Réinitialisé à chaque exécution.**

## SyncSQLtoCSV-Cumul.err

Contient le cumul des erreurs constatées dans tous les traitements d'exportation.

**Cumulé à chaque exécution.**

## SyncSQLtoCSV-Cumul.mod

Contient le cumul des modifications et opérations effectuées.

**Cumulé à chaque exécution.**

# Exemple de fichier .ini

```ini
# -----------------------------------------------------------------------------------------------------------------------------
#    SyncSQLtoCSV.ini - Necessite Powershell 7 ou +
#      Creation d'un fichier CSV depuis une table SQL
# -----------------------------------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------
#     Parametrage du comportement de l'interface SyncSQLtoCSV.ps1
# -------------------------------------------------------------------

[start]
# Le parametre "logtoscreen" contrôle l'affichage de toutes les infos de log/error/warning dans la console
logtoscreen = yes

# Le parametre "debug" contrôle l'affichage des infos de debug dans la console
debug       = no

# Le parametre "warntoerr" permet d'inclure ou pas les warnings dans le fichier SyncSQLtoCSV-Cumul.err
warntoerr   = yes

# Le parametre "TransacSQL" définit le mode de transaction SQL (OneByOne ou AllInOne)
TransacSQL  = AllInOne

# -------------------------------------------------------------------
#     Chemin des fichiers de LOGS
# -------------------------------------------------------------------
[intf]
name = Creation d'un fichier CSV depuis une table SQL

# ----  Réinitialisé à chaque execution  ----

# Chemin du fichier log : 
pathfilelog   = $rootpath$\logs\SyncSQLtoCSV-OneShot.log

# ----  Cumulé à chaque execution  ----

# Chemin du fichier des modifications
pathfilemod = $rootpath$\logs\SyncSQLtoCSV-Cumul.mod

# Chemin du fichier d'erreur
pathfileerr   = $rootpath$\logs\SyncSQLtoCSV-Cumul.err

[SQL_Server]                                                                       
frmtdateOUT = dd/MM/yyyy HH:mm:ss

# -------------------------------------------------------------------
#     Parametrage de la table MASTER à exporter
# -------------------------------------------------------------------
[SQL_SRC]                                                                       
server        = WIN-09T11CB4M65\TEST
database      = REFERENTIEL_ADP
table         = ADP_Annuaire
key           = Matricule
login         = sa
password      = !Plmuvimvmhpb2
SQLformatDate = dd/MM/yyyy HH:mm:ss

# -------------------------------------------------------------------
#     Parametrage du fichier CSV à exporter
# -------------------------------------------------------------------
[CSV]                                                                       
filepath  = $rootpath$\fichiers\export.csv
Delimiter = ;

# -------------------------------------------------------------------
#     Parametrage des Emails
# -------------------------------------------------------------------

# Parametre pour l'envoi de mails
[email]
sendemail    = no
destinataire = btran56@gmail.com
Subject      = Export SQL vers CSV
emailmode    = SMTP
UseSSL       = false

# Login pour SMTP
expediteur   = btran56@gmail.com
server       = smtp.gmail.com
port         = 587
password     = 
```

# Utilisation

## Exécution avec fichier .ini par défaut

```powershell
.\SyncSQLtoCSV.ps1
```

Le script utilisera automatiquement le fichier `SyncSQLtoCSV.ini` situé dans le même répertoire.

## Exécution avec fichier .ini personnalisé

```powershell
.\SyncSQLtoCSV.ps1 MonFichierConfig.ini
```

Le script utilisera le fichier de configuration spécifié.

# Prérequis

* **PowerShell 7 ou supérieur**
* Accès à une base de données **SQL Server**
* Droits de lecture sur la table source
* Droits d'écriture dans le répertoire de destination du fichier CSV