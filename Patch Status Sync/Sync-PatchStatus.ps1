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

function Compare-And-UpdateCustomFields {
    param (
        [string]$deviceId,
        [string]$fieldName,
        [string]$newValue
    )
    try {
        $currentFields = Invoke-NinjaOneRequest -Method GET -Path "device/$deviceId/custom-fields"
        $currentValue = $currentFields."$fieldName"
        Write-Output "Retrieved value of $currentValue"
    } catch {
        Write-Warning "Failed to retrieve custom fields for device ID $deviceId. Error: $_"
        return
    }

    # Comparer la valeur actuelle avec la nouvelle valeur
    if ($currentValue -ne $newValue) {
        Write-Host "$(Get-Date) - Updating custom field '$fieldName' for device ID $deviceId"
        $request_body = @{
            $fieldName = $newValue
        } | ConvertTo-Json

        # Effectuer la mise à jour
        try {
            Invoke-NinjaOneRequest -Method PATCH -Path "device/$deviceId/custom-fields" -Body $request_body
            Write-Host "Successfully updated '$fieldName' for device ID $deviceId"
        } catch {
            Write-Warning "Failed to update custom fields for device ID $deviceId. Error: $_"
        }
    } else {
        Write-Host "$(Get-Date) - No update needed for '$fieldName' on device ID $deviceId"
    }
}

$pendingCF = "pendingPatches"
$approvedCF = "approvedPatches"
$failedCF = "failedPatches"

# Récupérer les appareils et organisations en utilisant les fonctions du module
try {
    $devices = Invoke-NinjaOneRequest -Method GET -Path 'devices-detailed' -QueryParams "df=class%20in%20(WINDOWS_WORKSTATION,%20WINDOWS_SERVER)"
    $organizations = Invoke-NinjaOneRequest -Method GET -Path 'organizations'

}
catch {
    Write-Error "Failed to retrieve devices or organizations. Error: $_"
    exit
}

# Définir les paramètres de requête pour les installations de correctifs
$queryParams = @{
    df              = 'class in (WINDOWS_WORKSTATION, WINDOWS_SERVER)'
    status          = 'FAILED'
}

# Formater les paramètres de requête en chaîne (encodage URL)
$QueryParamString = ($queryParams.GetEnumerator() | ForEach-Object { 
    "$($_.Key)=$($_.Value -replace ' ', '%20')"
}) -join '&'

# Appeler Invoke-NinjaOneRequest en utilisant le splatting
$patchfailures = Invoke-NinjaOneRequest -Method GET -Path 'queries/os-patch-installs' -QueryParams $QueryParamString | Select-Object -ExpandProperty 'results'

# Définir les paramètres de requête pour les installations de correctifs
$queryParams = @{
    df              = 'class in (WINDOWS_WORKSTATION, WINDOWS_SERVER)'
    status          = 'MANUAL'
}

# Formater les paramètres de requête en chaîne (encodage URL)
$QueryParamString = ($queryParams.GetEnumerator() | ForEach-Object { 
    "$($_.Key)=$($_.Value -replace ' ', '%20')"
}) -join '&'

# Appeler Invoke-NinjaOneRequest en utilisant le splatting
$pendingpatches = Invoke-NinjaOneRequest -Method GET -Path 'queries/os-patches' -QueryParams $QueryParamString | Select-Object -ExpandProperty 'results'

# Définir les paramètres de requête pour les installations de correctifs
$queryParams = @{
    df              = 'class in (WINDOWS_WORKSTATION, WINDOWS_SERVER)'
    status          = 'APPROVED'
}

# Formater les paramètres de requête en chaîne (encodage URL)
$QueryParamString = ($queryParams.GetEnumerator() | ForEach-Object { 
    "$($_.Key)=$($_.Value -replace ' ', '%20')"
}) -join '&'

# Appeler Invoke-NinjaOneRequest en utilisant le splatting
$approvedpatches = Invoke-NinjaOneRequest -Method GET -Path 'queries/os-patches' -QueryParams $QueryParamString | Select-Object -ExpandProperty 'results'

# Définir les paramètres de requête pour les installations de correctifs
$queryParams = @{
    df              = 'class in (WINDOWS_WORKSTATION, WINDOWS_SERVER)'
    fields = 'pendingPatches'
}

# Formater les paramètres de requête en chaîne (encodage URL)
$QueryParamString = ($queryParams.GetEnumerator() | ForEach-Object { 
    "$($_.Key)=$($_.Value -replace ' ', '%20')"
}) -join '&'

# Appeler Invoke-NinjaOneRequest en utilisant le splatting
$pendingcustomfields = Invoke-NinjaOneRequest -Method GET -Path 'queries/custom-fields-detailed' -QueryParams $QueryParamString -Paginate | Select-Object -ExpandProperty 'results'

# Définir les paramètres de requête pour les installations de correctifs
$queryParams = @{
    df              = 'class in (WINDOWS_WORKSTATION, WINDOWS_SERVER)'
    fields = 'failedPatches'
}

# Formater les paramètres de requête en chaîne (encodage URL)
$QueryParamString = ($queryParams.GetEnumerator() | ForEach-Object { 
    "$($_.Key)=$($_.Value -replace ' ', '%20')"
}) -join '&'

