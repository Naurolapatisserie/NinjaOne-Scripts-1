<#

Script PowerShell pour générer un rapport des installations de correctifs d'appareils Windows du mois précédent dans une organisation spécifique en utilisant l'API NinjaOne
Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

#>

$NinjaOneInstance     = "app.ninjarmm.com"
$NinjaOneClientId     = "-"
$NinjaOneClientSecret = "-"

# Détails d'authentification API
$body = @{
    grant_type = "client_credentials"
    client_id = $NinjaOneClientId
    client_secret = $NinjaOneClientSecret
    scope = "monitoring"
}

# En-têtes pour la requête d'authentification
$API_AuthHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$API_AuthHeaders.Add("accept", 'application/json')
$API_AuthHeaders.Add("Content-Type", 'application/x-www-form-urlencoded')

# S'authentifier et récupérer le jeton d'accès
try {
    $auth_token = Invoke-RestMethod -Uri https://$NinjaOneInstance/oauth/token -Method POST -Headers $API_AuthHeaders -Body $body
    $access_token = $auth_token.access_token
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

# En-têtes pour les requêtes API suivantes, incluant le jeton d'accès obtenu
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
$FirstDayString = $firstDayOfPreviousMonth.ToString('yyyyMMdd')
$LastDayString = $lastDayOfPreviousMonth.ToString('yyyyMMdd')

# Afficher les résultats
Write-Host "First day of previous month: $firstDayString"
Write-Host "Last day of previous month: $lastDayString"

# Définir le chemin du fichier pour le rapport CSV de sortie
$today = Get-Date -format "yyyyMMdd"
$patchinfo_report = "C:\Users\JeffHunter\NinjaReports\${today}_Patch_Report.csv"

# Définir les points de terminaison API pour les informations d'appareil et de correctif
$devices_url = "https://$NinjaOneInstance/v2/devices"
$patchreport_url = "https://$NinjaOneInstance/api/v2/queries/os-patch-installs?df=class%20in%20(WINDOWS_WORKSTATION,%20WINDOWS_SERVER)&status=Installed&installedBefore=$LastDayString&installedAfter=$FirstDayString"

# Récupérer les appareils et les détails d'installation des correctifs
try {
    $devices = Invoke-RestMethod -Uri $devices_url -Method GET -Headers $headers
    $patchinstalls = Invoke-RestMethod -Uri $patchreport_url -Method GET -Headers $headers | Select-Object -ExpandProperty 'results'
}
catch {
    Write-Error "Failed to connect to NinjaOne API. Error: $_"
    exit
}

# Traiter chaque installation de correctif pour enrichir avec les informations d'appareil et d'organisation
foreach ($patchinstall in $patchinstalls) {
    $currentDevice = $devices | Where-Object {$_.id -eq $patchinstall.deviceId} | Select-Object -First 1
    # Ajouter le nom de l'appareil à chaque enregistrement d'installation de correctif
    Add-Member -InputObject $patchinstall -NotePropertyName "DeviceName" -NotePropertyValue $currentDevice.systemName
    # Convertir les horodatages du temps Unix au format DateTime
    $patchinstall.installedAt = ([DateTimeOffset]::FromUnixTimeSeconds($patchinstall.installedAt).DateTime).ToString()
    $patchinstall.timestamp = ([DateTimeOffset]::FromUnixTimeSeconds($patchinstall.timestamp).DateTime).ToString()
}

# Afficher les installations de correctifs dans un tableau formaté
$patchinstalls | Select-Object name, status, installedAt, kbNumber, DeviceName | Format-Table

# Exporter les détails d'installation des correctifs vers un fichier CSV
$patchinstalls | Select-Object name, status, installedAt, kbNumber, DeviceName | Export-CSV -NoTypeInformation -Path $patchinfo_report
