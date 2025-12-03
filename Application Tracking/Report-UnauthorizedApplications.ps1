<#
.SYNOPSIS
    Génère un rapport de statut NinjaOne, incluant les applications non autorisées, les détails des appareils et le mappage des emplacements.

.DESCRIPTION
    Ce script :
    - Se connecte à l'API NinjaOne en utilisant des identifiants.
    - Récupère les appareils, organisations et champs personnalisés.
    - Associe les appareils avec leurs valeurs de champs personnalisés correspondantes (ex. applications non autorisées).
    - Produit un rapport de statut au format CSV contenant les appareils, emplacements, organisations et champs personnalisés.
    - Affiche une liste maître de toutes les applications non autorisées sur tous les appareils.

.PARAMETER Action
    Le script vérifie la prise en charge de PowerShell 7+ et redémarre automatiquement dans PowerShell 7 si nécessaire.

.PARAMETER NinjaOneInstance
    [string] L'URL de votre instance NinjaOne. Récupérée depuis un champ personnalisé sécurisé.

.PARAMETER NinjaOneClientId
    [string] Votre ID client API NinjaOne. Récupéré depuis un champ personnalisé sécurisé.

.PARAMETER NinjaOneClientSecret
    [string] Votre secret client API NinjaOne. Récupéré depuis un champ personnalisé sécurisé.

.INPUTS
    - Identifiants NinjaOne (champs personnalisés stockés de manière sécurisée).
    - PowerShell 7 doit être installé et disponible.
    - Le script utilise le module `NinjaOneDocs` (GitHub : https://github.com/lwhitelock/NinjaOneDocs).

.OUTPUTS
    - Un rapport CSV enregistré dans le répertoire `C:\temp\`.
    - Une liste maître des applications non autorisées affichée dans la console.

.EXAMPLE
    # Exécuter le script pour générer le rapport de statut NinjaOne
    .\ScriptName.ps1

    Sortie :
        - Rapport enregistré dans C:\temp\yyyyMMdd_Ninja_Status_Report.csv
        - Une liste des applications non autorisées est affichée dans la console.

.EXAMPLE
    # Redémarrer dans PowerShell 7 si nécessaire et générer le rapport
    pwsh -File .\ScriptName.ps1

.NOTES
    - **Dépendances** : PowerShell 7+, module `NinjaOneDocs`.
    - Le script s'assure que PowerShell 7 est installé et l'utilise pour l'exécution.
    - Les appareils et organisations sont enrichis avec les détails d'emplacement et de champs personnalisés.
    - Les identifiants API NinjaOne sont récupérés de manière sécurisée en utilisant les fonctions de propriétés NinjaOne.

.LINK
    Module GitHub NinjaOneDocs : https://github.com/lwhitelock/NinjaOneDocs
#>


# Vérifier la version PowerShell requise (7+)
if (!($PSVersionTable.PSVersion.Major -ge 7)) {
    try {
        if (!(Test-Path "$env:SystemDrive\Program Files\PowerShell\7")) {
            Write-Output 'Does not appear Powershell 7 is installed'
            exit 1
        }

        # Rafraîchir le PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
        
        # Redémarrer le script dans PowerShell 7
        pwsh -File "`"$PSCommandPath`"" @PSBoundParameters
        
    }
    catch {
        Write-Output 'PowerShell 7 was not installed. Update PowerShell and try again.'
        throw $Error
    }
    finally { exit $LASTEXITCODE }
}

# Installer ou mettre à jour le module NinjaOneDocs ou créer votre propre fork ici https://github.com/lwhitelock/NinjaOneDocs
try {
    $moduleName = "NinjaOneDocs"
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Install-Module -Name $moduleName -Force -AllowClobber
    }
    Import-Module $moduleName
}
catch {
    Write-Error "Failed to import NinjaOneDocs module. Error: $_"
    exit
}


# Vos identifiants NinjaRMM - ceux-ci doivent être stockés dans des champs personnalisés NinjaOne sécurisés
$NinjaOneInstance = Ninja-Property-Get ninjaoneInstance
$NinjaOneClientId = Ninja-Property-Get ninjaoneClientId
$NinjaOneClientSecret = Ninja-Property-Get ninjaoneClientSecret

