#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Erweiterte Windows-Bereinigung für temporäre Dateien und Cache-Verzeichnisse
.DESCRIPTION
    Löscht alte Dateien aus System- und Benutzer-Temp-Verzeichnissen mit paralleler Verarbeitung.
    Kann optional Browser-Caches, Delivery Optimization-Dateien und leere Verzeichnisse entfernen.
.PARAMETER DaysOld
    Alter der zu löschenden Dateien in Tagen (Standard: 7)
.PARAMETER IncludeEventLogs
    Leert zusätzlich alle Windows Event-Logs
.PARAMETER IncludeBrowserCaches
    Bezieht die Caches von Edge, Chrome und Firefox in die Bereinigung ein
.PARAMETER IncludeDeliveryOptimization
    Bereinigt den "Delivery Optimization" Cache (Windows Update P2P-Cache)
.PARAMETER RemoveEmptyDirs
    Löscht leere Unterverzeichnisse aus den Zielpfaden nach der Dateibereinigung
.PARAMETER MaxThreads
    Maximale Anzahl paralleler Threads (Standard: 4)
.PARAMETER LogPath
    Pfad für detailliertes Cleanup-Log (optional)
.PARAMETER ExcludePaths
    Array von Pfaden, die von der Bereinigung ausgeschlossen werden sollen
.EXAMPLE
    .\Cleanup-Windows.ps1 -DaysOld 7 -IncludeEventLogs -IncludeBrowserCaches -RemoveEmptyDirs -Verbose
.NOTES
    Version: 3.0
    Optimiert für Performance und Robustheit. Enthält nun Browser-Caches und Löschung leerer Ordner.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [ValidateRange(1, 365)]
    [int]$DaysOld = 7, # Standard auf 7 Tage erhöht für mehr Sicherheit
    
    [Parameter()]
    [switch]$IncludeEventLogs,

    [Parameter()]
    [switch]$IncludeBrowserCaches,

    [Parameter()]
    [switch]$IncludeDeliveryOptimization,

    [Parameter()]
    [switch]$RemoveEmptyDirs,
    
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
        StartTime = Get-Date
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
    param(
        [Parameter()][switch]$IncludeBrowserCaches,
        [Parameter()][switch]$IncludeDeliveryOptimization
    )
    
    $paths = [System.Collections.ArrayList]::new()
    
    # Systemweite Pfade
    $systemPaths = @(
        "$($Script:Config.SystemRoot)\Temp",
        "$($Script:Config.SystemRoot)\Logs\CBS",
        "$($Script:Config.SystemRoot)\Downloaded Program Files",
        "$($Script:Config.ProgramData)\Microsoft\Windows\WER",
        "$($Script:Config.SystemRoot)\SoftwareDistribution\Download",
        "$($Script:Config.SystemRoot)\Prefetch"
    )

    # NEU: Optionale Systempfade
    if ($IncludeDeliveryOptimization) {
        $systemPaths += "$($Script:Config.SystemRoot)\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
    }
    
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

    # NEU: Optionale Browser-Caches
    if ($IncludeBrowserCaches) {
        $browserRelativePaths = @(
            "AppData\Local\Microsoft\Edge\User Data\Default\Cache",
            "AppData\Local\Microsoft\Edge\User Data\Default\Code Cache",
            "AppData\Local\Google\Chrome\User Data\Default\Cache",
            "AppData\Local\Google\Chrome\User Data\Default\Code Cache",
            "AppData\Local\Mozilla\Firefox\Profiles\*\cache2",
            "AppData\Local\Mozilla\Firefox\Profiles\*\startupCache"
        )
        $userRelativePaths += $browserRelativePaths
    }
    
    foreach ($userProfile in $userProfiles) {
        foreach ($relativePath in $userRelativePaths) {
            $fullPath = Join-Path -Path $userProfile -ChildPath $relativePath
            
            # NEU: Geänderte Logik für Wildcards
            # Wenn der Pfad ein Wildcard enthält, fügen wir ihn direkt hinzu.
            # Get-ChildItem (in Remove-OldFilesFromPath) kann damit umgehen.
            if ($fullPath -like '*\*') {
                [void]$paths.Add($fullPath)
                Write-Verbose "Benutzerpfad (mit Wildcard) hinzugefügt: $fullPath"
            }
            # Andernfalls testen, ob er existiert
            elseif (Test-Path -Path $fullPath -ErrorAction SilentlyContinue) {
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
        Löscht alte Dateien aus einem spezifischen Pfad (unterstützt Wildcards)
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
        # Get-ChildItem -Path unterstützt Wildcards direkt (z.B. ...\*\cache2)
        $files = Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
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
        # Dieser Catch fängt eher Fehler beim Get-ChildItem ab (z.B. Pfad nicht gefunden, falls Wildcard nichts trifft)
        Write-Warning "Fehler beim Durchsuchen von '$Path': $($_.Exception.Message)"
    }
    
    $stopwatch.Stop()
    $result.Duration = $stopwatch.Elapsed
    
    return $result
}

# NEUE FUNKTION
function Remove-EmptyDirectories {
    <#
    .SYNOPSIS
        Löscht rekursiv leere Verzeichnisse in einem Pfad
    .PARAMETER Path
        Der zu durchsuchende Pfad
    .OUTPUTS
        PSCustomObject mit Bereinigungsstatistiken
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $result = [PSCustomObject]@{
        Path        = $Path
        DirsDeleted = 0
        Errors      = 0
    }

    try {
        # Hole alle Verzeichnisse, sortiere nach Tiefe (längster Pfad zuerst)
        $dirs = Get-ChildItem -Path $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) } |
        Sort-Object { $_.FullName.Length } -Descending
        
        foreach ($dir in $dirs) {
            # Prüfen, ob Verzeichnis wirklich leer ist
            if ($null -eq (Get-ChildItem -Path $dir.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
                if ($PSCmdlet.ShouldProcess($dir.FullName, "Remove Empty Directory")) {
                    try {
                        Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction Stop
                        $result.DirsDeleted++
                        Write-Verbose "Leeres Verzeichnis gelöscht: $($dir.FullName)"
                    }
                    catch {
                        $result.Errors++
                        Write-Warning "Fehler beim Löschen des leeren Verzeichnisses '$($dir.FullName)': $($_.Exception.Message)"
                    }
                }
            }
        }
    }
    catch {
        $result.Errors++
        Write-Warning "Fehler beim Durchsuchen (leere Verzeichnisse) von '$Path': $($_.Exception.Message)"
    }
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
            # VERBESSERT: wevtutil ist extern, try/catch greift nicht. Prüfe $LASTEXITCODE.
            wevtutil cl "$log" 2>$null # stderr umleiten
            
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Fehler beim Leeren von Event-Log '$log' (ExitCode: $LASTEXITCODE)"
            }
            else {
                $clearedLogs++
                Write-Verbose "Event-Log geleert: $log"
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
        Array mit Datei-Bereinigungsergebnissen
    .PARAMETER EmptyDirResults
        Array mit Ordner-Bereinigungsergebnissen
    .PARAMETER LogPath
        Optionaler Pfad für CSV-Export
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results,

        [Parameter()] # NEU
        [array]$EmptyDirResults,
        
        [Parameter()]
        [string]$LogPath
    )
    
    # Datei-Statistiken
    $totalFiles = ($Results | Measure-Object -Property FilesDeleted -Sum).Sum
    $totalBytes = ($Results | Measure-Object -Property BytesFreed -Sum).Sum
    $totalFileErrors = ($Results | Measure-Object -Property Errors -Sum).Sum
    $totalDuration = [TimeSpan]::FromSeconds(($Results | ForEach-Object { $_.Duration.TotalSeconds } | Measure-Object -Sum).Sum)

    # NEU: Ordner-Statistiken
    $totalEmptyDirs = 0
    $totalDirErrors = 0
    if ($EmptyDirResults) {
        $totalEmptyDirs = ($EmptyDirResults | Measure-Object -Property DirsDeleted -Sum).Sum
        $totalDirErrors = ($EmptyDirResults | Measure-Object -Property Errors -Sum).Sum
    }
    $totalErrors = $totalFileErrors + $totalDirErrors

    
    # Konsolen-Ausgabe
    $report = @"

