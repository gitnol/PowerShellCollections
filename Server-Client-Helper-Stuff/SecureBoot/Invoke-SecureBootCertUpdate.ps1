#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Secure Boot UEFI CA 2023 - Update Manager

.DESCRIPTION
    Erkennt automatisch in welcher Phase des Updates sich das System befindet
    und fuehrt den naechsten Schritt aus. Gibt ein [PSCustomObject] zurueck,
    das den Ergebnisstatus beschreibt und fuer Multi-Machine-Rollouts geeignet ist.

    Unterstuetzt zwei Task-Mechanismen:
        ALT: SecureBootEncodeUEFI.exe (Tasks_Migrated, abgelaufener BootTrigger)
        NEU: COM-Handler TpmTasks.dll / SBServicing (aktueller Mechanismus)

    Phasen:
        0  - Vorpruefung
        1  - Snapshot bestaetigen
        2  - Ist-Zustand pruefen
        3  - Registry setzen + Task starten
        4  - Reboot 1 ausstehend
        5  - Nach Reboot 1: Zwischenzustand pruefen
        6  - Reboot 2 ausstehend
        7  - Endergebnis pruefen
        8  - Abgeschlossen
        99 - Warte-Phase (Script zu frueh nach Reboot 1 gestartet)

    HINWEIS fuer Remote-Betrieb: Wenn -AutoConfirm einen Reboot ausloest
    (Restart-Computer -Force), bricht die Remote-Session ab, bevor das
    Ergebnisobjekt zurueckgegeben wird. Empfehlung: Reboot-Phasen per
    Invoke-Command -AsJob behandeln oder Reboots separat planen.

.PARAMETER AutoConfirm
    Fuehrt ausstehende Schritte ohne Rueckfrage aus. Fuer Multi-Machine-Betrieb
    via Invoke-Command immer angeben.

.PARAMETER Status
    Gibt nur den aktuellen Status als PSCustomObject zurueck, ohne Aktion.

.PARAMETER Reset
    Setzt den gespeicherten Fortschritt zurueck (State-Datei und Registry-Key).
    Kombinierbar mit -AutoConfirm.

.EXAMPLE
    .\Invoke-SecureBootCertUpdate.ps1
    .\Invoke-SecureBootCertUpdate.ps1 -Status
    .\Invoke-SecureBootCertUpdate.ps1 -AutoConfirm
    .\Invoke-SecureBootCertUpdate.ps1 -Reset -AutoConfirm
#>
[CmdletBinding()]
param(
    [switch]$AutoConfirm,
    [switch]$Status,
    [switch]$Reset
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────────────────────────────────────
# Konstanten
# ─────────────────────────────────────────────────────────────────────────────
$REG_PATH      = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot"
$REG_NAME      = "AvailableUpdates"
$REG_VALUE     = 0x40
$REG_SVC_PATH  = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing"
$TASK_PATH     = "\Microsoft\Windows\PI\"
$TASK_NAME     = "Secure-Boot-Update"
$COM_CLSID     = "{5014B7C8-934E-4262-9816-887FA745A6C4}"
$STATE_FILE    = "$env:ProgramData\SecureBootUpdate\state.json"
$LOG_FILE      = "$env:ProgramData\SecureBootUpdate\update.log"
$CERT_PATTERN  = "Windows UEFI CA 2023"

$PHASE_NAMES = @{
    0  = 'Vorpruefung'
    1  = 'Snapshot bestaetigen'
    2  = 'Ist-Zustand pruefen'
    3  = 'Registry setzen und Task starten'
    4  = 'Reboot 1 ausstehend'
    5  = 'Nach Reboot 1: Zwischenzustand'
    6  = 'Reboot 2 ausstehend'
    7  = 'Endergebnis pruefen'
    8  = 'Abgeschlossen'
    99 = 'Warte auf Task nach Reboot 1'
}

# ─────────────────────────────────────────────────────────────────────────────
# Hilfsfunktionen
# ─────────────────────────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message)
    $dir = Split-Path $LOG_FILE
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $env:COMPUTERNAME | $Message"
    Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8
}

