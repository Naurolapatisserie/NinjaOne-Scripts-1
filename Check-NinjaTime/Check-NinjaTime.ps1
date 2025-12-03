<#
.SYNOPSIS
    Script de planification multi-mode avec mode fenêtre récurrente, période de grâce configurable,
    et prise en charge des valeurs par défaut via variables d'environnement.

.DESCRIPTION
    Ce script prend en charge plusieurs modes de planification :
      - Once : Un événement unique basé sur une date/heure complète.
      - Daily : S'exécute chaque jour à l'heure spécifiée dans TargetTime (seule l'heure est utilisée).
      - Weekly : S'exécute un ou plusieurs jours de la semaine à l'heure spécifiée dans TargetTime.
      - Monthly : S'exécute un jour numéroté spécifique du mois à l'heure spécifiée dans TargetTime.
      - Window : S'exécute si l'heure actuelle est dans (ou sur le point d'atteindre) une fenêtre récurrente.
               Pour le mode Window, vous pouvez spécifier un modèle de récurrence :
                   * Daily (par défaut) : La fenêtre se répète chaque jour.
                   * Weekly : La fenêtre se répète le(s) jour(s) spécifié(s) de la semaine.
               En mode récurrent, la partie date est ignorée et seule l'heure est utilisée.
               
    Une période de grâce configurable ($TimeWindowMinutes) détermine si le script attendra jusqu'à l'heure cible
    (ou le début de la fenêtre) si elle est dans ce nombre de minutes ; sinon, le script se termine, permettant une exécution récurrente.

.PARAMETER Mode
    Le mode de planification. Valeurs autorisées : Once, Daily, Weekly, Monthly, Window.
    (Par défaut : variable d'environnement 'mode'.)

.PARAMETER TargetTime
    (Pour les modes non-Window) Date/heure complète ou heure du jour.
    (Par défaut : variable d'environnement 'targetTime'.)

.PARAMETER DayOfWeek
    (Pour le mode Weekly dans les modes non-window) Un ou plusieurs jours de la semaine (ex. "Monday", "Friday").
    (Par défaut : variable d'environnement 'weeklyDayOfWeek'.)

.PARAMETER DayOfMonth
    (Pour le mode Monthly dans les modes non-window) Le jour numérique du mois (1–31).
    (Par défaut : variable d'environnement 'monthlyDayOfMonth'.)

.PARAMETER WindowStart
    (Pour le mode Window) L'heure de début de la fenêtre.
    (Par défaut : variable d'environnement 'windowStart'.)
    Seule la partie heure sera utilisée (ex. "13:00").

.PARAMETER WindowEnd
    (Pour le mode Window) L'heure de fin de la fenêtre.
    (Par défaut : variable d'environnement 'windowEnd'.)
    Seule la partie heure sera utilisée (ex. "23:00").

.PARAMETER WindowRecurrence
    (Pour le mode Window) Spécifie si la fenêtre se répète "Daily" ou "Weekly".
    (Par défaut : variable d'environnement 'windowRecurrence' ; si non fourni, "Daily" par défaut.)

.PARAMETER WindowDayOfWeek
    (Pour le mode Window avec récurrence Weekly) Un ou plusieurs jours de la semaine où la fenêtre se répète.
    (Par défaut : variable d'environnement 'windowDayOfWeek'.)

.NOTES
    Remplacez les sections "# PLACEZ VOTRE CODE D'ACTION ICI" par vos commandes réelles.
#>

param(
    [string]$Mode,
    [string]$TargetTime,
    [string[]]$DayOfWeek,
    [int]$DayOfMonth,
    [string]$WindowStart,
    [string]$WindowEnd,
    [string]$WindowRecurrence,
    [string[]]$WindowDayOfWeek
)

# Assigner depuis les variables d'environnement si non passées.
if (-not $Mode)         { $Mode = $env:mode }
if (-not $TargetTime)     { $TargetTime = $env:targetTime }
if (-not $DayOfWeek)      { $DayOfWeek = $env:weeklyDayOfWeek }
if (-not $DayOfMonth)     { $DayOfMonth = $env:monthlyDayOfMonth }
if (-not $WindowStart)    { $WindowStart = $env:windowStart }
if (-not $WindowEnd)      { $WindowEnd = $env:windowEnd }
if (-not $WindowRecurrence) { $WindowRecurrence = $env:windowRecurrence }
if (-not $WindowDayOfWeek){ $WindowDayOfWeek = $env:windowDayOfWeek }

# Sortie de débogage pour vérifier les valeurs entrantes.
Write-Output "Mode: '$Mode'"
Write-Output "TargetTime: '$TargetTime'"
Write-Output "DayOfWeek: '$($DayOfWeek -join ', ')'"
Write-Output "DayOfMonth: '$DayOfMonth'"
Write-Output "WindowStart (raw): '$WindowStart'"
Write-Output "WindowEnd (raw): '$WindowEnd'"
Write-Output "WindowRecurrence: '$WindowRecurrence'"
Write-Output "WindowDayOfWeek: '$($WindowDayOfWeek -join ', ')'"

# Période de grâce configurable (en minutes) pour attendre jusqu'à l'heure cible/fenêtre.
$TimeWindowMinutes = 5

# Convertir les chaînes d'entrée en objets DateTime ou TimeSpan selon les besoins.
if ($Mode -ne "Window") {
    if ([string]::IsNullOrEmpty($TargetTime)) {
        Write-Error "TargetTime parameter is required for mode $Mode."
        exit 2
    }
    try {
        $TargetTime = [datetime]::Parse($TargetTime)
    } catch {
        Write-Error "TargetTime '$TargetTime' could not be parsed as a valid DateTime."
        exit 2
    }
} else {
    if ([string]::IsNullOrEmpty($WindowStart) -or [string]::IsNullOrEmpty($WindowEnd)) {
        Write-Error "WindowStart and WindowEnd parameters are required for Window mode."
        exit 2
    }
    try {
        # Analyser la chaîne ISO8601 et extraire la partie heure locale au format "HH:mm".
        $wsString = ([datetimeoffset]::Parse($WindowStart.Trim())).LocalDateTime.ToString("HH:mm")
        $weString = ([datetimeoffset]::Parse($WindowEnd.Trim())).LocalDateTime.ToString("HH:mm")
        # Convertir les chaînes d'heure en objets TimeSpan.
        $WindowStartTS = [TimeSpan]::Parse($wsString)
        $WindowEndTS   = [TimeSpan]::Parse($weString)
        Write-Output "Parsed WindowStart TimeSpan: $WindowStartTS, WindowEnd TimeSpan: $WindowEndTS"
    } catch {
        Write-Error "WindowStart or WindowEnd could not be parsed as valid TimeSpan values. Error: $_"
        exit 2
    }
}

function Get-NextOccurrence {
    param(
        [string]$Mode,
        [datetime]$TargetTime,
        [string[]]$DayOfWeek,
        [int]$DayOfMonth
    )
    $now = Get-Date
    switch ($Mode) {
        "Once" {
            return $TargetTime
        }
        "Daily" {
            $todayOccurrence = $now.Date + $TargetTime.TimeOfDay
            if ($todayOccurrence -gt $now) {
                return $todayOccurrence
            } else {
                return $todayOccurrence.AddDays(1)
            }
        }
        "Weekly" {
            if (-not $DayOfWeek) {
                Write-Error "DayOfWeek parameter is required for Weekly mode."
                exit 2
            }
            $occurrences = foreach ($dow in $DayOfWeek) {
                $targetDay = [int][System.DayOfWeek]::$dow
                $currentDay = [int]$now.DayOfWeek
                $daysToAdd = $targetDay - $currentDay
                if ($daysToAdd -lt 0 -or ($daysToAdd -eq 0 -and ($now.TimeOfDay -ge $TargetTime.TimeOfDay))) {
                    $daysToAdd += 7
                }
                $now.Date.AddDays($daysToAdd) + $TargetTime.TimeOfDay
            }
            return $occurrences | Sort-Object | Select-Object -First 1
        }
        "Monthly" {
            if (-not $DayOfMonth) {
                Write-Error "DayOfMonth parameter is required for Monthly mode."
                exit 2
            }
            $year = $now.Year
            $month = $now.Month
            try {
                $occurrence = Get-Date -Year $year -Month $month -Day $DayOfMonth -Hour $TargetTime.Hour -Minute $TargetTime.Minute -Second $TargetTime.Second
            } catch {
                Write-Error "Invalid DayOfMonth for the current month."
                exit 2
            }
            if ($occurrence -gt $now) {
                return $occurrence
            } else {
                $nextMonth = $now.AddMonths(1)
                $year = $nextMonth.Year
                $month = $nextMonth.Month
                try {
                    $occurrence = Get-Date -Year $year -Month $month -Day $DayOfMonth -Hour $TargetTime.Hour -Minute $TargetTime.Minute -Second $TargetTime.Second
                } catch {
                    Write-Error "Invalid DayOfMonth for the next month."
                    exit 2
                }
                return $occurrence
            }
        }
        default {
            Write-Error "Unsupported mode in Get-NextOccurrence."
            exit 2
        }
    }
}

$now = Get-Date

switch ($Mode) {
    "Window" {
        if ($WindowRecurrence -eq "Daily") {
            # Utiliser les TimeSpans que nous avons extraits.
            $todayWindowStart = $now.Date + $WindowStartTS
            $todayWindowEnd   = $now.Date + $WindowEndTS
            if ($WindowEndTS -lt $WindowStartTS) {
                $todayWindowEnd = $todayWindowEnd.AddDays(1)
            }
            
            if ($now -lt $todayWindowStart) {
                $timeToWait = $todayWindowStart - $now
                if ($timeToWait.TotalMinutes -gt $TimeWindowMinutes) {
                    Write-Output "Today's window starts in more than $TimeWindowMinutes minutes. Exiting."
                    exit 2
                }
                Write-Output "Current time is before today's window. Sleeping for $([math]::Ceiling($timeToWait.TotalSeconds)) seconds until window starts at $todayWindowStart."
                Start-Sleep -Seconds ([math]::Ceiling($timeToWait.TotalSeconds))
            } elseif ($now -gt $todayWindowEnd) {
                Write-Output "Today's window has passed. Exiting."
                exit 2
            }
            Write-Output "Current time is within today's window. Executing action..."
            # PLACEZ VOTRE CODE D'ACTION ICI pour le mode fenêtre récurrente quotidienne.
            exit 1
            Write-Output "Action executed in Daily Window mode."
        }
        elseif ($WindowRecurrence -eq "Weekly") {
            if (-not $WindowDayOfWeek) {
                Write-Error "WindowDayOfWeek parameter is required for Weekly window recurrence."
                exit 2
            }
            $windowOccurrences = foreach ($dow in $WindowDayOfWeek) {
                $targetDay = [int][System.DayOfWeek]::$dow
                $currentDay = [int]$now.DayOfWeek
                $daysToAdd = $targetDay - $currentDay
                if ($daysToAdd -lt 0 -or ($daysToAdd -eq 0 -and ($now.TimeOfDay -ge $WindowStartTS))) {
                    $daysToAdd += 7
                }
                $occurrenceStart = $now.Date.AddDays($daysToAdd) + $WindowStartTS
                $occurrenceEnd   = $now.Date.AddDays($daysToAdd) + $WindowEndTS
                if ($WindowEndTS -lt $WindowStartTS) {
                    $occurrenceEnd = $occurrenceEnd.AddDays(1)
                }
                [PSCustomObject]@{
                    Start = $occurrenceStart
                    End   = $occurrenceEnd
                }
            }
            $nextWindow = $windowOccurrences | Sort-Object Start | Select-Object -First 1

            if ($now -lt $nextWindow.Start) {
                $timeToWait = $nextWindow.Start - $now
                if ($timeToWait.TotalMinutes -gt $TimeWindowMinutes) {
                    Write-Output "Next window start ($($nextWindow.Start)) is not within the next $TimeWindowMinutes minutes. Exiting."
                    exit 2
                }
                Write-Output "Current time is before the next weekly window. Sleeping for $([math]::Ceiling($timeToWait.TotalSeconds)) seconds until window starts at $($nextWindow.Start)."
                Start-Sleep -Seconds ([math]::Ceiling($timeToWait.TotalSeconds))
            } elseif ($now -gt $nextWindow.End) {
                Write-Output "Current time is past the next window ($($nextWindow.End)). Exiting."
                exit 2
            }
            Write-Output "Current time is within the weekly window. Executing action..."
            # PLACEZ VOTRE CODE D'ACTION ICI pour le mode fenêtre récurrente hebdomadaire.
            exit 1
            Write-Output "Action executed in Weekly Window mode."
        }
        else {
            Write-Error "Unsupported WindowRecurrence value."
            exit 2
        }
    }
    default {
        $nextOccurrence = Get-NextOccurrence -Mode $Mode -TargetTime $TargetTime -DayOfWeek $DayOfWeek -DayOfMonth $DayOfMonth
        $timeDifference = $nextOccurrence - $now

        if ($timeDifference.TotalMinutes -gt $TimeWindowMinutes) {
            Write-Output "Scheduled time ($nextOccurrence) is not within the next $TimeWindowMinutes minutes. Exiting."
            exit 2
        } elseif ($timeDifference.TotalSeconds -gt 0) {
            Write-Output "Sleeping for $([math]::Ceiling($timeDifference.TotalSeconds)) seconds until scheduled time: $nextOccurrence"
            Start-Sleep -Seconds ([math]::Ceiling($timeDifference.TotalSeconds))
        } else {
            Write-Output "Scheduled time has already passed. Exiting."
            exit 2
        }
        Write-Output "Scheduled time reached. Executing action..."
        exit 1
        # PLACEZ VOTRE CODE D'ACTION ICI pour les modes Once/Daily/Weekly/Monthly.
        Write-Output "Action executed for mode $Mode."
    }
}
