<#

Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

Notes du Script :
# Une évaluation et des tests supplémentaires avec les hôtes VMware et Hyper-V sont recommandés pour assurer une tabulation précise
# Plus d'informations ici : https://ninjarmm.zendesk.com/hc/en-us/community/posts/4424760908813/comments/4445857839757

Attributions :
# Juan Miguel, Steve Mohring, Alexander Wissfeld

#>

$NinjaOneInstance     = "app.ninjarmm.com"
$NinjaOneClientId     = "-"
$NinjaOneClientSecret = "-"

# Initialiser les paramètres du corps pour l'authentification OAuth 2.0
$body = @{
    grant_type = "client_credentials" # Définit le type d'autorisation demandé
    client_id = $NinjaOneClientId # Votre ID d'application client NinjaRMM
    client_secret = $NinjaOneClientSecret # Votre secret d'application client NinjaRMM
    scope = "monitoring" # La portée d'accès demandée
}

# Créer un dictionnaire pour contenir les en-têtes de la requête d'authentification
$API_AuthHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$API_AuthHeaders.Add("accept", 'application/json')
$API_AuthHeaders.Add("Content-Type", 'application/x-www-form-urlencoded')

# S'authentifier avec NinjaRMM et récupérer le jeton d'accès
$auth_token = Invoke-RestMethod -Uri https://$NinjaOneInstance/oauth/token -Method POST -Headers $API_AuthHeaders -Body $body
$access_token = $auth_token | Select-Object -ExpandProperty 'access_token' -EA 0

# Préparer les en-têtes pour les requêtes API suivantes en utilisant le jeton d'accès obtenu
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept", 'application/json')
$headers.Add("Authorization", "Bearer $access_token")

# Obtenir la date actuelle au format yyyyMMdd
$today = Get-Date -format "yyyyMMdd"

# Définir le chemin du fichier pour le rapport de licences
$licenses_report = "C:\Users\JeffHunter\NinjaReports\" + $today + "_Ninja_Licenses_Report.csv"

# Définir les points de terminaison API pour les appareils et organisations
$devices_url = "https://$NinjaOneInstance/v2/devices"
$organizations_url = "https://$NinjaOneInstance/v2/organizations"
$remotes_url = "https://$NinjaOneInstance/v2/group/16/device-ids"
$bitdefenders_url = "https://$NinjaOneInstance/v2/group/8/device-ids"
$webroots_url = "https://$NinjaOneInstance/v2/group/7/device-ids"

# Récupérer les données depuis l'API NinjaRMM
try {
    $devices = Invoke-RestMethod -Uri $devices_url -Method GET -Headers $headers
    $organizations = Invoke-RestMethod -Uri $organizations_url -Method GET -Headers $headers
    $remotes = Invoke-RestMethod -Uri $remotes_url -Method GET -Headers $headers
    $bitdefenders = Invoke-RestMethod -Uri $bitdefenders_url -Method GET -Headers $headers
    $webroots = Invoke-RestMethod -Uri $webroots_url -Method GET -Headers $headers
}
catch {
    Write-Error "Failed to connect to NinjaOne API. Error: $_"
    exit
}


# Étendre les objets organisations avec des propriétés supplémentaires pour classifier les appareils
Foreach ($organization in $organizations) {
    Add-Member -InputObject $organization -NotePropertyName "Workstations" -NotePropertyValue @()
    Add-Member -InputObject $organization -NotePropertyName "Servers" -NotePropertyValue @()
    Add-Member -InputObject $organization -NotePropertyName "Networks" -NotePropertyValue @()
    Add-Member -InputObject $organization -NotePropertyName "Remotes" -NotePropertyValue @()
    Add-Member -InputObject $organization -NotePropertyName "Bitdefenders" -NotePropertyValue @()
    Add-Member -InputObject $organization -NotePropertyName "Webroots" -NotePropertyValue @()
}

# Énumérer les appareils et les assigner à leur organisation et catégorie respectives
Write-Host 'Enumerating everything ...'
Foreach ($device in $devices) {
    $currentOrg = $organizations | Where-Object {$_.id -eq $device.organizationId}
    if ($device.nodeClass.EndsWith("_SERVER")) {
        $currentOrg.servers += $device.systemName
    } elseif ($device.nodeClass.EndsWith("_WORKSTATION") -or $device.nodeClass -eq "MAC") {
        $currentOrg.workstations += $device.systemName
    } elseif ($device.nodeClass.StartsWith("NMS")) {
        $currentOrg.networks += $device.id
    }
    if ($remotes.Contains($device.id)) { $currentOrg.remotes += $device.systemName }
    if ($bitdefenders.Contains($device.id)) { $currentOrg.bitdefenders += $device.systemName }
    if ($webroots.Contains($device.id)) { $currentOrg.webroots += $device.systemName }
}
Write-Host 'Done ✅'

# Créer et afficher un rapport récapitulatif des organisations et leurs nombres d'appareils
$reportSummary = Foreach ($organization in $organizations) {
    [PSCustomObject]@{
        Name = $organization.Name
        Workstations = $organization.workstations.length
        Servers = $organization.servers.length
        TotalDevices = ($organization.workstations.length + $organization.servers.length)
        NetworkDevices = $organization.networks.length
        RemoteAccessEnabled = $organization.remotes.length
        BitdefenderEnabled = $organization.bitdefenders.length
        WebrootEnabled = $organization.webroots.length
    }
}

# Afficher le rapport récapitulatif en format tableau
$reportSummary | Format-Table | Out-String

# Exporter le rapport vers un fichier CSV
$reportSummary | Export-CSV -NoTypeInformation -Path $licenses_report

# Confirmer la complétion et l'emplacement du rapport
Write-Host "CSV files have been created with success!"
Write-Host "Go to $licenses_report to find your Licenses Report"