function Save-State {
    param([hashtable]$State)
    $dir = Split-Path $STATE_FILE
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $State | ConvertTo-Json | Set-Content -Path $STATE_FILE -Encoding UTF8
}

function Load-State {
    if (Test-Path $STATE_FILE) {
        try {
            $raw = Get-Content $STATE_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
            return @{
                Phase         = [int]$raw.Phase
                SnapshotDone  = [bool]$raw.SnapshotDone
                Reboot1Done   = [bool]$raw.Reboot1Done
                Reboot2Done   = [bool]$raw.Reboot2Done
                StartedAt     = $raw.StartedAt
                LastUpdated   = $raw.LastUpdated
            }
        }
        catch { return $null }
    }
    return $null
}

function Confirm-Action {
    param([string]$Question)
    if ($AutoConfirm) { return $true }
    do {
        $answer = Read-Host "$Question (J/N)"
    } until ($answer -match "^[JjNn]$")
    return $answer -match "^[Jj]$"
}

# ─────────────────────────────────────────────────────────────────────────────
# System-Zustandsermittlung
# ─────────────────────────────────────────────────────────────────────────────
function Get-SystemState {
    $state = @{
        SecureBootEnabled    = $false
        SecureBootUnknown    = $false
        UEFICA2023InDB       = $false
        UEFICA2023CheckError = $false
        RegKeyExists         = $false
        RegValue             = $null
        TaskExists           = $false
        TaskLastRunTime      = $null
        TaskLastResult       = $null
        TaskState            = $null
        IsWindows10          = $false
        BuildNumber          = 0
        ProductName          = ""
        RebootPending        = $false
        LastBootTime         = $null
        TaskRanAfterBoot     = $false
        ServicingCapable     = $null
        ServicingStatus      = ""
        ServicingError       = 0
        ComHandlerRegistered = $false
        OldTaskMigrated      = $false
    }

    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) { $state.LastBootTime = $os.LastBootUpTime }
    }
    catch { }

    try {
        $state.SecureBootEnabled = Confirm-SecureBootUEFI
    }
    catch { $state.SecureBootUnknown = $true }

    try {
        $db = Get-SecureBootUEFI -Name db -ErrorAction Stop
        $dbStr = [System.Text.Encoding]::ASCII.GetString($db.bytes)
        $state.UEFICA2023InDB = $dbStr -match [regex]::Escape($CERT_PATTERN)
    }
    catch { $state.UEFICA2023CheckError = $true }

    try {
        $regVal = Get-ItemProperty -Path $REG_PATH -Name $REG_NAME -ErrorAction SilentlyContinue
        if ($null -ne $regVal) {
            $state.RegKeyExists = $true
            $state.RegValue     = $regVal.$REG_NAME
        }
    }
    catch { }

    try {
        $task = Get-ScheduledTask -TaskName $TASK_NAME -TaskPath $TASK_PATH -ErrorAction SilentlyContinue
        if ($task) {
            $state.TaskExists = $true
            $state.TaskState  = $task.State
            $info = $task | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
            if ($info) {
                $state.TaskLastRunTime = $info.LastRunTime
                $state.TaskLastResult  = $info.LastTaskResult
                if ($state.LastBootTime -and $info.LastRunTime -gt $state.LastBootTime) {
                    $state.TaskRanAfterBoot = $true
                }
            }
        }
    }
    catch { }

    try {
        $osInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $build  = [int]$osInfo.CurrentBuildNumber
        $state.BuildNumber = $build
        $state.IsWindows10 = ($build -lt 22000)
        $pname = $osInfo.ProductName
        if ($build -ge 22000) { $pname = $pname -replace "Windows 10", "Windows 11" }
        $state.ProductName = $pname
    }
    catch { }

    $pendingKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    )
    foreach ($key in $pendingKeys) {
        if (Test-Path $key) {
            if ($key -like "*Session Manager*") {
                $val = Get-ItemProperty -Path $key -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
                if ($val) { $state.RebootPending = $true }
            }
            else { $state.RebootPending = $true }
        }
    }

    try {
        $svc = Get-ItemProperty -Path $REG_SVC_PATH -ErrorAction SilentlyContinue
        if ($svc) {
            $state.ServicingCapable = $svc.WindowsUEFICA2023Capable
            $state.ServicingStatus  = $svc.UEFICA2023Status
            $state.ServicingError   = $svc.UEFICA2023Error
        }
    }
    catch { }

    try {
        $dll = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\CLSID\$COM_CLSID\InprocServer32" `
            -ErrorAction SilentlyContinue
        if ($dll) {
            $dllPath = $dll."(Default)"
            if ($dllPath -and (Test-Path $dllPath)) {
                $state.ComHandlerRegistered = $true
            }
        }
    }
    catch { }

    $migratedPath = "$env:WINDIR\System32\Tasks_Migrated\Microsoft\Windows\PI\SecureBootEncodeUEFI"
    $state.OldTaskMigrated = (Test-Path $migratedPath)

    return $state
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase bestimmen
# ─────────────────────────────────────────────────────────────────────────────
function Get-CurrentPhase {
    param($SysState, $SavedState)

    if ($SysState.UEFICA2023InDB -and -not $SysState.RebootPending) { return 8 }
    if ($SysState.UEFICA2023InDB -and $SysState.RebootPending)      { return 6 }

    if ($SysState.RegKeyExists -and $SysState.RegValue -eq $REG_VALUE) {
        if ($null -ne $SavedState -and $SavedState.Reboot1Done -and -not $SysState.TaskRanAfterBoot) {
            return 99
        }
        return 4
    }

    if ($SysState.TaskRanAfterBoot -and -not $SysState.UEFICA2023InDB) { return 6 }

    if ($SysState.TaskExists -and $SysState.TaskLastRunTime) {
        if ($SysState.TaskLastRunTime -gt (Get-Date).AddDays(-2) -and -not $SysState.UEFICA2023InDB) {
            return 6
        }
    }

    if ($null -ne $SavedState) {
        if ($SavedState.Reboot1Done -and -not $SavedState.Reboot2Done) { return 6 }
        if ($SavedState.Phase -ge 3 -and -not $SavedState.Reboot1Done) { return 4 }
        if ($SavedState.SnapshotDone -and $SavedState.Phase -lt 3)     { return 3 }
        if ($SavedState.Phase -eq 1)                                    { return 2 }
    }

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Schritt-Ausfuehrung — gibt @{ Action; Success; Message; RebootRequired } zurueck
# ─────────────────────────────────────────────────────────────────────────────
function Invoke-Phase {
    param([int]$Phase, $SysState, $SavedState)

    switch ($Phase) {

        # ── Phase 0: Vorpruefung ──────────────────────────────────────────
        0 {
            Write-Verbose "Phase 0 – Vorpruefung"

            if (-not $SysState.TaskExists) {
                Write-Log "FEHLER: Scheduled Task nicht gefunden auf $env:COMPUTERNAME"
                return @{
                    Action         = 'Vorpruefung fehlgeschlagen'
                    Success        = $false
                    Message        = "Scheduled Task '$TASK_NAME' nicht gefunden. Windows Updates einspielen."
                    RebootRequired = $false
                }
            }

            if ($SysState.SecureBootUnknown -or -not $SysState.SecureBootEnabled) {
                Write-Verbose "WARNUNG: Secure Boot nicht aktiv oder nicht erkennbar – Update hat keinen Effekt."
            }

            $mechanism = if ($SysState.ComHandlerRegistered) {
                'COM-Handler TpmTasks.dll (aktuell)'
            } else {
                'SecureBootEncodeUEFI.exe (alt, 2 Reboots erforderlich)'
            }
            Write-Verbose "Task-Mechanismus: $mechanism"

            if ($null -ne $SysState.ServicingCapable -and $SysState.ServicingCapable -eq 0) {
                Write-Verbose "WindowsUEFICA2023Capable = 0 – Workaround wird in Phase 3 angewendet."
            }

            $newState = @{
                Phase        = 1
                SnapshotDone = $false
                Reboot1Done  = $false
                Reboot2Done  = $false
                StartedAt    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                LastUpdated  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            Save-State $newState
            Write-Log "Phase 0 abgeschlossen – warte auf Snapshot-Bestaetigung"

            return @{
                Action         = 'Vorpruefung abgeschlossen'
                Success        = $true
                Message        = "Naechster Schritt: Snapshot erstellen (PRE_SecureBoot_Cert_Update_$(Get-Date -Format 'yyyyMMdd')), dann Script erneut starten."
                RebootRequired = $false
            }
        }

        # ── Phase 1: Snapshot bestaetigen ────────────────────────────────
        1 {
            Write-Verbose "Phase 1 – Snapshot bestaetigen"

            if (Confirm-Action "Snapshot wurde erstellt und ist sichtbar?") {
                $SavedState.SnapshotDone = $true
                $SavedState.Phase        = 2
                $SavedState.LastUpdated  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                Save-State $SavedState
                Write-Log "Phase 1 abgeschlossen – Snapshot bestaetigt"
                return Invoke-Phase -Phase 2 -SysState $SysState -SavedState $SavedState
            }
            else {
                return @{
                    Action         = 'Snapshot ausstehend'
                    Success        = $true
                    Message        = 'Snapshot erstellen (Quiesce: Ja, Memory: Nein) und Script danach erneut starten.'
                    RebootRequired = $false
                }
            }
        }

        # ── Phase 2: Ist-Zustand pruefen ─────────────────────────────────
        2 {
            Write-Verbose "Phase 2 – Ist-Zustand Secure Boot DB"

            if ($SysState.UEFICA2023CheckError) {
                Write-Verbose "WARNUNG: Pruefung nicht moeglich (kein UEFI?)."
            }
            elseif ($SysState.UEFICA2023InDB) {
                $SavedState.Phase       = 8
                $SavedState.Reboot1Done = $true
                $SavedState.Reboot2Done = $true
                $SavedState.LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                Save-State $SavedState
                Write-Log "Phase 2: UEFI CA 2023 bereits vorhanden – kein Update noetig"
                return @{
                    Action         = 'Kein Update erforderlich'
                    Success        = $true
                    Message        = "'$CERT_PATTERN' ist bereits in der Secure Boot DB."
                    RebootRequired = $false
                }
            }

            Write-Verbose "'$CERT_PATTERN' nicht in DB – Update erforderlich."

            if (Confirm-Action "Mit Update fortfahren (Registry setzen + Task starten)?") {
                $SavedState.Phase       = 3
                $SavedState.LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                Save-State $SavedState
                return Invoke-Phase -Phase 3 -SysState $SysState -SavedState $SavedState
            }
            else {
                return @{
                    Action         = 'Update verschoben'
                    Success        = $true
                    Message        = 'Update durch Benutzer nicht bestaetigt. Script erneut starten um fortzufahren.'
                    RebootRequired = $false
                }
            }
        }

        # ── Phase 3: Registry + Task ──────────────────────────────────────
        3 {
            Write-Verbose "Phase 3 – Registry setzen + Task starten"

            if ($null -ne $SysState.ServicingCapable -and $SysState.ServicingCapable -eq 0) {
                Write-Verbose "WindowsUEFICA2023Capable = 0 – Workaround wird angewendet."
                try {
                    if (-not (Test-Path $REG_SVC_PATH)) { New-Item -Path $REG_SVC_PATH -Force | Out-Null }
                    Set-ItemProperty -Path $REG_SVC_PATH -Name "WindowsUEFICA2023Capable" `
                        -Value 1 -Type DWord -ErrorAction Stop
                    Write-Log "Phase 3: Capable-Workaround angewendet (0 -> 1)"
                }
                catch {
                    Write-Verbose "WARNUNG: Capable konnte nicht gesetzt werden: $_"
                }
            }

            try {
                if (-not (Test-Path $REG_PATH)) { New-Item -Path $REG_PATH -Force | Out-Null }
                Set-ItemProperty -Path $REG_PATH -Name $REG_NAME -Value $REG_VALUE -Type DWord -ErrorAction Stop
                $verify = Get-ItemProperty -Path $REG_PATH -Name $REG_NAME -ErrorAction Stop
                $hexSet = "0x{0:X2}" -f $verify.$REG_NAME
                Write-Verbose "Registry gesetzt: $REG_NAME = $hexSet"
                Write-Log "Phase 3: Registry gesetzt – $REG_NAME = $hexSet"
            }
            catch {
                Write-Log "FEHLER Phase 3 Registry: $_"
                return @{
                    Action         = 'Registry-Fehler'
                    Success        = $false
                    Message        = "Fehler beim Setzen der Registry: $_"
                    RebootRequired = $false
                }
            }

            try {
                Start-ScheduledTask -TaskName $TASK_NAME -TaskPath $TASK_PATH -ErrorAction Stop
                $waitSec = if ($SysState.ComHandlerRegistered) { 60 } else { 3 }
                Write-Verbose "Warte $waitSec Sekunden auf Task-Ausfuehrung..."
                Start-Sleep -Seconds $waitSec
                $taskInfo = Get-ScheduledTask -TaskName $TASK_NAME -TaskPath $TASK_PATH
                Write-Verbose "Task gestartet – Status: $($taskInfo.State)"
                Write-Log "Phase 3: Task gestartet – Status: $($taskInfo.State)"
            }
            catch {
                Write-Log "FEHLER Phase 3 Task: $_"
                return @{
                    Action         = 'Task-Fehler'
                    Success        = $false
                    Message        = "Fehler beim Starten des Tasks: $_"
                    RebootRequired = $false
                }
            }

            if ($SysState.ComHandlerRegistered) {
                Write-Verbose "Pruefe ob Zertifikat direkt eingetragen wurde (COM-Handler)..."
                try {
                    $dbNow = Get-SecureBootUEFI -Name db -ErrorAction SilentlyContinue
                    $inDB  = $false
                    if ($dbNow) {
                        $dbStr = [System.Text.Encoding]::ASCII.GetString($dbNow.bytes)
                        $inDB  = $dbStr -match [regex]::Escape($CERT_PATTERN)
                    }

                    if ($inDB) {
                        if ($null -ne $SavedState) {
                            $SavedState.Phase       = 7
                            $SavedState.Reboot1Done = $true
                            $SavedState.Reboot2Done = $true
                            $SavedState.LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                            Save-State $SavedState
                        }
                        Write-Log "Phase 3: COM-Handler erfolgreich – UEFI CA 2023 in DB"
                        return @{
                            Action         = 'COM-Handler erfolgreich'
                            Success        = $true
                            Message        = "'$CERT_PATTERN' direkt eingetragen. Power Off -> Power On empfohlen um NVRAM dauerhaft zu verankern."
                            RebootRequired = $true
                        }
                    }
                    else {
                        $svcNow = Get-ItemProperty -Path $REG_SVC_PATH -ErrorAction SilentlyContinue
                        if ($svcNow) {
                            Write-Verbose "Servicing: Capable=$($svcNow.WindowsUEFICA2023Capable) | Status=$($svcNow.UEFICA2023Status)"
                        }
                    }
                }
                catch {
                    Write-Verbose "COM-Handler-Pruefung nicht moeglich: $_"
                }
            }

            $SavedState.Phase       = 4
            $SavedState.LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            Save-State $SavedState
            Write-Log "Phase 3 abgeschlossen – warte auf Reboot"

            if (Confirm-Action "System jetzt neu starten (Reboot 1)?") {
                Write-Verbose "System startet in 10 Sekunden neu..."
                Start-Sleep -Seconds 10
                $SavedState.Reboot1Done = $true
                $SavedState.Phase       = 5
                $SavedState.LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                Save-State $SavedState
                Write-Log "Reboot 1 wird durchgefuehrt"
                Restart-Computer -Force
            }

            return @{
                Action         = 'Registry gesetzt, Task gestartet'
                Success        = $true
                Message        = 'Reboot 1 erforderlich. Script nach dem Reboot erneut starten.'
                RebootRequired = $true
            }
        }

        # ── Phase 4: Reboot 1 ausstehend ─────────────────────────────────
        4 {
            Write-Verbose "Phase 4 – Reboot 1 / Power Off + Power On"

            if (Confirm-Action "System jetzt neu starten (Reboot 1)?") {
                Write-Verbose "System startet in 10 Sekunden neu..."
                Start-Sleep -Seconds 10
                if ($null -ne $SavedState) {
                    $SavedState.Reboot1Done = $true
                    $SavedState.Phase       = 5
                    $SavedState.LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    Save-State $SavedState
                }
                Write-Log "Reboot 1 wird durchgefuehrt"
                Restart-Computer -Force
            }

            return @{
                Action         = 'Reboot 1 ausstehend'
                Success        = $true
                Message        = 'Reboot 1 noch nicht durchgefuehrt. Script nach dem Reboot erneut starten.'
                RebootRequired = $true
            }
        }

        # ── Phase 5: Nach Reboot 1 ────────────────────────────────────────
        5 {
            Write-Verbose "Phase 5 – Zwischenzustand nach Reboot 1"

            $regNow = Get-ItemProperty -Path $REG_PATH -Name $REG_NAME -ErrorAction SilentlyContinue
            if ($null -eq $regNow) {
                Write-Verbose "Registry-Key wurde vom Task zurueckgesetzt."
            }
            else {
                Write-Verbose "Registry-Key noch vorhanden: $REG_NAME = 0x$("{0:X2}" -f $regNow.$REG_NAME)"
            }

            $taskInfo = Get-ScheduledTaskInfo -TaskName $TASK_NAME -TaskPath $TASK_PATH -ErrorAction SilentlyContinue
            if ($taskInfo) {
                Write-Verbose "Task zuletzt: $($taskInfo.LastRunTime) | Ergebnis: 0x$("{0:X8}" -f $taskInfo.LastTaskResult)"
            }

            $svcNow = Get-ItemProperty -Path $REG_SVC_PATH -ErrorAction SilentlyContinue
            if ($svcNow) {
                Write-Verbose "Servicing: Capable=$($svcNow.WindowsUEFICA2023Capable) | Status=$($svcNow.UEFICA2023Status)"
            }

            if ($null -ne $SavedState) {
                $SavedState.Phase       = 6
                $SavedState.Reboot1Done = $true
                $SavedState.LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                Save-State $SavedState
            }

            if (Confirm-Action "System jetzt neu starten (Reboot 2)?") {
                Write-Verbose "System startet in 10 Sekunden neu..."
                Start-Sleep -Seconds 10
                if ($null -ne $SavedState) {
                    $SavedState.Reboot2Done = $true
                    $SavedState.Phase       = 7
                    $SavedState.LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    Save-State $SavedState
                }
                Write-Log "Reboot 2 wird durchgefuehrt"
                Restart-Computer -Force
            }

            return @{
                Action         = 'Zwischenzustand nach Reboot 1 geprueft'
                Success        = $true
                Message        = 'Reboot 2 / Power Off + Power On erforderlich. Script nach dem Reboot erneut starten.'
                RebootRequired = $true
            }
        }

        # ── Phase 6: Reboot 2 ausstehend ─────────────────────────────────
        6 {
            Write-Verbose "Phase 6 – Reboot 2 / Power Off + Power On"

            if (Confirm-Action "System jetzt neu starten (Reboot 2)?") {
                Write-Verbose "System startet in 10 Sekunden neu..."
                Start-Sleep -Seconds 10
                if ($null -ne $SavedState) {
                    $SavedState.Reboot2Done = $true
                    $SavedState.Phase       = 7
                    $SavedState.LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    Save-State $SavedState
                }
                Write-Log "Reboot 2 wird durchgefuehrt"
                Restart-Computer -Force
            }

            return @{
                Action         = 'Reboot 2 ausstehend'
                Success        = $true
                Message        = 'Reboot 2 / Power Off + Power On erforderlich. Script nach dem Reboot erneut starten.'
                RebootRequired = $true
            }
        }

        # ── Phase 7: Endergebnis pruefen ──────────────────────────────────
        7 {
            Write-Verbose "Phase 7 – Endergebnis pruefen"

            if (-not $SysState.UEFICA2023InDB) {
                Write-Log "FEHLER Phase 7: UEFI CA 2023 nicht in DB"
                return @{
                    Action         = 'Verifikation fehlgeschlagen'
                    Success        = $false
                    Message        = "'$CERT_PATTERN' ist NICHT in der Secure Boot DB. Moegliche Ursachen: kein Power Cycle, Secure Boot deaktiviert, Capable=0-Workaround nicht angewendet, Registry nicht korrekt gesetzt. Phase 3 erneut ausfuehren."
                    RebootRequired = $false
                }
            }

            $svcFinal = Get-ItemProperty -Path $REG_SVC_PATH -ErrorAction SilentlyContinue
            if ($svcFinal) {
                Write-Verbose "Servicing-Status: $($svcFinal.UEFICA2023Status) | Capable: $($svcFinal.WindowsUEFICA2023Capable)"
            }

            $regNow = Get-ItemProperty -Path $REG_PATH -Name $REG_NAME -ErrorAction SilentlyContinue
            if ($null -ne $regNow) {
                Write-Verbose "Registry-Key noch vorhanden: $REG_NAME = 0x$("{0:X2}" -f $regNow.$REG_NAME) (Residualwert, kein Handlungsbedarf)"
            }

            if ($null -ne $SavedState) {
                $SavedState.Phase       = 8
                $SavedState.Reboot2Done = $true
                $SavedState.LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                Save-State $SavedState
            }
            Write-Log "Phase 7 abgeschlossen – Update erfolgreich. UEFI CA 2023 in DB."

            $msg = "'$CERT_PATTERN' erfolgreich in Secure Boot DB eingetragen (gueltig bis ca. 2033)."
            $msg += if ($SysState.RebootPending) { " Reboot noch ausstehend laut System." } else { " Kein weiterer Reboot erforderlich." }

            return @{
                Action         = 'Update abgeschlossen'
                Success        = $true
                Message        = $msg
                RebootRequired = $SysState.RebootPending
            }
        }

        # ── Phase 8: Abgeschlossen ────────────────────────────────────────
        8 {
            Write-Log "Status-Check: System bereits abgeschlossen – kein Handlungsbedarf"
            return @{
                Action         = 'Kein Handlungsbedarf'
                Success        = $true
                Message        = "'$CERT_PATTERN' ist in der Secure Boot DB. Das System ist vollstaendig aktualisiert."
                RebootRequired = $false
            }
        }

        # ── Phase 99: Warte-Phase ─────────────────────────────────────────
        99 {
            Write-Verbose "Phase 99 – Script zu frueh nach Reboot 1 gestartet, Task noch nicht gelaufen."

            $warteMax = 300
            $interval = 15
            $waited   = 0

            if (Confirm-Action "Automatisch warten bis Task gelaufen ist (max. 5 Minuten)?") {
                while ($waited -lt $warteMax) {
                    Write-Verbose "Warte... ($waited/$warteMax Sekunden)"
                    Start-Sleep -Seconds $interval
                    $waited += $interval

                    $taskInfo = Get-ScheduledTaskInfo -TaskName $TASK_NAME -TaskPath $TASK_PATH -ErrorAction SilentlyContinue
                    if ($taskInfo -and $SysState.LastBootTime -and $taskInfo.LastRunTime -gt $SysState.LastBootTime) {
                        Write-Log "Phase 99: Task nach Warten erkannt – Script neu starten"
                        return @{
                            Action         = 'Task nach Warten erkannt'
                            Success        = $true
                            Message        = "Task hat nach dem Boot gelaufen ($($taskInfo.LastRunTime.ToString('HH:mm:ss'))). Script erneut starten fuer naechsten Schritt."
                            RebootRequired = $false
                        }
                    }
                }

                Write-Log "Phase 99: Timeout – Task hat nicht reagiert"
                return @{
                    Action         = 'Timeout beim Warten auf Task'
                    Success        = $false
                    Message        = "Task hat in $warteMax Sekunden nicht reagiert. Manuell pruefen: Get-ScheduledTaskInfo -TaskName '$TASK_NAME' -TaskPath '$TASK_PATH'"
                    RebootRequired = $false
                }
            }
            else {
                return @{
                    Action         = 'Warte auf Task'
                    Success        = $true
                    Message        = "Task noch nicht nach Reboot 1 gelaufen. 2-5 Minuten warten und Script erneut ausfuehren."
                    RebootRequired = $false
                }
            }
        }

        default {
            return @{
                Action         = 'Unbekannte Phase'
                Success        = $false
                Message        = "Phase $Phase ist nicht definiert."
                RebootRequired = $false
            }
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Reset-Funktion
# ─────────────────────────────────────────────────────────────────────────────
function Invoke-Reset {
    Write-Verbose "RESET: Gespeicherten Fortschritt loeschen"

    if (-not (Confirm-Action "Wirklich zuruecksetzen (State-Datei und Registry-Key loeschen)?")) {
        return @{ Action = 'Reset abgebrochen'; Success = $true; Message = 'Reset durch Benutzer abgebrochen.' }
    }

    $messages = [System.Collections.Generic.List[string]]::new()

    if (Test-Path $STATE_FILE) {
        Remove-Item $STATE_FILE -Force
        $messages.Add("State-Datei geloescht.")
    }
    $reg = Get-ItemProperty -Path $REG_PATH -Name $REG_NAME -ErrorAction SilentlyContinue
    if ($reg) {
        Remove-ItemProperty -Path $REG_PATH -Name $REG_NAME -ErrorAction SilentlyContinue
        $messages.Add("Registry-Key '$REG_NAME' entfernt.")
    }
    Write-Log "RESET durchgefuehrt"

    return @{
        Action  = 'Reset durchgefuehrt'
        Success = $true
        Message = if ($messages.Count -gt 0) { $messages -join ' ' } else { 'Nichts zu loeschen.' }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Hilfsfunktion: PSCustomObject aus Systemzustand + Ergebnis bauen
# ─────────────────────────────────────────────────────────────────────────────
function New-ResultObject {
    param($SysState, [int]$Phase, [hashtable]$PhaseResult)

    [PSCustomObject]@{
        ComputerName      = $env:COMPUTERNAME
        Timestamp         = (Get-Date)
        Phase             = $Phase
        PhaseName         = $PHASE_NAMES[$Phase]
        ActionTaken       = $PhaseResult.Action
        Success           = $PhaseResult.Success
        Message           = $PhaseResult.Message
        RebootRequired    = $PhaseResult.RebootRequired
        SecureBootEnabled = $SysState.SecureBootEnabled
        UEFICA2023InDB    = $SysState.UEFICA2023InDB
        TaskExists        = $SysState.TaskExists
        TaskMechanism     = if ($SysState.ComHandlerRegistered) { 'COM-Handler (TpmTasks.dll)' } else { 'SecureBootEncodeUEFI.exe' }
        ServicingStatus   = $SysState.ServicingStatus
        ServicingCapable  = $SysState.ServicingCapable
        RebootPending     = $SysState.RebootPending
        BuildNumber       = $SysState.BuildNumber
        ProductName       = $SysState.ProductName
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Hauptprogramm
# ─────────────────────────────────────────────────────────────────────────────
Write-Verbose "Ermittle System-Zustand auf $env:COMPUTERNAME..."
$sysState   = Get-SystemState
$savedState = Load-State
$phase      = Get-CurrentPhase -SysState $sysState -SavedState $savedState

Write-Verbose "Phase: $phase ($($PHASE_NAMES[$phase]))"
Write-Verbose "Secure Boot: $(if ($sysState.SecureBootEnabled) { 'Aktiv' } elseif ($sysState.SecureBootUnknown) { 'Unbekannt' } else { 'Inaktiv' })"
Write-Verbose "UEFI CA 2023 in DB: $($sysState.UEFICA2023InDB)"
Write-Verbose "Task vorhanden: $($sysState.TaskExists) | Mechanismus: $(if ($sysState.ComHandlerRegistered) { 'COM-Handler' } else { 'EXE' })"

if ($Status) {
    Write-Log "Status-Abfrage – Phase $phase"
    New-ResultObject -SysState $sysState -Phase $phase -PhaseResult @{
        Action         = 'Status'
        Success        = $true
        Message        = 'Status-Modus – keine Aktion ausgefuehrt.'
        RebootRequired = $false
    }
    return
}

if ($Reset) {
    $result = Invoke-Reset
    New-ResultObject -SysState $sysState -Phase $phase -PhaseResult $result
    return
}

$result = Invoke-Phase -Phase $phase -SysState $sysState -SavedState $savedState
Write-Log "Script beendet – Phase $phase auf $env:COMPUTERNAME"
New-ResultObject -SysState $sysState -Phase $phase -PhaseResult $result
