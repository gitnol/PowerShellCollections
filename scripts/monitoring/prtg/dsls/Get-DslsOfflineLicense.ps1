<#
.SYNOPSIS
    PRTG-Sensor: Anzahl der aktuell vergebenen Offline-Lizenzen (Nomad) auf dem DSLS.

.DESCRIPTION
    Liest ueber den Admin-Befehl 'mns -l' die Liste der ausgeliehenen
    Offline-Lizenzen des Dassault Systemes License Server und zaehlt die
    Eintraege.

    Kanal "Aktive Offline-Lizenzen": Warnung ab 5.

    Offline-Lizenzen sind fuer die Dauer der Ausleihe aus dem Pool genommen.
    Ein dauerhaft hoher Wert bedeutet, dass Arbeitsplaetze Lizenzen binden,
    ohne sie zu nutzen.

.PARAMETER TargetServer
    Hostname oder IP des Lizenzservers. Standard: localhost

.PARAMETER DslsExe
    Pfad zu DSLicSrv.exe.

.PARAMETER Port
    Admin-Port des DSLS. Standard: 4084

.PARAMETER WarningThreshold
    Ab wie vielen Offline-Lizenzen PRTG warnt. Standard: 5

.EXAMPLE
    .\Get-DslsOfflineLicense.ps1 -TargetServer licsrv01.contoso.local -WarningThreshold 10

.NOTES
    Einrichtung in PRTG: Sensor "EXE/Skript (Erweitert)", Parameter z.B.
        -TargetServer "%host"

    Gezaehlt werden Zeilen mit einer Laufzeit-/Ablaufangabe, weil 'mns -l'
    pro ausgeliehener Lizenz genau eine solche Zeile ausgibt. Die
    Schluesselwoerter sind sprachabhaengig - siehe $entryPattern.

    Autor: IT-Administration
#>
[CmdletBinding()]
param(
    [string]$TargetServer = 'localhost',

    [string]$DslsExe = 'C:\Program Files\Dassault Systemes\DS License Server\win_b64\code\bin\DSLicSrv.exe',

    [ValidateRange(1, 65535)]
    [int]$Port = 4084,

    [ValidateRange(1, 10000)]
    [int]$WarningThreshold = 5
)

Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'PRTG.Dsls.psm1') -Force

$entryPattern = '(?i)\b(duration|laufzeit|expiration|ablauf)\b'

if (-not (Test-DslsServer -TargetServer $TargetServer)) {
    Write-PrtgResponse -ErrorText "Lizenzserver $TargetServer ist nicht erreichbar."
    return
}

try {
    $output = Invoke-DslsAdmin -TargetServer $TargetServer -DslsExe $DslsExe -Port $Port `
        -Command 'mns -l'
}
catch {
    Write-PrtgResponse -ErrorText "DSLS-Abfrage fehlgeschlagen: $($_.Exception.Message)"
    return
}

$count = @($output).Where({ $_ -match $entryPattern }).Count

$result = New-PrtgResult -Channel 'Aktive Offline-Lizenzen' -Value $count `
    -LimitMaxWarning $WarningThreshold

Write-PrtgResponse -Result $result -Text "$count Offline-Lizenz(en) im Umlauf."
