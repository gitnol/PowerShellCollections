#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Ultimate Windows Cleanup Tool v4.0 (Fixed) - Stabile Version
.DESCRIPTION
    Erweiterte Windows-Bereinigung mit optimierten Defaults und flexiblen Bereinigungsmodi.
    Diese Version wurde für maximale Kompatibilität und Stabilität optimiert.
.PARAMETER DaysOld
    Alter der zu löschenden Dateien in Tagen (Standard: 3)
.PARAMETER QuickClean
    Schnelle Basis-Bereinigung (nur Temp-Dateien, keine Browser/Ordner)
.PARAMETER DeepClean
    Maximale Bereinigung (Browser-Caches, Delivery Optimization, leere Ordner)
.PARAMETER SafeMode
    Konservativer Modus (14 Tage alt, keine Browser-Caches)
.PARAMETER IncludeEventLogs
    Leert zusätzlich alle Windows Event-Logs
.PARAMETER IncludeBrowserCaches
    Bezieht Browser-Caches in die Bereinigung ein
.PARAMETER RemoveEmptyDirs
    Löscht leere Unterverzeichnisse nach der Bereinigung
.PARAMETER MaxThreads
    Maximale Anzahl paralleler Threads (Standard: 4)
.PARAMETER LogPath
    Pfad für detailliertes Cleanup-Log
.PARAMETER DryRun
    Simuliert die Bereinigung ohne tatsächliche Löschungen
.EXAMPLE
    .\Ultimate-Cleanup-v4-Fixed.ps1 -QuickClean
.EXAMPLE
    .\Ultimate-Cleanup-v4-Fixed.ps1 -DeepClean -DryRun
.NOTES
    Version: 4.0 Fixed
    Optimiert für Stabilität und Kompatibilität
#>

[CmdletBinding(DefaultParameterSetName = 'Standard', SupportsShouldProcess = $true)]
param(
    [Parameter(ParameterSetName = 'Standard')]
    [Parameter(ParameterSetName = 'Quick')]
    [Parameter(ParameterSetName = 'Deep')]
    [Parameter(ParameterSetName = 'Safe')]
    [ValidateRange(1, 365)]
    [int]$DaysOld = 3,
    
    [Parameter(ParameterSetName = 'Quick', Mandatory)]
    [switch]$QuickClean,
    
    [Parameter(ParameterSetName = 'Deep', Mandatory)]
    [switch]$DeepClean,
    
    [Parameter(ParameterSetName = 'Safe', Mandatory)]
    [switch]$SafeMode,
    
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
    [string[]]$ExcludePaths = @(),
    
    [Parameter()]
    [switch]$DryRun
)

#region Mode Configuration
if ($QuickClean) {
    $DaysOld = 1
    $IncludeBrowserCaches = $false
    $IncludeDeliveryOptimization = $false
    $RemoveEmptyDirs = $false
    Write-Verbose "Quick-Clean Modus aktiviert"
}
elseif ($DeepClean) {
    $DaysOld = 7
    $IncludeBrowserCaches = $true
    $IncludeDeliveryOptimization = $true
    $RemoveEmptyDirs = $true
    $IncludeEventLogs = $true
    Write-Verbose "Deep-Clean Modus aktiviert"
}
elseif ($SafeMode) {
    $DaysOld = 14
    $IncludeBrowserCaches = $false
    Write-Verbose "Safe-Mode aktiviert"
}

