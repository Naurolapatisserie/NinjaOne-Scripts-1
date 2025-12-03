<#
.SYNOPSIS
    Sauvegarde ou restaure les listes de logiciels autorisés pour les organisations et appareils dans NinjaOne.

.DESCRIPTION
    Ce script fournit deux actions principales :
    1. **Backup** : Récupère et enregistre les listes de logiciels autorisés pour les organisations et appareils dans un fichier JSON.
    2. **Restore** : Restaure les listes de logiciels autorisés pour les organisations ou appareils depuis un fichier de sauvegarde JSON.

    Le script prend en charge le filtrage des cibles pour la restauration (organisations ou appareils) et la sélection automatique du fichier de sauvegarde le plus récent.

.PARAMETER Action
    [string] Spécifie l'action à effectuer.
    Valeurs valides : "Backup" ou "Restore".

.PARAMETER BackupFile
    [string] Le chemin vers le fichier JSON de sauvegarde à utiliser pour la restauration.
    Requis lors d'une action de restauration.

.PARAMETER BackupDirectory
    [string] Le répertoire contenant les fichiers de sauvegarde.
    Si aucun BackupFile n'est spécifié, le script sélectionnera automatiquement le fichier de sauvegarde le plus récent.

.PARAMETER TargetType
    [string] Le type de cibles à restaurer.
    Valeurs valides : "All", "Organizations" ou "Devices".

.PARAMETER RestoreTargets
    [string] Une liste séparée par virgules des cibles spécifiques à restaurer (noms d'organisations ou d'appareils).
    Si TargetType est "All", ce paramètre est ignoré.

.EXAMPLE
    # Effectuer une sauvegarde de toutes les listes de logiciels autorisés
    .\ScriptName.ps1 -Action Backup

.EXAMPLE
    # Restaurer les listes de logiciels autorisés pour toutes les organisations depuis la sauvegarde la plus récente
    .\ScriptName.ps1 -Action Restore -BackupDirectory "C:\Backups" -TargetType Organizations

