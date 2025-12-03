<#

Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

#>

# Vos identifiants NinjaRMM
$NinjaOneInstance = 'ca.ninjarmm.com' # This varies depending on region or environment. For example, if you are in the US, this would be '$NinjaOneInstance'
$NinjaOneClientId = ''
$NinjaOneClientSecret = ''

# Ajouter l'ID du groupe (tous les appareils du groupe seront déplacés vers une organisation et un emplacement spécifiques)
$GroupID = '222'
$organizationId = '8'
$locationId = '18'

$body = @{
  grant_type = "client_credentials"
  client_id = $NinjaOneClientId
  client_secret = $NinjaOneClientSecret
  scope = "monitoring management"
}
    
$API_AuthHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$API_AuthHeaders.Add("accept", 'application/json')
$API_AuthHeaders.Add("Content-Type", 'application/x-www-form-urlencoded')
   
$auth_token = Invoke-RestMethod -Uri https://$NinjaOneInstance/oauth/token -Method POST -Headers $API_AuthHeaders -Body $body
$access_token = $auth_token | Select-Object -ExpandProperty 'access_token' -EA 0
   
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept", 'application/json')
$headers.Add("Authorization", "Bearer $access_token")
    

$groupdevices_url = "https://$NinjaOneInstance/v2/group/$GroupID/device-ids"

# Récupère tous les IDs d'appareils dans ce groupe
$groupdevices = Invoke-RestMethod -Uri $groupdevices_url -Method GET -Headers $headers
  

# Pour chaque ID d'appareil trouvé dans ce groupe, un appel API est fait pour déplacer l'appareil vers une organisation et un emplacement spécifiques
  foreach ($key in $groupdevices) {

  # définir les urls ninja
  $deviceupdates_url = "https://$NinjaOneInstance/api/v2/device/" + $key

  # définir le corps de la requête - besoin de trouver l'ID de rôle désiré tel que défini dans https://$NinjaOneInstance/api/v2/roles
  $request_body = @{
    organizationId = $organizationId
    locationId = $locationId
  }

  # convertir le corps en JSON
  $json = $request_body | ConvertTo-Json

  Write-Host "Assigning device role to" $key

  # Faisons la magie opérer
  Invoke-RestMethod -Method 'Patch' -Uri $deviceupdates_url -Headers $headers -Body $json -ContentType "application/json" -Verbose
  }