if ($DryRun) {
    $WhatIfPreference = $true
    Write-Warning "DRY-RUN MODUS: Keine Dateien werden gelöscht, nur Simulation!"
}
#endregion

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
    [CmdletBinding()]
    param(
        [switch]$IncludeBrowserCaches,
        [switch]$IncludeDeliveryOptimization
    )
    
    $paths = New-Object System.Collections.ArrayList
    
    # Systemweite Pfade
    $systemPaths = @(
        "$($Script:Config.SystemRoot)\Temp",
        "$($Script:Config.SystemRoot)\Logs\CBS",
        "$($Script:Config.SystemRoot)\Downloaded Program Files",
        "$($Script:Config.ProgramData)\Microsoft\Windows\WER",
        "$($Script:Config.SystemRoot)\SoftwareDistribution\Download",
        "$($Script:Config.SystemRoot)\Prefetch"
    )
    
    if ($IncludeDeliveryOptimization) {
        $systemPaths += "$($Script:Config.SystemRoot)\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
    }
    
    foreach ($path in $systemPaths) {
        if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
            $null = $paths.Add([PSCustomObject]@{
                    Path     = $path
                    Category = 'System'
                    Type     = 'System'
                })
            Write-Verbose "Systempfad hinzugefügt: $path"
        }
    }
    
    # Benutzerspezifische Pfade
    try {
        $userProfiles = Get-CimInstance -Class Win32_UserProfile -Filter "Special = FALSE" -ErrorAction Stop |
        Where-Object { $_.LocalPath -and (Test-Path $_.LocalPath) } |
        Select-Object -ExpandProperty LocalPath
    }
    catch {
        Write-Warning "Fehler beim Abrufen der Benutzerprofile: $_"
        $userProfiles = @()
    }
    
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
    
    if ($IncludeBrowserCaches) {
        $browserPaths = @(
            "AppData\Local\Microsoft\Edge\User Data\Default\Cache",
            "AppData\Local\Microsoft\Edge\User Data\Default\Code Cache",
            "AppData\Local\Google\Chrome\User Data\Default\Cache",
            "AppData\Local\Google\Chrome\User Data\Default\Code Cache",
            "AppData\Local\Mozilla\Firefox\Profiles"
        )
        $userRelativePaths += $browserPaths
    }
    
    foreach ($userProfile in $userProfiles) {
        $userName = Split-Path $userProfile -Leaf
        foreach ($relativePath in $userRelativePaths) {
            $fullPath = Join-Path -Path $userProfile -ChildPath $relativePath
            
            # Firefox-Profile speziell behandeln
            if ($relativePath -eq "AppData\Local\Mozilla\Firefox\Profiles" -and (Test-Path $fullPath)) {
                $firefoxProfiles = Get-ChildItem -Path $fullPath -Directory -ErrorAction SilentlyContinue
                foreach ($myprofile in $firefoxProfiles) {
                    $cachePath = Join-Path $myprofile.FullName "cache2"
                    if (Test-Path $cachePath) {
                        $null = $paths.Add([PSCustomObject]@{
                                Path     = $cachePath
                                Category = 'Browser-Cache'
                                Type     = "User-$userName"
                            })
                        Write-Verbose "Firefox-Cache hinzugefügt: $cachePath"
                    }
                }
            }
            elseif (Test-Path -Path $fullPath -ErrorAction SilentlyContinue) {
                $category = if ($relativePath -like "*Cache*") { 'User-Cache' } 
                elseif ($relativePath -like "*Temp*") { 'User-Temp' }
                else { 'User-Other' }
                
                $null = $paths.Add([PSCustomObject]@{
                        Path     = $fullPath
                        Category = $category
                        Type     = "User-$userName"
                    })
                Write-Verbose "Benutzerpfad hinzugefügt: $fullPath"
            }
        }
    }
    
    # Exclude-Filter anwenden
    if ($ExcludePaths.Count -gt 0) {
        $filteredPaths = New-Object System.Collections.ArrayList
        foreach ($pathObj in $paths) {
            $excluded = $false
            foreach ($excludePath in $ExcludePaths) {
                if ($pathObj.Path -like $excludePath) {
                    $excluded = $true
                    break
                }
            }
            if (-not $excluded) {
                $null = $filteredPaths.Add($pathObj)
            }
        }
        Write-Verbose "Exclude-Filter angewendet, verbleibende Pfade: $($filteredPaths.Count)"
        return @($filteredPaths)
    }
    
    return @($paths)
}