.EXAMPLE
    # Restaurer les logiciels autorisés pour des appareils spécifiques depuis un fichier de sauvegarde spécifique
    .\ScriptName.ps1 -Action Restore -BackupFile "C:\Backups\Backup_20240923_120000.json" `
                     -TargetType Devices -RestoreTargets "Device1,Device2"

.EXAMPLE
    # Trouver automatiquement la sauvegarde la plus récente et restaurer les listes de logiciels pour tous les appareils
    .\ScriptName.ps1 -Action Restore -BackupDirectory "C:\Backups" -TargetType Devices

.INPUTS
    Variables d'environnement :
        - $env:action          : Spécifie l'action ("Backup" ou "Restore").
        - $env:backupFile      : Chemin vers le fichier de sauvegarde pour la restauration.

.OUTPUTS
    - Pour **Backup** : Un fichier JSON contenant les listes de logiciels autorisés est enregistré à l'emplacement spécifié ou par défaut.
    - Pour **Restore** : Met à jour les listes de logiciels autorisés dans NinjaOne et affiche les messages de succès/échec.

.NOTES
    - Version PowerShell : 5.1 ou ultérieure.
    - Le script nécessite des identifiants API pour NinjaOne.

#>

param(
    # Paramètre Action pour déterminer Sauvegarde ou Restauration
    [Parameter(Mandatory = $false, HelpMessage = "Specify the action to perform: Backup or Restore.")]
    [string]$Action,

    # Paramètres spécifiques à la restauration
    [Parameter(Mandatory = $false, HelpMessage = "Path to the backup JSON file for restoration.")]
    [string]$BackupFile,

    [Parameter(Mandatory = $false, HelpMessage = "Directory containing backup files for restoration.")]
    [string]$BackupDirectory,

    [Parameter(Mandatory = $false, HelpMessage = "Type of target to restore: All, Organizations, or Devices.")]
    [string]$TargetType,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of specific targets to restore.")]
    [string]$RestoreTargets
)
if ($env:action -and $env:action -notlike "null") { $Action = $env:action }
if ($env:backupFile -and $env:backupFile -notlike "null") { $BackupFile = $env:backupFile }
if ($env:backupDirectory -and $env:backupDirectory -notlike "null") { $BackupDirectory = $env:backupDirectory }
if ($env:targetType -and $env:targetType -notlike "null") { $TargetType = $env:targetType }
if ($env:restoreTargets -and $env:restoreTargets -notlike "null") { $RestoreTargets = $env:restoreTargets }

try {
    # Configuration
    $NinjaOneInstance = Ninja-Property-Get ninjaoneInstance
    $NinjaOneClientId = Ninja-Property-Get ninjaoneClientId
    $NinjaOneClientSecret = Ninja-Property-Get ninjaoneClientSecret

    # Authentification
    $authBody = @{
        grant_type    = "client_credentials"
        client_id     = $NinjaOneClientId
        client_secret = $NinjaOneClientSecret
        scope         = "monitoring management"
    }
    $authHeaders = @{
        accept        = 'application/json'
        "Content-Type" = 'application/x-www-form-urlencoded'
    }
}
catch {
    Write-Error "Failed to authenticate with NinjaOne API: $_"
    exit 1
}
try {
    $authResponse = Invoke-RestMethod -Uri "https://$NinjaOneInstance/oauth/token" -Method POST -Headers $authHeaders -Body $authBody
    $accessToken = $authResponse.access_token
    # En-têtes pour les requêtes API
    $headers = @{
        accept        = 'application/json'
        Authorization = "Bearer $accessToken"
    }
} catch {
    Write-Error "Failed to authenticate with NinjaOne API: $_"
    exit 1
}

# Récupérer les organisations depuis NinjaOne
$organizationsUrl = "https://$NinjaOneInstance/v2/organizations"
try {
    $organizations = Invoke-RestMethod -Uri $organizationsUrl -Method GET -Headers $headers
} catch {
    Write-Error "Failed to fetch organizations: $_"
    exit 1
}

# Récupérer les appareils depuis NinjaOne
$devicesUrl = "https://$NinjaOneInstance/v2/devices?df=class%20in%20(WINDOWS_WORKSTATION,%20WINDOWS_SERVER)"
try {
    $devices = Invoke-RestMethod -Uri $devicesUrl -Method GET -Headers $headers
} catch {
    Write-Error "Failed to fetch organizations: $_"
    exit 1
}

function Backup-AuthorizedSoftware {
    param(
        [string]$OutputFile = "Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    )

    Write-Host "Starting backup of authorized software lists..."

    $backupData = [ordered]@{
        Organizations = @()
        Devices       = @()
    }

    # Sauvegarder les organisations
    foreach ($org in $organizations) {
        $orgId = $org.id
        $orgName = $org.name
        $customFieldsUrl = "https://$NinjaOneInstance/api/v2/organization/$orgId/custom-fields"
        try {
            $customFields = Invoke-RestMethod -Uri $customFieldsUrl -Method GET -Headers $headers
            $softwareList = $customFields.softwareList.text -as [string]
        } catch {
            Write-Warning "Failed to retrieve custom fields for organization '$orgName': $_"
            $softwareList = $null
        }

        $backupData.Organizations += [ordered]@{
            Name         = $orgName
            Id           = $orgId
            SoftwareList = $softwareList
        }
    }

    # Sauvegarder les appareils
    foreach ($dev in $devices) {
        $deviceId = $dev.id
        $deviceName = $dev.systemName
        $customFieldsUrl = "https://$NinjaOneInstance/api/v2/device/$deviceId/custom-fields"
        try {
            $customFields = Invoke-RestMethod -Uri $customFieldsUrl -Method GET -Headers $headers
            $deviceSoftwareList = $customFields.deviceSoftwareList.text -as [string]
        } catch {
            Write-Warning "Failed to retrieve custom fields for device '$deviceName': $_"
            $deviceSoftwareList = $null
        }

        # Ajouter l'appareil à la sauvegarde uniquement si une valeur est présente
        if ([string]::IsNullOrWhiteSpace($deviceSoftwareList)) {
            Write-Host "Skipping backup for device '$deviceName' as no software list is set." -ForegroundColor Yellow
            continue
        }

        $backupData.Devices += [ordered]@{
            Name              = $deviceName
            Id                = $deviceId
            DeviceSoftwareList = $deviceSoftwareList
        }
    }


    # Enregistrer la sauvegarde dans un fichier
    $backupJson = $backupData | ConvertTo-Json -Depth 10
    $backupJson | Out-File $OutputFile -Encoding UTF8

    Write-Host "Backup complete. File saved to: $OutputFile" -ForegroundColor Green
}

function Get-MostRecentBackupFile {
    param (
        [string]$Directory,
        [string[]]$SearchKeywords
    )

    # Construire le modèle de recherche en combinant les mots-clés avec des jokers
    $searchPattern = $SearchKeywords | ForEach-Object { "*$_*" }

    # Initialiser un tableau pour contenir les fichiers correspondants
    $matchingFiles = @()

    foreach ($pattern in $searchPattern) {
        $files = Get-ChildItem -Path $Directory -Filter $pattern -File -ErrorAction SilentlyContinue
        if ($files) {
            $matchingFiles += $files
        }
    }

    if ($matchingFiles.Count -eq 0) {
        throw "No backup files found in directory '$Directory' matching the keywords: $($SearchKeywords -join ', ')"
    }

    # Sélectionner le fichier le plus récent basé sur LastWriteTime
    $mostRecentFile = $matchingFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    return $mostRecentFile.FullName
}
function Restore-AuthorizedSoftware {
    [CmdletBinding(DefaultParameterSetName = 'Directory')]
    param(
        # Jeu de paramètres 1 : Spécifier le fichier de sauvegarde
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'File')]
        [string]$BackupFile,

        # Jeu de paramètres 2 : Spécifier le répertoire de sauvegarde et les mots-clés
        [Parameter(Mandatory = $false, ParameterSetName = 'Directory')]
        [string]$BackupDirectory,

        # Paramètres communs
        [Parameter(Mandatory = $true)]
        [ValidateSet("All","Organizations","Devices")]
        [string]$TargetType,

        [Parameter(Mandatory = $false)]
        [string]$RestoreTargets
    )

    # Fonction pour trouver le fichier de sauvegarde le plus récent correspondant aux mots-clés
    

    # Déterminer le fichier de sauvegarde basé sur le jeu de paramètres
    switch ($PSCmdlet.ParameterSetName) {
        'File' {
            $BackupFilePath = $BackupFile
            Write-Host "Using specified backup file: $BackupFilePath" -ForegroundColor Cyan
        }
        'Directory' {
            try {
                $BackupFilePath = Get-MostRecentBackupFile -Directory $BackupDirectory -SearchKeywords "Backup"
                Write-Host "Using most recent backup file: $BackupFilePath" -ForegroundColor Cyan
            } catch {
                Write-Error $_
                return
            }
        }
    }

    # S'assurer que les cibles ne sont pas spécifiées quand TargetType est 'All'
    if ($TargetType -eq "All" -and $RestoreTargets) {
        Write-Error "Cannot specify targets when TargetType is 'All'. Remove the Targets parameter or choose a different TargetType."
        return
    }

    # Lire et analyser le fichier de sauvegarde
    try {
        $backupData = Get-Content $BackupFilePath -Raw | ConvertFrom-Json
    } catch {
        Write-Error "Failed to parse JSON from '$BackupFilePath': $_"
        return
    }

    # S'assurer que Organizations et Devices sont au moins des tableaux vides s'ils ne sont pas présents
    if (-not $backupData.Organizations) {
        $backupData.Organizations = @()
    }
    if (-not $backupData.Devices) {
        $backupData.Devices = @()
    }

    Write-Host "Starting restore from backup: $BackupFilePath" -ForegroundColor Cyan

    # Diviser les cibles si fournies
    $TargetList = $null
    if ($RestoreTargets) {
        $TargetList = $RestoreTargets -split "," | ForEach-Object { $_.Trim() }
    }

    # Fonction pour restaurer les logiciels autorisés d'une seule organisation
    function Restore-Organization($OrgData) {
        $orgId = $OrgData.Id
        $orgName = $OrgData.Name
        $updatedValue = $OrgData.SoftwareList

        if (-not $updatedValue) {
            Write-Host "Organization '$orgName' has no software list to restore." -ForegroundColor Yellow
            return
        }

        $customFieldsUrl = "https://$NinjaOneInstance/api/v2/organization/$orgId/custom-fields"
        $requestBody = @{
            softwareList = @{ html = $updatedValue }
        } | ConvertTo-Json -Depth 10

        try {
            Invoke-RestMethod -Method PATCH -Uri $customFieldsUrl -Headers $Headers -Body $requestBody -ContentType "application/json"
            Write-Host "Successfully restored authorized software for organization '$orgName'." -ForegroundColor Green
        } catch {
            Write-Error "Failed to restore authorized software for '$orgName': $_"
        }
    }

    # Fonction pour restaurer les logiciels autorisés d'un seul appareil
    function Restore-Device($DevData) {
        $deviceId = $DevData.Id
        $deviceName = $DevData.Name
        $updatedValue = $DevData.DeviceSoftwareList

        $customFieldsUrl = "https://$NinjaOneInstance/api/v2/device/$deviceId/custom-fields"
        $requestBody = if ($updatedValue) {
            @{ deviceSoftwareList = @{ html = $updatedValue } }
        } else {
            @{ deviceSoftwareList = $null }
        }
        $requestBody = $requestBody | ConvertTo-Json -Depth 10

        try {
            Invoke-RestMethod -Method PATCH -Uri $customFieldsUrl -Headers $Headers -Body $requestBody -ContentType "application/json"
            Write-Host "Successfully restored authorized software for device '$deviceName'." -ForegroundColor Green
        } catch {
            Write-Error "Failed to restore authorized software for '$($deviceName)': $_"
        }
    }

    switch ($TargetType) {
        "All" {
            # Restaurer toutes les organisations
            foreach ($org in $backupData.Organizations) {
                Restore-Organization $org
            }
            # Restaurer tous les appareils
            foreach ($dev in $backupData.Devices) {
                Restore-Device $dev
            }
        }

        "Organizations" {
            if (-not $TargetList) {
                # Restaurer toutes les organisations
                foreach ($org in $backupData.Organizations) {
                    Restore-Organization $org
                }
            } else {
                # Préparer une table de recherche uniquement si nous avons des organisations
                $OrgByName = @{}
                if ($backupData.Organizations.Count -gt 0) {
                    $OrgByName = $backupData.Organizations | Group-Object -Property Name -AsHashTable -AsString
                }
                foreach ($targetName in $TargetList) {
                    if ($OrgByName -and $OrgByName.ContainsKey($targetName)) {
                        Restore-Organization $OrgByName[$targetName]
                    } else {
                        Write-Warning "No matching organization found for '$targetName'. Skipping."
                    }
                }
            }
        }

        "Devices" {
            if (-not $TargetList) {
                # Restaurer tous les appareils
                foreach ($dev in $backupData.Devices) {
                    Restore-Device $dev
                }
            } else {
                # Préparer une table de recherche uniquement si nous avons des appareils
                $DevByName = @{}
                if ($backupData.Devices.Count -gt 0) {
                    $DevByName = $backupData.Devices | Group-Object -Property Name -AsHashTable -AsString
                }

                foreach ($targetName in $TargetList) {
                    if ($DevByName -and $DevByName.ContainsKey($targetName)) {
                        Restore-Device $DevByName[$targetName]
                    } else {
                        Write-Warning "No matching device found for '$targetName'. Skipping."
                    }
                }
            }
        }
    }

    Write-Host "Restore process completed." -ForegroundColor Green
}

# Logique conditionnelle basée sur $Action
switch ($Action) {
    "Backup" {
        # Logique de sauvegarde
        $OutputFile = "C:\Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        Backup-AuthorizedSoftware -OutputFile $OutputFile
    }

    "Restore" {
        # Validation des paramètres de restauration
        if (-not $BackupFile -and -not $BackupDirectory) {
            Write-Error "Error: You must provide either a BackupFile or BackupDirectory for restoration."
            exit
        }
        
        if (-not $BackupFile) {
            # Si aucun BackupFile n'est fourni, trouver le fichier de sauvegarde le plus récent dans BackupDirectory
            try {
                $BackupFile = Get-MostRecentBackupFile -Directory $BackupDirectory -SearchKeywords "Backup"
                Write-Host "Using most recent backup file: $BackupFilePath" -ForegroundColor Cyan
            } catch {
                Write-Error $_
                exit
            }
        }    

        Restore-AuthorizedSoftware -BackupFile $BackupFile `
                                   -TargetType $TargetType `
                                   -RestoreTargets $RestoreTargets
    }

    default {
        Write-Error "Invalid Action. Use 'Backup' or 'Restore'."
    }
}


