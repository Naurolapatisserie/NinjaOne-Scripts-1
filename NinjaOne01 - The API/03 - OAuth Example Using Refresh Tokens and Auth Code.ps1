<#
Ceci est fourni comme exemple éducatif de comment interagir avec l'API NinjaOne en utilisant le flux code d'autorisation et jeton de rafraîchissement.
Tout script doit être évalué et testé dans un environnement contrôlé avant d'être utilisé en production.
Comme ce script est un exemple éducatif, des améliorations supplémentaires peuvent être nécessaires pour gérer des ensembles de données plus importants.

Description :
    Ce script démontre le flux OAuth2 "Code d'Autorisation" plus un rafraîchissement de jeton pour obtenir un jeton Bearer
    pour les appels API NinjaOne. Il lance un écouteur HTTP local pour intercepter le "code d'autorisation" du
    callback OAuth NinjaOne, l'échange contre des jetons, puis utilise le jeton de rafraîchissement pour obtenir un jeton d'accès final.

Comment le script fonctionne :
    1) Définir les variables de base : $ClientID, $Secret, $Instance, $RedirectURL.
    2) Créer une fonction qui démarre un écouteur HTTP local sur $RedirectURL, lance un navigateur vers la
       page d'autorisation NinjaOne, et attend le code d'autorisation retourné.
    3) Échanger le code d'autorisation contre un jeton initial (incluant le jeton de rafraîchissement).
    4) Utiliser le jeton de rafraîchissement pour obtenir le jeton Bearer final.
    5) Préparer un en-tête Authorization avec le jeton Bearer pour les appels API NinjaOne suivants.

Note de Sécurité :
    Pour la démonstration, ce script stocke client_secret dans une variable texte brut. Dans un environnement de production,
    stockez ces secrets de manière plus sécurisée (ex. via le Module PowerShell Secret Management, Windows Credential Manager,
    ou Azure Key Vault). Protégez également les permissions de fichiers soigneusement.

#>

$NinjaOneInstance     = "app.ninjarmm.com"
$NinjaOneClientId     = "-"
$NinjaOneClientSecret = "-"
$redirect_uri = "http://localhost:8888/"
$auth_url = "https://$NinjaOneInstance/ws/oauth/authorize"

# S'assurer que l'Assembly System.Web est chargé
# Cet assembly est requis pour analyser les chaînes de requête du callback URL
try {
    [System.Web.HttpUtility] | Out-Null
}
catch {
    Add-Type -AssemblyName System.Web
}


# Démarrer le Serveur HTTP Local pour Capturer le Code d'Auth

try {
    # L'écouteur répondra aux requêtes GET avec le paramètre 'code' dans la chaîne de requête
    Write-Host "Starting HTTP server to listen for callback to $redirect_uri ..."
    $httpServer = [System.Net.HttpListener]::new()
    $httpServer.Prefixes.Add($redirect_uri)
    $httpServer.Start()

    # Lancer le Navigateur vers la Page OAuth NinjaOne
    Write-Host "Launching NinjaOne API OAuth authorization page $auth_url ..."
    # Construire l'URL d'autorisation complète avec les paramètres de requête
    $AuthURL = "https://$Instance/ws/oauth/authorize?response_type=code&client_id=$NinjaOneClientId&client_secret=$NinjaOneSecret&redirect_uri=$redirect_uri&state=custom_state&scope=monitoring%20management%20offline_access"
    Start-Process $AuthURL

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
catch {
    Write-Error "Failed to retrieve authorization code from the NinjaOne API. Error: $_"
    exit
}

# Échanger le Code d'Autorisation contre un Jeton Initial
Write-Host "Exchanging Authorization Code for tokens ..."

$AuthBody = @{
    'grant_type' = 'authorization_code'
    'client_id' = $NinjaOneClientID
    'client_secret' = $NinjaOneClientSecret
    'code' = $authorization_code
    'redirect_uri' = $redirect_uri
    'scope' = "monitoring management offline_access"
}

try {
    $Response = Invoke-WebRequest -Uri "https://$NinjaOneInstance/ws/oauth/token" -Method POST -Body $AuthBody -ContentType 'application/x-www-form-urlencoded'
}
catch {
    Write-Error "Failed to connect to NinjaOne API. Error: $_"
    exit
}
# Stocker le jeton de rafraîchissement pour les requêtes suivantes
$RefreshToken = ($Response.Content | ConvertFrom-Json).refresh_token

Write-Host "Initial token obtained. Refresh token is:" $RefreshToken

# Construire l'En-tête d'Autorisation
$AccessToken = ($Response.Content | ConvertFrom-Json).access_token
$AuthHeader = @{
    'Authorization' = "Bearer $AccessToken"
}

Write-Host "`nFinal Access Token obtained. You can use '$($AuthHeader.Authorization)' in your API calls."
Write-Host "Done!"
