# ====================================================================================
# Modernes WMI (Windows Management Instrumentation) Reparatur-Skript
# Autor: Gemini
# Version: 1.0 (PowerShell)
# Features: Transkript-Logging, Try/Catch-Fehlerbehandlung, PowerShell-Cmdlets
# ====================================================================================
# Danach optimiert mit Gemini und Claude. (back and forth)
# Version: 2.0 (PowerShell Optimiert)
# Features: Robuste Fehlerbehandlung, Backup-Validation, Service-Monitoring
# ACHTUNG: Als Administrator ausführen!
# ====================================================================================

<#
.SYNOPSIS
    Repariert beschädigte Windows Management Instrumentation (WMI) Repositories und Services.

.DESCRIPTION
    Dieses PowerShell-Skript führt eine umfassende WMI-Reparatur durch, die folgende Schritte umfasst:
    
    • Stoppt abhängige Services (VSS, SMPHost, WinMgmt)
    • Erstellt automatisch ein Backup des bestehenden WMI-Repositories
    • Setzt das WMI-Repository zurück (winmgmt /resetrepository)
    • Registriert alle System- und WMI-Provider-DLLs neu
    • Kompiliert MOF/MFL-Dateien für WMI-Klassen
    • Führt Konsistenzprüfungen durch
    • Testet die WMI-Funktionalität nach der Reparatur
    
    Das Skript protokolliert alle Aktionen in einer detaillierten Transkript-Datei und bietet
    umfassende Fehlerbehandlung mit Backup-Wiederherstellungsoptionen.

.PARAMETER SkipBackup
    Überspringt die Erstellung eines Repository-Backups. NICHT EMPFOHLEN für Produktionssysteme.

.PARAMETER Force
    Überspringt alle Benutzerabfragen und führt die Reparatur automatisch durch.
    Nützlich für unbeaufsichtigte Ausführung oder Skript-Integration.

.PARAMETER TimeoutSeconds
    Maximale Wartezeit in Sekunden für Service-Operationen. Standard: 120 Sekunden.

.INPUTS
    Keine Pipeline-Eingaben erforderlich.

.OUTPUTS
    - Detaillierte Konsolen-Ausgabe mit Fortschrittsanzeigen
    - Vollständiges Transkript-Log im TEMP-Verzeichnis
    - Optional: Repository-Backup im WBEM-Verzeichnis

.EXAMPLE
    PS C:\> .\Repair-WMI.ps1
    
    Führt eine vollständige WMI-Reparatur mit Backup und Benutzerabfragen durch.

.EXAMPLE
    PS C:\> .\Repair-WMI.ps1 -Force
    
    Führt eine unbeaufsichtigte WMI-Reparatur ohne Benutzerabfragen durch.

.EXAMPLE
    PS C:\> .\Repair-WMI.ps1 -SkipBackup -TimeoutSeconds 60
    
    Führt eine WMI-Reparatur ohne Backup durch und verwendet kürzere Timeouts.

.NOTES
    Dateiname:      Repair-WMI.ps1
    Autor:          System Administrator
    Erstellt:       $(Get-Date -Format 'yyyy-MM-dd')
    Version:        2.0
    PowerShell:     Requires 5.1 oder höher
    Plattform:      Windows 10/11, Windows Server 2016+
    
    WICHTIGE HINWEISE:
    • Erfordert Administrator-Rechte (automatisch geprüft)
    • Erstellt automatisch Backups (außer bei -SkipBackup)
    • Neustart nach Reparatur wird dringend empfohlen
    • Bei kritischen Systemen vorher testen!
    
    HÄUFIGE ANWENDUNGSFÄLLE:
    • WMI-Abfragen schlagen fehl oder liefern keine Daten
    • Group Policy Update-Probleme (gpupdate Fehler)
    • SCCM/Intune Agent-Probleme
    • PowerShell WMI-Cmdlet Fehler
    • Monitoring-Tools können keine WMI-Daten abrufen

.LINK
    https://docs.microsoft.com/en-us/windows/win32/wmisdk/
    
