<#
.SYNOPSIS
    Prüft den Online-Status von Computern aus Active Directory und listet deren IP-Adressen auf.
.DESCRIPTION
    Dieses Skript durchsucht Active Directory nach Computern, prüft deren Erreichbarkeit mittels Ping und löst deren IP-Adressen auf.
    Es unterscheidet dabei zwischen Servern und Clients und ermöglicht die Anzeige zusätzlicher Informationen wie die Beschreibung aus AD.
.PARAMETER Filter
    Der LDAP-Filter, der verwendet wird, um Computer aus Active Directory zu suchen. Standardmäßig werden alle Windows-Computer gesucht.

#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$Filter = "OperatingSystem -like '*Windows*'",
    [int]$ThrottleLimit = 30
)

$null = & ipconfig /flushdns
# Konstante steuert tatsächlichen Neustart
$DoWhatIf = $true   # $true = nur Simulation / $false = echter Neustart
$OnlineServer = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

# Alle
$Server = Get-ADComputer -Filter $Filter -Properties OperatingSystem |
Select-Object -ExpandProperty Name

# Parallel prüfen und ggf. neustarten
$Server | ForEach-Object -Parallel {
    $Name = $_
    $DoWhatIf = $using:DoWhatIf
    $OnlineServer = $using:OnlineServer

    if (Test-Connection -ComputerName $Name -Count 1 -TimeoutSeconds 1 -Quiet) {
        try {
            $IP = (Resolve-DnsName -Name $Name -ErrorAction Stop | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1 -ExpandProperty IPAddress)
        }
        catch {
            $IP = "unbekannt"
        }

        $OnlineServer.Add([pscustomobject]@{
                Server    = $Name
                IPAddress = $IP
                Timestamp = (Get-Date)
            })

        Write-Host "$Name ($IP) ist online."
        # Invoke-Command -ComputerName $Name -ScriptBlock {
        #     param($DoWhatIf)
        #     Restart-Computer -Force -WhatIf:$DoWhatIf
        # } -ArgumentList $DoWhatIf
    }
    else {
        Write-Host "$Name ist offline."
    }
} -ThrottleLimit $ThrottleLimit

# Ausgabe
$OnlineServer | Sort-Object Server


$OnlineServer | Out-GridView