<#

Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

#>

$NinjaOneInstance     = "app.ninjarmm.com"
$NinjaOneClientId     = "-"
$NinjaOneClientSecret = "-"

# Obtenir la date actuelle
$today = Get-Date -Format "HHmmss"
# définir le dossier de base
$basefolder = "C:\Users\JeffHunter\NinjaReports\"
# définir les chemins de fichiers
$patchinginforeport = $basefolder + "monthlypatchinginfo" + $today + "report.csv"

# Détails d'authentification API
$body = @{
    grant_type = "client_credentials"
    client_id = $NinjaOneClientId
    client_secret = $NinjaOneClientSecret
    scope = "monitoring"
}

$API_AuthHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$API_AuthHeaders.Add("accept", 'application/json')
$API_AuthHeaders.Add("Content-Type", 'application/x-www-form-urlencoded')

try {
    $auth_token = Invoke-RestMethod -Uri https://$NinjaOneInstance/oauth/token -Method POST -Headers $API_AuthHeaders -Body $body
    $access_token = $auth_token | Select-Object -ExpandProperty 'access_token' -EA 0
}
catch {
    Write-Error "Failed to connect to NinjaOne API. Error: $_"
    exit
}
# Vérifier si nous avons obtenu un jeton d'accès avec succès
if (-not $access_token) {
    Write-Host "Failed to obtain access token. Please check your client ID and client secret."
    exit
}

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept", 'application/json')
$headers.Add("Authorization", "Bearer $access_token")

# Initialiser la date (s'assurer que $date est définie)
$date = Get-Date

# Calculer le premier jour du mois précédent en utilisant des vérifications explicites
if ($date.Month -eq 1) {
    $prevMonth = 12
    $year = $date.Year - 1
} else {
    $prevMonth = $date.Month - 1
    $year = $date.Year
}

# Créer un objet DateTime pour le premier jour du mois précédent
$firstDayOfPreviousMonth = Get-Date -Year $year -Month $prevMonth -Day 1

# Calculer le dernier jour du mois précédent
$lastDayOfPreviousMonth = $firstDayOfPreviousMonth.AddMonths(1).AddDays(-1)

# Formater les dates en chaînes au format 'yyyyMMdd'
$firstDayString = $firstDayOfPreviousMonth.ToString('yyyyMMdd')
$lastDayString = $lastDayOfPreviousMonth.ToString('yyyyMMdd')

# Afficher les résultats
Write-Host "First day of previous month: $firstDayString"
Write-Host "Last day of previous month: $lastDayString"

# définir les urls ninja
$devices_url = "https://$NinjaOneInstance/v2/devices?df=class%20in%20(WINDOWS_WORKSTATION,%20WINDOWS_SERVER)"
$organizations_url = "https://$NinjaOneInstance/v2/organizations"
$activities_url = "https://$NinjaOneInstance/api/v2/activities?df=class%20in%20(WINDOWS_WORKSTATION,%20WINDOWS_SERVER)&class=DEVICE&type=PATCH_MANAGEMENT&status=in%20(PATCH_MANAGEMENT_APPLY_PATCH_COMPLETED,%20PATCH_MANAGEMENT_SCAN_COMPLETED,%20PATCH_MANAGEMENT_FAILURE)&after=" + $firstDayString + "&before=" + $lastDayString + "&pageSize=1000"
$patchreport_url = "https://$NinjaOneInstance/api/v2/queries/os-patch-installs?df=class%20in%20(WINDOWS_WORKSTATION,%20WINDOWS_SERVER)&status=Installed&installedAfter=" + $firstDayString + "&installedBefore=" + $lastDayString
$failedpatch_url = "https://$NinjaOneInstance/api/v2/queries/os-patch-installs?df=class%20in%20(WINDOWS_WORKSTATION,%20WINDOWS_SERVER)&status=Failed"

# appeler les urls ninja
try {
    $devices = Invoke-RestMethod -Uri $devices_url -Method GET -Headers $headers
    $request = Invoke-RestMethod -Uri $activities_url -Method GET -Headers $headers -Verbose
    $patchinstalls = Invoke-RestMethod -Uri $patchreport_url -Method GET -Headers $headers | Select-Object -ExpandProperty 'results'
    $patchfailures = Invoke-RestMethod -Uri $failedpatch_url -Method GET -Headers $headers | Select-Object -ExpandProperty 'results'
    $organizations = Invoke-RestMethod -Uri $organizations_url -Method GET -Headers $headers
}
catch {
    Write-Error "Failed to retrieve required data from NinjaOne API. Error: $_"
    exit}

$userActivities = $request.activities
$activitiesRemaining = $true
$olderThan = $userActivities[-1].id