================== BEREINIGUNGSBERICHT (v3.0) ==================
Startzeit:             $($Script:Config.Statistics.StartTime)
Endzeit:               $(Get-Date)
Gesamtdauer (Dateien): $([Math]::Round($totalDuration.TotalMinutes, 2)) Minuten

Bereinigte Pfade:      $($Results.Count)
Gelöschte Dateien:     $totalFiles
Gelöschte leere Ordner: $totalEmptyDirs
Freigegebener Speicher: $([Math]::Round($totalBytes/1MB, 2)) MB
Fehler:                $totalErrors (Dateien: $totalFileErrors, Ordner: $totalDirErrors)

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
            Write-Information "Detailliertes Log (Dateien) gespeichert: $LogPath" -InformationAction Continue

            # NEU: Separates Log für gelöschte Ordner
            if ($EmptyDirResults) {
                $dirLogPath = $LogPath -replace '\.csv$', '_EmptyDirs.csv'
                $EmptyDirResults | Export-Csv -Path $dirLogPath -NoTypeInformation -Encoding UTF8
                Write-Information "Detailliertes Log (leere Ordner) gespeichert: $dirLogPath" -InformationAction Continue
            }
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
Windows Cleanup Tool v3.0
=========================
Bereinigungs-Schwellwert: Dateien älter als $DaysOld Tag(e)
Parallele Threads: $MaxThreads
Event-Logs leeren: $IncludeEventLogs
Browser-Caches: $IncludeBrowserCaches
Delivery Optimization: $IncludeDeliveryOptimization
Leere Ordner entfernen: $RemoveEmptyDirs
"@ -InformationAction Continue
    
    # Pfade ermitteln
    Write-Progress -Activity "Windows-Bereinigung" -Status "Ermittle Bereinigungspfade..." -PercentComplete 0
    # NEU: Übergebe optionale Schalter
    $cleanupPaths = Get-CleanupPaths -IncludeBrowserCaches:$IncludeBrowserCaches -IncludeDeliveryOptimization:$IncludeDeliveryOptimization
    
    if ($cleanupPaths.Count -eq 0) {
        Write-Warning "Keine gültigen Bereinigungspfade gefunden."
        return
    }
    
    Write-Information "Gefundene Bereinigungspfade: $($cleanupPaths.Count)" -InformationAction Continue
    
    # Threshold berechnen
    $threshold = (Get-Date).AddDays(-$DaysOld)
    
    # === PHASE 1: DATEIEN LÖSCHEN (PARALLEL) ===
    Write-Progress -Activity "Windows-Bereinigung" -Status "Initialisiere parallele Dateibereinigung..." -PercentComplete 10
    
    $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
    $runspacePool.Open()
    
    $jobs = @()
    $scriptBlockFiles = ${function:Remove-OldFilesFromPath}
    
    # Jobs erstellen
    foreach ($path in $cleanupPaths) {
        $powershell = [PowerShell]::Create().AddScript($scriptBlockFiles).AddArgument($path).AddArgument($threshold)
        
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
        $percentComplete = [Math]::Min(80, 10 + ($completed / $jobs.Count * 70)) # Läuft bis 80%
        Write-Progress -Activity "Windows-Bereinigung" `
            -Status "Verarbeite Pfade (Dateien)... ($completed/$($jobs.Count))" `
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
    
    # === PHASE 2: LEERE ORDNER LÖSCHEN (PARALLEL) ===
    $emptyDirResults = @()
    if ($RemoveEmptyDirs) {
        Write-Progress -Activity "Windows-Bereinigung" -Status "Initialisiere Bereinigung leerer Ordner..." -PercentComplete 80

        $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
        $runspacePool.Open()
        
        $jobs = @()
        $scriptBlockDirs = ${function:Remove-EmptyDirectories}
        
        foreach ($path in $cleanupPaths) {
            # Wildcard-Pfade müssen hier aufgelöst werden, da Remove-EmptyDirectories sie nicht selbst auflöst
            $resolvedPaths = @()
            if ($path -like '*\*') {
                try {
                    $resolvedPaths = (Resolve-Path -Path $path -ErrorAction SilentlyContinue).Path
                }
                catch {
                    Write-Verbose "Wildcard-Pfad für leere Ordner konnte nicht aufgelöst werden: $path"
                }
            }
            else {
                $resolvedPaths = @($path)
            }

            foreach ($resolvedPath in $resolvedPaths) {
                if (Test-Path $resolvedPath) {
                    $powershell = [PowerShell]::Create().AddScript($scriptBlockDirs).AddArgument($resolvedPath)
                    
                    if ($WhatIfPreference) {
                        $powershell.AddParameter('WhatIf', $true)
                    }
                    
                    $powershell.RunspacePool = $runspacePool
                    
                    $jobs += [PSCustomObject]@{
                        Path       = $resolvedPath
                        PowerShell = $powershell
                        Handle     = $powershell.BeginInvoke()
                    }
                }
            }
        }
        
        # Jobs überwachen...
        $completed = 0
        $jobCount = $jobs.Count
        while ($jobs | Where-Object { -not $_.Handle.IsCompleted }) {
            Start-Sleep -Milliseconds 200
            $completed = ($jobs | Where-Object { $_.Handle.IsCompleted }).Count
            if ($jobCount -gt 0) {
                $percentComplete = [Math]::Min(90, 80 + ($completed / $jobCount * 10)) # Läuft von 80% bis 90%
                Write-Progress -Activity "Windows-Bereinigung" `
                    -Status "Bereinige leere Verzeichnisse... ($completed/$jobCount)" `
                    -PercentComplete $percentComplete
            }
        }
        
        # Ergebnisse einsammeln...
        foreach ($job in $jobs) {
            try {
                $result = $job.PowerShell.EndInvoke($job.Handle)
                if ($result) { $emptyDirResults += $result }
            }
            catch { Write-Warning "Fehler bei Pfad (leere Verzeichnisse) '$($job.Path)': $($_.Exception.Message)" }
            finally { $job.PowerShell.Dispose() }
        }
        
        $runspacePool.Close()
        $runspacePool.Dispose()
    }

    # === PHASE 3: EVENT-LOGS ===
    if ($IncludeEventLogs) {
        Write-Progress -Activity "Windows-Bereinigung" -Status "Leere Event-Logs..." -PercentComplete 95
        $clearedLogs = Clear-WindowsEventLogs
        Write-Information "Event-Logs geleert: $clearedLogs" -InformationAction Continue
    }
    
    # === PHASE 4: BERICHT ===
    Write-Progress -Activity "Windows-Bereinigung" -Status "Erstelle Bericht..." -PercentComplete 100
    Write-CleanupReport -Results $results -EmptyDirResults $emptyDirResults -LogPath $LogPath
    
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