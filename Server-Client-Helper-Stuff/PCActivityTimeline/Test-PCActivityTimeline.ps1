#Requires -Version 5.1
<#
.SYNOPSIS
    Diagnose-Script für Get-PCActivityTimeline.ps1
    Prüft Konnektivität, Audit-Richtlinien, Event-Counts und
    gibt rohe Properties[] der ersten Treffer jeder Event-ID aus —
    damit können die Property-Indices im Haupt-Script verifiziert werden.

.USAGE
    .\Test-PCActivityTimeline.ps1 -ComputerName "8A0228-D.lewa-attendorn.local"
    .\Test-PCActivityTimeline.ps1 -ComputerName "8A0228-D.lewa-attendorn.local" -Credential (Get-Credential)
    .\Test-PCActivityTimeline.ps1 -ComputerName "8A0228-D.lewa-attendorn.local" -AllePropertiesAusgeben
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ComputerName,

    [Parameter(Mandatory = $false)]
    [pscredential]$Credential,

    # Gibt für JEDEN gefundenen Event die vollständigen Properties aus
    # (sonst nur der erste Treffer je EventID). Kann sehr viel Output erzeugen.
    [Parameter(Mandatory = $false)]
    [switch]$AllePropertiesAusgeben,

    # Wie viele Tage rückwärts für die Diagnose-Abfragen
    [Parameter(Mandatory = $false)]
    [int]$TageRueckwaerts = 3
)

$SEP  = '=' * 72
$sep2 = '-' * 72

function Write-Section {
    param([string]$Title)
    Write-Host $SEP -ForegroundColor DarkCyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host $SEP -ForegroundColor DarkCyan
}

function Write-OK   { param([string]$Msg) Write-Host "  [OK]  $Msg" -ForegroundColor Green  }
function Write-WARN { param([string]$Msg) Write-Host "  [!!]  $Msg" -ForegroundColor Yellow }
function Write-ERR  { param([string]$Msg) Write-Host "  [XX]  $Msg" -ForegroundColor Red    }
function Write-INFO { param([string]$Msg) Write-Host "  [..]  $Msg" -ForegroundColor Gray   }

# ─────────────────────────────────────────────────────────────────────────────
Write-Section "1 / 5  —  NETZWERK & ERREICHBARKEIT"
# ─────────────────────────────────────────────────────────────────────────────

Write-INFO "Ping $ComputerName ..."
$ping = Test-Connection -ComputerName $ComputerName -Count 2 -Quiet -ErrorAction SilentlyContinue
if ($ping) {
    Write-OK "Ping erfolgreich"
} else {
    Write-ERR "Ping fehlgeschlagen — Rechner nicht erreichbar oder ICMP geblockt"
}

