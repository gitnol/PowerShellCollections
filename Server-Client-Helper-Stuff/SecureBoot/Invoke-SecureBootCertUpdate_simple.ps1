#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Einmaliges Einleiten des Secure Boot 2023-Zertifikat-Updates (einfache Variante).
.DESCRIPTION
    Prüft zunächst ob das Windows UEFI CA 2023 Zertifikat bereits in der UEFI-DB vorhanden ist.
    Falls nicht: Registry-Wert setzen, Scheduled Task starten, Ergebnis zurückgeben.
    Auf neueren Systemen (COM-Handler TpmTasks.dll) wird das Zertifikat direkt eingetragen.
    Auf älteren Systemen (SecureBootEncodeUEFI.exe) ist ein Neustart erforderlich.

    Für den vollständigen phasengesteuerten Update-Prozess mit State-Tracking:
    → Invoke-SecureBootCertUpdate.ps1

.PARAMETER AutoConfirm
    Unterdrückt die interaktive Neustart-Abfrage. Für Remote-Betrieb via Invoke-Command
    immer angeben, da Read-Host in Remote-Sessions hängt.

.EXAMPLE
    .\Invoke-SecureBootCertUpdate_simple.ps1
    .\Invoke-SecureBootCertUpdate_simple.ps1 -AutoConfirm
    Invoke-Command -ComputerName SERVER01 -ScriptBlock { & $using:script -AutoConfirm }
#>
[CmdletBinding()]
param(
    [switch]$AutoConfirm
)

# ─────────────────────────────────────────────────────────────────────────────
# Konstanten
# ─────────────────────────────────────────────────────────────────────────────
$REG_PATH   = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot"
$REG_NAME   = "AvailableUpdates"
# Zusammensetzung 0x5944:
#   0x0004 = KEK: Microsoft Corporation KEK 2K CA 2023 eintragen
#   0x0040 = DB:  Windows UEFI CA 2023 eintragen  ← Primärziel
#   0x0100 = Bootmgr: Boot Manager mit 2023-Signatur aktualisieren
#   0x0800 = DB:  Microsoft Option ROM UEFI CA 2023 (konditional via 0x4000)
#   0x1000 = DB:  Microsoft UEFI CA 2023 (konditional via 0x4000)
#   0x4000 = Modifier: 0x0800/0x1000 nur eintragen wenn UEFI CA 2011 bereits in DB
$REG_VALUE  = 0x5944
$TASK_PATH  = "\Microsoft\Windows\PI\"
$TASK_NAME  = "Secure-Boot-Update"
$CERT_SUBJECT = 'Windows UEFI CA 2023'
$COM_CLSID  = "{5014B7C8-934E-4262-9816-887FA745A6C4}"

# ─────────────────────────────────────────────────────────────────────────────
# X.509-Zertifikat korrekt aus EFI_SIGNATURE_LIST parsen
# ─────────────────────────────────────────────────────────────────────────────
function Test-UEFICA2023InDb {
    param([byte[]]$DbBytes)
    if (-not $DbBytes -or $DbBytes.Length -lt 28) { return $false }
    $x509Guid = [System.Guid]::new('a5c059a1-94e4-4aa7-87b5-ab155c2bf072')
    $pos = 0
    while ($pos + 28 -le $DbBytes.Length) {
        $listGuid = [System.Guid]::new([byte[]]$DbBytes[$pos..($pos + 15)])
        $listSize = [BitConverter]::ToUInt32($DbBytes, $pos + 16)
        $hdrSize  = [BitConverter]::ToUInt32($DbBytes, $pos + 20)
        $sigSize  = [BitConverter]::ToUInt32($DbBytes, $pos + 24)
        if ($listSize -eq 0 -or $sigSize -le 16) { break }
        if ($listGuid -eq $x509Guid) {
            $entry = $pos + 28 + [int]$hdrSize
            $end   = $pos + [int]$listSize
            while ($entry + [int]$sigSize -le $end) {
                try {
                    $certBytes = $DbBytes[($entry + 16)..($entry + [int]$sigSize - 1)]
                    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]$certBytes)
                    if ($cert.Subject -match [regex]::Escape($CERT_SUBJECT)) { return $true }
                }
                catch { }
                $entry += [int]$sigSize
            }
        }
        $pos += [int]$listSize
    }
    return $false
}

function Suspend-BitLockerForUpdate {
    $result = @{ Suspended = $false; Volumes = @(); Message = '' }
    try {
        $activeVols = Get-BitLockerVolume -ErrorAction Stop |
            Where-Object { $_.ProtectionStatus -eq 'On' }
        if (-not $activeVols) {
            $result.Message = 'Kein aktives BitLocker-Volume gefunden.'
            return $result
        }
        foreach ($vol in $activeVols) {
            Suspend-BitLocker -MountPoint $vol.MountPoint -RebootCount 2 -ErrorAction Stop
            $result.Volumes += $vol.MountPoint
        }
        $result.Suspended = $true
        $result.Message   = "BitLocker ausgesetzt (RebootCount=2) auf: $($result.Volumes -join ', ')"
    }
    catch {
        $result.Message = "BitLocker-Suspend fehlgeschlagen: $_"
    }
    return $result
}