function Remove-OldFilesFromPath {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PathInfo,
        
        [Parameter(Mandatory)]
        [datetime]$Threshold,
        
        [Parameter()]
        [switch]$DryRun
    )
    
    $result = [PSCustomObject]@{
        Path         = $PathInfo.Path
        Category     = $PathInfo.Category
        Type         = $PathInfo.Type
        FilesDeleted = 0
        BytesFreed   = 0
        Errors       = 0
        Duration     = $null
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $files = Get-ChildItem -Path $PathInfo.Path -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.LastWriteTime -le $Threshold -and 
            -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
        }
        
        foreach ($file in $files) {
            if ($DryRun -or $WhatIfPreference) {
                $result.FilesDeleted++
                $result.BytesFreed += $file.Length
                Write-Verbose "[DRY-RUN] Würde löschen: $($file.FullName)"
            }
            elseif ($PSCmdlet.ShouldProcess($file.FullName, "Remove")) {
                try {
                    $fileSize = $file.Length
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                    $result.FilesDeleted++
                    $result.BytesFreed += $fileSize
                    Write-Verbose "Gelöscht: $($file.FullName)"
                }
                catch {
                    $result.Errors++
                    Write-Warning "Fehler beim Löschen: $($file.FullName)"
                }
            }
        }
    }
    catch {
        Write-Error "Fehler beim Durchsuchen von '$($PathInfo.Path)': $_"
    }
    
    $stopwatch.Stop()
    $result.Duration = $stopwatch.Elapsed
    
    return $result
}