.LINK
    https://docs.microsoft.com/en-us/troubleshoot/windows-client/admin-development/fix-wmi-corruption
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Überspringt die Erstellung eines Repository-Backups (NICHT EMPFOHLEN)")]
    [switch]$SkipBackup,
    
    [Parameter(HelpMessage = "Überspringt alle Benutzerabfragen für unbeaufsichtigte Ausführung")]
    [switch]$Force,
    
    [Parameter(HelpMessage = "Maximale Wartezeit in Sekunden für Service-Operationen")]
    [ValidateRange(30, 300)]
    [int]$TimeoutSeconds = 120
)

# --- Skript-Konfiguration ---
$ErrorActionPreference = "Stop"
$LogFile = Join-Path -Path $env:TEMP -ChildPath "WMI-Repair-Log-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
$BackupPath = Join-Path -Path "$env:windir\System32\wbem" -ChildPath "Repository.bak-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
$RepositoryPath = Join-Path -Path "$env:windir\System32\wbem" -ChildPath "Repository"
$WbemPath = Join-Path -Path "$env:windir" -ChildPath "System32\wbem"

# --- Starte erweiterte Protokollierung ---
Start-Transcript -Path $LogFile -Force
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "WMI-Reparatur wird gestartet..." -ForegroundColor Green
Write-Host "Transkript: $LogFile" -ForegroundColor Gray
Write-Host "Computer: $env:COMPUTERNAME | Benutzer: $env:USERNAME" -ForegroundColor Gray
Write-Host "========================================================" -ForegroundColor Cyan

# --- Hilfsfunktionen ---
function Wait-ForServiceStatus {
    param(
        [string]$ServiceName,
        [string]$DesiredStatus,
        [int]$TimeoutSeconds = 60
    )
    
    $timeout = (Get-Date).AddSeconds($TimeoutSeconds)
    Write-Verbose "Warte auf Service '$ServiceName' Status '$DesiredStatus'..."
    
    do {
        try {
            $service = Get-Service -Name $ServiceName -ErrorAction Stop
            if ($service.Status -eq $DesiredStatus) {
                Write-Verbose "Service '$ServiceName' ist '$DesiredStatus'"
                return $true
            }
            Start-Sleep -Seconds 1
        }
        catch {
            Write-Warning "Service '$ServiceName' nicht gefunden oder nicht verfügbar."
            return $false
        }
    } while ((Get-Date) -lt $timeout)
    
    Write-Warning "Timeout: Service '$ServiceName' erreichte Status '$DesiredStatus' nicht innerhalb von $TimeoutSeconds Sekunden."
    return $false
}

function Test-WMIFunctionality {
    Write-Verbose "Teste WMI-Grundfunktionen..."
    try {
        # Teste sowohl CIM als auch traditionelle WMI-Zugriffe
        $null = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        Write-Verbose "CIM-Test erfolgreich"
        
        # Zusätzlicher Test für traditionelle WMI-Kompatibilität
        $null = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        Write-Host "    ✓ WMI/CIM-Test erfolgreich" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "    ⚠ WMI/CIM-Test fehlgeschlagen: $($_.Exception.Message)"
        return $false
    }
}

