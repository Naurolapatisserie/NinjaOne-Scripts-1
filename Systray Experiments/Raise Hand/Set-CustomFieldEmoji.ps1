$CustomFieldName = $env:customFieldName

$Message = '✋'

# Fonction pour vérifier si une commande existe
function Test-CommandExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )
    return (Get-Command $CommandName -ErrorAction SilentlyContinue) -ne $null
}

# Vérifier si la cmdlet Ninja-Property-Set existe
if (-not (Test-CommandExists -CommandName 'Ninja-Property-Set')) {
    Write-Error "Ninja-Property-Set cmdlet not found. Please ensure it is installed and accessible."
    exit 1
}

# Fonction pour définir le champ personnalisé
function Set-CustomField {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FieldName,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )
    try {
        Ninja-Property-Set -Name $FieldName -Value $Value -ErrorAction Stop
        Write-Host "Custom field '$FieldName' set to '$Value'."
    } catch {
        Write-Error "Failed to set custom field '$FieldName'. Error: $_"
        exit 1
    }
}

# Fonction pour effacer le champ personnalisé
function Clear-CustomField {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FieldName
    )
    try {
        Ninja-Property-Set -Name $FieldName -Value "" -ErrorAction Stop
        Write-Host "Custom field '$FieldName' cleared."
    } catch {
        Write-Error "Failed to clear custom field '$FieldName'. Error: $_"
        exit 1
    }
}

# Définir le champ personnalisé avec le message
Set-CustomField -FieldName $CustomFieldName -Value $Message

# Attendre 5 minutes
Write-Host "Waiting for 5 minutes..."
Start-Sleep -Seconds 180

# Effacer le champ personnalisé
Clear-CustomField -FieldName $CustomFieldName