# Appeler Invoke-NinjaOneRequest en utilisant le splatting
$failedcustomfields = Invoke-NinjaOneRequest -Method GET -Path 'queries/custom-fields-detailed' -QueryParams $QueryParamString -Paginate | Select-Object -ExpandProperty 'results'

# Définir les paramètres de requête pour les installations de correctifs
$queryParams = @{
    df              = 'class in (WINDOWS_WORKSTATION, WINDOWS_SERVER)'
    fields = 'approvedPatches'
}

# Formater les paramètres de requête en chaîne (encodage URL)
$QueryParamString = ($queryParams.GetEnumerator() | ForEach-Object { 
    "$($_.Key)=$($_.Value -replace ' ', '%20')"
}) -join '&'

# Appeler Invoke-NinjaOneRequest en utilisant le splatting
$approvedcustomfields = Invoke-NinjaOneRequest -Method GET -Path 'queries/custom-fields-detailed' -QueryParams $QueryParamString -Paginate | Select-Object -ExpandProperty 'results'

# Traiter les correctifs en attente
$groupedpending = $pendingpatches | Group-Object -Property deviceId
# Traiter les correctifs en attente
$groupedfailed = $patchfailures | Group-Object -Property deviceId
# Traiter les correctifs en attente
$groupedapproved = $approvedpatches | Group-Object -Property deviceId


foreach ($group in $groupedpending) {
    $deviceId = $group.Name
    $updatesForDevice = $group.Group

    # Convertir les mises à jour en chaîne JSON pour comparaison
    $newValue = ($updatesForDevice | ForEach-Object { $_.name }) -join ","
    Compare-And-UpdateCustomFields -instance $NinjaOneInstance -deviceId $deviceId -fieldName "pendingPatches" -newValue $newValue
}

foreach ($group in $groupedfailed) {
    $deviceId = $group.Name
    $updatesForDevice = $group.Group

    # Convertir les mises à jour en chaîne JSON pour comparaison
    $newValue = ($updatesForDevice | ForEach-Object { $_.name }) -join ","
    Compare-And-UpdateCustomFields -instance $NinjaOneInstance -deviceId $deviceId -fieldName "failedPatches" -newValue $newValue
}

foreach ($group in $groupedapproved) {
    $deviceId = $group.Name
    $updatesForDevice = $group.Group

    # Convertir les mises à jour en chaîne JSON pour comparaison
    $newValue = ($updatesForDevice | ForEach-Object { $_.name }) -join ","
    Compare-And-UpdateCustomFields -instance $NinjaOneInstance -deviceId $deviceId -fieldName "approvedPatches" -newValue $newValue
}


# Créer des tables de hachage pour des vérifications d'appartenance rapides
$PendingDeviceIds   = @{}
$FailedDeviceIds    = @{}
$ApprovedDeviceIds  = @{}

$groupedpending | ForEach-Object   { $PendingDeviceIds[[string]$_.Name]   = $true }
$groupedfailed | ForEach-Object    { $FailedDeviceIds[[string]$_.Name]    = $true }
$groupedapproved | ForEach-Object  { $ApprovedDeviceIds[[string]$_.Name]  = $true }

# Vérifier les correctifs en attente obsolètes
foreach ($cf in $pendingcustomfields) {
    # Convertir deviceId en chaîne pour correspondre aux clés dans la table de hachage
    $deviceId = [string]$cf.deviceId
    $currentPending = $cf.fields.value

    # S'il y a des données dans pendingPatches mais que l'appareil n'est pas dans la liste $groupedpending actuelle, c'est obsolète
    if ([string]::IsNullOrWhiteSpace($currentPending) -eq $false -and -not $PendingDeviceIds.ContainsKey($deviceId)) {
        Write-Host "$(Get-Date) - Stale pendingPatches found for device $deviceId. Clearing field."
        Compare-And-UpdateCustomFields -deviceId $deviceId -fieldName "pendingPatches" -newValue ""
    }
}

# Vérifier les correctifs échoués obsolètes
foreach ($cf in $failedcustomfields) {
    # Convertir deviceId en chaîne pour correspondre aux clés dans la table de hachage
    $deviceId = [string]$cf.deviceId
    $currentFailed = $cf.failedPatches

    # S'il y a des données dans failedPatches mais que l'appareil n'est pas dans la liste $groupedfailed actuelle, c'est obsolète
    if ([string]::IsNullOrWhiteSpace($currentFailed) -eq $false -and -not $FailedDeviceIds.ContainsKey($deviceId)) {
        Write-Host "$(Get-Date) - Stale failedPatches found for device $deviceId. Clearing field."
        Compare-And-UpdateCustomFields -deviceId $deviceId -fieldName "failedPatches" -newValue ""
    }
}

# Vérifier les correctifs approuvés obsolètes
foreach ($cf in $approvedcustomfields) {
    $deviceId = [string]$cf.deviceId
    $currentApproved = $cf.approvedPatches

    # S'il y a des données dans approvedPatches mais que l'appareil n'est pas dans la liste $groupedapproved actuelle, c'est obsolète
    if ([string]::IsNullOrWhiteSpace($currentApproved) -eq $false -and -not $ApprovedDeviceIds.ContainsKey($deviceId)) {
        Write-Host "$(Get-Date) - Stale approvedPatches found for device $deviceId. Clearing field."
        Compare-And-UpdateCustomFields -deviceId $deviceId -fieldName "approvedPatches" -newValue ""
    }
}
