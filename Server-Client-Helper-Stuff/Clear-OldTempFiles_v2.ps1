#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Erweiterte Windows-Bereinigung für temporäre Dateien und Cache-Verzeichnisse
.DESCRIPTION
    Löscht alte Dateien aus System- und Benutzer-Temp-Verzeichnissen mit paralleler Verarbeitung
.PARAMETER DaysOld
    Alter der zu löschenden Dateien in Tagen (Standard: 1)
.PARAMETER IncludeEventLogs
    Leert zusätzlich alle Windows Event-Logs
.PARAMETER MaxThreads
    Maximale Anzahl paralleler Threads (Standard: 4)
.PARAMETER LogPath
    Pfad für detailliertes Cleanup-Log (optional)
.PARAMETER ExcludePaths
    Array von Pfaden, die von der Bereinigung ausgeschlossen werden sollen
.EXAMPLE
    .\Cleanup-Windows.ps1 -DaysOld 7 -IncludeEventLogs -Verbose
.NOTES
    Version: 2.0
    Optimiert für Performance und Robustheit
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [ValidateRange(0, 365)]
    [int]$DaysOld = 1,
    
    [Parameter()]
    [switch]$IncludeEventLogs,
    
    [Parameter()]
    [ValidateRange(1, 16)]
    [int]$MaxThreads = 4,
    
    [Parameter()]
    [string]$LogPath,
    
    [Parameter()]
    [string[]]$ExcludePaths = @()
)

#region Configuration
$Script:Config = @{
    SystemRoot  = $env:SystemRoot
    ProgramData = $env:ProgramData
    Statistics  = @{
        TotalFiles      = 0
        TotalSize       = 0
        FailedDeletions = 0
        StartTime       = Get-Date
    }
}
#endregion

#region Functions
function Get-CleanupPaths {
    <#
    .SYNOPSIS
        Ermittelt alle zu bereinigenden Pfade mit Validierung
    .OUTPUTS
        Array von validierten Pfaden
    #>
    [CmdletBinding()]
    param()
    
    $paths = [System.Collections.ArrayList]::new()
    
    # Systemweite Pfade mit Umgebungsvariablen
    $systemPaths = @(
        "$($Script:Config.SystemRoot)\Temp",
        "$($Script:Config.SystemRoot)\Logs\CBS",
        "$($Script:Config.SystemRoot)\Downloaded Program Files",
        "$($Script:Config.ProgramData)\Microsoft\Windows\WER",
        "$($Script:Config.SystemRoot)\SoftwareDistribution\Download",
        "$($Script:Config.SystemRoot)\Prefetch"
    )
    
    # Validiere und füge Systempfade hinzu
    foreach ($path in $systemPaths) {
        if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
            [void]$paths.Add($path)
            Write-Verbose "Systempfad hinzugefügt: $path"
        }
        else {
            Write-Verbose "Systempfad nicht gefunden: $path"
        }
    }
    
    # Benutzerspezifische Pfade
    $userProfiles = Get-CimInstance -Class Win32_UserProfile -Filter "Special = FALSE" |
    Where-Object { $_.LocalPath -and (Test-Path $_.LocalPath) } |
    Select-Object -ExpandProperty LocalPath
    
    $userRelativePaths = @(
        "AppData\Local\Temp",
        "AppData\Local\Microsoft\Windows\INetCache",
        "AppData\Local\Microsoft\Windows\WER",
        "AppData\Local\Microsoft\Terminal Server Client\Cache",
        "AppData\Local\Microsoft\Windows\AppCache",
        "AppData\Local\Microsoft\Internet Explorer\Recovery",
        "AppData\Local\CrashDumps",
        "AppData\LocalLow\Temp"
    )
    
    foreach ($userProfile in $userProfiles) {
        foreach ($relativePath in $userRelativePaths) {
            $fullPath = Join-Path -Path $userProfile -ChildPath $relativePath
            if (Test-Path -Path $fullPath -ErrorAction SilentlyContinue) {
                [void]$paths.Add($fullPath)
                Write-Verbose "Benutzerpfad hinzugefügt: $fullPath"
            }
        }
    }
    
    # Exclude-Filter anwenden
    if ($ExcludePaths.Count -gt 0) {
        $paths = $paths | Where-Object {
            $currentPath = $_
            -not ($ExcludePaths | Where-Object { $currentPath -like $_ })
        }
    }
    
    return $paths.ToArray()
}

