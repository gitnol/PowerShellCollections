<#
.SYNOPSIS
    Setzt die TeamViewer-Zugriffssteuerung auf mehreren Rechnern gleichzeitig.

.DESCRIPTION
    Prueft die Rechner parallel auf Erreichbarkeit und setzt anschliessend den
    AccessControlType in der Registry:

        0 = Vollzugriff
        1 = Bestaetigung durch den Benutzer erforderlich
        2 = Nur Ansicht
        3 = Benutzerdefiniert

    Das Ergebnis gibt das Skript als Objekte in die Pipeline aus (ComputerName,
    Status, Details). Status ist Erfolgreich, Warnung, Fehler, Offline oder
    NichtErreichbar (pingbar, aber WinRM-Fehler). Kein Rechner verschwindet
    stillschweigend aus dem Ergebnis.

.PARAMETER ComputerNames
    Computernamen oder DNSHostNames, auch per Pipeline.

.PARAMETER AccessControlType
    Der TeamViewer AccessControlType (0 bis 3, siehe oben).

.PARAMETER Credential
    Anderes Konto fuer das Remoting, z. B. ein Admin-Konto. Ohne Angabe laeuft
    es unter dem aktuellen Konto.

.PARAMETER NoServiceRestart
    Setzt nur den Registry-Wert, der TeamViewer-Dienst wird nicht neu gestartet.
    Die Einstellung wirkt dann erst nach dem naechsten Dienststart.

.PARAMETER GridView
    Zeigt das Ergebnis zusaetzlich in einem Out-GridView-Fenster (nur
    interaktiv sinnvoll).

.EXAMPLE
    .\Set-TeamViewerAccess.ps1 -ComputerNames PC01.contoso.local -AccessControlType 0 -Credential (Get-Credential)

.EXAMPLE
    Get-Content .\pcs.txt | .\Set-TeamViewerAccess.ps1 -AccessControlType 1 -WhatIf

.OUTPUTS
    PSCustomObject mit ComputerName, Status, Details

.NOTES
    Benoetigt PowerShell 7 (Test-ConnectionInParallel) und WinRM auf den
    Zielrechnern. Wirkt erst nach einem Neustart des TeamViewer-Dienstes auf
    dem Zielrechner; der Neustart trennt laufende TeamViewer-Sitzungen.

    Test-ConnectionInParallel kommt aus dem Modul
    modules/PSCollections.Connectivity. Diese Datei trug frueher eine eigene
    Kopie davon, die den Parameter -Targets statt -ComputerName hiess; der
    alte Name ist im Modul als Alias erhalten.
#>

#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Liste von Computernamen oder DNSHostNames.")]
    [Alias('ComputerName')]
    [string[]]$ComputerNames,

    [Parameter(Mandatory = $true, HelpMessage = "Der TeamViewer AccessControlType (0 = Vollzugriff, 1 = Bestätigung, 2 = Nur Ansicht, 3 = Custom).")]
    [ValidateRange(0, 3)]
    [int]$AccessControlType,

    [Parameter(HelpMessage = "Konto für das Remoting, z. B. ein Admin-Konto.")]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty,

    [switch]$NoServiceRestart,

    [switch]$GridView
)
begin {
    # Gemeinsames Modul laden. Der Suchlauf nach oben macht den Import
    # unabhaengig davon, wie tief die Datei im Verzeichnisbaum liegt.
    # Muss hier stehen (statt davor): Code vor begin/process macht beide
    # Blockkeywords sonst zu gewoehnlichen Befehlsaufrufen (K1).
    $repoRoot = $PSScriptRoot
    while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot 'modules'))) {
        $repoRoot = Split-Path $repoRoot -Parent
    }
    Import-Module (Join-Path $repoRoot 'modules/PSCollections.Connectivity/PSCollections.Connectivity.psd1') -Force

    $allNames = [System.Collections.Generic.List[string]]::new()
}

process {
    # Pipeline-Eingaben sammeln und erst im end-Block verarbeiten: sonst liefe
    # Pruefung, Remoting und Ausgabe je Eingabeelement einzeln.
    foreach ($name in $ComputerNames) {
        if ($name) { $allNames.Add($name.Trim()) }
    }
}