function New-Result {
    param(
        [string]$Status,
        [string]$Action,
        [string]$Message,
        [bool]$RebootRequired = $false,
        [bool]$BitLockerSuspended = $false
    )
    [PSCustomObject]@{
        ComputerName       = $env:COMPUTERNAME
        Timestamp          = Get-Date
        Status             = $Status
        Action             = $Action
        Message            = $Message
        RebootRequired     = $RebootRequired
        BitLockerSuspended = $BitLockerSuspended
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Secure Boot Status prüfen
# ─────────────────────────────────────────────────────────────────────────────
$secureBootEnabled = $false
try {
    $secureBootEnabled = Confirm-SecureBootUEFI
}
catch { }

if (-not $secureBootEnabled) {
    New-Result -Status 'SKIPPED' -Action 'Keine Aktion' `
        -Message 'Secure Boot ist nicht aktiv oder nicht erkennbar. Update hätte keinen Effekt.'
    return
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Pre-Check: Zertifikat bereits vorhanden?
# ─────────────────────────────────────────────────────────────────────────────
try {
    $db = Get-SecureBootUEFI -Name db -ErrorAction Stop
    if (Test-UEFICA2023InDb -DbBytes $db.bytes) {
        New-Result -Status 'OK' -Action 'Keine Aktion' `
            -Message "'$CERT_SUBJECT' ist bereits in der Secure Boot DB. Kein Update erforderlich."
        return
    }
}
catch {
    New-Result -Status 'FEHLER' -Action 'Abgebrochen' `
        -Message "Secure Boot DB konnte nicht gelesen werden: $_"
    return
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Task-Existenz prüfen
# ─────────────────────────────────────────────────────────────────────────────
$task = Get-ScheduledTask -TaskName $TASK_NAME -TaskPath $TASK_PATH -ErrorAction SilentlyContinue
if (-not $task) {
    New-Result -Status 'FEHLER' -Action 'Abgebrochen' `
        -Message "Scheduled Task '$TASK_NAME' nicht gefunden. Aktuelle Windows Updates einspielen und erneut versuchen."
    return
}

# COM-Handler vorhanden? Entscheidet über Wartezeit und Sofortverifikation
$comHandlerRegistered = $false
try {
    $dll = Get-ItemProperty "HKLM:\SOFTWARE\Classes\CLSID\$COM_CLSID\InprocServer32" -ErrorAction SilentlyContinue
    if ($dll -and $dll.'(Default)' -and (Test-Path $dll.'(Default)')) {
        $comHandlerRegistered = $true
    }
}
catch { }

# ─────────────────────────────────────────────────────────────────────────────
# 4. BitLocker aussetzen (PCR 7 ändert sich durch DB-Update → sonst Recovery)
# ─────────────────────────────────────────────────────────────────────────────
$blResult = Suspend-BitLockerForUpdate
if ($blResult.Suspended) {
    Write-Verbose "BitLocker: $($blResult.Message)"
} else {
    Write-Warning "BitLocker-Suspend: $($blResult.Message) – Recovery-Key bereithalten falls BitLocker aktiv ist!"
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. Registry setzen
# ─────────────────────────────────────────────────────────────────────────────
Write-Verbose "Setze $REG_NAME = 0x$("{0:X4}" -f $REG_VALUE)"
try {
    if (-not (Test-Path $REG_PATH)) { New-Item -Path $REG_PATH -Force | Out-Null }
    Set-ItemProperty -Path $REG_PATH -Name $REG_NAME -Value $REG_VALUE -Type DWord -ErrorAction Stop
}
catch {
    New-Result -Status 'FEHLER' -Action 'Registry-Fehler' `
        -Message "Fehler beim Schreiben der Registry: $_" `
        -BitLockerSuspended $blResult.Suspended
    return
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. Task starten
# ─────────────────────────────────────────────────────────────────────────────
Write-Verbose "Starte Task '$TASK_NAME'..."
try {
    Start-ScheduledTask -TaskName $TASK_NAME -TaskPath $TASK_PATH -ErrorAction Stop
}
catch {
    New-Result -Status 'FEHLER' -Action 'Task-Fehler' `
        -Message "Fehler beim Starten des Scheduled Tasks: $_" `
        -BitLockerSuspended $blResult.Suspended
    return
}

# ─────────────────────────────────────────────────────────────────────────────
# 7. Sofortverifikation (nur COM-Handler schreibt direkt ins UEFI-NVRAM)
# ─────────────────────────────────────────────────────────────────────────────
if ($comHandlerRegistered) {
    Write-Verbose "COM-Handler erkannt – warte 60 Sekunden auf NVRAM-Commit..."
    Start-Sleep -Seconds 60
    try {
        $dbAfter = Get-SecureBootUEFI -Name db -ErrorAction SilentlyContinue
        if ($dbAfter -and (Test-UEFICA2023InDb -DbBytes $dbAfter.bytes)) {
            New-Result -Status 'OK' -Action 'Direkt eingetragen' `
                -Message "'$CERT_SUBJECT' wurde direkt in die DB eingetragen. Power Off + Power On empfohlen um NVRAM dauerhaft zu verankern." `
                -RebootRequired $true -BitLockerSuspended $blResult.Suspended
            return
        }
    }
    catch { }
}

# ─────────────────────────────────────────────────────────────────────────────
# 8. Reboot erforderlich (älterer SecureBootEncodeUEFI.exe Mechanismus)
# ─────────────────────────────────────────────────────────────────────────────
$rebootMsg = "Registry gesetzt und Task gestartet. Neustart erforderlich damit die UEFI-Firmware das Zertifikat beim Booten einträgt. " +
             "In manchen Fällen ist ein zweiter Neustart nötig. Danach mit Test-SecureBootCert2023.ps1 prüfen."

if (-not $AutoConfirm) {
    $response = Read-Host "`nSystem jetzt neu starten? (J/N)"
    if ($response -match '^[JjYy]') {
        Restart-Computer -Force
        return
    }
}

New-Result -Status 'REBOOT_REQUIRED' -Action 'Update eingeleitet' -Message $rebootMsg -RebootRequired $true -BitLockerSuspended $blResult.Suspended
