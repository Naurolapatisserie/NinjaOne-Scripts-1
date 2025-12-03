<#
.SYNOPSIS
    Met à jour les listes de déploiement de logiciels pour les organisations et appareils dans NinjaOne.

.DESCRIPTION
    Ce script fournit plusieurs actions pour gérer les listes de déploiement de logiciels :
    1. **Ajouter des Logiciels aux Organisations** : Ajoute des logiciels à la liste de déploiement pour toutes ou certaines organisations.
    2. **Supprimer des Logiciels des Organisations** : Supprime des logiciels de la liste de déploiement pour toutes ou certaines organisations.
    3. **Ajouter des Logiciels aux Appareils** : Ajoute des logiciels à la liste de déploiement pour des appareils spécifiques.
    4. **Supprimer des Logiciels des Appareils** : Supprime des logiciels de la liste de déploiement pour des appareils spécifiques.

    Le script prend en charge le filtrage des cibles (organisations ou appareils) et met à jour dynamiquement les champs personnalisés NinjaOne.

.PARAMETER AppendToOrganizations
    [string] Une liste séparée par virgules des noms d'organisations auxquelles ajouter des logiciels.

.PARAMETER SoftwareToAppend
    [string] Une liste séparée par virgules des noms de logiciels à ajouter à la liste de déploiement.

.PARAMETER RemoveFromOrganizations
    [string] Une liste séparée par virgules des noms d'organisations desquelles supprimer des logiciels.

.PARAMETER SoftwareToRemove
    [string] Une liste séparée par virgules des noms de logiciels à supprimer de la liste de déploiement.

.PARAMETER AppendToDevices
    [string] Une liste séparée par virgules des noms d'appareils auxquels ajouter des logiciels.

.PARAMETER DeviceSoftwareToAppend
    [string] Une liste séparée par virgules des noms de logiciels à ajouter à la liste de déploiement de l'appareil.

.PARAMETER RemoveFromDevices
    [string] Une liste séparée par virgules des noms d'appareils desquels supprimer des logiciels.

.PARAMETER DeviceSoftwareToRemove
    [string] Une liste séparée par virgules des noms de logiciels à supprimer de la liste de déploiement de l'appareil.

.NOTES
    - Version PowerShell : 5.1 ou ultérieure.
    - Le script nécessite des identifiants API pour NinjaOne.
#>

param (
    [string]$Option3,
    [string]$Option4,
    [string]$Option5,
    [string]$Option6,
    [string]$Option7,
    [string]$Option8,
    [string]$Option9,
    [string]$Option10
)

if ($env:appendToOrganizations -and $env:appendToOrganizations -notlike "null") { 
    $Option3 = $env:appendToOrganizations 
}

if ($env:softwareToAppend -and $env:softwareToAppend -notlike "null") { 
    $Option4 = $env:softwareToAppend 
}

if ($env:removeFromOrganizations -and $env:removeFromOrganizations -notlike "null") { 
    $Option5 = $env:removeFromOrganizations 
}

if ($env:softwareToRemove -and $env:softwareToRemove -notlike "null") { 
    $Option6 = $env:softwareToRemove 
}

if ($env:appendToDevices -and $env:appendToDevices -notlike "null") { 
    $Option7 = $env:appendToDevices 
}

if ($env:deviceSoftwareToAppend -and $env:deviceSoftwareToAppend -notlike "null") { 
    $Option8 = $env:deviceSoftwareToAppend 
}

if ($env:removeFromDevices -and $env:removeFromDevices -notlike "null") { 
    $Option9 = $env:removeFromDevices 
}

if ($env:deviceSoftwareToRemove -and $env:deviceSoftwareToRemove -notlike "null") { 
    $Option10 = $env:deviceSoftwareToRemove 
}

# Configuration
$NinjaOneInstance = Ninja-Property-Get ninjaoneInstance
$NinjaOneClientId = Ninja-Property-Get ninjaoneClientId
$NinjaOneClientSecret = Ninja-Property-Get ninjaoneClientSecret

