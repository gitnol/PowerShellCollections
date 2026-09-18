<#
.SYNOPSIS
    PRTG-Sensor: Anzahl der Fehlermeldungen im DSLS-Log der letzten 24 Stunden.

.DESCRIPTION
    Liest ueber den Admin-Befehl 'sl -from <datum>' das Serverlog des
    Dassault Systemes License Server ab gestern und zaehlt Zeilen, die auf
    einen Fehler hindeuten.

    Kanal "DSLS Fehler (letzte 24h)": Warnung ab 1, Fehler ab 10.

.PARAMETER TargetServer
    Hostname oder IP des Lizenzservers. Standard: localhost

.PARAMETER DslsExe
    Pfad zu DSLicSrv.exe.

.PARAMETER Port
    Admin-Port des DSLS. Standard: 4084

.EXAMPLE
    .\Get-DslsLogError.ps1 -TargetServer licsrv01.contoso.local

.NOTES
    Einrichtung in PRTG: Sensor "EXE/Skript (Erweitert)", Parameter z.B.
        -TargetServer "%host"

    Die Fehlererkennung ist eine Heuristik ueber Schluesselwoerter und damit
    sprachabhaengig. Sie zaehlt auch Zeilen, in denen "error" nur im Kontext
    vorkommt (Spaltenueberschriften, Konfigurationsnamen). Der Sensor eignet
    sich deshalb als Trendindikator, nicht als exakte Fehlerzaehlung -
    Schwellwerte entsprechend grosszuegig setzen.

    Autor: IT-Administration
#>
[CmdletBinding()]
param(
    [string]$TargetServer = 'localhost',

    [string]$DslsExe = 'C:\Program Files\Dassault Systemes\DS License Server\win_b64\code\bin\DSLicSrv.exe',

    [ValidateRange(1, 65535)]
    [int]$Port = 4084
)

Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'PRTG.Dsls.psm1') -Force

$errorPattern = '(?i)\b(error|fehler|denied|failed|ungueltig|ung\u00fcltig)\b'

if (-not (Test-DslsServer -TargetServer $TargetServer)) {
    Write-PrtgResponse -ErrorText "Lizenzserver $TargetServer ist nicht erreichbar."
    return
}

$from = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')

try {
    $output = Invoke-DslsAdmin -TargetServer $TargetServer -DslsExe $DslsExe -Port $Port `
        -Command "sl -from $from"
}
catch {
    Write-PrtgResponse -ErrorText "DSLS-Abfrage fehlgeschlagen: $($_.Exception.Message)"
    return
}

$errorCount = @($output).Where({ $_ -match $errorPattern }).Count

$result = New-PrtgResult -Channel 'DSLS Fehler (letzte 24h)' -Value $errorCount `
    -LimitMaxWarning 1 -LimitMaxError 10

Write-PrtgResponse -Result $result `
    -Text "$errorCount Zeile(n) mit Fehlerhinweis seit $from."
