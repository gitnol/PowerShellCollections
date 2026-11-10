#Requires -Version 5.1
<#
.SYNOPSIS
    Liest den SOLIDWORKS PDM Client-Lizenztyp (Editor, Contributor, Viewer) aus der Registry.

.DESCRIPTION
    Liest die Zeichenfolge "PTID" unter
    HKLM\SOFTWARE\SolidWorks\Applications\PDMWorks Enterprise
    und ordnet die GUID dem Lizenztyp zu.
    Remote-Zugriff per PowerShell-Remoting (Invoke-Command, WinRM).
    Der Dienst "Remote Registry" wird NICHT benoetigt.
    Es gibt keine Admin-Vorpruefung: fehlt das Recht, wird eine Meldung
    ausgegeben und Exitcode 3 zurueckgegeben.

.PARAMETER ComputerName
    Zielrechner. Standard: lokaler Rechner (ohne Remoting).

.PARAMETER Credential
    Optional: Konto fuer den Remote-Zugriff.

.EXAMPLE
    .\Get-PdmLicenseType.ps1

.EXAMPLE
    .\Get-PdmLicenseType.ps1 -ComputerName PC-0815 | Format-List

.NOTES
    Version: 2.0.0
    Exitcodes:
      0 = Lizenztyp erkannt
      3 = Verbindung/Zugriff fehlgeschlagen
      4 = Schluessel PDMWorks Enterprise nicht gefunden (PDM Client nicht installiert?)
      5 = Wert PTID nicht vorhanden
      6 = PTID vorhanden, aber GUID unbekannt
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential
)

$ErrorActionPreference = 'Stop'

$KnownIds = @{
    '{05AD35C4-8A9A-4114-B51F-32186222ABA1}' = 'Editor'
    '{E2BE88CF-6E17-43e2-A837-C1051F3E4EDB}' = 'Contributor'
    '{CC72DD26-1A34-4209-B50B-21C7DD5E29F6}' = 'Viewer'
}

$IsLocal = $ComputerName -in @('.', 'localhost', $env:COMPUTERNAME)

# Laeuft lokal bzw. auf dem Zielrechner; liefert nur Status und Rohwert zurueck.
$ReadBlock = {
    $path = 'HKLM:\SOFTWARE\SolidWorks\Applications\PDMWorks Enterprise'
    if (-not (Test-Path -LiteralPath $path)) { return @{ Status = 'NoKey'; Value = $null } }
    $val = (Get-ItemProperty -LiteralPath $path -Name 'PTID' -ErrorAction SilentlyContinue).PTID
    if ($null -eq $val) { return @{ Status = 'NoValue'; Value = $null } }
    return @{ Status = 'Ok'; Value = [string]$val }
}

try {
    if ($IsLocal) {
        $Result = & $ReadBlock
    } else {
        $Params = @{ ComputerName = $ComputerName; ScriptBlock = $ReadBlock }
        if ($Credential) { $Params.Credential = $Credential }
        $Result = Invoke-Command @Params
    }
} catch {
    Write-Host ('Fehler: Zugriff auf "{0}" fehlgeschlagen: {1}' -f $ComputerName, $_.Exception.Message)
    exit 3
}

$LicenseName = 'Unbekannt'
$ExitCode    = 0

switch ($Result.Status) {
    'NoKey'   { Write-Host 'Fehler: Schluessel PDMWorks Enterprise nicht gefunden.'; $ExitCode = 4 }
    'NoValue' { Write-Host 'Fehler: Wert PTID ist nicht vorhanden.';                $ExitCode = 5 }
    'Ok' {
        $Guid = $Result.Value.Trim()
        if ($KnownIds.ContainsKey($Guid)) {
            $LicenseName = $KnownIds[$Guid]
            Write-Host ('Lizenztyp auf "{0}": {1}' -f $ComputerName, $LicenseName)
        } else {
            Write-Host ('Warnung: PTID "{0}" ist keiner bekannten Lizenz zugeordnet.' -f $Guid)
            $ExitCode = 6
        }
    }
}

[PSCustomObject]@{
    ComputerName = $ComputerName
    LicenseType  = $LicenseName
    PTID         = $Result.Value
}

exit $ExitCode
