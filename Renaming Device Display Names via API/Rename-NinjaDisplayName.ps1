<#
Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.
#>

# Vos identifiants NinjaRMM
$NinjaOneInstance = 'ca.ninjarmm.com' # Adjust if necessary based on your region
$NinjaOneClientId = ''
$NinjaOneClientSecret = ''

# Préparer le corps pour l'authentification
$body = @{
    grant_type = "client_credentials"
    client_id = $NinjaOneClientId
    client_secret = $NinjaOneClientSecret
    scope = "monitoring management"
}

# Préparer les en-têtes pour la requête d'authentification
$API_AuthHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$API_AuthHeaders.Add("accept", 'application/json')
$API_AuthHeaders.Add("Content-Type", 'application/x-www-form-urlencoded')

# Obtenir le jeton d'authentification
try {
    $auth_token = Invoke-RestMethod -Uri https://$NinjaOneInstance/oauth/token -Method POST -Headers $API_AuthHeaders -Body $body
    $access_token = $auth_token | Select-Object -ExpandProperty 'access_token' -EA 0
} catch {
    Write-Error "Failed to obtain authentication token. $_"
    exit 1
}

# Préparer les en-têtes pour les requêtes API suivantes
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept", 'application/json')
$headers.Add("Authorization", "Bearer $access_token")

# Importer les données d'appareils depuis un fichier CSV
$deviceimports = Import-CSV -Path "C:\Users\JeffHunter\Documents\NinjaReports\csvexample2.csv"

# Traiter chaque entrée d'importation d'appareil
$assets = foreach ($deviceimport in $deviceimports) {
    [PSCustomObject]@{
        Name = $deviceimport.systemName
        DisplayName = $deviceimport.displayName
        ID = $null
    }
}

# Récupérer la liste détaillée des appareils depuis NinjaOne
$devices_url = "https://$NinjaOneInstance/v2/devices"
try {
    $devices = Invoke-RestMethod -Uri $devices_url -Method GET -Headers $headers
} catch {
    Write-Error "Failed to fetch devices. $_"
    exit 1
}


# Faire correspondre les appareils et ajouter leurs IDs aux actifs
foreach ($device in $devices) {
    $currentDev = $assets | Where-Object { $_.Name -eq $device.systemName }
    if ($null -ne $currentDev) {
        $currentDev.ID = $device.id
    }
}

# Mettre à jour les noms d'affichage pour chaque actif
foreach ($asset in $assets) {
    if ($null -ne $asset.ID) {
        # Définir le point de terminaison API NinjaOne pour mettre à jour le nom d'affichage
        $displayname_url = "https://$NinjaOneInstance/api/v2/device/" + $asset.ID

        # Extraire le nom d'affichage et préparer le corps de la requête
        $displayname = $asset.DisplayName
        $request_body = @{
            displayName = "$displayname"
        }

        # Convertir le corps de la requête en JSON
        $json = $request_body | ConvertTo-Json

        Write-Host "Changing display name for:" $asset.Name "to" $asset.DisplayName

        # Mettre à jour le nom d'affichage via l'API
        try {
            Invoke-RestMethod -Method 'Patch' -Uri $displayname_url -Headers $headers -Body $json -ContentType "application/json" -Verbose
        } catch {
            Write-Error "Failed to update display name for $($asset.Name). $_"
        }
    } else {
        Write-Warning "Skipping update for $($asset.Name) as ID is null."
    }
}
