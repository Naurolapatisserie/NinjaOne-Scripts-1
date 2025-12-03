$JsonFilePath = "c:\ProgramData\NinjaRMMAgent\jsonoutput\jsonoutput-agent.txt"

# Vérifier que le fichier existe
if (-not (Test-Path $JsonFilePath)) {
    Write-Error "File not found: $JsonFilePath"
    exit 1
}

# Lire et convertir le contenu JSON
$jsonContent = Get-Content $JsonFilePath -Raw | ConvertFrom-Json

# Extraire le jeu de données OS (en supposant que le jeu de données a dataspecName "os")
$osDataset = $jsonContent.node.datasets | Where-Object { $_.dataspecName -eq "os" }

if (-not $osDataset) {
    Write-Output "OS dataset not found in the JSON file."
    exit 1
}

# En supposant qu'il y a un point de données OS, extraire son objet de données
$osData = $osDataset.datapoints[0].data

Write-Output "Operating System Information:"
Write-Output "--------------------------------"
Write-Output ("Name           : {0}" -f $osData.name)
Write-Output ("Short Name     : {0}" -f $osData.shortName)
Write-Output ("Build Number   : {0}" -f $osData.buildNumber)
Write-Output ("Install Date   : {0}" -f $osData.installDate)
Write-Output ("Release ID     : {0}" -f $osData.releaseId)
Write-Output ("Architecture   : {0}" -f $osData.osArchitecture)
Write-Output ""

# Déterminer si le nom de l'OS indique Windows 10 ou Windows 11
if ($osData.name -match "10") {
    Write-Output "This device appears to be running Windows 10."
} elseif ($osData.name -match "11") {
    Write-Output "This device appears to be running Windows 11."
} else {
    Write-Output "The OS version does not clearly indicate Windows 10 or 11."
}

# Pour réutilisation (ex. analyse serveur), vérifier si le nom de l'OS inclut "Server"
if ($osData.name -match "Server") {
    Write-Output "This appears to be a server operating system."
} else {
    Write-Output "This does not appear to be a server operating system."
}
