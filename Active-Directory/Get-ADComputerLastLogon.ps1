function Get-ADComputerLastLogon {
    [CmdletBinding()]
    param(
        [string]$Filter = '*'
    )

    # Alle DCs ermitteln
    $DCs = Get-ADDomainController -Filter *

    $allResults = foreach ($DC in $DCs) {
        Get-ADComputer -Filter $Filter -Server $DC.HostName -Properties lastLogon, pwdLastSet, OperatingSystem, Enabled, Description |
        Select-Object Name,
        DistinguishedName,
        OperatingSystem,
        Enabled,
        @{Name = 'DC'; Expression = { $DC.HostName } },
        @{Name = 'LastLogon'; Expression = { [datetime]::FromFileTime($_.lastLogon) } },
        @{Name = 'PwdLastSet'; Expression = { [datetime]::FromFileTime($_.pwdLastSet) } },
        Description
    }

    # pro Computer den neuesten Logonwert wählen
    $allResults | Group-Object DistinguishedName | ForEach-Object {
        $latest = $_.Group | Sort-Object LastLogon -Descending | Select-Object -First 1
        [PSCustomObject]@{
            Name            = $latest.Name
            OperatingSystem = $latest.OperatingSystem
            Enabled         = $latest.Enabled
            LastLogon       = $latest.LastLogon
            PwdLastSet      = $latest.PwdLastSet
            Description     = $latest.Description
        }
    }
}

# Beispiel: nur aktive Windows 10 Computer
Get-ADComputerLastLogon -Filter 'Enabled -eq $True -and OperatingSystem -like "*Windows*10*"' | Out-GridView

$erg = Get-ADComputerLastLogon -Filter 'Enabled -eq $True -and OperatingSystem -like "*Windows*"' 
$thresholdDate = (Get-Date).AddMonths((-1))
$erg | Where-Object { $_.LastLogon -lt $thresholdDate } | Out-GridView -Title "Aktive Computer mit letztem Logon älter als 1 Monat"
$erg | Where-Object { $_.LastLogon -gt $thresholdDate } | Out-GridView -Title "Aktive Computer mit letztem Logon neuer als 1 Monat"
$myhosts = ($erg | Where-Object { $_.LastLogon -gt $thresholdDate }).Name