function Remove-EmptyDirectories {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [switch]$DryRun
    )
    
    $result = [PSCustomObject]@{
        Path        = $Path
        DirsDeleted = 0
        Errors      = 0
    }
    
    try {
        $dirs = Get-ChildItem -Path $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Sort-Object -Property FullName -Descending
        
        foreach ($dir in $dirs) {
            $items = Get-ChildItem -Path $dir.FullName -Force -ErrorAction SilentlyContinue
            
            if ($null -eq $items -or $items.Count -eq 0) {
                if ($DryRun -or $WhatIfPreference) {
                    $result.DirsDeleted++
                    Write-Verbose "[DRY-RUN] Würde leeren Ordner löschen: $($dir.FullName)"
                }
                elseif ($PSCmdlet.ShouldProcess($dir.FullName, "Remove Empty Directory")) {
                    try {
                        Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction Stop
                        $result.DirsDeleted++
                        Write-Verbose "Leerer Ordner gelöscht: $($dir.FullName)"
                    }
                    catch {
                        $result.Errors++
                        Write-Verbose "Fehler beim Löschen des Ordners: $($dir.FullName)"
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Fehler beim Durchsuchen von '$Path': $_"
    }
    
    return $result
}

function Clear-WindowsEventLogs {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([switch]$DryRun)
    
    $clearedLogs = 0
    $failedLogs = 0
    
    try {
        $eventLogs = @(wevtutil el)
    }
    catch {
        Write-Warning "Fehler beim Abrufen der Event-Logs: $_"
        return [PSCustomObject]@{
            Cleared = 0
            Failed  = 0
            Total   = 0
        }
    }
    
    foreach ($log in $eventLogs) {
        if ($DryRun -or $WhatIfPreference) {
            $clearedLogs++
            Write-Verbose "[DRY-RUN] Würde Event-Log leeren: $log"
        }
        elseif ($PSCmdlet.ShouldProcess($log, "Clear EventLog")) {
            try {
                $null = wevtutil cl "$log" 2>$null
                $clearedLogs++
                Write-Verbose "Event-Log geleert: $log"
            }
            catch {
                $failedLogs++
                Write-Verbose "Fehler beim Leeren von Event-Log: $log"
            }
        }
    }
    
    return [PSCustomObject]@{
        Cleared = $clearedLogs
        Failed  = $failedLogs
        Total   = $eventLogs.Count
    }
}

function Write-CleanupReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results,
        
        [Parameter()]
        [array]$EmptyDirResults,
        
        [Parameter()]
        [PSCustomObject]$EventLogResults,
        
        [Parameter()]
        [string]$LogPath,
        
        [Parameter()]
        [switch]$DryRun
    )
    
    # Statistiken berechnen
    $totalFiles = 0
    $totalBytes = 0
    $totalErrors = 0
    
    foreach ($result in $Results) {
        $totalFiles += $result.FilesDeleted
        $totalBytes += $result.BytesFreed
        $totalErrors += $result.Errors
    }
    
    $totalEmptyDirs = 0
    if ($EmptyDirResults) {
        foreach ($dirResult in $EmptyDirResults) {
            $totalEmptyDirs += $dirResult.DirsDeleted
        }
    }
    
    # Bericht erstellen
    $modeText = if ($DryRun -or $WhatIfPreference) { "[DRY-RUN SIMULATION]" } else { "[AUSGEFÜHRT]" }
    
    $report = @"

================== BEREINIGUNGSBERICHT $modeText ==================
Startzeit:             $($Script:Config.Statistics.StartTime)
Endzeit:               $(Get-Date)
Bereinigungs-Alter:    Dateien älter als $DaysOld Tag(e)

ERGEBNISSE:
-----------
Bereinigte Pfade:      $($Results.Count)
Gelöschte Dateien:     $totalFiles
Freigegebener Speicher: $([Math]::Round($totalBytes/1MB, 2)) MB
"@
    
    if ($totalEmptyDirs -gt 0) {
        $report += "`r`nGelöschte leere Ordner: $totalEmptyDirs"
    }
    
    if ($EventLogResults) {
        $report += "`r`nEvent-Logs geleert:    $($EventLogResults.Cleared)/$($EventLogResults.Total)"
    }
    
    $report += "`r`nFehler:                $totalErrors"
    
    # Top 5 Pfade
    $top5 = $Results | Sort-Object BytesFreed -Descending | Select-Object -First 5
    if ($top5) {
        $report += "`r`n`r`nTOP 5 PFADE (nach Speicher):"
        $report += "`r`n-----------------------------"
        foreach ($item in $top5) {
            $report += "`r`n[$($item.Category)] $($item.Path)"
            $report += "`r`n  → $([Math]::Round($item.BytesFreed/1MB, 2)) MB ($($item.FilesDeleted) Dateien)"
        }
    }
    
    $report += "`r`n========================================================="
    
    Write-Information $report -InformationAction Continue
    
    # CSV-Export
    if ($LogPath) {
        try {
            $Results | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8
            Write-Information "Log gespeichert: $LogPath" -InformationAction Continue
        }
        catch {
            Write-Warning "Fehler beim Speichern des Logs: $_"
        }
    }
}
#endregion

#region Main Execution
function Start-WindowsCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    
    # Modus-Information
    $modeInfo = if ($QuickClean) { "QUICK-CLEAN" } 
    elseif ($DeepClean) { "DEEP-CLEAN" } 
    elseif ($SafeMode) { "SAFE-MODE" }
    else { "STANDARD" }
    
    Write-Information @"
╔══════════════════════════════════════════════════════╗
║     Windows Ultimate Cleanup Tool v4.0 Fixed        ║
║     Modus: $modeInfo                                ║
╚══════════════════════════════════════════════════════╝

Konfiguration:
--------------
Bereinigungs-Schwellwert: Dateien älter als $DaysOld Tag(e)
Parallele Threads:        $MaxThreads
Browser-Caches:           $IncludeBrowserCaches
Delivery Optimization:    $IncludeDeliveryOptimization
Leere Ordner entfernen:   $RemoveEmptyDirs
Event-Logs leeren:        $IncludeEventLogs
Dry-Run Modus:            $DryRun
"@ -InformationAction Continue
    
    # Pfade ermitteln
    Write-Progress -Activity "Windows-Bereinigung" -Status "Ermittle Bereinigungspfade..." -PercentComplete 0
    
    $cleanupPaths = Get-CleanupPaths -IncludeBrowserCaches:$IncludeBrowserCaches `
        -IncludeDeliveryOptimization:$IncludeDeliveryOptimization
    
    if ($cleanupPaths.Count -eq 0) {
        Write-Warning "Keine gültigen Bereinigungspfade gefunden."
        return
    }
    
    Write-Information "Gefundene Pfade: $($cleanupPaths.Count)" -InformationAction Continue
    
    # Threshold berechnen
    $threshold = (Get-Date).AddDays(-$DaysOld)
    
    # PHASE 1: Parallele Dateibereinigung
    Write-Progress -Activity "Windows-Bereinigung" -Status "Starte Dateibereinigung..." -PercentComplete 10
    
    # Runspace-Pool erstellen
    $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
    $runspacePool.Open()
    
    $jobs = @()
    $scriptBlock = ${function:Remove-OldFilesFromPath}
    
    # Jobs erstellen
    foreach ($pathInfo in $cleanupPaths) {
        # PowerShell-Instanz erstellen und konfigurieren
        $powershell = [PowerShell]::Create()
        $null = $powershell.AddScript($scriptBlock)
        $null = $powershell.AddArgument($pathInfo)
        $null = $powershell.AddArgument($threshold)
        
        if ($DryRun -or $WhatIfPreference) {
            $null = $powershell.AddParameter('DryRun', $true)
        }
        
        $powershell.RunspacePool = $runspacePool
        
        # Job-Objekt erstellen
        $job = [PSCustomObject]@{
            PathInfo   = $pathInfo
            PowerShell = $powershell
            Handle     = $powershell.BeginInvoke()
        }
        
        $jobs += $job
    }
    
    # Jobs überwachen
    $results = @()
    $completed = 0
    $totalJobs = $jobs.Count
    
    while ($true) {
        $runningJobs = @($jobs | Where-Object { -not $_.Handle.IsCompleted })
        if ($runningJobs.Count -eq 0) { break }
        
        Start-Sleep -Milliseconds 500
        $completed = $totalJobs - $runningJobs.Count
        $percentComplete = [Math]::Min(70, 10 + ([Math]::Round(($completed / $totalJobs) * 60)))
        
        Write-Progress -Activity "Windows-Bereinigung" `
            -Status "Verarbeite Pfade... ($completed/$totalJobs)" `
            -PercentComplete $percentComplete
    }
    
    # Ergebnisse sammeln
    foreach ($job in $jobs) {
        try {
            $result = $job.PowerShell.EndInvoke($job.Handle)
            if ($result) {
                $results += $result
            }
        }
        catch {
            Write-Warning "Fehler bei Pfad '$($job.PathInfo.Path)': $_"
        }
        finally {
            $job.PowerShell.Dispose()
        }
    }
    
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    # PHASE 2: Leere Ordner löschen (optional)
    $emptyDirResults = @()
    if ($RemoveEmptyDirs) {
        Write-Progress -Activity "Windows-Bereinigung" -Status "Bereinige leere Ordner..." -PercentComplete 75
        
        foreach ($pathInfo in $cleanupPaths) {
            if (Test-Path $pathInfo.Path) {
                $dirResult = Remove-EmptyDirectories -Path $pathInfo.Path -DryRun:$DryRun
                if ($dirResult) {
                    $emptyDirResults += $dirResult
                }
            }
        }
    }
    
    # PHASE 3: Event-Logs leeren (optional)
    $eventLogResults = $null
    if ($IncludeEventLogs) {
        Write-Progress -Activity "Windows-Bereinigung" -Status "Leere Event-Logs..." -PercentComplete 90
        $eventLogResults = Clear-WindowsEventLogs -DryRun:$DryRun
    }
    
    # PHASE 4: Bericht erstellen
    Write-Progress -Activity "Windows-Bereinigung" -Status "Erstelle Bericht..." -PercentComplete 95
    
    Write-CleanupReport -Results $results `
        -EmptyDirResults $emptyDirResults `
        -EventLogResults $eventLogResults `
        -LogPath $LogPath `
        -DryRun:$DryRun
    
    Write-Progress -Activity "Windows-Bereinigung" -Completed
    
    # Abschlussmeldung
    if ($DryRun -or $WhatIfPreference) {
        Write-Warning "DRY-RUN ABGESCHLOSSEN - Keine Dateien wurden gelöscht"
    }
    else {
        Write-Information "✓ Bereinigung erfolgreich abgeschlossen!" -InformationAction Continue
    }
}

# Hauptausführung
try {
    # Prüfe Administratorrechte
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        throw "Dieses Skript erfordert Administratorrechte. Bitte als Administrator ausführen."
    }
    
    # Starte Bereinigung
    Start-WindowsCleanup
}
catch {
    Write-Error "Kritischer Fehler: $_"
    exit 1
}
#endregion