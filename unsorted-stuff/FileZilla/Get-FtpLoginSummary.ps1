#Requires -Version 5.1
<#
.SYNOPSIS
    Analysiert FileZilla Server Logs und gibt eine Zusammenfassung der
    erfolgreichen und fehlgeschlagenen FTP-Logins aus.

.DESCRIPTION
    Parst FileZilla Server Logs (inkl. rotierter Dateien), verknuepft
    USER-Kommandos mit Login-Ergebnissen ueber die Session-ID und
    erstellt eine GROUP-BY-Auswertung nach Benutzer + IP-Adresse.

.PARAMETER LogPaths
    Pfade zu den FileZilla Log-Dateien (Wildcards unterstuetzt).

.PARAMETER LastDays
    Anzahl der Tage rueckwirkend ab heute (Standard: 365).

.PARAMETER ExportCsv
    Optionaler Pfad fuer den CSV-Export des rohen Login-Logs.

.PARAMETER ExportSummaryCsv
    Optionaler Pfad fuer den CSV-Export der gruppierten Zusammenfassung.

.PARAMETER GridView
    Zeigt Ergebnisse in Out-GridView an (erfordert Windows).

.EXAMPLE
    .\Get-FtpLoginSummary.ps1 -LastDays 30 -GridView

.EXAMPLE
    .\Get-FtpLoginSummary.ps1 -LastDays 365 -ExportSummaryCsv "D:\analyze_filezilla_logs\summary.csv"
#>

