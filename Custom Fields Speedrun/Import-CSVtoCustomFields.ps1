<#
Ce script démontre comment interagir avec l'API NinjaOne, importer des données d'appareils à partir d'un fichier CSV,
correspondre ces données avec les appareils de NinjaOne et mettre à jour les champs personnalisés de manière dynamique en fonction des en-têtes du CSV.
Il inclut une gestion des erreurs améliorée, une journalisation et une génération dynamique du corps de la requête.

Paramètres :
- $OverwriteEmptyValues : Détermine si les valeurs vides du CSV sont incluses comme $null (en écrasant les données existantes)
  ou exclues du payload de mise à jour. (Par défaut : $false)

Avant d'exécuter ce script :
- Assurez-vous que le fichier CSV (csvexample.csv) a au moins les colonnes suivantes : Id, name.
- Les colonnes supplémentaires du CSV (par exemple, assetOwner, location, etc.) seront utilisées comme champs personnalisés.
- Remplacez $NinjaOneClientId et $NinjaOneClientSecret par vos identifiants.

#>

param(
    [bool]$OverwriteEmptyValues = $false
)

# Vos identifiants NinjaRMM
$NinjaOneInstance = ''  # Varie en fonction de la région/environnement (par exemple 'app.ninjarmm.com' pour les États-Unis)
$NinjaOneClientId = ''                  # Entrez votre ID client ici
$NinjaOneClientSecret = ''              # Entrez votre secret client ici

# Importer les données d'appareils depuis un fichier CSV
$csvPath = "C:\Users\JeffHunter\OneDrive - NinjaOne\Custom Fields Speedrun\datatoimport.csv"

try {
    $deviceimports = Import-Csv -Path $csvPath
} catch {
    Write-Error "Échec de l'importation du fichier CSV à partir de $csvPath. $_"
    exit 1
}

# Valider que le CSV a les colonnes requises (Id et name)
$requiredColumns = @("Id", "name")
foreach ($col in $requiredColumns) {
    if (-not ($deviceimports[0].PSObject.Properties.Name -contains $col)) {
        Write-Error "Le fichier CSV manque de la colonne requise '$col'. Veuillez vérifier la structure du CSV."
        exit 1
    }
}

Write-Host "Importation du CSV réussie. Traitement de $($deviceimports.Count) entrées..."

# Préparer le corps pour l'authentification
$body = @{
    grant_type    = "client_credentials"
    client_id     = $NinjaOneClientId
    client_secret = $NinjaOneClientSecret
    scope         = "monitoring management"
}

# Préparer les en-têtes pour la requête d'authentification
$API_AuthHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$API_AuthHeaders.Add("accept", "application/json")
$API_AuthHeaders.Add("Content-Type", "application/x-www-form-urlencoded")

# Obtenir le jeton d'authentification
try {
    $auth_token = Invoke-RestMethod -Uri "https://$NinjaOneInstance/oauth/token" -Method POST -Headers $API_AuthHeaders -Body $body
    $access_token = $auth_token.access_token
} catch {
    Write-Error "Échec de l'obtention du jeton d'authentification. $_"
    exit 1
}

# Préparer les en-têtes pour les requêtes API suivantes
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept", "application/json")
$headers.Add("Authorization", "Bearer $access_token")

# Récupérer la liste détaillée des appareils de NinjaOne
$devices_url = "https://$NinjaOneInstance/v2/devices-detailed"
try {
    $devices = Invoke-RestMethod -Uri $devices_url -Method GET -Headers $headers
} catch {
    Write-Error "Échec de la récupération des appareils. $_"
    exit 1
}

# Fonction : Invoke-NinjaAPIRequest avec un mécanisme de réessai
function Invoke-NinjaAPIRequest {
    param (
        [Parameter(Mandatory = $true)][string]$Uri,
        [string]$Method = 'GET',
        [Parameter(Mandatory = $true)][hashtable]$Headers,
        [string]$Body = $null
    )

    $maxRetries = 3
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        try {
            return Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -Body $Body -ContentType "application/json"
        } catch {
            Write-Error "La requête API vers $Uri a échoué à la tentative $($retryCount + 1) : $_"
            $retryCount++
            Start-Sleep -Seconds 2
        }
    }
    Write-Error "La requête API vers $Uri a échoué après $maxRetries tentatives."
    return $null
}

# Traiter chaque entrée d'importation d'appareil et préparer les objets d'actifs avec des champs personnalisés dynamiques.
$assets = foreach ($deviceimport in $deviceimports) {
    # Trouver l'appareil correspondant par ID
    $device = $devices | Where-Object { $_.id -eq $deviceimport.Id }

    # Construire un dictionnaire dynamique de champs personnalisés à partir du CSV.
    # Exclure les champs connus ('Id' et 'name') ; inclure toutes les autres colonnes.
    $customFields = @{}
    foreach ($property in $deviceimport.PSObject.Properties) {
        if ($property.Name -notin @("Id", "name")) {
            # Vérifier la valeur vide.
            if ([string]::IsNullOrEmpty($property.Value)) {
                if ($OverwriteEmptyValues) {
                    # Inclure la propriété avec une valeur $null pour écraser les données existantes.
                    $customFields[$property.Name] = $null
                } else {
                    # Ignorer la propriété pour laisser les données actuelles intactes.
                    continue
                }
            } else {
                $customFields[$property.Name] = $property.Value
            }
        }
    }

    if ($device) {
        [PSCustomObject]@{
            Name         = $deviceimport.name
            ID           = $deviceimport.Id
            SystemName   = $device.systemName
            CustomFields = $customFields
        }
    } else {
        Write-Warning "L'appareil ID $($deviceimport.Id) n'a pas été trouvé dans la liste des appareils."
        [PSCustomObject]@{
            Name         = $deviceimport.name
            ID           = $deviceimport.Id
            SystemName   = $null
            CustomFields = $customFields
        }
    }
}

# Debug : Afficher les actifs importés.
Write-Host "Actifs importés :"
$assets | ForEach-Object { Write-Host "ID : $($_.ID) - Nom : $($_.Name) - Nom du système : $($_.SystemName)" }

# Mettre à jour les champs personnalisés pour chaque actif (uniquement si SystemName n'est pas null et qu'il y a des champs personnalisés à mettre à jour)
foreach ($asset in $assets) {
    if (($null -ne $asset.SystemName) -and $asset.CustomFields.Count -gt 0) {
        # Définir le point de terminaison de l'API NinjaOne pour la mise à jour des champs personnalisés.
        $customfields_url = "https://$NinjaOneInstance/api/v2/device/$($asset.ID)/custom-fields"

        # Convertir le dictionnaire dynamique de champs personnalisés en JSON.
        $json = $asset.CustomFields | ConvertTo-Json -Depth 3

        Write-Host "Mise à jour des champs personnalisés pour : $($asset.SystemName) avec les données :"
        Write-Host $json

        # Mettre à jour les champs personnalisés via l'API en utilisant notre fonction d'assistance.
        $result = Invoke-NinjaAPIRequest -Uri $customfields_url -Method 'Patch' -Headers $headers -Body $json
        if ($result -eq $null) {
            Write-Error "Échec de la mise à jour des champs personnalisés pour $($asset.Name)."
        }
        
        # Optionnel : Délai pour aider à gérer les limites de débit de l'API.
        Start-Sleep -Seconds 1
    } else {
        Write-Warning "Skipping update for asset with ID $($asset.ID) as SystemName is null or no custom fields provided."
    }
}