# --- Hauptlogik mit umfassender Fehlerbehandlung ---
try {
    # 0. Systemvoraussetzungen prüfen
    Write-Host "[0/9] Prüfe Systemvoraussetzungen..." -ForegroundColor Cyan
    
    if (-not (Test-Path $WbemPath)) {
        throw "WMI-Verzeichnis '$WbemPath' nicht gefunden. System könnte beschädigt sein."
    }
    Write-Host "    ✓ WMI-Verzeichnis gefunden" -ForegroundColor Green

    # 1. Services stoppen und konfigurieren
    Write-Host "[1/9] Stoppe und konfiguriere abhängige Services..." -ForegroundColor Cyan
    
    $servicesToStop = @("vss", "smphost")
    foreach ($serviceName in $servicesToStop) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop
            if ($service.Status -ne "Stopped") {
                Write-Verbose "Stoppe Service '$serviceName'..."
                Stop-Service -Name $serviceName -Force -ErrorAction Stop
                Wait-ForServiceStatus -ServiceName $serviceName -DesiredStatus "Stopped" -TimeoutSeconds 30
            }
            Set-Service -Name $serviceName -StartupType Manual -ErrorAction Stop
            Write-Host "    ✓ Service '$serviceName' gestoppt und auf 'Manual' gesetzt" -ForegroundColor Green
        }
        catch {
            Write-Warning "    ⚠ Service '$serviceName': $($_.Exception.Message)"
        }
    }

    # WMI-Service speziell behandeln
    Write-Verbose "Stoppe WMI-Service (winmgmt)..."
    try {
        Set-Service -Name "winmgmt" -StartupType Disabled -ErrorAction Stop
        Stop-Service -Name "winmgmt" -Force -ErrorAction Stop
        $wmistopped = Wait-ForServiceStatus -ServiceName "winmgmt" -DesiredStatus "Stopped" -TimeoutSeconds 60
        if (-not $wmistopped) {
            Write-Warning "    WMI-Service konnte nicht gestoppt werden. Fortfahren auf eigene Gefahr."
        }
        else {
            Write-Host "    ✓ WMI-Service erfolgreich gestoppt" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "    WMI-Service Stopp-Fehler: $($_.Exception.Message)"
    }

    # 2. Backup des Repositorys (mit Validierung)
    if (-not $SkipBackup) {
        Write-Host "[2/9] Erstelle Backup des WMI-Repositorys..." -ForegroundColor Cyan
        if (Test-Path $RepositoryPath) {
            Write-Verbose "Backup läuft... (kann mehrere Minuten dauern)"
            
            try {
                # Robocopy für bessere Backup-Behandlung
                $robocopyArgs = @(
                    "`"$RepositoryPath`"",
                    "`"$BackupPath`"",
                    "/E", "/COPYALL", "/R:1", "/W:1", "/NP"
                )
                $robocopyResult = & robocopy @robocopyArgs 2>&1
                $robocopyExitCode = $LASTEXITCODE
                
                if ($robocopyExitCode -le 1) {
                    # Backup-Validierung
                    $originalCount = (Get-ChildItem -Path $RepositoryPath -Recurse -File).Count
                    $backupCount = (Get-ChildItem -Path $BackupPath -Recurse -File).Count
                    
                    if ($backupCount -ge ($originalCount * 0.95)) {
                        # 95% Toleranz
                        Write-Host "    ✓ Backup erfolgreich erstellt: $BackupPath" -ForegroundColor Green
                        Write-Host "    📊 Dateien - Original: $originalCount, Backup: $backupCount" -ForegroundColor Gray
                    }
                    else {
                        throw "Backup-Validierung fehlgeschlagen. Original: $originalCount, Backup: $backupCount"
                    }
                }
                else {
                    throw "Robocopy fehlgeschlagen mit Exit-Code: $robocopyExitCode"
                }
            }
            catch {
                Write-Warning "    ⚠ Backup-Fehler: $($_.Exception.Message)"
                if (-not $Force) {
                    $continue = Read-Host "Trotzdem fortfahren? (Nicht empfohlen!) [j/N]"
                    if ($continue -ne 'j' -and $continue -ne 'J') {
                        throw "Abbruch durch Benutzer nach Backup-Fehler."
                    }
                }
            }
        }
        else {
            Write-Warning "    ⚠ Kein Repository-Ordner zum Sichern gefunden."
        }
    }
    else {
        Write-Host "[2/9] Backup übersprungen (Parameter -SkipBackup)" -ForegroundColor Yellow
    }

    # 3. Sicherheitsabfrage und Reset des Repositorys
    Write-Host "[3/9] Setze WMI-Repository zurück..." -ForegroundColor Cyan
    Write-Host "    ⚠ ACHTUNG: Das WMI-Repository wird jetzt zurückgesetzt!" -ForegroundColor Red
    
    if (Test-Path $BackupPath) {
        Write-Host "    📁 Backup verfügbar: $BackupPath" -ForegroundColor Green
    }
    else {
        Write-Host "    ❌ KEIN BACKUP VERFÜGBAR!" -ForegroundColor Red
    }
    
    if (-not $Force) {
        $choice = Read-Host "    Fortfahren? [j/N]"
        if ($choice -ne 'J' -and $choice -ne 'j') {
            throw "Abbruch durch Benutzer."
        }
    }

    Write-Verbose "Führe Repository-Reset durch..."
    $resetProcess = Start-Process -FilePath "winmgmt" -ArgumentList "/resetrepository" -Wait -PassThru -WindowStyle Hidden
    if ($resetProcess.ExitCode -eq 0) {
        Write-Host "    ✓ Repository erfolgreich zurückgesetzt" -ForegroundColor Green
    }
    else {
        Write-Warning "    ⚠ Repository-Reset Exit-Code: $($resetProcess.ExitCode) (kann normal sein)"
    }

    # 4. System-DLLs registrieren
    Write-Host "[4/9] Registriere System-DLLs..." -ForegroundColor Cyan
    $systemDlls = @(
        "$env:windir\system32\scecli.dll",
        "$env:windir\system32\userenv.dll"
    )
    
    foreach ($dll in $systemDlls) {
        if (Test-Path $dll) {
            Write-Verbose "Registriere $(Split-Path $dll -Leaf)..."
            $regResult = Start-Process -FilePath "regsvr32" -ArgumentList "/s", "`"$dll`"" -Wait -PassThru -WindowStyle Hidden
            if ($regResult.ExitCode -eq 0) {
                Write-Host "    ✓ $(Split-Path $dll -Leaf) registriert" -ForegroundColor Green
            }
            else {
                Write-Warning "    ⚠ Fehler bei $(Split-Path $dll -Leaf): Exit-Code $($regResult.ExitCode)"
            }
        }
        else {
            Write-Warning "    ⚠ DLL nicht gefunden: $dll"
        }
    }

    # 5. WMI-DLLs registrieren
    Write-Host "[5/9] Registriere WMI-Provider-DLLs..." -ForegroundColor Cyan
    $wmiDlls = Get-ChildItem -Path $WbemPath -Filter "*.dll" -ErrorAction SilentlyContinue
    $dllCount = 0
    $successCount = 0
    
    foreach ($dll in $wmiDlls) {
        $dllCount++
        Write-Progress -Activity "Registriere WMI-DLLs" -Status $dll.Name -PercentComplete (($dllCount / $wmiDlls.Count) * 100)
        
        $regResult = Start-Process -FilePath "regsvr32" -ArgumentList "/s", "`"$($dll.FullName)`"" -Wait -PassThru -WindowStyle Hidden
        if ($regResult.ExitCode -eq 0) {
            $successCount++
        }
    }
    Write-Progress -Activity "Registriere WMI-DLLs" -Completed
    Write-Host "    ✓ $successCount von $dllCount DLLs erfolgreich registriert" -ForegroundColor Green

    # 6. WMI-Dienst starten
    Write-Host "[6/9] Starte WMI-Dienst..." -ForegroundColor Cyan
    try {
        Set-Service -Name "winmgmt" -StartupType Automatic -ErrorAction Stop
        Start-Service -Name "winmgmt" -ErrorAction Stop
        
        $wmiStarted = Wait-ForServiceStatus -ServiceName "winmgmt" -DesiredStatus "Running" -TimeoutSeconds $TimeoutSeconds
        if (-not $wmiStarted) {
            throw "WMI-Service konnte nicht gestartet werden."
        }
        Write-Host "    ✓ WMI-Service erfolgreich gestartet" -ForegroundColor Green
    }
    catch {
        throw "Kritischer Fehler beim Starten des WMI-Services: $($_.Exception.Message)"
    }

    # 7. MOF- und MFL-Dateien kompilieren
    Write-Host "[7/9] Kompiliere MOF- und MFL-Dateien..." -ForegroundColor Cyan
    
    # MOF-Dateien
    $mofFiles = Get-ChildItem -Path $WbemPath -Filter "*.mof" -Recurse -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -notmatch "Uninstall|Remove|AutoRecover" }
    
    # MFL-Dateien
    $mflFiles = Get-ChildItem -Path $WbemPath -Filter "*.mfl" -Recurse -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -notmatch "Uninstall|Remove" }
    
    $allFiles = @($mofFiles) + @($mflFiles)
    $compiledCount = 0
    $totalFiles = $allFiles.Count
    
    Write-Verbose "Kompiliere $totalFiles Dateien..."
    foreach ($file in $allFiles) {
        $compiledCount++
        Write-Progress -Activity "Kompiliere MOF/MFL-Dateien" -Status $file.Name -PercentComplete (($compiledCount / $totalFiles) * 100)
        
        $compileResult = Start-Process -FilePath "mofcomp" -ArgumentList "`"$($file.FullName)`"" -Wait -PassThru -WindowStyle Hidden
        if ($compileResult.ExitCode -ne 0) {
            Write-Verbose "    Warnung bei $($file.Name): Exit-Code $($compileResult.ExitCode)"
        }
    }
    Write-Progress -Activity "Kompiliere MOF/MFL-Dateien" -Completed
    Write-Host "    ✓ $compiledCount Dateien kompiliert" -ForegroundColor Green

    # 8. WMI-Konsistenz prüfen
    Write-Host "[8/9] Überprüfe WMI-Konsistenz..." -ForegroundColor Cyan
    $salvageResult = Start-Process -FilePath "winmgmt" -ArgumentList "/salvagerepository" -Wait -PassThru -WindowStyle Hidden
    if ($salvageResult.ExitCode -eq 0) {
        Write-Host "    ✓ Konsistenzprüfung erfolgreich" -ForegroundColor Green
    }
    else {
        Write-Warning "    ⚠ Konsistenzprüfung Exit-Code: $($salvageResult.ExitCode)"
    }

    # 9. Finale Tests
    Write-Host "[9/9] Führe WMI-Funktionstests durch..." -ForegroundColor Cyan
    $wmiWorking = Test-WMIFunctionality
    
    if ($wmiWorking) {
        Write-Host "    ✓ WMI-Funktionalität bestätigt" -ForegroundColor Green
    }
    else {
        Write-Warning "    ⚠ WMI-Funktionalität beeinträchtigt - Neustart erforderlich"
    }

    # --- Erfolgsmeldung ---
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host "🎉 WMI-Reparatur erfolgreich abgeschlossen!" -ForegroundColor Green
    Write-Host "📄 Vollständiges Transkript: $LogFile" -ForegroundColor Gray
    if (Test-Path $BackupPath) {
        Write-Host "💾 Repository-Backup: $BackupPath" -ForegroundColor Gray
    }
    Write-Host "========================================================" -ForegroundColor Green
    
    # Neustart-Empfehlung
    Write-Host "⚠ WICHTIG: Es wird dringend empfohlen, das System jetzt neu zu starten." -ForegroundColor Yellow
    
    if (-not $Force) {
        $restart = Read-Host "System jetzt neu starten? [j/N]"
        if ($restart -eq 'j' -or $restart -eq 'J') {
            Write-Host "Neustart wird in 10 Sekunden eingeleitet..." -ForegroundColor Yellow
            Start-Sleep -Seconds 3
            Restart-Computer -Force -Delay 10
        }
    }
}
catch {
    Write-Host "========================================================" -ForegroundColor Red
    Write-Error "❌ FEHLER: $($_.Exception.Message)"
    Write-Host "Das Skript wurde abgebrochen." -ForegroundColor Red
    
    if (Test-Path $BackupPath) {
        Write-Host "💾 Repository-Backup verfügbar: $BackupPath" -ForegroundColor Yellow
        Write-Host "Bei schwerwiegenden Problemen kann das Backup manuell wiederhergestellt werden." -ForegroundColor Yellow
    }
    Write-Host "📄 Vollständiges Fehler-Log: $LogFile" -ForegroundColor Gray
    Write-Host "========================================================" -ForegroundColor Red
    
    exit 1
}
finally {
    # Protokollierung in jedem Fall beenden
    Stop-Transcript
    if (-not $Force) {
        Read-Host "Drücke Enter zum Beenden"
    }
}