$organizationFieldName = "softwareToDeploy"
$deviceFieldName = "deviceSoftwareToDeploy"

# Authentification
$authBody = @{
    grant_type    = "client_credentials"
    client_id     = $NinjaOneClientId
    client_secret = $NinjaOneClientSecret
    scope         = "monitoring management"
}
$authHeaders = @{
    accept         = 'application/json'
    "Content-Type" = 'application/x-www-form-urlencoded'
}

try {
    $authResponse = Invoke-RestMethod -Uri "https://$NinjaOneInstance/oauth/token" -Method POST -Headers $authHeaders -Body $authBody
    $accessToken = $authResponse.access_token
} catch {
    Write-Error "Failed to authenticate with NinjaOne API: $_"
    exit 1
}

# Headers for API requests
$headers = @{
    accept        = 'application/json'
    Authorization = "Bearer $accessToken"
}

# Fetch organizations from NinjaOne
$organizationsUrl = "https://$NinjaOneInstance/v2/organizations"
try {
    $organizations = Invoke-RestMethod -Uri $organizationsUrl -Method GET -Headers $headers
} catch {
    Write-Error "Failed to fetch organizations: $_"
    exit 1
}

# Fetch devices from NinjaOne
$devicesUrl = "https://$NinjaOneInstance/v2/devices?df=class%20in%20(WINDOWS_WORKSTATION,%20WINDOWS_SERVER)"
try {
    $devices = Invoke-RestMethod -Uri $devicesUrl -Method GET -Headers $headers
} catch {
    Write-Error "Failed to fetch devices: $_"
    exit 1
}

# Validate parameters and enforce conditions
function Test-Parameters {

    if ($Option4 -and -not $Option3) {
        Write-Error "You provided software to add, but no target organizations. Specify organizations or use 'ALL'." -ErrorAction Stop
    }
    
    if ($Option3 -and -not $Option4) {
        Write-Error "You provided target organizations, but no software to add. Specify a list of software to add." -ErrorAction Stop
    }
    
    if ($Option6 -and -not $Option5) {
        Write-Error "You provided software to remove, but did not provide target organizations." -ErrorAction Stop
    }
    
    if ($Option5 -and -not $Option6) {
        Write-Error "You provided target organizations, but no software to remove." -ErrorAction Stop
    }
    
    if ($Option7 -and -not $Option8) {
        Write-Error "You provided devices to update, but no software to add." -ErrorAction Stop
    }
    
    if ($Option8 -and -not $Option7) {
        Write-Error "You provided software to add, but no devices to target." -ErrorAction Stop
    }
    
    if ($Option10 -and -not $Option9) {
        Write-Error "You provided software to remove, but no devices to target." -ErrorAction Stop
    }
    
    if ($Option9 -and -not $Option10) {
        Write-Error "You provided devices to update, but no software to remove." -ErrorAction Stop
    }
    $ParametersToCheck = @($Option1, $Option2, $Option3, $Option4, $Option5, $Option6, $Option7, $Option8, $Option9, $Option10)
    foreach ($param in $ParametersToCheck) {
        if ($param -and $param.Length -gt 2048) {
            Write-Error "Your entry exceeds the character limit of 2048." -ErrorAction Stop
        }
    }
    return 0
}

if (Test-Parameters -eq 1) {
    Write-Host "Exiting script after executing overwrite with current software inventory." -ForegroundColor Yellow
    return
}

# Create a HashSet of device IDs for quick lookup
$deviceIds = @($devices.id) | ForEach-Object { $_ } | Sort-Object -Unique

