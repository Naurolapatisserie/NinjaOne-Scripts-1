<#

Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

#>

$NinjaOneInstance     = "app.ninjarmm.com"
$NinjaOneClientId     = "-"
$NinjaOneClientSecret = "-"

# Paramètres du script
$days = 3 # Nombre de jours dans le passé pour obtenir les données - augmenter ce nombre augmentera proportionnellement le temps d'exécution du script
$scriptName = "Process Log"

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

# Obtenir le jeton d'authentification
try {
    $authResponse = Invoke-RestMethod -Uri https://$NinjaOneInstance/oauth/token -Method POST -Headers $API_AuthHeaders -Body $body
    $access_token = $authResponse.access_token
} catch {
    Write-Error "Failed to authenticate. Error: $_"
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

# Calculs de dates
$date = (Get-Date).AddDays(-$days).ToString("yyyyMMdd")
$today = Get-Date -Format "yyyyMMdd"

# Chemin du fichier pour le rapport
$failedScriptsReport = "C:\Users\JeffHunter\NinjaReports\${today}_Script_Report.csv"

# Définir les points de terminaison API
$devices_url = "https://$NinjaOneInstance/v2/devices"
$activities_url = "https://$NinjaOneInstance/api/v2/activities?class=DEVICE&type=ACTION&status=COMPLETED&after=${date}&pageSize=1000"

# Récupérer les appareils et les activités initiales
# Le point de terminaison /activities/ est limité à 1000 entrées à la fois, donc la pagination doit être utilisée pour les ensembles de données plus importants
try {
    $devices = Invoke-RestMethod -Uri $devices_url -Method GET -Headers $headers
    $activitiesResponse = Invoke-RestMethod -Uri $activities_url -Method GET -Headers $headers
} catch {
    Write-Error "Failed to retrieve data. Error: $_"
    exit
}

$userActivities = $activitiesResponse.activities
$activitiesRemaining = $true
$olderThan = $userActivities[-1].id

# Paginer à travers les activités restantes si applicable
while($activitiesRemaining) {
    $activities_url = "https://$NinjaOneInstance/api/v2/activities?type=ACTION&status=COMPLETED&after=${date}&olderThan=${olderThan}&pageSize=1000"
    $response = Invoke-RestMethod -Uri $activities_url -Method GET -Headers $headers

    if ($response.activities.count -eq 0) {
        $activitiesRemaining = $false
    } else {
        $userActivities += $response.activities
        $olderThan = $response.activities[-1].id
    }
}

# Convertir l'horodatage Unix en format date/heure lisible - l'heure sera en UTC
foreach ($activity in $userActivities) {
    $activity.activityTime = ([System.DateTimeOffset]::FromUnixTimeSeconds($activity.activityTime)).DateTime.ToString()
}

# Filtrer toutes les activités de scripts terminés en recherchant explicitement les activités de scripts échoués qui correspondent au nom du script
$failedScripts = $userActivities | Where-Object { $_.activityResult -match "FAILURE" -and $_.sourceName.substring(4) -like "*$scriptName*"} | Select-Object deviceId,activityResult,activityTime,activityType,subject,message

# Mapper les noms d'appareils aux activités de scripts échoués
foreach ($failedScript in $failedScripts) {
    $failedScript | Add-Member -NotePropertyName "DeviceName" -NotePropertyValue ""
    $device = $devices | Where-Object {$_.id -eq $failedScript.deviceId}
    $failedScript.DeviceName = $device.systemName
}

# Préparer les données finales pour le rapport
$failedScripts = $failedScripts | Select-Object deviceName,activityResult,activityTime,activityType,message

if ($failedScripts.Count -eq 0) {
    Write-Host "No failed script executions have been found for the script and time period specified."
} else {
    Write-Host ($failedScripts | Format-Table | Out-String)
    # Décommenter la ligne ci-dessous pour activer l'export CSV
    $failedScripts | Export-Csv -NoTypeInformation -Path $failedScriptsReport
    Write-Host "CSV file containing failed scripts has been created successfully!"
    Write-Host "Go to $failedScriptsReport to find your Failed Scripts Report"
}