Write-INFO "WinRM-Port 5985 (HTTP) ..."
$winrm = Test-NetConnection -ComputerName $ComputerName -Port 5985 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
if ($winrm.TcpTestSucceeded) {
    Write-OK "WinRM Port 5985 offen"
} else {
    Write-WARN "WinRM Port 5985 nicht erreichbar — Invoke-Command wird fehlschlagen (lokal kein Problem)"
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Section "2 / 5  —  INVOKE-COMMAND VERBINDUNGSTEST"
# ─────────────────────────────────────────────────────────────────────────────

$invokeParams = @{
    ComputerName = $ComputerName
    ScriptBlock  = { $env:COMPUTERNAME }
    ErrorAction  = 'Stop'
}
if ($Credential) { $invokeParams['Credential'] = $Credential }

try {
    $remoteHostname = Invoke-Command @invokeParams
    Write-OK "Invoke-Command erfolgreich. Remote-Hostname: $remoteHostname"
} catch {
    Write-ERR "Invoke-Command fehlgeschlagen: $_"
    Write-WARN "Weitere Tests laufen lokal weiter — ggf. Ergebnisse nicht repräsentativ"
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Section "3 / 5  —  AUDIT-RICHTLINIEN (remote)"
# ─────────────────────────────────────────────────────────────────────────────
# Liefert nur Ergebnisse wenn das Remote-Konto Admin-Rechte auf dem Zielrechner hat.

$auditScript = {
    # GUIDs sind sprach-unabhängig — funktioniert auf DE und EN Windows
    $subcategories = @(
        @{ Name = 'Logon';                       GUID = '{0CCE9215-69AE-11D9-BED3-505054503030}' }
        @{ Name = 'Logoff';                      GUID = '{0CCE9216-69AE-11D9-BED3-505054503030}' }
        @{ Name = 'Other Logon/Logoff Events';   GUID = '{0CCE921C-69AE-11D9-BED3-505054503030}' }
        @{ Name = 'Special Logon';               GUID = '{0CCE921B-69AE-11D9-BED3-505054503030}' }
    )
    $results = foreach ($sub in $subcategories) {
        $raw = (auditpol /get /subcategory:"$($sub.GUID)" 2>$null) -join ' '
        $setting = if     ($raw -match 'No Auditing|Keine')              { 'Keine Überwachung  ← PROBLEM' }
                   elseif ($raw -match 'Success and Failure|Erfolg und') { 'Erfolg und Fehler  (optimal)' }
                   elseif ($raw -match 'Success|Erfolg')                 { 'Nur Erfolg' }
                   elseif ($raw -match 'Failure|Fehler')                 { 'Nur Fehler' }
                   else                                                  { "Unbekannt (raw: $($raw.Substring(0,[Math]::Min(80,$raw.Length))))" }
        [PSCustomObject]@{ Unterkategorie = $sub.Name; Einstellung = $setting }
    }
    $results
}

$auditInvokeParams = @{
    ComputerName = $ComputerName
    ScriptBlock  = $auditScript
    ErrorAction  = 'SilentlyContinue'
}
if ($Credential) { $auditInvokeParams['Credential'] = $Credential }

try {
    $auditResults = Invoke-Command @auditInvokeParams
    if ($auditResults) {
        $auditResults | ForEach-Object {
            $color = if ($_.Einstellung -match 'PROBLEM') { 'Red' }
                     elseif ($_.Einstellung -match 'optimal') { 'Green' }
                     else { 'Yellow' }
            Write-Host ("  {0,-40} {1}" -f $_.Unterkategorie, $_.Einstellung) -ForegroundColor $color
        }
        Write-Host ""
        Write-WARN "4800/4801 (Lock/Unlock) und 4802/4803 (Screensaver) benötigen:"
        Write-INFO "  'Other Logon/Logoff Events' = Erfolg und Fehler"
        Write-WARN "4625 (fehlgesch. Anmeldung) benötigt:"
        Write-INFO "  'Logon' = Erfolg und Fehler (nicht nur Erfolg!)"
    } else {
        Write-WARN "Keine Audit-Daten empfangen (evtl. fehlende Rechte oder auditpol nicht verfügbar)"
    }
} catch {
    Write-WARN "Audit-Abfrage fehlgeschlagen: $_"
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Section "4 / 5  —  EVENT-COUNTS PRO ID (letzte $TageRueckwaerts Tage)"
# ─────────────────────────────────────────────────────────────────────────────

$countScript = {
    param([int]$Tage)
    $seit = (Get-Date).AddDays(-$Tage)

    $systemIDs   = @(12, 13, 41, 42, 107, 1001, 1074, 1076, 6005, 6006, 6008, 6009, 6013)
    $securityIDs = @(4624, 4625, 4634, 4647, 4648, 4672, 4778, 4779, 4800, 4801, 4802, 4803)

    $counts = [System.Collections.Generic.List[PSCustomObject]]::new()

    # System Log
    foreach ($id in $systemIDs) {
        $n = 0
        try {
            $evts = Get-WinEvent -FilterHashtable @{ LogName='System'; Id=$id; StartTime=$seit } -ErrorAction SilentlyContinue
            $n = @($evts).Count
        } catch {}
        $counts.Add([PSCustomObject]@{
            Log     = 'System'
            EventID = $id
            Anzahl  = $n
            Status  = if ($n -gt 0) { 'Daten vorhanden' } else { 'Keine Daten' }
        })
    }

    # Power-Troubleshooter (System Log, spezieller Provider)
    $n = 0
    try {
        $evts = Get-WinEvent -FilterHashtable @{
            LogName='System'; ProviderName='Microsoft-Windows-Power-Troubleshooter'; Id=1; StartTime=$seit
        } -ErrorAction SilentlyContinue
        $n = @($evts).Count
    } catch {}
    $counts.Add([PSCustomObject]@{
        Log     = 'System (Power-Troubleshooter)'
        EventID = 1
        Anzahl  = $n
        Status  = if ($n -gt 0) { 'Daten vorhanden' } else { 'Keine Daten' }
    })

    # Security Log
    foreach ($id in $securityIDs) {
        $n = 0
        try {
            $evts = Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=$id; StartTime=$seit } -ErrorAction SilentlyContinue
            $n = @($evts).Count
        } catch {}
        $counts.Add([PSCustomObject]@{
            Log     = 'Security'
            EventID = $id
            Anzahl  = $n
            Status  = if ($n -gt 0) { 'Daten vorhanden' } else { 'Keine Daten' }
        })
    }

    return $counts
}

$countInvokeParams = @{
    ComputerName = $ComputerName
    ScriptBlock  = $countScript
    ArgumentList = @($TageRueckwaerts)
    ErrorAction  = 'SilentlyContinue'
}
if ($Credential) { $countInvokeParams['Credential'] = $Credential }

try {
    $countResults = Invoke-Command @countInvokeParams
    if ($countResults) {
        $countResults | ForEach-Object {
            $color = if ($_.Anzahl -gt 0) { 'Green' } else { 'DarkGray' }
            Write-Host ("  {0,-35} ID {1,-6} {2,6} Einträge   {3}" -f $_.Log, $_.EventID, $_.Anzahl, $_.Status) -ForegroundColor $color
        }
    }
} catch {
    Write-WARN "Count-Abfrage fehlgeschlagen: $_"
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Section "5 / 5  —  ROHE PROPERTIES[] JE EVENT-ID (erster Treffer)"
# ─────────────────────────────────────────────────────────────────────────────
Write-INFO "Dies zeigt die tatsächlichen Properties-Indices — damit können"
Write-INFO "die Hardcode-Indices im Haupt-Script verifiziert werden."
Write-Host $sep2 -ForegroundColor DarkGray

$rawScript = {
    param([int]$Tage, [bool]$Alle)
    $seit = (Get-Date).AddDays(-$Tage)

    $queries = @(
        @{ Log = 'System';   IDs = @(12, 13, 41, 42, 107, 1001, 1074, 1076, 6005, 6006, 6008, 6009, 6013) }
        @{ Log = 'Security'; IDs = @(4624, 4625, 4634, 4647, 4648, 4672, 4778, 4779, 4800, 4801, 4802, 4803) }
    )

    $output = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($query in $queries) {
        foreach ($id in $query.IDs) {
            try {
                $evts = Get-WinEvent -FilterHashtable @{
                    LogName   = $query.Log
                    Id        = $id
                    StartTime = $seit
                } -ErrorAction SilentlyContinue

                $subset = if ($Alle) { $evts } else { @($evts)[0] }

                foreach ($ev in $subset) {
                    if ($null -eq $ev) { continue }
                    $propsFormatted = for ($i = 0; $i -lt $ev.Properties.Count; $i++) {
                        "[$i] = $($ev.Properties[$i].Value)"
                    }
                    $output.Add([PSCustomObject]@{
                        Log         = $query.Log
                        EventID     = $ev.Id
                        Zeitpunkt   = $ev.TimeCreated
                        Provider    = $ev.ProviderName
                        Properties  = ($propsFormatted -join ' | ')
                        Message1stLine = ($ev.Message -split "`n")[0].Trim()
                    })
                }
            } catch {}
        }
    }

    # Power-Troubleshooter separat
    try {
        $evts = Get-WinEvent -FilterHashtable @{
            LogName      = 'System'
            ProviderName = 'Microsoft-Windows-Power-Troubleshooter'
            Id           = 1
            StartTime    = $seit
        } -ErrorAction SilentlyContinue

        $subset = if ($Alle) { $evts } else { @($evts)[0] }
        foreach ($ev in $subset) {
            if ($null -eq $ev) { continue }
            $propsFormatted = for ($i = 0; $i -lt $ev.Properties.Count; $i++) {
                "[$i] = $($ev.Properties[$i].Value)"
            }
            $output.Add([PSCustomObject]@{
                Log         = 'System (Power-Troubleshooter)'
                EventID     = $ev.Id
                Zeitpunkt   = $ev.TimeCreated
                Provider    = $ev.ProviderName
                Properties  = ($propsFormatted -join ' | ')
                Message1stLine = ($ev.Message -split "`n")[0].Trim()
            })
        }
    } catch {}

    return $output | Sort-Object Log, EventID
}

$rawInvokeParams = @{
    ComputerName = $ComputerName
    ScriptBlock  = $rawScript
    ArgumentList = @($TageRueckwaerts, ([bool]$AllePropertiesAusgeben))
    ErrorAction  = 'SilentlyContinue'
}
if ($Credential) { $rawInvokeParams['Credential'] = $Credential }

try {
    $rawResults = Invoke-Command @rawInvokeParams
    if ($rawResults) {
        foreach ($r in $rawResults) {
            Write-Host $sep2 -ForegroundColor DarkGray
            Write-Host ("  [{0}] EventID {1}   {2}   Provider: {3}" -f $r.Log, $r.EventID, $r.Zeitpunkt, $r.Provider) -ForegroundColor White
            Write-Host ("  Meldung (1. Zeile): {0}" -f $r.Message1stLine) -ForegroundColor DarkYellow
            Write-Host "  Properties:" -ForegroundColor Cyan
            $r.Properties -split ' \| ' | ForEach-Object {
                Write-Host "    $_" -ForegroundColor Gray
            }
        }
        Write-Host $sep2 -ForegroundColor DarkGray
    } else {
        Write-WARN "Keine rohen Properties empfangen (keine Events im Zeitraum oder Verbindungsfehler)"
    }
} catch {
    Write-WARN "Raw-Properties-Abfrage fehlgeschlagen: $_"
}

Write-Host ""
Write-Section "ZUSAMMENFASSUNG"
Write-INFO "Bitte den vollständigen Output an Claude schicken."
Write-INFO "Besonders wichtig: Abschnitt 4 (Counts) und 5 (Properties)."
Write-INFO "Daraus kann das Haupt-Script gezielt korrigiert werden."
Write-Host $SEP -ForegroundColor DarkCyan