function Remove-OldFilesFromPath {
    <#
    .SYNOPSIS
        Löscht alte Dateien aus einem spezifischen Pfad
    .PARAMETER Path
        Der zu bereinigende Pfad
    .PARAMETER Threshold
        DateTime-Schwellwert für alte Dateien
    .OUTPUTS
        PSCustomObject mit Bereinigungsstatistiken
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [datetime]$Threshold
    )
    
    $result = [PSCustomObject]@{
        Path         = $Path
        FilesDeleted = 0
        BytesFreed   = 0
        Errors       = 0
        Duration     = $null
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Suche nach alten Dateien
        $searchPath = Join-Path -Path $Path -ChildPath '*'
        $files = Get-ChildItem -Path $searchPath -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.LastWriteTime -le $Threshold -and 
            -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
        }
        
        foreach ($file in $files) {
            if ($PSCmdlet.ShouldProcess($file.FullName, "Remove")) {
                try {
                    $fileSize = $file.Length
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                    $result.FilesDeleted++
                    $result.BytesFreed += $fileSize
                    Write-Verbose "Gelöscht: $($file.FullName) ($([Math]::Round($fileSize/1KB, 2)) KB)"
                }
                catch {
                    $result.Errors++
                    Write-Warning "Fehler beim Löschen von '$($file.FullName)': $($_.Exception.Message)"
                }
            }
        }
    }
    catch {
        Write-Error "Fehler beim Durchsuchen von '$Path': $($_.Exception.Message)"
    }
    
    $stopwatch.Stop()
    $result.Duration = $stopwatch.Elapsed
    
    return $result
}

function Clear-WindowsEventLogs {
    <#
    .SYNOPSIS
        Leert alle Windows Event-Logs
    .OUTPUTS
        Anzahl der geleerten Logs
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    
    $clearedLogs = 0
    $eventLogs = wevtutil el
    
    foreach ($log in $eventLogs) {
        if ($PSCmdlet.ShouldProcess($log, "Clear EventLog")) {
            try {
                wevtutil cl "$log" 2>$null
                $clearedLogs++
                Write-Verbose "Event-Log geleert: $log"
            }
            catch {
                Write-Warning "Fehler beim Leeren von Event-Log '$log': $($_.Exception.Message)"
            }
        }
    }
    
    return $clearedLogs
}

function Write-CleanupReport {
    <#
    .SYNOPSIS
        Erstellt einen detaillierten Bereinigungsbericht
    .PARAMETER Results
        Array mit Bereinigungsergebnissen
    .PARAMETER LogPath
        Optionaler Pfad für CSV-Export
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results,
        
        [Parameter()]
        [string]$LogPath
    )
    
    $totalFiles = ($Results | Measure-Object -Property FilesDeleted -Sum).Sum
    $totalBytes = ($Results | Measure-Object -Property BytesFreed -Sum).Sum
    $totalErrors = ($Results | Measure-Object -Property Errors -Sum).Sum
    $totalDuration = [TimeSpan]::FromSeconds(($Results | ForEach-Object { $_.Duration.TotalSeconds } | Measure-Object -Sum).Sum)
    
    # Konsolen-Ausgabe
    $report = @"

================== BEREINIGUNGSBERICHT ==================
Startzeit:        $($Script:Config.Statistics.StartTime)
Endzeit:          $(Get-Date)
Gesamtdauer:      $([Math]::Round($totalDuration.TotalMinutes, 2)) Minuten

Bereinigte Pfade: $($Results.Count)
Gelöschte Dateien: $totalFiles
Freigegebener Speicher: $([Math]::Round($totalBytes/1MB, 2)) MB
Fehler: $totalErrors

