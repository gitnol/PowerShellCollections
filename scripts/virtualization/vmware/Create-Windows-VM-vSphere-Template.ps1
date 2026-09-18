<#
.SYNOPSIS
    Bereitet eine Windows-VM als vSphere-Template vor.
.DESCRIPTION
    Version: 4.1 (Linter-Fixed)
    Dieses Skript führt eine tiefgreifende Systembereinigung durch, inklusive Sicherheits-Hardening,
    Performance-Optimierungen und erweiterter Löschroutinen. Es misst den freigegebenen Speicherplatz
    und zeigt den Fortschritt an. Es unterstützt einen '-WhatIf' Trockenlauf.
.PARAMETER ClearEventLogs
    Löscht alle Windows-Ereignisprotokolle.
.PARAMETER ClearWSUS
    Setzt den WSUS-Client-Footprint zurück.
.PARAMETER AggressiveDISM
    Führt DISM StartComponentCleanup mit dem /ResetBase-Switch aus.
.PARAMETER SysprepAndShutdown
    Führt zum Schluss Sysprep /generalize /oobe /shutdown /mode:vm aus.
.EXAMPLE
    # Führt den kompletten "Gold Standard"-Lauf durch und versiegelt die VM.
    .\Create-Windows-VM-vSphere-Template.ps1 -ClearEventLogs -ClearWSUS -AggressiveDISM -SysprepAndShutdown

.EXAMPLE
    # Führt einen Trockenlauf durch, um alle geplanten Aktionen anzuzeigen.
    .\Create-Windows-VM-vSphere-Template.ps1 -ClearEventLogs -ClearWSUS -AggressiveDISM -SysprepAndShutdown -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$ClearEventLogs,
    [switch]$ClearWSUS,
    [switch]$AggressiveDISM,
    [switch]$SysprepAndShutdown
)

$ErrorActionPreference = 'Stop'

# --- Hilfsfunktionen ---
function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Warning $msg }
function Write-Err($msg) { Write-Error $msg }

# --- Fortschritts- & Validierungsfunktionen ---
function Write-Progress-Step($activity) {
    $script:currentStep++
    Write-Progress -Activity "Template-Vorbereitung" -Status $activity -PercentComplete (($script:currentStep / $script:totalSteps) * 100) -Id 0
}

function Get-DiskSpaceInfo {
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive.Trim(':'))'"
    return [PSCustomObject]@{
        FreeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    }
}

# --- Bereinigungsfunktionen ---

function Remove-PathSafe {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if (Test-Path -LiteralPath $Path) {
        if ($PSCmdlet.ShouldProcess($Path, "Löschen")) {
            try {
                Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
                Write-Verbose "Erfolgreich gelöscht: $Path"
            }
            catch {
                Write-Warn "Konnte nicht vollständig löschen: $Path -> $($_.Exception.Message)"
            }
        }
    }
}

function Invoke-ComponentCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess("Komponentenspeicher (WinSxS)", "Bereinigen via DISM")) {
        try {
            Write-Info "DISM StartComponentCleanup wird ausgeführt..."
            DISM.exe /Online /Cleanup-Image /StartComponentCleanup | Out-Null
            if ($AggressiveDISM.IsPresent) {
                Write-Info "Aggressiv: DISM ResetBase wird ausgeführt (macht Updates permanent)..."
                DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
            }
        }
        catch {
            Write-Warn "DISM Cleanup Warnung: $($_.Exception.Message)"
        }
    }
}

function Clear-AllEventLogs {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess("Alle Windows Event-Logs", "Löschen")) {
        Write-Info "Alle Event-Logs werden gelöscht..."
        try {
            wevtutil.exe el | ForEach-Object {
                try { wevtutil.exe cl $_ | Out-Null } catch {}
            }
        }
        catch {
            Write-Warn "Generelle Eventlog-Cleanup Warnung: $($_.Exception.Message)"
        }
    }
}

