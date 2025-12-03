<#

Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

Notes du Script :
# Ceci utilise un module tiers pour générer un rapport HTML appelé PSWriteHTML
# Le script peut être modifié pour produire un CSV si préféré

#>

# Installer et importer le module requis
# Vérifier si le module PSWriteHTML est installé
$module = Get-Module -ListAvailable -Name PSWriteHTML
if (-not $module) {
    # Si le module n'est pas installé, l'installer
    Install-Module -Name PSWriteHTML -AllowClobber -Force
}
# Importer le module PSWriteHTML
Import-Module -Name PSWriteHTML

$NinjaOneInstance     = "app.ninjarmm.com"
$NinjaOneClientId     = "-"
$NinjaOneClientSecret = "-"

# Corps pour l'authentification
$body = @{
    grant_type = "client_credentials"
    client_id = $NinjaOneClientId
    client_secret = $NinjaOneClientSecret
    scope = "monitoring"
}

# En-têtes pour l'authentification
$API_AuthHeaders = @{
    'accept' = 'application/json'
    'Content-Type' = 'application/x-www-form-urlencoded'
}

# S'authentifier et obtenir le jeton d'accès
try {
    $auth_token = Invoke-RestMethod -Uri "https://$NinjaOneInstance/oauth/token" -Method POST -Headers $API_AuthHeaders -Body $body
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
# En-têtes pour les appels API suivants
$headers = @{
    'accept' = 'application/json'
    'Authorization' = "Bearer $access_token"
}

# Définir les URLs Ninja
$devices_url = "https://$NinjaOneInstance/v2/devices-detailed"
$organizations_url = "https://$NinjaOneInstance/v2/organizations-detailed"
$locations_url = "https://$NinjaOneInstance/v2/locations"
$softwares_url = "https://$NinjaOneInstance/v2/queries/software"

# Appeler les URLs Ninja pour obtenir les données
try {
    $devices = Invoke-RestMethod -Uri $devices_url -Method GET -Headers $headers
    $organizations = Invoke-RestMethod -Uri $organizations_url -Method GET -Headers $headers
    $locations = Invoke-RestMethod -Uri $locations_url -Method GET -Headers $headers
    $softwares = Invoke-RestMethod -Uri $softwares_url -Method GET -Headers $headers
}
catch {
    Write-Error "Failed to retrieve data from NinjaOne API. Error: $_"
    exit
}

# Définir les noms d'applications pour le filtrage
$appNames = @("Chrome", "Firefox", "Edge")

# Filtrer les résultats logiciels
$filteredObjCreated = $softwares.results | Where-Object { $_.name -ne $null } | Select-Object name, version, deviceId, publisher
$filteredObj = $appNames | ForEach-Object {
    $appName = $_
    $filteredObjCreated | Where-Object { $_.name -like "*$appName*" }
} | Sort-Object deviceId -Unique

# Ajouter le nom de l'appareil, le nom de l'organisation et le nom de l'emplacement pour faire un rapport complet
foreach ($device in $devices){
    $currentDev = $filteredObj | Where-Object {$_.deviceId -eq $device.id}
    $currentDev | Add-Member -MemberType NoteProperty -Name 'DeviceName' -Value $device.systemname -Force
    $currentDev | Add-Member -MemberType NoteProperty -Name 'OrgID' -Value $device.organizationId -Force
    $currentDev | Add-Member -MemberType NoteProperty -Name 'LocID' -Value $device.locationId -Force       
}
foreach ($organization in $organizations){
    $currentOrg = $filteredObj | Where-Object {$_.OrgID -eq $organization.id}
    $currentOrg | Add-Member -MemberType NoteProperty -Name 'OrgName' -Value $organization.name -Force  
}
foreach ($location in $locations){
    $currentLoc = $filteredObj | Where-Object {$_.LocID -eq $location.id}
    $currentLoc | Add-Member -MemberType NoteProperty -Name 'LocName' -Value $location.name -Force 
}

# Afficher la vue HTML
$filteredObj | Out-HtmlView
