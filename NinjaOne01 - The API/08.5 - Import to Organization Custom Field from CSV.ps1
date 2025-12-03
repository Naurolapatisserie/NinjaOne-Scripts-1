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
    client_id = $NinjaOneClientId  # Remplacer par votre ID client réel
    client_secret = $NinjaOneClientSecret  # Remplacer par votre secret client réel
    scope = "monitoring management"
}

# Charger le fichier CSV contenant les données d'organisation
$deviceimports = Import-CSV -Path "C:\Users\JeffHunter\OneDrive - NinjaRMM\Scripting\Final Versions\CSVs\Import to Org CF.csv"

# Configurer les en-têtes pour la requête d'authentification
$API_AuthHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$API_AuthHeaders.Add("accept", 'application/json')
$API_AuthHeaders.Add("Content-Type", 'application/x-www-form-urlencoded')

# S'authentifier et récupérer le jeton d'accès
$auth_uri = "https://$NinjaOneInstance/oauth/token"
$auth_token = Invoke-RestMethod -Uri $auth_uri -Method POST -Headers $API_AuthHeaders -Body $body
$access_token = $auth_token.access_token

# Préparer les en-têtes pour les requêtes API suivantes
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept", 'application/json')
$headers.Add("Authorization", "Bearer $access_token")

# Récupérer les organisations
$organizations_url = "https://$NinjaOneInstance/v2/organizations"
try {
    $organizations = Invoke-RestMethod -Uri $organizations_url -Method GET -Headers $headers
}
catch {
    Write-Error "Failed to retrieve organizations from NinjaOne API. Error: $_"
    exit
}

# Traiter chaque entrée dans le CSV
$assets = Foreach ($deviceimport in $deviceimports) {
    [PSCustomObject]@{
        ID = 0
        DisplayName = $deviceimport.'Organization Name'
        OrgCustomField = $deviceimport.'Custom Field'
        OrgVariable = $deviceimport.'Organization Variable'
    }
}

# Mettre à jour l'ID pour chaque actif basé sur le nom d'organisation correspondant
foreach ($organization in $organizations) {
    foreach ($asset in $assets) {
        if ($asset.DisplayName -like $organization.name) {
            $asset.ID = $organization.id
        }
    }
}

# Patcher les champs personnalisés pour chaque organisation
foreach ($asset in $assets) {
    $customfields_url = "https://$NinjaOneInstance/api/v2/organization/$($asset.ID)/custom-fields"
  
    # Construire dynamiquement le corps de la requête en utilisant le nom et la valeur du champ personnalisé
    $request_body = @{
        $asset.OrgCustomField = $asset.OrgVariable
    }

    $json = $request_body | ConvertTo-Json

    Write-Host "Patching custom fields for: $($asset.DisplayName) with an organization ID of: $($asset.ID)"
    Write-Host "Writing into URL: $customfields_url"

    # Exécuter la requête PATCH
    try {
        Invoke-RestMethod -Method 'Patch' -Uri $customfields_url -Headers $headers -Body $json -ContentType "application/json" -Verbose
    }
    catch {
        Write-Error "Failed to connect to NinjaOne API. Error: $_"
        exit
    }
}
