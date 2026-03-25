<#
.SYNOPSIS
    Ermittelt die Versionen von SQL Server Instanzen auf remote Servern.

.DESCRIPTION
    Das Skript fuehrt eine parallelisierte Registry-Abfrage auf den uebergebenen Servern aus.
    Es liest die Instanznamen und die zugehoerigen Patch-Level (Versionen) aus und gibt diese strukturiert als PSCustomObject zurueck. 
    Nicht erreichbare Server werden stumm uebersprungen.

.PARAMETER ComputerName
    Ein Array von Computernamen oder IP-Adressen, die abgefragt werden sollen.

.EXAMPLE
    .\Get-SqlServerVersion.ps1 -ComputerName "SVR01", "SVR02", "SVR02"

.EXAMPLE
    $serverListe = (Get-ADComputer -Filter {OperatingSystem -like "*Server*"}).Name
    .\Get-SqlServerVersion.ps1 -ComputerName $serverListe | Sort-Object Version | Format-Table
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$ComputerName
)

begin {
    $abfrageBlock = {
        $regPfad = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
        $gefundeneInstanzen = @()

        if (Test-Path -Path $regPfad) {
            $instanzen = Get-ItemProperty -Path $regPfad
            $eigenschaften = $instanzen.psobject.properties | Where-Object { 
                $_.Name -notmatch "^_" -and $_.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider") 
            }

            foreach ($instanz in $eigenschaften) {
                $instanzName = $instanz.Name
                $instanzOrdner = $instanz.Value
                $setupPfad = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($instanzOrdner)\Setup"

                if (Test-Path -Path $setupPfad) {
                    $patchLevel = (Get-ItemProperty -Path $setupPfad).PatchLevel
                    
                    if ([string]::IsNullOrWhiteSpace($patchLevel)) {
                        $patchLevel = "Unbekannt"
                    } else {
                        # Wert wird beibehalten
                    }
                    
                    $gefundeneInstanzen += [PSCustomObject]@{
                        Servername = $env:COMPUTERNAME
                        Instanz    = $instanzName
                        Version    = $patchLevel
                    }
                } else {
                    $gefundeneInstanzen += [PSCustomObject]@{
                        Servername = $env:COMPUTERNAME
                        Instanz    = $instanzName
                        Version    = "Kein Setup-Schluessel"
                    }
                }
            }
        }
        return $gefundeneInstanzen
    }
}

process {
    $roheErgebnisse = Invoke-Command -ComputerName $ComputerName -ScriptBlock $abfrageBlock -ErrorAction SilentlyContinue

    if ($null -ne $roheErgebnisse) {
        foreach ($ergebnis in $roheErgebnisse) {
            [PSCustomObject]@{
                Servername = $ergebnis.Servername
                Instanz    = $ergebnis.Instanz
                Version    = $ergebnis.Version
            }
        }
    }
}