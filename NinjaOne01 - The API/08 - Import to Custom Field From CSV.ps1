<#

Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

#>

$NinjaOneInstance     = "app.ninjarmm.com"
$NinjaOneClientId     = "-"
$NinjaOneClientSecret = "-"

# Définir les détails d'authentification
$body = @{
    grant_type = "client_credentials"
    client_id = $NinjaOneClientId # Remplacer par votre ID client réel
    client_secret = $NinjaOneClientSecret # Remplacer par votre secret client réel
    scope = "monitoring management"
}

# Définir les en-têtes pour la requête d'authentification
$API_AuthHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$API_AuthHeaders.Add("accept", 'application/json')
$API_AuthHeaders.Add("Content-Type", 'application/x-www-form-urlencoded')

# Obtenir un jeton d'accès depuis le point de terminaison OAuth NinjaRMM
try {
    $auth_token = Invoke-RestMethod -Uri https://$NinjaOneInstance/oauth/token -Method POST -Headers $API_AuthHeaders -Body $body
    $access_token = $auth_token.access_token
}
catch {
    Write-Error "Failed to connect to NinjaOne API. Error: $_"
    exit}

# Vérifier si nous avons obtenu un jeton d'accès avec succès
if (-not $access_token) {
    Write-Host "Failed to obtain access token. Please check your client ID and client secret."
    exit
}

# Définir les en-têtes pour les requêtes API suivantes en utilisant le jeton d'accès obtenu
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept", 'application/json')
$headers.Add("Authorization", "Bearer $access_token")

# Importer les données d'appareils depuis un fichier CSV
$deviceimports = Import-CSV -Path "C:\Users\JeffHunter\OneDrive - NinjaOne\Scripting\NinjaOne01 - The API\NinjaOne01 - The API\Resources\Import to Device CF.csv"

# Préparer la liste des appareils à partir des données CSV importées
$assets = Foreach ($deviceimport in $deviceimports) {
    [PSCustomObject]@{
        Name = $deviceimport.name
        AssetOwner = $deviceimport.assetOwner
        ID = $deviceimport.Id
    }
}

# Mettre à jour les champs personnalisés pour chaque appareil
foreach ($asset in $assets) {
    # Construire l'URL pour le point de terminaison des champs personnalisés de l'appareil
    $customfields_url = "https://$NinjaOneInstance/api/v2/device/" + $asset.ID + "/custom-fields"

    # Préparer le corps de la requête avec les données du champ personnalisé
    $request_body = @{
        assetOwner = $asset.AssetOwner
    }

    # Convertir le corps de la requête au format JSON
    $json = $request_body | ConvertTo-Json

    # Afficher l'opération en cours
    Write-Host "Patching custom fields for: " $asset.Name

    # Envoyer une requête PATCH pour mettre à jour les champs personnalisés de l'appareil
    Invoke-RestMethod -Method 'Patch' -Uri $customfields_url -Headers $headers -Body $json -ContentType "application/json" -Verbose
}