Top 5 Pfade nach freigegebenem Speicher:
$($Results | Sort-Object BytesFreed -Descending | Select-Object -First 5 | ForEach-Object {
    "  - $($_.Path): $([Math]::Round($_.BytesFreed/1MB, 2)) MB"
} | Out-String)
=========================================================
"@
    
    Write-Information $report -InformationAction Continue
    
    # Optional: CSV-Export
    if ($LogPath) {
        try {
            $Results | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8
            Write-Information "Detailliertes Log gespeichert: $LogPath" -InformationAction Continue
        }
        catch {
            Write-Warning "Fehler beim Speichern des Logs: $($_.Exception.Message)"
        }
    }
}
#endregion

#region Main Execution
function Start-WindowsCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    
    # Banner
    Write-Information @"
Windows Cleanup Tool v2.0
=========================
Bereinigungs-Schwellwert: Dateien älter als $DaysOld Tag(e)
Parallele Threads: $MaxThreads
Event-Logs leeren: $IncludeEventLogs
"@ -InformationAction Continue
    
    # Pfade ermitteln
    Write-Progress -Activity "Windows-Bereinigung" -Status "Ermittle Bereinigungspfade..." -PercentComplete 0
    $cleanupPaths = Get-CleanupPaths
    
    if ($cleanupPaths.Count -eq 0) {
        Write-Warning "Keine gültigen Bereinigungspfade gefunden."
        return
    }
    
    Write-Information "Gefundene Bereinigungspfade: $($cleanupPaths.Count)" -InformationAction Continue
    
    # Threshold berechnen
    $threshold = (Get-Date).AddDays(-$DaysOld)
    
    # Runspace-Pool für parallele Verarbeitung
    Write-Progress -Activity "Windows-Bereinigung" -Status "Initialisiere parallele Verarbeitung..." -PercentComplete 10
    
    $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
    $runspacePool.Open()
    
    $jobs = @()
    $scriptBlock = ${function:Remove-OldFilesFromPath}
    
    # Jobs erstellen
    foreach ($path in $cleanupPaths) {
        $powershell = [PowerShell]::Create().AddScript($scriptBlock).AddArgument($path).AddArgument($threshold)
        
        if ($WhatIfPreference) {
            $powershell.AddParameter('WhatIf', $true)
        }
        
        $powershell.RunspacePool = $runspacePool
        
        $jobs += [PSCustomObject]@{
            Path       = $path
            PowerShell = $powershell
            Handle     = $powershell.BeginInvoke()
        }
    }
    
    # Jobs überwachen und Ergebnisse sammeln
    $results = @()
    $completed = 0
    
    while ($jobs | Where-Object { -not $_.Handle.IsCompleted }) {
        Start-Sleep -Milliseconds 500
        $completed = ($jobs | Where-Object { $_.Handle.IsCompleted }).Count
        $percentComplete = [Math]::Min(90, 10 + ($completed / $jobs.Count * 80))
        Write-Progress -Activity "Windows-Bereinigung" `
            -Status "Verarbeite Pfade... ($completed/$($jobs.Count))" `
            -PercentComplete $percentComplete
    }
    
    # Ergebnisse einsammeln
    foreach ($job in $jobs) {
        try {
            $result = $job.PowerShell.EndInvoke($job.Handle)
            if ($result) {
                $results += $result
            }
        }
        catch {
            Write-Warning "Fehler bei Pfad '$($job.Path)': $($_.Exception.Message)"
        }
        finally {
            $job.PowerShell.Dispose()
        }
    }
    
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    # Event-Logs leeren (optional)
    if ($IncludeEventLogs) {
        Write-Progress -Activity "Windows-Bereinigung" -Status "Leere Event-Logs..." -PercentComplete 95
        $clearedLogs = Clear-WindowsEventLogs
        Write-Information "Event-Logs geleert: $clearedLogs" -InformationAction Continue
    }
    
    # Bericht erstellen
    Write-Progress -Activity "Windows-Bereinigung" -Status "Erstelle Bericht..." -PercentComplete 100
    Write-CleanupReport -Results $results -LogPath $LogPath
    
    Write-Progress -Activity "Windows-Bereinigung" -Completed
}

# Hauptausführung
try {
    Start-WindowsCleanup
}
catch {
    Write-Error "Kritischer Fehler: $($_.Exception.Message)"
    exit 1
}
#endregion