# Boucler tant qu'il y a encore des activités disponibles dans la réponse API.
while($activitiesRemaining -eq $true) {
    $activities_url = "https://$NinjaOneInstance/api/v2/activities?df=class%20in%20(WINDOWS_WORKSTATION,%20WINDOWS_SERVER)&class=DEVICE&type=PATCH_MANAGEMENT&status=in%20(PATCH_MANAGEMENT_APPLY_PATCH_COMPLETED,%20PATCH_MANAGEMENT_SCAN_COMPLETED,%20PATCH_MANAGEMENT_FAILURE)&after=" + $firstDayString + "&before=" + $lastDayString + "&olderThan=" + $olderThan + "&pageSize=1000"
    $response = Invoke-RestMethod -Uri $activities_url -Method GET -Headers $headers

    if ($response.activities.count -eq 0) {
        $activitiesRemaining = $false
    } else {
        $userActivities += $response.activities
        $olderThan = $response.activities[-1].id
    }
}


# Filtrer les activités utilisateur
$patchScans = @()
$patchScanFailures = @()
$patchApplicationCycles = @()
$patchApplicationFailures = @()

foreach ($activity in $userActivities) {
    if ($activity.activityResult -match "SUCCESS") {
        if ($activity.statusCode -match "PATCH_MANAGEMENT_SCAN_COMPLETED") {
            $patchScans += $activity
        } elseif ($activity.statusCode -match "PATCH_MANAGEMENT_APPLY_PATCH_COMPLETED") {
            $patchApplicationCycles += $activity
        }
    } elseif ($activity.activityResult -match "FAILURE") {
        if ($activity.statusCode -match "PATCH_MANAGEMENT_SCAN_COMPLETED") {
            $patchScanFailures += $activity
        } elseif ($activity.statusCode -match "PATCH_MANAGEMENT_APPLY_PATCH_COMPLETED") {
            $patchApplicationFailures += $activity
        }
    }
}

# Indexer les appareils par ID pour une recherche plus rapide
$deviceIndex = @{}
foreach ($device in $devices) {
    $deviceIndex[$device.id] = $device
}

# Initialiser les objets organisation avec la propriété PatchFailures
foreach ($organization in $organizations) {
    Add-Member -InputObject $organization -NotePropertyName "PatchScans" -NotePropertyValue @() -Force
    Add-Member -InputObject $organization -NotePropertyName "PatchFailures" -NotePropertyValue @() -Force
    Add-Member -InputObject $organization -NotePropertyName "PatchInstalls" -NotePropertyValue @() -Force
    Add-Member -InputObject $organization -NotePropertyName "Workstations" -NotePropertyValue @() -Force
    Add-Member -InputObject $organization -NotePropertyName "Servers" -NotePropertyValue @() -Force

}

# Assigner les appareils aux organisations
foreach ($device in $devices) {
    $currentOrg = $organizations | Where-Object { $_.id -eq $device.organizationId }
    if ($device.nodeClass.EndsWith("_SERVER")) {
        $currentOrg.Servers += $device.systemName
    } elseif ($device.nodeClass.EndsWith("_WORKSTATION") -or $device.nodeClass -eq "MAC") {
        $currentOrg.Workstations += $device.systemName
    }
}

# Traiter les analyses de correctifs
foreach ($patchScan in $patchScans) {
    $device = $deviceIndex[$patchScan.deviceId]
    $patchScan | Add-Member -NotePropertyName "DeviceName" -NotePropertyValue $device.systemName -Force
    $patchScan | Add-Member -NotePropertyName "OrgID" -NotePropertyValue $device.organizationId -Force
    $organization = $organizations | Where-Object { $_.id -eq $device.organizationId }
    $organization.PatchScans += $patchScan
}

# Traiter les installations de correctifs
foreach ($patchinstall in $patchinstalls) {
    $device = $deviceIndex[$patchinstall.deviceId]
    $patchinstall | Add-Member -NotePropertyName "DeviceName" -NotePropertyValue $device.systemName -Force
    $patchinstall | Add-Member -NotePropertyName "OrgID" -NotePropertyValue $device.organizationId -Force
    $organization = $organizations | Where-Object { $_.id -eq $device.organizationId }
    $organization.PatchInstalls += $patchinstall
}

# Traiter les échecs d'installation de correctifs
foreach ($patchfailure in $patchfailures) {
    $device = $deviceIndex[$patchfailure.deviceId]
    $patchfailure | Add-Member -NotePropertyName "DeviceName" -NotePropertyValue $device.systemName -Force
    $patchfailure | Add-Member -NotePropertyName "OrgID" -NotePropertyValue $device.organizationId -Force
    $organization = $organizations | Where-Object { $_.id -eq $device.organizationId }
    $organization.PatchFailures += $patchfailure
}


# Générer les résultats
$results = foreach ($organization in $organizations) {
    [PSCustomObject]@{
        Name = $organization.Name
        Workstations = ($organization.Workstations).Count
        Servers = ($organization.Servers).Count
        Total = ($organization.Workstations).Count + ($organization.Servers).Count
        PatchScans = ($organization.PatchScans).Count
        PatchInstalls = ($organization.PatchInstalls).Count
        PatchFailures = ($organization.PatchFailures).Count
    }
}

# Exporter les résultats
Write-Output $results | Format-Table
$results | Export-CSV -NoTypeInformation -Path $patchinginforeport

Write-Host "CSV file has been created successfully!"
