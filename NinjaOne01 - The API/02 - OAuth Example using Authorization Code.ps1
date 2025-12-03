<#

Ceci est fourni comme exemple éducatif de comment interagir avec l'API Ninja avec le type d'autorisation code d'autorisation et la plateforme d'application "Web".
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

# Attributions :
Ryan Southwell pour l'écouteur HTTP qui récupère le code d'autorisation

# Comment ce script fonctionne :
#   1) Définir les variables essentielles pour OAuth (client_id, client_secret, redirect_uri, scope, etc.).
#   2) Charger ou ajouter l'assembly System.Web si pas déjà chargé ; requis pour analyser les chaînes de requête URL.
#   3) Démarrer un serveur HTTP local qui écoute le code d'autorisation (callback de NinjaOne).
#   4) Ouvrir (lancer) une fenêtre de navigateur vers la page d'autorisation OAuth de NinjaOne.
#   5) Une fois autorisé, le script capture le paramètre "code" de l'URL redirigée.
#   6) Utiliser ce code d'autorisation, avec vos identifiants client, pour demander un jeton d'accès.
#   7) Définir les en-têtes avec le nouveau jeton Bearer.
#   8) Faire un appel API exemple (ex. récupérer une liste d'organisations).
#   9) Afficher les résultats dans la console.

#   AVERTISSEMENT : Ce script stocke intentionnellement les identifiants OAuth dans des variables (pour démonstration).
#   Dans un environnement de production, considérez stocker les identifiants de manière plus sécurisée en utilisant :
#       - Windows Credential Manager
#       - Module Secret Management dans PowerShell
#       - Azure Key Vault (dans les environnements Azure)
#   et toujours restreindre les permissions de fichiers pour tout secret stocké.

#>

$NinjaOneInstance     = "app.ninjarmm.com"
$NinjaOneClientId     = "-"
$NinjaOneClientSecret = "-"
$redirect_uri = "http://localhost:8888/"

# Portée OAuth2 et URL d'autorisation
$scope = "monitoring management"
$auth_url = "https://$NinjaOneInstance/ws/oauth/authorize"

# Cet assembly est requis pour analyser les chaînes de requête du callback URL
Try {
    [System.Web.HttpUtility] | Out-Null
}
Catch {
    Add-Type -AssemblyName System.Web
}

# Démarrer le Serveur HTTP Local pour Capturer le Code d'Auth
# L'écouteur répondra aux requêtes GET avec le paramètre 'code' dans la chaîne de requête
Write-Host "Starting HTTP server to listen for callback to $redirect_uri ..."
$httpServer = [System.Net.HttpListener]::new()
$httpServer.Prefixes.Add($redirect_uri)
$httpServer.Start()


# Lancer le Navigateur vers la Page OAuth NinjaOne
Try {
Write-Host "Launching NinjaOne API OAuth authorization page $auth_url ..."
# Construire l'URL d'autorisation complète avec les paramètres de requête
$auth_redirect_url = $auth_url + "?response_type=code&client_id=" + $NinjaOneClientId + "&redirect_uri=" + $redirect_uri + "&state=custom_state&scope=monitoring%20management"
Start-Process $auth_redirect_url

Write-Host "Listening for authorization code from local callback to $redirect_uri ..."

# Écouter le Code d'Autorisation
while ($httpServer.IsListening) {
    $httpContext   = $httpServer.GetContext()
    $httpRequest   = $httpContext.Request
    $httpResponse  = $httpContext.Response
    $httpRequestURL = [uri]($httpRequest.Url)

    if ($httpRequest.IsLocal) {
        Write-Host "Heard local request to $httpRequestURL ..."
        # Analyser la chaîne de requête pour voir si elle contient le code d'autorisation
        $httpRequestQuery = [System.Web.HttpUtility]::ParseQueryString($httpRequestURL.Query)

        if (-not [string]::IsNullOrEmpty($httpRequestQuery['code'])) {
            # Stocker le code si présent
            $authorization_code = $httpRequestQuery['code']
            $httpResponse.StatusCode = 200

            # HTML simple pour afficher le message de succès dans le navigateur
            [string]$httpResponseContent = "<html><body>Authorized! You may now close this browser tab/window.</body></html>"
            $httpResponseBuffer = [System.Text.Encoding]::UTF8.GetBytes($httpResponseContent)
            $httpResponse.ContentLength64 = $httpResponseBuffer.Length
            $httpResponse.OutputStream.Write($httpResponseBuffer, 0, $httpResponse.ContentLength64)
        }
        else {
            Write-Host "HTTP 400: Missing 'code' parameter in URL query string."
            $httpResponse.StatusCode = 400
        }
    }
    else {
        # Rejeter toute requête non locale vers notre écouteur
        Write-Host "HTTP 403: Blocking remote request to $httpRequestURL ..."
        $httpResponse.StatusCode = 403
    }

    # Fermer la connexion
    $httpResponse.Close()

    # Arrêter le serveur une fois que nous avons le code d'autorisation
    if (-not [string]::IsNullOrEmpty($authorization_code)) {
        $httpServer.Stop()
    }
}

Write-Host "Parsed authorization code: $authorization_code"
}
Catch {
    Write-Error "Failed to retrieve authorization code from NinjaOne API. Error: $_"
    exit
}

# Préparer les en-têtes pour la requête de jeton
$API_AuthHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$API_AuthHeaders.Add("accept", "application/json")
$API_AuthHeaders.Add("Content-Type", "application/x-www-form-urlencoded")

# Corps pour la requête de jeton
$body = @{
    grant_type    = "authorization_code"
    client_id     = $NinjaOneClientId
    client_secret = $NinjaOneClientSecret
    redirect_uri  = $redirect_uri
    scope         = $scope
    code          = $authorization_code
}

try {
    Write-Host "Requesting access token from NinjaOne ..."
    $auth_token  = Invoke-RestMethod -Uri "https://$NinjaOneInstance/ws/oauth/token" -Method POST -Headers $API_AuthHeaders -Body $body
}
catch {
    Write-Error "Failed to retrieve access token from NinjaOne API. Error: $_"
    exit
}

# Extraire le jeton d'accès du JSON retourné
$access_token = $auth_token | Select-Object -ExpandProperty 'access_token' -EA 0
# Vérifier si nous avons obtenu un jeton d'accès avec succès
if (-not $access_token) {
    Write-Host "Failed to obtain access token. Please check your client ID and client secret."
    exit
}
Write-Host "Retrieved access token: $access_token"
# Construire les en-têtes avec le jeton d'accès pour faire des appels API
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept", "application/json")
$headers.Add("Authorization", "Bearer $access_token")

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