#############################
# Section 2 - Add software to deploy list for all or select organizations
if ($Option3) {
    if ($Option3 -ieq "ALL") {
        Write-Host "Updating all organizations with new software to deploy..." -ForegroundColor Cyan
        $NewCustomFieldValues = $Option4 -split "," | ForEach-Object { $_.Trim() }
        foreach ($organization in $organizations) {
            if ($null -ne $organization) {
                $orgId = $organization.id
                $orgName = $organization.name
                $customFieldsUrl = "https://$NinjaOneInstance/api/v2/organization/$orgId/custom-fields"
                try {
                    $customFields = Invoke-RestMethod -Uri $customFieldsUrl -Method GET -Headers $headers
                    $existingValue = $customFields.PSObject.Properties[$organizationFieldName].Value -as [string]
                } catch {
                    Write-Error "Failed to retrieve custom fields for '$orgName': $_"
                    continue
                }
                if ($existingValue) {
                    $combinedValues = ($existingValue -split "," | ForEach-Object { $_.Trim() }) + $NewCustomFieldValues
                    $updatedValue = ($combinedValues | Sort-Object | Get-Unique) -join ","
                } else {
                    $updatedValue = $NewCustomFieldValues -join ","
                }
                $requestBody = @{ ($organizationFieldName) = $updatedValue } | ConvertTo-Json -Depth 10
                Write-Host "Updating custom field for organization '$orgName' with ID: $orgId"
                Write-Host "New value: $updatedValue"
                try {
                    Start-Sleep -Milliseconds 200
                    Invoke-RestMethod -Method PATCH -Uri $customFieldsUrl -Headers $headers -Body $requestBody -ContentType "application/json"
                    Write-Host "Successfully updated custom field for '$orgName'."
                } catch {
                    Write-Error "Failed to update custom field for '$orgName': $_"
                }
            } else {
                Write-Warning "Organization not found in NinjaOne."
            }
        }
    } else {
        if ($Option4) {
            Write-Host "Updating select organizations with new software to deploy..." -ForegroundColor Cyan
            $OrgNames = $Option3 -split "," | ForEach-Object { $_.Trim() }
            $NewCustomFieldValues = $Option4 -split "," | ForEach-Object { $_.Trim() }
            foreach ($OrgName in $OrgNames) {
                $organization = $organizations | Where-Object { $_.name -eq $OrgName }
                if ($null -ne $organization) {
                    $orgId = $organization.id
                    $customFieldsUrl = "https://$NinjaOneInstance/api/v2/organization/$orgId/custom-fields"
                    try {
                        $customFields = Invoke-RestMethod -Uri $customFieldsUrl -Method GET -Headers $headers
                        $existingValue = $customFields.PSObject.Properties[$organizationFieldName].Value -as [string]
                    } catch {
                        Write-Error "Failed to retrieve custom fields for '$OrgName': $_"
                        continue
                    }
                    if ($existingValue) {
                        $combinedValues = ($existingValue -split "," | ForEach-Object { $_.Trim() }) + $NewCustomFieldValues
                        $updatedValue = ($combinedValues | Sort-Object | Get-Unique) -join ","
                    } else {
                        $updatedValue = $NewCustomFieldValues -join ","
                    }
                    $requestBody = @{ ($organizationFieldName) = $updatedValue } | ConvertTo-Json -Depth 10
                    Write-Host "Updating custom field for organization '$OrgName' with ID: $orgId"
                    Write-Host "New value: $updatedValue"
                    try {
                        Start-Sleep -Milliseconds 200
                        Invoke-RestMethod -Method PATCH -Uri $customFieldsUrl -Headers $headers -Body $requestBody -ContentType "application/json"
                        Write-Host "Successfully updated custom field for '$OrgName'."
                    } catch {
                        Write-Error "Failed to update custom field for '$OrgName': $_"
                    }
                } else {
                    Write-Warning "Organization '$OrgName' not found in NinjaOne."
                }
            }
        }
    }
}

