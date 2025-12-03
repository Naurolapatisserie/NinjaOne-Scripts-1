<#
.SYNOPSIS
    Compare les applications installées sur un appareil avec la liste des applications autorisées dans NinjaOne.

.DESCRIPTION
    Ce script vérifie les applications logicielles installées par rapport aux applications autorisées définies
    au niveau de l'organisation et de l'appareil dans NinjaOne. Le mode de comparaison peut être "Exact",
    "CaseInsensitive" ou "Partial". Les applications non conformes (non autorisées) sont signalées et
    mises à jour en tant que propriété personnalisée NinjaOne.

.PARAMETER jsonFilePath
    [string] Le chemin vers le fichier JSON contenant les données d'inventaire logiciel.
    Par défaut : C:\ProgramData\NinjaRMMAgent\jsonoutput\jsonoutput-agent.txt

.PARAMETER matchMode
    [string] Le mode de correspondance pour la comparaison des applications.
    Options :
        - "Exact"          : Correspond exactement aux noms des applications.
        - "CaseInsensitive": Correspond aux noms sans tenir compte de la casse.
        - "Partial"        : Correspond partiellement aux applications (correspondance de sous-chaîne).

.INPUTS
    - Le script lit un fichier JSON pour l'inventaire logiciel.
    - La variable d'environnement `matchingCriteria` détermine le mode de comparaison.

.OUTPUTS
    - Affiche les applications non conformes (non autorisées) dans la console.
    - Met à jour la propriété NinjaOne `unauthorizedApplications` avec la liste des logiciels non conformes.
    - Affiche "Aucune divergence trouvée" si toutes les applications sont autorisées.

.EXAMPLE
    # Exécuter le script avec le chemin par défaut et les critères de correspondance définis via variable d'environnement
    .\ScriptName.ps1

.NOTES
    - Version PowerShell : 5.1 ou ultérieure.
    - Requis : L'agent NinjaOne doit exporter les données d'inventaire logiciel en JSON.
    - La propriété personnalisée NinjaOne `unauthorizedApplications` est mise à jour si des divergences sont trouvées.
    - Erreur si le fichier JSON est manquant ou invalide.

#>



# Chemin vers le fichier JSON
$jsonFilePath = "C:\ProgramData\NinjaRMMAgent\jsonoutput\jsonoutput-agent.txt"

# Définir les applications autorisées dans des objets séparés (données d'exemple)
$orgAuthorizedApps = Ninja-Property-Get softwareList | ConvertFrom-Json | Select-Object -ExpandProperty 'text' -EA 0
$deviceAuthorizedApps = Ninja-Property-Get deviceSoftwareList | ConvertFrom-Json | Select-Object -ExpandProperty 'text' -EA 0
$authorizedApps = $orgAuthorizedApps + $deviceAuthorizedApps

$authorizedApps = $authorizedApps -split ','
$authorizedApps = $authorizedApps | ForEach-Object { $_.Trim() }

# Définir un paramètre pour le mode de correspondance
# Options : "Exact", "CaseInsensitive", "Partial"
$matchMode = $env:matchingCriteria # Change to "Exact" or "CaseInsensitive" as needed

# Fonction pour effectuer la correspondance selon le mode
function Compare-Application {
    param (
        [string]$InstalledApp,
        [string[]]$AuthorizedApps,
        [string]$Mode
    )
    switch ($Mode) {
        "Exact" {
            return $AuthorizedApps -contains $InstalledApp
        }
        "CaseInsensitive" {
            return $AuthorizedApps | ForEach-Object { $_ -ieq $InstalledApp }
        }
        "Partial" {
            foreach ($authApp in $AuthorizedApps) {
                if ($InstalledApp -match [regex]::Escape($authApp)) {
                    return $true
                }
            }
            return $false
        }
        default {
            throw "Invalid match mode specified: $Mode. Valid options are 'Exact', 'CaseInsensitive', or 'Partial'."
        }
    }
}

# Vérifier si le fichier existe
if (Test-Path $jsonFilePath) {
    # Lire le fichier JSON
    $jsonContent = Get-Content -Path $jsonFilePath -Raw
    
    # Analyser le contenu JSON
    $jsonObject = $jsonContent | ConvertFrom-Json
    
    # Extraire les données d'inventaire logiciel
    $softwareInventory = $jsonObject.node.datasets | Where-Object { $_.dataspecName -eq "softwareInventory" }
    
    # Créer une liste des applications installées
    $installedApps = @()
    foreach ($datapoint in $softwareInventory.datapoints) {
        foreach ($software in $datapoint.data) {
            $installedApps += $software.name
        }
    }
    
    # Comparer les applications installées avec les applications autorisées en utilisant le mode sélectionné
    $discrepancies = @()
    foreach ($app in $installedApps) {
        if (-not (Compare-Application -InstalledApp $app -AuthorizedApps $authorizedApps -Mode $matchMode)) {
            $discrepancies += [PSCustomObject]@{
                DiscrepantApplication = $app
            }
        }
    }
    
        # Afficher les résultats
        if ($discrepancies.Count -gt 0) {
            # Extraire les noms des applications non conformes en chaîne séparée par des virgules
            $discrepantAppsString = ($discrepancies.DiscrepantApplication) -join ', '
            Write-Output "WARNING - Discrepancies found: $discrepantAppsString"
            Ninja-Property-Set unauthorizedApplications $discrepantAppsString
        } else {
            Write-Output "No discrepancies found. All installed applications are authorized."
            Ninja-Property-Set unauthorizedApplicatiions $null
        }

} else {
    Write-Error "The file '$jsonFilePath' does not exist."
}