function Reset-WSUSClient {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Info "WSUS-Client wird zurückgesetzt..."
    $services = @("wuauserv", "bits")
    $regKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\SusClientId",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\SusClientIdValidation"
    )
    $swDistPath = "$env:windir\SoftwareDistribution"

    try {
        if ($PSCmdlet.ShouldProcess($services -join ", ", "Dienste anhalten")) {
            Stop-Service -Name $services -Force -ErrorAction SilentlyContinue
        }

        Remove-PathSafe -Path $swDistPath

        foreach ($key in $regKeys) {
            if (Test-Path $key) {
                if ($PSCmdlet.ShouldProcess($key, "Registry-Schlüssel löschen")) {
                    Remove-Item -Path $key -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    catch {
        Write-Warn "WSUS-Reset Warnung: $($_.Exception.Message)"
    }
    finally {
        if ($PSCmdlet.ShouldProcess($services -join ", ", "Dienste starten")) {
            Start-Service -Name $services -ErrorAction SilentlyContinue
        }
    }
}

function Reset-NetworkState {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess("Netzwerk-Cache (IP, ARP, DNS)", "Zurücksetzen")) {
        Write-Info "Netzwerkzustand wird bereinigt..."
        try {
            ipconfig.exe /release | Out-Null
            arp.exe -d * | Out-Null
            ipconfig.exe /flushdns | Out-Null
        }
        catch {
            Write-Warn "Netzwerk-Bereinigung Warnung: $($_.Exception.Message)"
        }
    }
}

function Clear-UserProfiles {
    [CmdletBinding()]
    param()
    Write-Info "Benutzerprofile: Temp/Recent/Caches (inkl. Browser) werden aufgeräumt..."
    $profileRoot = "$env:SystemDrive\Users"
    $excludedProfiles = @("Default", "Default User", "Public", "All Users")
    Get-ChildItem -LiteralPath $profileRoot -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.PSIsContainer -and $_.Name -notin $excludedProfiles } |
    ForEach-Object {
        $userProfilePath = $_.FullName
        Write-Verbose "Bereinige Profil: $userProfilePath"
        # Standard-Caches
        Remove-PathSafe -Path "$userProfilePath\AppData\Local\Temp"
        Remove-PathSafe -Path "$userProfilePath\AppData\Local\Microsoft\Windows\INetCache"
        Remove-PathSafe -Path "$userProfilePath\AppData\Roaming\Microsoft\Windows\Recent"
        # Browser-Caches
        Remove-PathSafe -Path "$userProfilePath\AppData\Local\Google\Chrome\User Data\Default\Cache"
        Get-ChildItem -Path "$userProfilePath\AppData\Local\Mozilla\Firefox\Profiles\*\cache2" -ErrorAction SilentlyContinue | ForEach-Object { Remove-PathSafe -Path $_.FullName }
    }
}

function Clear-SystemJunk {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Info "System: Temporäre Dateien, Logs, Dumps und Fehlerberichte werden geleert..."
    Remove-PathSafe -Path "$env:windir\Temp"
    Remove-PathSafe -Path "$env:windir\Logs"
    Remove-PathSafe -Path "$env:SystemDrive\Windows\Minidump"
    Remove-PathSafe -Path "$env:ProgramData\Microsoft\Windows\WER" # Windows Error Reporting
    
    if ($PSCmdlet.ShouldProcess("Papierkorb", "Leeren")) {
        try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Clear-PerformanceCaches {
    [CmdletBinding()]
    param()
    Write-Info "Performance-Caches (Prefetch) werden bereinigt..."
    Remove-PathSafe -Path "$env:windir\Prefetch"
}

function Clear-IISLogs {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $iisLogPath = "$env:SystemDrive\inetpub\logs"
    if (Test-Path $iisLogPath) {
        if ($PSCmdlet.ShouldProcess($iisLogPath, "IIS-Logs löschen")) {
            Write-Info "IIS-Logs werden bereinigt..."
            Remove-PathSafe -Path $iisLogPath
        }
    }
}

function Reset-SearchIndex {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess("Windows Search Index", "Zurücksetzen")) {
        Write-Info "Windows Search Index wird zurückgesetzt..."
        $serviceName = "WSearch"
        try {
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            Remove-PathSafe -Path "$env:ProgramData\Microsoft\Search\Data"
        }
        catch {
            Write-Warn "Fehler beim Zurücksetzen des Search Index: $($_.Exception.Message)"
        }
        finally {
            try { Start-Service -Name $serviceName -ErrorAction SilentlyContinue } catch {}
        }
    }
}

function Clear-SensitiveData {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Info "Sensitive Daten (RDP-Verlauf, Credentials, PS-History) werden gelöscht..."
    # RDP-Verlauf
    Remove-PathSafe -Path "$env:USERPROFILE\Documents\Default.rdp"
    
    # PowerShell Verlauf
    if ($PSCmdlet.ShouldProcess("PowerShell Verlauf", "Löschen")) {
        try {
            $historyPath = (Get-PSReadlineOption).HistorySavePath
            if (Test-Path $historyPath) { Remove-Item $historyPath -Force -ErrorAction Stop }
        }
        catch {
            Write-Warn "Konnte PowerShell-Verlauf nicht löschen: $($_.Exception.Message)"
        }
    }

    # Gespeicherte Anmeldeinformationen
    if ($PSCmdlet.ShouldProcess("Credential Manager", "Alle gespeicherten Einträge leeren")) {
        try {
            $credentials = cmdkey.exe /list
            foreach ($line in $credentials) {
                if ($line -match "^\s*Target:\s*(.*)") {
                    $target = $matches[1].Trim()
                    if ($target) {
                        cmdkey.exe /delete:$target | Out-Null
                    }
                }
            }
        }
        catch {
            Write-Warn "Fehler beim Leeren des Credential Managers."
        }
    }
}

function Invoke-SysprepShutdown {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $sysprepPath = "$env:windir\System32\Sysprep\Sysprep.exe"
    if (-not (Test-Path $sysprepPath)) { throw "Sysprep.exe nicht gefunden: $sysprepPath" }
    
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Generalize with Sysprep and Shutdown")) {
        Write-Info "Führe Sysprep /generalize /oobe /shutdown /mode:vm aus. Das System wird danach heruntergefahren."
        & $sysprepPath /generalize /oobe /shutdown /mode:vm
    }
}


# --- Hauptablauf ---
$summary = [System.Collections.Generic.List[object]]::new()
$logFile = "$env:windir\Temp\TemplatePrep-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').log"
Start-Transcript -Path $logFile -Append | Out-Null
Write-Info "Protokoll wird nach '$logFile' geschrieben."

# 1. Validierung (Vorher)
$diskSpaceBefore = Get-DiskSpaceInfo

# 2. Fortschrittsanzeige initialisieren
$script:currentStep = 0
$script:totalSteps = 10 # Grundschritte
if ($ClearEventLogs) { $script:totalSteps++ }
if ($ClearWSUS) { $script:totalSteps++ }
if ($SysprepAndShutdown) { $script:totalSteps++ }


try {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $summary.Add([PSCustomObject]@{ Step = "Betriebssystem"; Detail = "$($osInfo.Caption) Build $($osInfo.BuildNumber)" })

    Write-Progress-Step "Entferne sensitive Daten..."
    Clear-SensitiveData
    $summary.Add([PSCustomObject]@{ Step = "Sicherheit"; Detail = "RDP, Credentials & PS-History gelöscht" })

    Write-Progress-Step "Bereinige System-Junk..."
    Clear-SystemJunk
    $summary.Add([PSCustomObject]@{ Step = "System-Junk"; Detail = "Temp/Logs/WER geleert" })

    Write-Progress-Step "Bereinige Benutzerprofile..."
    Clear-UserProfiles
    $summary.Add([PSCustomObject]@{ Step = "Benutzerprofile"; Detail = "Caches (inkl. Browser) bereinigt" })
    
    Write-Progress-Step "Bereinige Performance-Caches..."
    Clear-PerformanceCaches
    $summary.Add([PSCustomObject]@{ Step = "Performance"; Detail = "Prefetch-Cache geleert" })

    Write-Progress-Step "Bereinige IIS-Logs..."
    Clear-IISLogs
    $summary.Add([PSCustomObject]@{ Step = "IIS"; Detail = "Logs bereinigt (falls vorhanden)" })

    if ($ClearEventLogs) {
        Write-Progress-Step "Lösche Event-Logs..."
        Clear-AllEventLogs
        $summary.Add([PSCustomObject]@{ Step = "Event-Logs"; Detail = "Alle Logs gelöscht" })
    }

    if ($ClearWSUS) {
        Write-Progress-Step "Setze WSUS-Client zurück..."
        Reset-WSUSClient
        $summary.Add([PSCustomObject]@{ Step = "WSUS-Client"; Detail = "Footprint zurückgesetzt" })
    }

    Write-Progress-Step "Setze Netzwerk-Cache zurück..."
    Reset-NetworkState
    $summary.Add([PSCustomObject]@{ Step = "Netzwerk"; Detail = "IP freigegeben, ARP/DNS-Cache geleert" })

    Write-Progress-Step "Setze Windows Search Index zurück..."
    Reset-SearchIndex
    $summary.Add([PSCustomObject]@{ Step = "Search Index"; Detail = "Index-Datenbank gelöscht" })

    Write-Progress-Step "Bereinige Komponentenspeicher..."
    Invoke-ComponentCleanup
    $summary.Add([PSCustomObject]@{ Step = "Komponentenspeicher"; Detail = "WinSxS via DISM bereinigt" })

    if ($SysprepAndShutdown) {
        Write-Progress-Step "Führe Sysprep aus..."
        Invoke-SysprepShutdown
        $summary.Add([PSCustomObject]@{ Step = "Sysprep"; Detail = "Ausgeführt, System fährt herunter" })
    }
    else {
        $summary.Add([PSCustomObject]@{ Step = "Sysprep"; Detail = "Übersprungen" })
    }
}
catch {
    Write-Err "Ein unerwarteter Fehler ist im Hauptablauf aufgetreten: $($_.Exception.Message)"
}
finally {
    # 3. Validierung (Nachher) & Bericht
    $diskSpaceAfter = Get-DiskSpaceInfo
    $spaceSavedGB = $diskSpaceAfter.FreeSpaceGB - $diskSpaceBefore.FreeSpaceGB
    
    Write-Progress -Activity "Template-Vorbereitung" -Completed -Id 0
    Stop-Transcript

    "`n" + ("-" * 35)
    "Zusammenfassung der Aktionen"
    $summary | Format-Table -AutoSize
    
    "`n" + ("-" * 35)
    "Speicherplatz-Bericht"
    Write-Host "Freier Speicherplatz vorher: $($diskSpaceBefore.FreeSpaceGB) GB"
    Write-Host "Freier Speicherplatz nachher : $($diskSpaceAfter.FreeSpaceGB) GB"
    Write-Host "Freigegebener Speicherplatz : $([math]::Round(-$spaceSavedGB, 2)) GB" -ForegroundColor Yellow
    "`n" + ("-" * 35)
    Write-Host "Log-Datei gespeichert unter: $logFile"

    if (-not $SysprepAndShutdown) {
        Write-Info "Skript abgeschlossen. Du kannst die VM jetzt herunterfahren."
        Start-Sleep -Seconds 10
    }
}
