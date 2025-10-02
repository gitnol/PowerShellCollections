#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Deaktiviert systemweit Windows- und Office-Telemetrie
.DESCRIPTION
    Umfassendes Skript zur Deaktivierung von Telemetrie- und Datensammlungsfunktionen
    für Windows und Microsoft Office. Verarbeitet alle Benutzerprofile inklusive
    abgemeldeter Benutzer durch temporäres Laden von NTUSER.DAT-Hives.
    Version 2.5: PSScriptAnalyzer-Korrekturen und Effizienz-Optimierungen.
.EXAMPLE
    .\Disable-Telemetry.ps1
.EXAMPLE
    .\Disable-Telemetry.ps1 -WhatIf
.EXAMPLE
    .\Disable-Telemetry.ps1 -Verbose
#>

[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper-Funktionen

function Write-Progress-Step {
    param(
        [string]$Step,
        [string]$Activity
    )
    Write-Host "[$Step] $Activity" -ForegroundColor Cyan
}

function Set-RegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [object]$Value,
        [string]$Type = 'DWord',
        [string]$Description
    )
    
    $result = [PSCustomObject]@{
        Aktion  = $Description
        Pfad    = "$Path\$Name"
        Status  = 'Fehler'
        Details = ''
    }
    
    try {
        if (-not (Test-Path $Path)) {
            if ($PSCmdlet.ShouldProcess($Path, "Registry-Pfad erstellen")) {
                New-Item -Path $Path -Force | Out-Null
                Write-Verbose "Registry-Pfad erstellt: $Path"
            }
        }
        
        if ($PSCmdlet.ShouldProcess("$Path\$Name", "Wert auf $Value setzen")) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
            $result.Status = 'Erfolgreich'
            $result.Details = "Wert: $Value"
            Write-Verbose "Registry-Wert gesetzt: $Path\$Name = $Value"
        }
        else {
            $result.Status = 'Übersprungen (WhatIf)'
        }
    }
    catch {
        $result.Details = $_.Exception.Message
        Write-Warning "Fehler bei $Description : $($_.Exception.Message)"
    }
    
    return $result
}

function Disable-Service {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,
        [Parameter(Mandatory)]
        [string]$Description
    )
    
    $result = [PSCustomObject]@{
        Aktion  = $Description
        Pfad    = "Dienst: $ServiceName"
        Status  = 'Fehler'
        Details = ''
    }
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        
        if ($null -eq $service) {
            $result.Status = 'Nicht vorhanden'
            $result.Details = 'Dienst existiert nicht auf diesem System'
            Write-Verbose "Dienst $ServiceName existiert nicht"
            return $result
        }
        
        if ($PSCmdlet.ShouldProcess($ServiceName, "Dienst stoppen und deaktivieren")) {
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $ServiceName -Force
                Write-Verbose "Dienst $ServiceName gestoppt"
            }
            
            Set-Service -Name $ServiceName -StartupType Disabled
            $result.Status = 'Erfolgreich'
            $result.Details = 'Gestoppt und deaktiviert'
            Write-Verbose "Dienst $ServiceName deaktiviert"
        }
        else {
            $result.Status = 'Übersprungen (WhatIf)'
        }
    }
    catch {
        $result.Details = $_.Exception.Message
        Write-Warning "Fehler bei Dienst $ServiceName : $($_.Exception.Message)"
    }
    
    return $result
}

function Get-UserProfiles {
    $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    
    # Effizientes Sammeln der Profile ohne += in der Schleife
    $userProfiles = Get-ChildItem $profileListPath | ForEach-Object {
        $sid = $_.PSChildName
        
        # Systemkonten ausschließen (SID endet auf -500 = Administrator oder S-1-5-18/19/20)
        if ($sid -match '-500$' -or $sid -match '^S-1-5-(18|19|20)$') {
            Write-Verbose "Überspringe Systemkonto: $sid"
            return # Springt zur nächsten Iteration
        }

        $profilePath = (Get-ItemProperty $_.PSPath).ProfileImagePath
        
        # Gebe das Objekt aus, PowerShell sammelt es im Array $userProfiles
        [PSCustomObject]@{
            SID         = $sid
            ProfilePath = $profilePath
            NTUserPath  = Join-Path $profilePath 'NTUSER.DAT'
            IsLoaded    = Test-Path "Registry::HKEY_USERS\$sid"
        }
    }
    
    return $userProfiles
}

function Set-OfficeTelemetryForProfile {
    param(
        [Parameter(Mandatory)]
        [string]$HiveRoot,
        [Parameter(Mandatory)]
        [string]$ProfileName
    )
    
    $officeVersions = @('16.0', '15.0', '14.0') # Office 2016/2019/365, 2013, 2010
    
    # Effizientes Sammeln der Ergebnisse
    $results = foreach ($version in $officeVersions) {
        $basePath = "$HiveRoot\Software\Microsoft\Office\$version\Common"
        
        # Telemetrie deaktivieren
        Set-RegistryValue -Path "$basePath\ClientTelemetry" `
            -Name 'DisableTelemetry' -Value 1 `
            -Description "Office $version Telemetrie deaktivieren ($ProfileName)"
        
        # Feedback deaktivieren
        Set-RegistryValue -Path "$basePath\Feedback" `
            -Name 'Enabled' -Value 0 `
            -Description "Office $version Feedback deaktivieren ($ProfileName)"
        
        # Kundenerfahrungsverbesserung deaktivieren
        Set-RegistryValue -Path "$basePath" `
            -Name 'QMEnable' -Value 0 `
            -Description "Office $version CEIP deaktivieren ($ProfileName)"
    }
    
    return $results
}

