<#
.SYNOPSIS
    PRTG-Sensor: Fehler, Warnungen und abgelehnte Lizenzanfragen im DSLS-Log der letzten Stunden.

.DESCRIPTION
    Liest ueber den Admin-Befehl 'sl -from <datum>' das Serverlog des
    Dassault Systemes License Server und zerlegt jeden Eintrag anhand des
    DSLS-Logformats

        JJJJ/MM/TT hh:mm:ss:fff <Schwere> <Modul> <Meldung>

    Gefiltert wird danach exakt auf die letzten $Hours Stunden (nicht nur auf
    den Kalendertag von "sl -from"). Kanaele:

        DSLS Fehler (<Hours>h)             Eintraege mit Schwere 'E'
        DSLS Warnungen (<Hours>h)          Eintraege mit Schwere 'W'
        DSLS Lizenz abgelehnt (<Hours>h)   Meldungstext "not granted"

    Damit ersetzt dieses Skript die reine Keyword-Heuristik einer frueheren
    Fassung: die Schwere kommt direkt aus dem strukturierten Logformat statt
    aus einem Treffer auf "error"/"fehler" im Freitext.

.PARAMETER TargetServer
    Hostname oder IP des Lizenzservers. Standard: localhost

.PARAMETER DslsExe
    Pfad zu DSLicSrv.exe auf dem Lizenzserver (wird dort per Remoting ausgefuehrt).

.PARAMETER Port
    Admin-Port des DSLS. Standard: 4084

.PARAMETER Hours
    Zeitfenster in Stunden, das ausgewertet wird. Standard: 24

.EXAMPLE
    .\Get-DslsLogSummary.ps1 -TargetServer licsrv01.contoso.local

.NOTES
    Einrichtung in PRTG: Sensor "EXE/Skript (Erweitert)", Parameter z.B.
        -TargetServer "%host"
    Sicherheitskontext: Windows-Anmeldedaten des uebergeordneten Geraets verwenden
    (braucht Remoting-Rechte auf dem Lizenzserver, siehe PRTG.Dsls.psm1).

    Schwere 'E' ist aus dem DSLS-Logformat abgeleitet; im bisher gesehenen Log
    kamen nur 'I' und 'W' vor.

    Die Sensormeldung nennt bewusst keine Benutzer- oder Rechnernamen (keine
    personenbezogenen Daten in der PRTG-Historie) - der Client-Teil einer
    Fehlermeldung wird dafuer abgeschnitten.

    Autor: IT-Administration
#>
[CmdletBinding()]
param(
    [string]$TargetServer = 'localhost',

    [string]$DslsExe = 'C:\Program Files\Dassault Systemes\DS License Server\win_b64\code\bin\DSLicSrv.exe',

    [ValidateRange(1, 65535)]
    [int]$Port = 4084,

    [int]$Hours = 24
)

Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'PRTG.Dsls.psm1') -Force

$inv = [Globalization.CultureInfo]::InvariantCulture

# Meldungen, mit denen DSLicSrv einen falschen Befehl/Parameter ablehnt -> Sensorfehler,
# nicht "0 Fehler im Log" (sonst versteckt ein kaputter Aufruf sich als gruener Sensor).
$commandErrorPattern = '(?i)(ung.ltige[rs]?\s.*\sf.r Option|g.ltiges Datumsformat|' +
'invalid .*option|unknown command|unbekannte[rs]? Befehl)'

if (-not (Test-DslsServer -TargetServer $TargetServer)) {
    Write-PrtgResponse -ErrorText "Lizenzserver $TargetServer ist nicht erreichbar."
    return
}

$cutoff = (Get-Date).AddHours(-$Hours)
# DSLS erwartet JJJJ/MM/TT; InvariantCulture, sonst wird '/' unter de-DE zu '.'
$since = $cutoff.ToString('yyyy/MM/dd', $inv)

try {
    $output = Invoke-DslsAdmin -TargetServer $TargetServer -DslsExe $DslsExe -Port $Port `
        -Command "sl -from $since"
}
catch {
    Write-PrtgResponse -ErrorText "DSLS-Abfrage fehlgeschlagen: $($_.Exception.Message)"
    return
}

if (-not $output) {
    Write-PrtgResponse -ErrorText "DSLicSrv lieferte keine Ausgabe (Server $TargetServer)."
    return
}

$cmdError = @($output | Where-Object { $_ -match $commandErrorPattern }) | Select-Object -First 1
if ($cmdError) {
    Write-PrtgResponse -ErrorText "DSLicSrv hat den Log-Befehl abgelehnt: $($cmdError.Trim())"
    return
}

# DSLS schreibt teils zwei Eintraege in eine Zeile -> vor jedem Zeitstempel umbrechen
$tsPattern = '\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}:\d{3} [A-Z] '
$text = ($output -join "`n") -replace "\s+(?=$tsPattern)", "`n"
$entryPattern = '^(?<ts>\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}):\d{3} (?<sev>[A-Z]) (?<module>\S+) (?<msg>.*)$'

$entries = @(foreach ($line in ($text -split "`n")) {
    if ($line -match $entryPattern) {
        [pscustomobject]@{
            Time     = [datetime]::ParseExact($Matches['ts'], 'yyyy/MM/dd HH:mm:ss', $inv)
            Severity = $Matches['sev']
            Module   = $Matches['module']
            Message  = $Matches['msg'].Trim()
        }
    }
})

# Jeder Lauf erzeugt selbst ADMINSERVER-Eintraege -> keine Eintraege = Parsing/Abfrage kaputt
if ($entries.Count -eq 0) {
    Write-PrtgResponse -ErrorText ('Keine Logeintraege erkannt. RAW: ' + (($output | Select-Object -First 10) -join ' | '))
    return
}

$recent = @($entries | Where-Object { $_.Time -ge $cutoff })
$errors = @($recent | Where-Object { $_.Severity -eq 'E' })
$warnings = @($recent | Where-Object { $_.Severity -eq 'W' })
$denied = @($recent | Where-Object { $_.Message -match '(?i)\bnot granted\b' })

$results = @(
    New-PrtgResult -Channel "DSLS Fehler (${Hours}h)" -Value $errors.Count `
        -LimitMaxWarning 0 -LimitMaxError 9
    New-PrtgResult -Channel "DSLS Warnungen (${Hours}h)" -Value $warnings.Count
    New-PrtgResult -Channel "DSLS Lizenz abgelehnt (${Hours}h)" -Value $denied.Count
)

# Meldungstext: Fehler > Ablehnungen je Feature, ohne Personenbezug
$parts = @('{0} Fehler, {1} Warnungen in {2}h' -f $errors.Count, $warnings.Count, $Hours)
if ($denied.Count -gt 0) {
    $perFeature = $denied |
        ForEach-Object { if ($_.Message -match '^(?<f>\S+)\s+not granted') { $Matches['f'] } else { '?' } } |
        Group-Object | Sort-Object Count -Descending |
        ForEach-Object { '{0} x{1}' -f $_.Name, $_.Count }
    $parts += 'Abgelehnt: ' + ($perFeature -join ', ')
}
if ($errors.Count -gt 0) {
    $last = $errors[-1]
    $msg = ($last.Message -replace '\(\s*from client.*$', '').Trim()   # Client-/Benutzerdaten abschneiden
    $parts += 'Letzter Fehler {0}: {1} {2}' -f $last.Time.ToString('dd.MM. HH:mm', $inv), $last.Module, $msg
}
$sensorText = ($parts -join '. ') + '.'

Write-PrtgResponse -Result $results -Text $sensorText
