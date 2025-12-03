<#

Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja en utilisant le type d'autorisation client credentials.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

#>

$NinjaOneInstance     = "app.ninjarmm.com"
$NinjaOneClientId     = "-"
$NinjaOneClientSecret = "-"

# Corps pour l'authentification
$body = @{
    grant_type = "client_credentials"
    client_id = $NinjaOneClientId
    client_secret = $NinjaOneClientSecret
    scope = "monitoring management"
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

# Appeler les URLs Ninja pour obtenir les données
try {
    $devices = Invoke-RestMethod -Uri $devices_url -Method GET -Headers $headers
    $organizations = Invoke-RestMethod -Uri $organizations_url -Method GET -Headers $headers
}
catch {
    Write-Error "Failed to retrieve organizations and devices from NinjaOne API. Error: $_"
    exit
}

# Étendre les objets organisations avec des propriétés supplémentaires pour classifier les appareils
Foreach ($organization in $organizations) {
    Add-Member -InputObject $organization -NotePropertyName "Workstations" -NotePropertyValue @()
    Add-Member -InputObject $organization -NotePropertyName "Servers" -NotePropertyValue @()
}

# Parcourir tous les appareils et copier chaque appareil vers l'organisation correspondante, avec des propriétés séparées pour stocker serveurs et stations de travail
Foreach ($device in $devices) {
    $currentOrg = $organizations | Where-Object {$_.id -eq $device.organizationId}
    if ($device.nodeClass.EndsWith("_SERVER")) {
        $currentOrg.servers += $device.systemName
    } elseif ($device.nodeClass.EndsWith("_WORKSTATION") -or $device.nodeClass -eq "MAC") {
        $currentOrg.workstations += $device.systemName
    }
}

# Créer et afficher un rapport récapitulatif des organisations et leurs nombres d'appareils ventilés par serveurs et stations de travail, plus le total des appareils
$reportSummary = Foreach ($organization in $organizations) {
    [PSCustomObject]@{
        Name = $organization.Name
        Workstations = $organization.workstations.length
        Servers = $organization.servers.length
        TotalDevices = ($organization.workstations.length + $organization.servers.length)
    }
}

# Afficher le rapport récapitulatif en format tableau
$reportSummary | Format-Table | Out-String