function Set-UserProfileOfficeTelemetry {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$UserProfile
    )
    
    $results = @()
    $tempHiveName = "TempHive_$($UserProfile.SID)"
    $hiveLoaded = $false
    
    try {
        if ($UserProfile.IsLoaded) {
            # Benutzer ist angemeldet - direkt zugreifen
            Write-Verbose "Verarbeite angemeldeten Benutzer: $($UserProfile.SID)"
            $hiveRoot = "Registry::HKEY_USERS\$($UserProfile.SID)"
            $results += Set-OfficeTelemetryForProfile -HiveRoot $hiveRoot -ProfileName "Angemeldet: $($UserProfile.SID)"
        }
        else {
            # Benutzer ist abgemeldet - Hive laden
            if (-not (Test-Path $UserProfile.NTUserPath)) {
                Write-Warning "NTUSER.DAT nicht gefunden: $($UserProfile.NTUserPath)"
                return $results # Gibt leeres Array zurück
            }
            
            Write-Verbose "Lade Hive für abgemeldeten Benutzer: $($UserProfile.SID)"
            
            if ($PSCmdlet.ShouldProcess($UserProfile.NTUserPath, "Registry-Hive laden")) {
                & reg.exe load "HKU\$tempHiveName" $UserProfile.NTUserPath 2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    $hiveLoaded = $true
                    Start-Sleep -Milliseconds 500 # Kurze Pause für Registry-Synchronisation
                    
                    $hiveRoot = "Registry::HKEY_USERS\$tempHiveName"
                    $results += Set-OfficeTelemetryForProfile -HiveRoot $hiveRoot -ProfileName "Abgemeldet: $($UserProfile.SID)"
                }
                else {
                    Write-Warning "Fehler beim Laden des Hives für $($UserProfile.SID)"
                }
            }
        }
    }
    catch {
        Write-Warning "Fehler beim Verarbeiten von Profil $($UserProfile.SID): $($_.Exception.Message)"
    }
    finally {
        # Hive IMMER entladen, auch bei Fehlern
        if ($hiveLoaded) {
            try {
                Write-Verbose "Entlade Hive: $tempHiveName"
                [gc]::Collect() # Garbage Collection erzwingen
                Start-Sleep -Milliseconds 500
                & reg.exe unload "HKU\$tempHiveName" 2>&1 | Out-Null
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Warnung: Hive $tempHiveName konnte nicht sofort entladen werden (wird beim Neustart freigegeben)"
                }
            }
            catch {
                Write-Warning "Fehler beim Entladen des Hives: $($_.Exception.Message)"
            }
        }
    }
    
    return $results
}

#endregion

#region Hauptausführung

$allResults = @()

try {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Windows & Office Telemetrie-Deaktivierung" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    # Schritt 1: Windows-Telemetrie konfigurieren
    Write-Progress-Step "1/3" "Konfiguriere Windows-Telemetrie..."
    
    $allResults += Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' `
        -Name 'AllowTelemetry' -Value 0 `
        -Description 'Windows Telemetrie auf Sicherheitsstufe setzen'
    
    $allResults += Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' `
        -Name 'AllowTelemetry' -Value 0 `
        -Description 'Windows Datensammlung deaktivieren'
    
    $allResults += Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' `
        -Name 'DoNotShowFeedbackNotifications' -Value 1 `
        -Description 'Feedback-Benachrichtigungen deaktivieren'
    
    $allResults += Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' `
        -Name 'AITEnable' -Value 0 `
        -Description 'Programm-Inventarisierung deaktivieren'
    
    # Schritt 2: Telemetrie-Dienste deaktivieren
    Write-Progress-Step "2/3" "Deaktiviere Telemetrie-Dienste..."
    
    $allResults += Disable-Service -ServiceName 'DiagTrack' `
        -Description 'Connected User Experiences and Telemetry Service'
    
    $allResults += Disable-Service -ServiceName 'dmwappushservice' `
        -Description 'WAP Push Message Routing Service'
    
    # Schritt 3: Office-Telemetrie für alle Benutzer
    Write-Progress-Step "3/3" "Konfiguriere Office-Telemetrie für alle Benutzerprofile..."
    
    $userProfiles = Get-UserProfiles
    Write-Host "Gefundene Benutzerprofile: $($userProfiles.Count)" -ForegroundColor Yellow
    
    foreach ($userProfile in $userProfiles) {
        Write-Verbose "Verarbeite Profil: $($userProfile.SID)"
        $allResults += Set-UserProfileOfficeTelemetry -UserProfile $userProfile
    }
    
    # Ausgabe und Logging
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Ergebnisse" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    $allResults | Format-Table -AutoSize -Wrap
    
    $summary = $allResults | Group-Object Status | Select-Object Name, Count
    Write-Host "Zusammenfassung:" -ForegroundColor Cyan
    $summary | Format-Table -AutoSize
    
    # CSV-Export
    $logPath = Join-Path $env:TEMP "Telemetrie-Deaktivierung_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $allResults | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8
    Write-Host "Detailprotokoll gespeichert: $logPath" -ForegroundColor Green
    
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Abgeschlossen!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}
catch {
    Write-Host "KRITISCHER FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Skript wird beendet." -ForegroundColor Red
    exit 1
}

#endregion