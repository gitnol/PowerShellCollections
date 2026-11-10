#Requires -Version 5.1
<#
.SYNOPSIS
    Setzt den SOLIDWORKS PDM Client-Lizenztyp (Editor, Contributor, Viewer) ueber die Registry.

.DESCRIPTION
    Schreibt die Zeichenfolge "PTID" unter
    HKLM\SOFTWARE\SolidWorks\Applications\PDMWorks Enterprise
    auf die GUID des gewuenschten Lizenztyps und verifiziert den Wert.
    Remote-Zugriff per PowerShell-Remoting (Invoke-Command, WinRM).
    Der Dienst "Remote Registry" wird NICHT benoetigt.
    Es gibt keine Admin-Vorpruefung: fehlt das Recht, wird eine Meldung
    ausgegeben und Exitcode 3 zurueckgegeben.
    Die Aenderung wirkt erst nach einem Neustart des Rechners.

.PARAMETER LicenseType
    Editor, Contributor oder Viewer.

.PARAMETER ComputerName
    Zielrechner. Standard: lokaler Rechner (ohne Remoting).

.PARAMETER Credential
    Optional: Konto fuer den Remote-Zugriff (Administrator auf dem Zielrechner).

.EXAMPLE
    .\Set-PdmLicenseType.ps1 -LicenseType Editor

.EXAMPLE
    .\Set-PdmLicenseType.ps1 -LicenseType Viewer -ComputerName PC-0815

.NOTES
    Version: 2.0.0
    Exitcodes:
      0 = Erfolg (Neustart erforderlich)
      3 = Verbindung/Zugriff fehlgeschlagen
      4 = Schluessel PDMWorks Enterprise nicht gefunden (PDM Client nicht installiert?)
      5 = Schreiben oder Verifizieren fehlgeschlagen
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Editor', 'Contributor', 'Viewer')]
    [string]$LicenseType,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential
)

$ErrorActionPreference = 'Stop'

$LicenseMap = @{
    'Editor'      = '{05AD35C4-8A9A-4114-B51F-32186222ABA1}'
    'Contributor' = '{E2BE88CF-6E17-43e2-A837-C1051F3E4EDB}'
    'Viewer'      = '{CC72DD26-1A34-4209-B50B-21C7DD5E29F6}'
}
$TargetId = $LicenseMap[$LicenseType]
$IsLocal  = $ComputerName -in @('.', 'localhost', $env:COMPUTERNAME)

# Laeuft lokal bzw. auf dem Zielrechner.
$WriteBlock = {
    param($TargetId)
    $path = 'HKLM:\SOFTWARE\SolidWorks\Applications\PDMWorks Enterprise'
    if (-not (Test-Path -LiteralPath $path)) { return @{ Status = 'NoKey' } }

    $old = (Get-ItemProperty -LiteralPath $path -Name 'PTID' -ErrorAction SilentlyContinue).PTID
    if ($old -ne $TargetId) {
        Set-ItemProperty -LiteralPath $path -Name 'PTID' -Value $TargetId -Type String
    }
    $new = (Get-ItemProperty -LiteralPath $path -Name 'PTID').PTID
    return @{ Status = $(if ($new -eq $TargetId) { 'Ok' } else { 'VerifyFailed' }); Old = $old; New = $new }
}

Write-Host ('Setze Lizenztyp "{0}" auf "{1}".' -f $LicenseType, $ComputerName)
try {
    if ($IsLocal) {
        $Result = & $WriteBlock $TargetId
    } else {
        $Params = @{ ComputerName = $ComputerName; ScriptBlock = $WriteBlock; ArgumentList = $TargetId }
        if ($Credential) { $Params.Credential = $Credential }
        $Result = Invoke-Command @Params
    }
} catch {
    Write-Host ('Fehler: Zugriff auf "{0}" fehlgeschlagen: {1}' -f $ComputerName, $_.Exception.Message)
    exit 3
}

switch ($Result.Status) {
    'NoKey' {
        Write-Host 'Fehler: Schluessel PDMWorks Enterprise nicht gefunden.'
        exit 4
    }
    'VerifyFailed' {
        Write-Host ('Fehler: Verifikation fehlgeschlagen. Aktueller Wert: {0}' -f $Result.New)
        exit 5
    }
    'Ok' {
        if ($Result.Old -eq $TargetId) {
            Write-Host ('Lizenztyp "{0}" ist auf "{1}" bereits gesetzt. Keine Aenderung, kein Neustart noetig.' -f $LicenseType, $ComputerName)
        } else {
            Write-Host ('Geaendert: {0} -> {1}' -f $Result.Old, $Result.New)
            Write-Host ('Erfolg: Lizenztyp "{0}" ist auf "{1}" gesetzt. Neustart erforderlich.' -f $LicenseType, $ComputerName)
        }
        exit 0
    }
}
