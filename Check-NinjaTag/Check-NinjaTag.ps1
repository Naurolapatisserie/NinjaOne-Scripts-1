param (
    [string]$Tags,
    
    [string]$Mode
)

# Assigner les variables d'environnement
$Tags = $env:tagsToSearch
$Mode = $env:mode

Write-Output $Tags

try {
    # Convertir l'entrée en tableau, supprimer les espaces et s'assurer que c'est toujours un tableau
    $tagArray = @($Tags -split ',' | ForEach-Object { $_.Trim() })

    if (-not $tagArray -or $tagArray.Count -eq 0) {
        Write-Error "No tags specified."
        exit 2
    }

    # Obtenir les tags actuellement assignés depuis NinjaOne
    $currentTags = Get-NinjaTag

    if (-not $currentTags) {
        Write-Error "Unable to retrieve current tags."
        exit 2
    }

    Write-Host "Raw Tags Input: '$Tags'"
    Write-Host "Parsed Tags: $($tagArray -join ', ')"
    Write-Host "Current Ninja Tags: $($currentTags -join ', ')"

    # Si un seul tag a été spécifié, le vérifier directement
    if ($tagArray.Count -eq 1) {
        if ($currentTags -contains $tagArray[0]) {
            Write-Host "Tag '$($tagArray[0])' is present."
            exit 0
        } else {
            Write-Host "Tag '$($tagArray[0])' is NOT present."
            exit 1
        }
    }

    # Logique multi-tags basée sur $Mode
    switch ($Mode) {
        "all" {
            # Tous les tags spécifiés doivent être présents
            $allFound = $tagArray | ForEach-Object { $currentTags -contains $_ } | Where-Object { $_ -eq $false } | Measure-Object
            if ($allFound.Count -eq 0) {
                Write-Host "All specified tags are present."
                exit 0
            } else {
                Write-Host "Not all specified tags are present."
                exit 1
            }
        }
        "any" {
            # Au moins un tag spécifié doit être présent
            $anyFound = $tagArray | Where-Object { $currentTags -contains $_ }
            if ($anyFound.Count -gt 0) {
                Write-Host "At least one specified tag is present: $($anyFound -join ', ')"
                exit 0
            } else {
                Write-Host "None of the specified tags are present."
                exit 1
            }
        }
    }
}
catch {
    Write-Error "An error occurred: $_"
    exit 2
}
