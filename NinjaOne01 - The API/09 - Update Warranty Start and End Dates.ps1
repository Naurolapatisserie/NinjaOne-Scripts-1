<#

Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

#>

$NinjaOneInstance     = "app.ninjarmm.com"
$NinjaOneClientId     = "-"
$NinjaOneClientSecret = "-"

# Importer les données d'appareils depuis un fichier CSV
$warrantyimports = Import-CSV -Path "C:\Users\JeffHunter\OneDrive - NinjaOne\Scripting\NinjaOne01 - The API\NinjaOne01 - The API\Resources\warranty_data.csv"

function Convert-ToUnixTime {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [DateTime]$DateTime
    )
    try {
        # S'assurer que $DateTime est un objet DateTime valide
        if (-not $DateTime -or -not ($DateTime -is [DateTime])) {
            Write-Output "Invalid DateTime input: '$DateTime'"
            return 0
        }

        # Convertir en UTC et calculer l'horodatage Unix
        $unixTime = [Math]::Floor((($DateTime.ToUniversalTime()) - [datetime]'1970-01-01T00:00:00Z').TotalSeconds)
        return $unixTime
    }
    catch {
        Write-Error "Failed to convert to Unix time: $_"
    }
}

# Exemple d'utilisation :
$exampleDate = "2025-12-12"
try {
    $unixTimestamp = Convert-ToUnixTime -DateTime ([DateTime]::Parse($exampleDate))
    Write-Output "Unix Timestamp: $unixTimestamp"
}
catch {
    Write-Error "Error processing input: $_"
}


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
    $auth_token = Invoke-RestMethod -Uri https://$NinjaOneInstance/ws/oauth/token -Method POST -Headers $API_AuthHeaders -Body $body
    $access_token = $auth_token | Select-Object -ExpandProperty 'access_token' -EA 0
} catch {
    Write-Error "Failed to obtain authentication token. $_"
    exit 1
}

# Préparer les en-têtes pour les requêtes API suivantes
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept", 'application/json')
$headers.Add("Authorization", "Bearer $access_token")

# Récupérer la liste détaillée des appareils depuis NinjaOne
$devices_url = "https://$NinjaOneInstance/ws/api/v2/devices-detailed"
try {
    $devices = Invoke-RestMethod -Uri $devices_url -Method GET -Headers $headers
} catch {
    Write-Error "Failed to fetch devices. $_"
    exit 1
}

# Traiter chaque entrée d'importation d'appareil et ajouter systemName si correspondance
$assets = foreach ($warrantyimport in $warrantyimports) {
    # Trouver l'appareil correspondant par ID
    $device = $devices | Where-Object { $_.id -eq $warrantyimport.Id }

    # Créer l'objet actif avec le systemName si l'appareil est trouvé
    if ($device) {
        [PSCustomObject]@{
            Name = $warrantyimport.name
            StartDate = $warrantyimport.WarrantyStart
            EndDate = $warrantyimport.WarrantyEnd
            FullfillDate = $warrantyimport.MftrFullfill
            ID = $warrantyimport.Id
        }
    }

}

# Mettre à jour les noms d'affichage pour chaque actif
foreach ($asset in $assets) {
    if ($null -ne $asset.ID) {
        # Définir le point de terminaison API NinjaOne pour mettre à jour les informations de garantie
        $warranty_url = "https://$NinjaOneInstance/api/v2/device/" + $asset.ID
        
        $WarrantyFields = @{
            'startDate' = Convert-ToUnixTime -DateTime $asset.StartDate
            'endDate'   = Convert-ToUnixTime -DateTime $asset.EndDate
            'manufacturerFulfillmentDate' = Convert-ToUnixTime -DateTime $asset.FullfillDate
            }   

        $request_body = @{
            warranty = $WarrantyFields
        }

        # Convertir le corps de la requête en JSON
        $json = $request_body | ConvertTo-Json

        Write-Host "Uploading warranty data for:" $asset.ID

        # Mettre à jour les infos de garantie via l'API
        try {
            Invoke-RestMethod -Method 'Patch' -Uri $warranty_url -Headers $headers -Body $json -ContentType "application/json" -Verbose
        } catch {
            Write-Error "Failed to update set warranty info for $($asset.ID). $_"
        }
    } else {
        Write-Warning "Skipping warranty update for $($asset.ID) as ID is null."
    }
}