#############################
# Section 3 - Remove software from all or select organizations
if ($Option5) {
    if ($Option5 -ieq "ALL") {
        Write-Host "Updating all organizations to remove software from deployment list..." -ForegroundColor Gray
        $ValuesToRemove = $Option6 -split "," | ForEach-Object { $_.Trim() }
        foreach ($organization in $organizations) {
            if ($null -ne $organization) {
                $orgId = $organization.id
                $customFieldsUrl = "https://$NinjaOneInstance/api/v2/organization/$orgId/custom-fields"
                try {
                    $customFields = Invoke-RestMethod -Uri $customFieldsUrl -Method GET -Headers $headers
                    $existingValue = $customFields.PSObject.Properties[$organizationFieldName].Value -as [string]
                } catch {
                    Write-Error "Failed to retrieve custom fields for '$orgName': $_"
                    continue
                }
                if ($existingValue) {
                    $filteredValues = ($existingValue -split "," | ForEach-Object { $_.Trim() }) | Where-Object { $_ -notin $ValuesToRemove }
                    $updatedValue = $filteredValues -join ","
                } else {
                    Write-Warning "No existing value for '$orgName', skipping update."
                    continue
                }
                $requestBody = @{ ($organizationFieldName) = $updatedValue } | ConvertTo-Json -Depth 10
                Write-Host "Updating custom field for organization '$orgName' with ID: $orgId"
                Write-Host "Updated value: $updatedValue"
                try {
                    Start-Sleep -Milliseconds 200
                    Invoke-RestMethod -Method PATCH -Uri $customFieldsUrl -Headers $headers -Body $requestBody -ContentType "application/json"
                    Write-Host "Successfully updated custom field for '$orgName'."
                } catch {
                    Write-Error "Failed to update custom field for '$orgName': $_"
                }
            } else {
                Write-Warning "Organization '$orgName' not found in NinjaOne."
            }
        }
    } else {
        if ($Option6) {
            Write-Host "Updating select organizations to remove software from deployment list..." -ForegroundColor Gray
            $OrgNames = $Option5 -split "," | ForEach-Object { $_.Trim() }
            $ValuesToRemove = $Option6 -split "," | ForEach-Object { $_.Trim() }
            foreach ($OrgName in $OrgNames) {
                $organization = $organizations | Where-Object { $_.name -eq $OrgName }
                if ($null -ne $organization) {
                    $orgId = $organization.id
                    $customFieldsUrl = "https://$NinjaOneInstance/api/v2/organization/$orgId/custom-fields"
                    try {
                        $customFields = Invoke-RestMethod -Uri $customFieldsUrl -Method GET -Headers $headers
                        $existingValue = $customFields.PSObject.Properties[$organizationFieldName].Value -as [string]
                    } catch {
                        Write-Error "Failed to retrieve custom fields for '$OrgName': $_"
                        continue
                    }
                    if ($existingValue) {
                        $filteredValues = ($existingValue -split "," | ForEach-Object { $_.Trim() }) | Where-Object { $_ -notin $ValuesToRemove }
                        $updatedValue = $filteredValues -join ","
                    } else {
                        Write-Warning "No existing value for '$OrgName', skipping update."
                        continue
                    }
                    $requestBody = @{ ($organizationFieldName) = $updatedValue } | ConvertTo-Json -Depth 10
                    Write-Host "Updating custom field for organization '$OrgName' with ID: $orgId"
                    Write-Host "Updated value: $updatedValue"
                    try {
                        Start-Sleep -Milliseconds 200
                        Invoke-RestMethod -Method PATCH -Uri $customFieldsUrl -Headers $headers -Body $requestBody -ContentType "application/json"
                        Write-Host "Successfully updated custom field for '$OrgName'."
                    } catch {
                        Write-Error "Failed to update custom field for '$OrgName': $_"
                    }
                } else {
                    Write-Warning "Organization '$OrgName' not found in NinjaOne."
                }
            }
        }
    }
}