if (!$ninjaoneInstance -and !$NinjaOneClientId -and !$NinjaOneClientSecret) {
    Write-Output "Missing required API credentials"
    exit 1
}

# Se connecter à NinjaOne en utilisant la fonction Connect-NinjaOne
try {
    Connect-NinjaOne -NinjaOneInstance $NinjaOneInstance -NinjaOneClientID $NinjaOneClientId -NinjaOneClientSecret $NinjaOneClientSecret
}
catch {
    Write-Error "Failed to connect to NinjaOne API. Error: $_"
    exit
}
    
# Obtenir la date d'aujourd'hui
$today = Get-Date -format "yyyyMMdd"

# Chemins des fichiers
$status_report = "C:\temp\" + $today + "_Ninja_Status_Report.csv"

# Récupérer les appareils et organisations en utilisant les fonctions du module
try {
    $devices = Invoke-NinjaOneRequest -Method GET -Path 'devices' -QueryParams "df=class%20in%20(WINDOWS_WORKSTATION,%20WINDOWS_SERVER)"
    $organizations = Invoke-NinjaOneRequest -Method GET -Path 'organizations'
    $locations = Invoke-NinjaOneRequest -Method GET -Path 'locations'
}
catch {
    Write-Error "Failed to retrieve devices, location, or organizations. Error: $_"
    exit
}

# Définir les paramètres de requête pour les installations de correctifs
$queryParams = @{
    df              = 'class in (WINDOWS_WORKSTATION, WINDOWS_SERVER)'
    fields          = 'unauthorizedApplications'
}

# Formater les paramètres de requête en chaîne (encodage URL)
$QueryParamString = ($queryParams.GetEnumerator() | ForEach-Object { 
    "$($_.Key)=$($_.Value -replace ' ', '%20')"
}) -join '&'

# Appeler Invoke-NinjaOneRequest en utilisant le splatting
$customfields = Invoke-NinjaOneRequest -Method GET -Path 'queries/custom-fields-detailed' -QueryParams $QueryParamString -Paginate | Select-Object -ExpandProperty 'results'

$customFieldIDs = $customfields | Select-Object -ExpandProperty deviceId
$matchingdevices = $devices | Where-Object { $customFieldIDs -contains $_.id }

$assets = Foreach ($device in $matchingdevices) {
    [PSCustomObject]@{
        DeviceName = $device.systemName
        DeviceID = $device.id
        LocationName = 0
        LocationID = $device.locationId
        OrganizationName = 0
        OrganizationID = $device.organizationId
        CustomField = 0
    }
}
foreach ($location in $locations) {
        $currentDev = $assets | Where-Object {$_.LocationID -eq $location.id}
    $currentDev | Add-Member -MemberType NoteProperty -Name 'LocationName' -Value $location.name -Force
    }

foreach ($organization in $organizations) {
        $currentDev = $assets | Where-Object {$_.OrganizationID -eq $organization.id}
    $currentDev | Add-Member -MemberType NoteProperty -Name 'OrganizationName' -Value $organization.name -Force
    }

foreach ($customfield in $customfields) {
    $currentDev = $assets | Where-Object {$_.DeviceID -eq $customfield.deviceId}
$currentDev | Add-Member -MemberType NoteProperty -Name 'CustomField' -Value $customfield.fields.value -Force
}

    # Supprimer les IDs qui ne sont pas nécessaires pour le rapport
$assets | Select-Object devicename, customfield, locationname, OrganizationName | Format-Table | Out-String

Write-Host 'Creating the final report'

$assets | Select-Object devicename, customfield, locationname, OrganizationName | Export-CSV -NoTypeInformation -Path $status_report  

Write-Host "csv files have been created with success!"
Write-Host "Go to " $status_report " to find your Status Report"

# Extraire, diviser et nettoyer les valeurs CustomField
$uniqueValues = $assets.CustomField `
    -split ',\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique

# Créer une liste maître séparée par virgules des valeurs uniques
$masterList = $uniqueValues -join ', '

# Afficher la liste maître
Write-Host "All unauthorized applications across all organizations: $masterList"