end {
    $names = @($allNames | Select-Object -Unique)
    if ($names.Count -eq 0) {
        Write-Warning "Keine Computernamen übergeben. Abbruch."
        return
    }

    $results = [System.Collections.Generic.List[object]]::new()

    # ─────────────────────────────────────────────────────────────────────────
    # 1. Erreichbarkeit prüfen
    # ─────────────────────────────────────────────────────────────────────────
    Write-Verbose "Starte Vorab-Prüfung der Erreichbarkeit für $($names.Count) Systeme..."

    $pingResults = @(Test-ConnectionInParallel -Throttle 20 -ComputerName $names)

    foreach ($offline in $pingResults | Where-Object { -not $_.Online }) {
        $results.Add([PSCustomObject]@{
                ComputerName = $offline.ComputerName
                Status       = 'Offline'
                Details      = "Keine Antwort auf Ping ($($offline.Status))."
            })
    }

    $targetHosts = @($pingResults | Where-Object Online | Select-Object -ExpandProperty ComputerName)

    # -WhatIf/-Confirm je Rechner
    $targetHosts = @($targetHosts | Where-Object {
            $PSCmdlet.ShouldProcess($_, "AccessControlType auf $AccessControlType setzen")
        })

    # ─────────────────────────────────────────────────────────────────────────
    # 2. TeamViewer-Konfiguration remote anpassen
    # ─────────────────────────────────────────────────────────────────────────
    if ($targetHosts.Count -gt 0) {
        Write-Verbose "Führe TeamViewer-Konfiguration auf $($targetHosts.Count) Online-Systemen aus..."

        $noRestart = $NoServiceRestart.IsPresent

        $invokeParams = @{
            ComputerName  = $targetHosts
            ThrottleLimit = 20
            ErrorAction   = 'SilentlyContinue'
            ErrorVariable = 'remoteErrors'
        }
        if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
            $invokeParams.Credential = $Credential
        }

        $remoteResults = Invoke-Command @invokeParams -ScriptBlock {
            $Value = $using:AccessControlType
            $Restart = -not $using:noRestart
            $RegPath = "HKLM:\SOFTWARE\TeamViewer\AccessControl"
            $KeyName = "AC_Server_AccessControlType"

            $Result = [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Status       = "Fehler"
                Details      = ""
            }

            try {
                if (-not (Test-Path -Path $RegPath)) {
                    New-Item -Path $RegPath -Force -ErrorAction Stop | Out-Null
                }

                Set-ItemProperty -Path $RegPath -Name $KeyName -Value $Value -Type DWord -ErrorAction Stop

                # Zurücklesen: Erfolg erst melden, wenn der Wert wirklich steht.
                $Actual = (Get-ItemProperty -Path $RegPath -Name $KeyName -ErrorAction Stop).$KeyName
                if ($Actual -ne $Value) {
                    $Result.Details = "Registry-Wert steht auf $Actual statt $Value."
                    return $Result
                }
                $Result.Details = "Registry-Key auf $Value gesetzt."

                if (-not $Restart) {
                    $Result.Status = "Erfolgreich"
                    $Result.Details += " Dienst nicht neu gestartet (wirkt erst nach Dienststart)."
                    return $Result
                }

                $TvService = @(Get-Service -Name "*teamviewer*" -ErrorAction SilentlyContinue)
                if ($TvService) {
                    $TvService | Restart-Service -Force -ErrorAction Stop
                    $Result.Status = "Erfolgreich"
                    $Result.Details += " Dienst ($($TvService.Name -join ', ')) neu gestartet."
                }
                else {
                    $Result.Status = "Warnung"
                    $Result.Details += " Aber TeamViewer-Dienst wurde nicht gefunden."
                }
            }
            catch {
                $Result.Status = "Fehler"
                $Result.Details = $_.Exception.Message
            }

            return $Result
        }

        foreach ($r in $remoteResults) {
            $results.Add([PSCustomObject]@{
                    ComputerName = $r.ComputerName
                    Status       = $r.Status
                    Details      = $r.Details
                })
        }

        # Pingbar, aber kein Remoting (WinRM aus, Zugriff verweigert, ...):
        # sichtbar machen statt stillschweigend auszulassen.
        $answered = @($remoteResults | Select-Object -ExpandProperty PSComputerName)
        foreach ($err in $remoteErrors) {
            $target = "$($err.TargetObject)"
            if ($target -and $target -in $answered) { continue }
            $results.Add([PSCustomObject]@{
                    ComputerName = if ($target) { $target } else { '(unbekannt)' }
                    Status       = 'NichtErreichbar'
                    Details      = $err.Exception.Message.Trim()
                })
        }
    }

    # ─────────────────────────────────────────────────────────────────────────
    # 3. Ergebnisse ausgeben
    # ─────────────────────────────────────────────────────────────────────────
    $sorted = @($results | Sort-Object Status, ComputerName)

    if ($GridView -and $sorted.Count -gt 0) {
        $sorted | Out-GridView -Title "TeamViewer AC-Typ Umstellung ($($sorted.Count) Systeme verarbeitet)"
    }

    $sorted
}