[CmdletBinding()]
param(
    [string[]]$LogPaths     = @('D:\FILEZILLA_LOGS\FILEZILLA*.log'),
    [int]     $LastDays     = 365,
    [string]  $ExportCsv,
    [string]  $ExportSummaryCsv,
    [switch]  $GridView
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# HILFSFUNKTION: Alle Log-Dateien aufloesen (Wildcards expandieren)
# ---------------------------------------------------------------------------
function Resolve-LogPaths {
    param([string[]]$Patterns)

    $resolved = [System.Collections.Generic.List[string]]::new()
    foreach ($pattern in $Patterns) {
        $found = Get-Item -Path $pattern -ErrorAction SilentlyContinue |
                 Where-Object { -not $_.PSIsContainer } |
                 Sort-Object Name
        if ($found) {
            foreach ($f in $found) { $resolved.Add($f.FullName) }
        } else {
            Write-Warning "Keine Dateien gefunden fuer Muster: $pattern"
        }
    }
    return $resolved
}

# ---------------------------------------------------------------------------
# KERNFUNKTION: Log-Dateien einlesen und Sessions aufbauen
# ---------------------------------------------------------------------------
function Read-FtpSessions {
    param(
        [string[]]$Files,
        [datetime]$Cutoff
    )

    # Regex: Timestamp | Direction | Session-ID | IP | optionaler Username | Message
    $lineRx = [regex](
        '^(?<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)' +
        '\s+(?<dir>>>|<<|==|!!)' +
        '\s+\[FTP Session\s+(?<sid>\d+)\s+(?<ip>(?:\d{1,3}\.){3}\d{1,3})' +
        '(?:\s+(?<user>[^\]]+))?\]\s+(?<msg>.+)$'
    )

    # Key = "Dateiname|RestartZaehler|SessionId"
    # RestartZaehler verhindert Kollisionen wenn FileZilla innerhalb
    # derselben Logdatei neu startet und Session-IDs von vorne beginnt.
    $sessions = [System.Collections.Generic.Dictionary[string, hashtable]]::new()

    foreach ($file in $Files) {
        Write-Verbose "Lese: $file"
        $fileKey      = [System.IO.Path]::GetFileName($file)
        $restartCount = 0
        # Aktive Session-IDs in diesem Datei-Run.
        # Wird benutzt um echte Server-Neustarts (Session-ID-Wiederverwendung)
        # von FileZillas zweiZeiliger 220-Begruessung zu unterscheiden.
        # Regel: Nur "220-" (Dash) = neuer Verbindungsstart.
        #        "220 " (Leerzeichen) = Fortsetzungszeile, wird ignoriert.
        #        "== [FTP Server] Session X ended" = Session-Ende, entfernt aus HashSet.
        $activeSids = [System.Collections.Generic.HashSet[string]]::new()
        # Vor-Check-Regex fuer Session-Ende-Zeilen (enthalten keine IP, matchen $lineRx nie)
        $sessionEndRx = [regex]'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z\s+==\s+\[FTP Server\]\s+Session (\d+) ended'

        $fs     = [System.IO.FileStream]::new($file,
                      [System.IO.FileMode]::Open,
                      [System.IO.FileAccess]::Read,
                      [System.IO.FileShare]::ReadWrite)
        $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
        try {
        while ($null -ne ($line = $reader.ReadLine())) {

            # Vor-Check 1: FileZilla-Neustart.
            # "new logging started" erscheint wenn der Server startet/neu startet.
            # Das ist die zuverlaessigste Markierung — unabhaengig davon ob vorherige
            # Sessions sauber beendet wurden oder nicht.
            if ($line -match 'new logging started') {
                $restartCount++
                $activeSids.Clear()
                continue
            }

            # Vor-Check 2: Session-Ende-Zeilen haben kein IP-Pattern und matchen $lineRx
            # nie. Trotzdem muessen wir sie abfangen, damit $activeSids aktuell bleibt.
            $se = $sessionEndRx.Match($line)
            if ($se.Success) {
                [void]$activeSids.Remove($se.Groups[1].Value)
                continue
            }

            $m = $lineRx.Match($line)
            if (-not $m.Success) { continue }

            $ts = [datetime]::Parse(
                $m.Groups['ts'].Value, $null,
                [System.Globalization.DateTimeStyles]::RoundtripKind
            )

            # 1h Puffer damit USER-Kommandos kurz vor dem Cutoff noch erfasst werden
            if ($ts -lt $Cutoff.AddHours(-1)) { continue }

            $rawSid = $m.Groups['sid'].Value
            $msg    = $m.Groups['msg'].Value.Trim()

            # Session-Start-Erkennung:
            #   "220-" (Dash)      = erste Zeile der FileZilla-Mehrzeilen-Begruessung
            #                        → definitiver Start einer neuen Verbindung
            #   "220 " (Leerzeichen) = Fortsetzungszeile ODER einzeilige Begruessung
            #                        → nur als Start zaehlen wenn rawSid noch unbekannt
            #
            # Echten Server-Neustart erkennt man daran, dass "220-" fuer eine Session-ID
            # auftaucht, die noch als aktiv gilt (d.h. kein "Session X ended" kam).
            if ($msg -match '^220-') {
                if ($activeSids.Contains($rawSid)) {
                    # Echte Wiederverwendung der Session-ID nach Neustart
                    $restartCount++
                    $activeSids.Clear()
                }
                [void]$activeSids.Add($rawSid)
            } elseif ($msg -match '^220\s') {
                # Einzeilige Begruessung (kein vorangehendes 220-) → als Start behandeln
                if (-not $activeSids.Contains($rawSid)) {
                    [void]$activeSids.Add($rawSid)
                }
                # Bereits bekannt = Fortsetzungszeile der Mehrzeilen-Begruessung → ignorieren
            }

            $sid = "$fileKey|$restartCount|$rawSid"

            if (-not $sessions.ContainsKey($sid)) {
                $sessions[$sid] = @{
                    SessionId      = $m.Groups['sid'].Value
                    IP             = $m.Groups['ip'].Value
                    User           = $null
                    LoginTime      = $null
                    LogoutTime     = $null
                    LoginSuccess   = $false
                    LoginFailed    = $false
                    Source         = $fileKey
                }
            }
            $s = $sessions[$sid]

            # Username: aus CLIENT-Kommando "USER xyz"
            if ($msg -match '^USER\s+(.+)$') {
                $s.User = $Matches[1].Trim()
            }

            # Erfolgreicher Login (230), muss im Zeitfenster liegen
            if ($msg -match '^230\s' -and $ts -ge $Cutoff) {
                $s.LoginSuccess = $true
                $s.LoginFailed  = $false
                if ($null -eq $s.LoginTime) { $s.LoginTime = $ts }
            }

            # Fehlgeschlagener Login (530)
            if ($msg -match '^530\s' -and $ts -ge $Cutoff) {
                if (-not $s.LoginSuccess) {
                    $s.LoginFailed = $true
                    if ($null -eq $s.LoginTime) { $s.LoginTime = $ts }
                }
            }

            # Session-Ende
            if ($msg -match '^221\s' -or $msg -match 'ended gracefully') {
                $s.LogoutTime = $ts
            }
        }
        } finally {
            $reader.Dispose()
            $fs.Dispose()
        }
    }

    # Nur Sessions mit bekanntem Ergebnis (Erfolg ODER Fehler) und im Zeitfenster
    return $sessions.Values | Where-Object {
        ($_.LoginSuccess -or $_.LoginFailed) -and $null -ne $_.LoginTime
    }
}

# ---------------------------------------------------------------------------
# HAUPTLOGIK
# ---------------------------------------------------------------------------

$cutoff = (Get-Date).ToUniversalTime().AddDays(-$LastDays)

Write-Host "FileZilla Log-Analyse"
Write-Host "Zeitraum: letzte $LastDays Tage (ab $($cutoff.ToString('yyyy-MM-dd HH:mm')) UTC)"
Write-Host ("=" * 60)

# Log-Dateien aufloesen
$resolvedFiles = Resolve-LogPaths -Patterns $LogPaths
if ($resolvedFiles.Count -eq 0) {
    Write-Error "Keine Log-Dateien gefunden. Pruefe -LogPaths Parameter."
    exit 1
}
Write-Host "Gefundene Log-Dateien: $($resolvedFiles.Count)"
$resolvedFiles | ForEach-Object { Write-Host "  $_" }
Write-Host ''

# Sessions einlesen
$sessions = @(Read-FtpSessions -Files $resolvedFiles -Cutoff $cutoff)
Write-Host "Verarbeitete Sessions (im Zeitfenster): $($sessions.Count)"
Write-Host ''

# Rohe Login-Liste (eine Zeile pro Session)
$loginLog = $sessions | ForEach-Object {
    [PSCustomObject]@{
        LoginTime  = $_.LoginTime
        User       = if ($_.User)         { $_.User }    else { '(anonym)' }
        IP         = $_.IP
        Status     = if ($_.LoginSuccess) { 'Erfolg' }   else { 'Fehler'   }
        SessionId  = $_.SessionId
        LogoutTime = $_.LogoutTime
        Source     = $_.Source
    }
} | Sort-Object LoginTime

# ---------------------------------------------------------------------------
# GROUP BY: Benutzer + IP + Status
# ---------------------------------------------------------------------------
$summary = $loginLog |
    Group-Object -Property User, IP |
    ForEach-Object {
        $entries   = $_.Group
        $user      = $entries[0].User
        $ip        = $entries[0].IP
        $erfolge   = @($entries | Where-Object { $_.Status -eq 'Erfolg' }).Count
        $fehler    = @($entries | Where-Object { $_.Status -eq 'Fehler' }).Count
        $ersterLogin  = ($entries | Sort-Object LoginTime | Select-Object -First 1).LoginTime
        $letzterLogin = ($entries | Sort-Object LoginTime | Select-Object -Last  1).LoginTime

        [PSCustomObject]@{
            Benutzer      = $user
            IP            = $ip
            Erfolge       = $erfolge
            Fehler        = $fehler
            Gesamt        = $erfolge + $fehler
            ErsterLogin   = $ersterLogin
            LetzterLogin  = $letzterLogin
        }
    } | Sort-Object -Property Benutzer, IP

# ---------------------------------------------------------------------------
# AUSGABE KONSOLE
# ---------------------------------------------------------------------------
Write-Host "=== ZUSAMMENFASSUNG (GROUP BY Benutzer + IP) ==="
$summary | Format-Table -AutoSize

Write-Host "=== STATISTIK ==="
$totalErfolge = ($summary | Measure-Object -Property Erfolge -Sum).Sum
$totalFehler  = ($summary | Measure-Object -Property Fehler  -Sum).Sum
$uniqueUser   = ($summary | Select-Object -ExpandProperty Benutzer -Unique).Count
$uniqueIPs    = ($summary | Select-Object -ExpandProperty IP        -Unique).Count

Write-Host "  Unique Benutzer:          $uniqueUser"
Write-Host "  Unique IP-Adressen:       $uniqueIPs"
Write-Host "  Erfolgreiche Logins:      $totalErfolge"
Write-Host "  Fehlgeschlagene Logins:   $totalFehler"
Write-Host "  Logins gesamt:            $($totalErfolge + $totalFehler)"

# Auffaellige Accounts (>= 5 Fehler ohne Erfolg)
$suspicious = $summary | Where-Object { $_.Fehler -ge 5 -and $_.Erfolge -eq 0 }
if ($suspicious) {
    Write-Host ''
    Write-Host "=== AUFFAELLIG: Nur Fehlversuche (>= 5 Fehler, kein Erfolg) ==="
    $suspicious | Format-Table -AutoSize
}

# ---------------------------------------------------------------------------
# EXPORTS
# ---------------------------------------------------------------------------
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'

if ($ExportCsv) {
    $null = New-Item -ItemType Directory -Path (Split-Path $ExportCsv -Parent) -Force
    $loginLog | Export-Csv -Path $ExportCsv -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Force
    Write-Host "Raw-Log exportiert: $ExportCsv ($($loginLog.Count) Eintraege)"
}

if ($ExportSummaryCsv) {
    $null = New-Item -ItemType Directory -Path (Split-Path $ExportSummaryCsv -Parent) -Force
    $summary | Export-Csv -Path $ExportSummaryCsv -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Force
    Write-Host "Zusammenfassung exportiert: $ExportSummaryCsv ($($summary.Count) Eintraege)"
}

if (-not $ExportCsv -and -not $ExportSummaryCsv) {
    $autoDir  = Split-Path $resolvedFiles[0] -Parent
    $autoPath = Join-Path $autoDir "ftp_summary_$ts.csv"
    $null = New-Item -ItemType Directory -Path $autoDir -Force
    $summary | Export-Csv -Path $autoPath -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Force
    Write-Host "Auto-Export (kein -ExportSummaryCsv angegeben): $autoPath"
}

if ($GridView) {
    $summary  | Out-GridView -Title "FTP Login-Zusammenfassung (letzte $LastDays Tage)"
    $loginLog | Out-GridView -Title "FTP Login-Detail-Log (letzte $LastDays Tage)"
}
