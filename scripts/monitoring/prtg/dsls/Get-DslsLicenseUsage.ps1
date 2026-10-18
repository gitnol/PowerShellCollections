<#
.SYNOPSIS
    PRTG-Sensor: Lizenznutzung und Restlaufzeit je Komponente auf dem DSLS.

.DESCRIPTION
    Fragt den Dassault Systemes License Server ueber DSLicSrv.exe ab und
    liefert pro Lizenzkomponente drei Kanaele:

        <Komponente> - Tage bis Ablauf   Warnung < 30, Fehler < 7
        <Komponente> - In Use            Warnung ab Gesamtzahl
        <Komponente> - Available

    Genutzt werden die Admin-Befehle 'gli' (Lizenzinventar mit Gueltigkeit)
    und 'glu -all' (aktuelle Nutzung).

.PARAMETER TargetServer
    Hostname oder IP des Lizenzservers. Standard: localhost

.PARAMETER DslsExe
    Pfad zu DSLicSrv.exe auf dem Lizenzserver (wird dort per Remoting ausgefuehrt).

.PARAMETER Port
    Admin-Port des DSLS. Standard: 4084

.PARAMETER WarnDays
    Ab wie wenig Resttagen PRTG warnt. Standard: 30

.PARAMETER ErrorDays
    Ab wie wenig Resttagen PRTG einen Fehler meldet. Standard: 7

.EXAMPLE
    .\Get-DslsLicenseUsage.ps1 -TargetServer licsrv01.contoso.local

.NOTES
    Einrichtung in PRTG: Sensor "EXE/Skript (Erweitert)", Parameter z.B.
        -TargetServer "%host"
    Sicherheitskontext: Windows-Anmeldedaten des uebergeordneten Geraets verwenden
    (braucht Remoting-Rechte auf dem Lizenzserver, siehe PRTG.Dsls.psm1).

    Die Ausgabe von DSLicSrv.exe ist sprachabhaengig. $usagePattern deckt die
    deutsche ("Anzahl:", "in Verwendung:") und die englische Ausgabe ("count:",
    "in use:"/"inuse:") ab.

    Autor: IT-Administration
#>
[CmdletBinding()]
param(
    [string]$TargetServer = 'localhost',

    [string]$DslsExe = 'C:\Program Files\Dassault Systemes\DS License Server\win_b64\code\bin\DSLicSrv.exe',

    [ValidateRange(1, 65535)]
    [int]$Port = 4084,

    [int]$WarnDays = 30,

    [int]$ErrorDays = 7
)

Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'PRTG.Dsls.psm1') -Force

# Zeile aus 'gli': Komponente, Anzahl, Start- und Ablaufzeitpunkt
#   Beispiel: HD2 1 2026-09-17.00:01.UTC 2028-08-20.23:59.UTC
# Zeitzonenkuerzel bewusst generisch (nicht nur "UTC") - je nach DSLS-Konfiguration
# steht dort z.B. auch eine lokale Zeitzone.
$inventoryPattern = '(?<component>\S+)\s+(?<qty>\d+)\s+' +
'(?<start>\d{4}-\d{2}-\d{2}\.\d{2}:\d{2}\.[A-Za-z0-9_+-]+)\s+' +
'(?<end>\d{4}-\d{2}-\d{2})\.\d{2}:\d{2}\.[A-Za-z0-9_+-]+'

# Zeile aus 'glu -all': Komponente, Gesamtzahl, belegte Lizenzen (deutsche oder englische Ausgabe)
$usagePattern = '^\s+(?<component>[A-Z0-9]+)\s+maxReleaseNumber.*?' +
'(?:Anzahl|count):\s*(?<total>\d+)\s+(?:in Verwendung|in use|inuse):\s*(?<inuse>\d+)'

if (-not (Test-DslsServer -TargetServer $TargetServer)) {
    Write-PrtgResponse -ErrorText "Lizenzserver $TargetServer ist nicht erreichbar."
    return
}

try {
    $output = Invoke-DslsAdmin -TargetServer $TargetServer -DslsExe $DslsExe -Port $Port `
        -Command 'gli; glu -all'
}
catch {
    Write-PrtgResponse -ErrorText "DSLS-Abfrage fehlgeschlagen: $($_.Exception.Message)"
    return
}

$licenses = [ordered]@{}

foreach ($line in $output) {
    if ($line -match $inventoryPattern) {
        $component = $Matches['component']
        $endDate = [datetime]::ParseExact($Matches['end'], 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        $daysLeft = [math]::Floor(($endDate - (Get-Date)).TotalDays)

        if (-not $licenses.Contains($component)) {
            $licenses[$component] = [pscustomobject]@{
                DaysLeft = $daysLeft
                Total    = $null
                InUse    = $null
            }
        }
        elseif ($daysLeft -lt $licenses[$component].DaysLeft) {
            # mehrere Lizenzzeilen je Komponente (z.B. gestaffelte Vertraege):
            # das fruehste Ablaufdatum zaehlt fuer die Warnung.
            $licenses[$component].DaysLeft = $daysLeft
        }
    }
    elseif ($line -match $usagePattern) {
        $component = $Matches['component']
        if ($licenses.Contains($component)) {
            $licenses[$component].Total = [int]$Matches['total']
            $licenses[$component].InUse = [int]$Matches['inuse']
        }
    }
}

if ($licenses.Count -eq 0) {
    Write-PrtgResponse -ErrorText 'Keine passenden Lizenzdaten im DSLS-Output gefunden.'
    return
}

$results = foreach ($component in $licenses.Keys) {
    $lic = $licenses[$component]

    New-PrtgResult -Channel "$component - Tage bis Ablauf" -Value $lic.DaysLeft `
        -Unit 'Custom' -CustomUnit 'Tage' -LimitMinWarning $WarnDays -LimitMinError $ErrorDays

    # Ohne passende glu-Zeile bleiben Total/InUse leer. Die Kanaele dann
    # wegzulassen ist sauberer als 0 zu melden - sonst sieht ein fehlendes
    # Parsing in PRTG aus wie "keine Lizenz in Benutzung".
    if ($null -ne $lic.Total -and $null -ne $lic.InUse) {
        New-PrtgResult -Channel "$component - In Use" -Value $lic.InUse `
            -LimitMaxWarning $lic.Total
        New-PrtgResult -Channel "$component - Available" -Value ($lic.Total - $lic.InUse)
    }
}

$withUsage = @($licenses.Keys).Where({ $null -ne $licenses[$_].Total }).Count
Write-PrtgResponse -Result $results `
    -Text "$($licenses.Count) Komponente(n) gelesen, davon $withUsage mit Nutzungsdaten."