#############################
# Section 4 - Adding software to select devices for deployment
if ($Option7) {
    if ($Option7 -ieq "ALL") {
        Write-Error "Not possible to update software to all devices, provide a CSV target..." -ForegroundColor Red
    } else {
        if ($Option8) {
            Write-Host "Updating select devices with new software to deploy..." -ForegroundColor Cyan
            $DeviceNames = $Option7 -split "," | ForEach-Object { $_.Trim() }
            $NewCustomFieldValues = $Option8 -split "," | ForEach-Object { $_.Trim() }
            foreach ($DeviceName in $DeviceNames) {
                $device = $devices | Where-Object { $_.systemName -eq $DeviceName }
                if ($null -ne $device) {
                    $customFieldsUrl = "https://$NinjaOneInstance/api/v2/device/$($device.id)/custom-fields"
                    try {
                        $customFields = Invoke-RestMethod -Uri $customFieldsUrl -Method GET -Headers $headers
                        $existingValue = $customFields.PSObject.Properties[$deviceFieldName].Value -as [string]
                    } catch {
                        Write-Error "Failed to retrieve custom fields for '$DeviceName': $_"
                        continue
                    }
                    if ($existingValue) {
                        $combinedValues = ($existingValue -split "," | ForEach-Object { $_.Trim() }) + $NewCustomFieldValues
                        $updatedValue = ($combinedValues | Sort-Object | Get-Unique) -join ","
                    } else {
                        $updatedValue = $NewCustomFieldValues -join ","
                    }
                    $requestBody = @{ ($deviceFieldName) = $updatedValue } | ConvertTo-Json -Depth 10
                    try {
                        Start-Sleep -Milliseconds 200
                        Invoke-RestMethod -Uri $customFieldsUrl -Method PATCH -Headers $headers -Body $requestBody -ContentType "application/json"
                        Write-Host "Updated custom field for '$DeviceName' with value: $updatedValue"
                    } catch {
                        Write-Error "Failed to update custom field for '$DeviceName': $_"
                    }
                } else {
                    Write-Warning "Device '$DeviceName' not found in NinjaOne."
                }
            }
        }
    }
}

#############################
# Section 5 - Removing device-specific softare from deployment list
if ($Option9) {
    if ($Option9 -ieq "ALL") {
        Write-Error "Not possible to remove software across all devices, provide a CSV target..." -ForegroundColor Red
    } else {
        if ($Option10) {
            Write-Host "Updating select devices to remove software from deployment list..." -ForegroundColor Cyan
            $DeviceNames = $Option9 -split "," | ForEach-Object { $_.Trim() }
            $ValuesToRemove = $Option10 -split "," | ForEach-Object { $_.Trim() }
            foreach ($DeviceName in $DeviceNames) {
                $device = $devices | Where-Object { $_.systemName -eq $DeviceName }
                if ($null -ne $device) {
                    $deviceId = $device.id
                    $customFieldsUrl = "https://$NinjaOneInstance/api/v2/device/$deviceId/custom-fields"
                    try {
                        $customFields = Invoke-RestMethod -Uri $customFieldsUrl -Method GET -Headers $headers
                        $existingValue = $customFields.PSObject.Properties[$deviceFieldName].Value -as [string]
                    } catch {
                        Write-Error "Failed to retrieve custom fields for '$DeviceName': $_"
                        continue
                    }
                    if ($existingValue) {
                        $filteredValues = ($existingValue -split "," | ForEach-Object { $_.Trim() }) | Where-Object { $_ -notin $ValuesToRemove }
                        $updatedValue = $filteredValues -join ","
                    } else {
                        Write-Warning "No existing value for '$DeviceName', skipping update."
                        continue
                    }
                    if (!$updatedValue) {
                        $updatedValue = $null
                    }
                    $requestBody = @{ ($deviceFieldName) = $updatedValue } | ConvertTo-Json -Depth 10
                    Write-Host "Updating custom field for device '$DeviceName' with ID: $deviceId"
                    Write-Host "Updated value: $updatedValue"
                    try {
                        Start-Sleep -Milliseconds 200
                        Invoke-RestMethod -Method PATCH -Uri $customFieldsUrl -Headers $headers -Body $requestBody -ContentType "application/json"
                        Write-Host "Successfully updated custom field for '$DeviceName'."
                    } catch {
                        Write-Error "Failed to update custom field for '$DeviceName': $_"
                    }
                } else {
                    Write-Warning "Device '$DeviceName' not found in NinjaOne."
                }
            }
        }
    }
}

Write-Host "Script execution completed." -ForegroundColor Green
