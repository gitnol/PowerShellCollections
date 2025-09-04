function Get-ADComputerLastLogon {
    [CmdletBinding()]
    param(
        [string]$Filter = '*'
    )

    # Alle DCs ermitteln
    $DCs = Get-ADDomainController -Filter *

    $allResults = foreach ($DC in $DCs) {
        Get-ADComputer -Filter $Filter -Server $DC.HostName -Properties lastLogon, pwdLastSet, OperatingSystem, Enabled |
        Select-Object Name,
        DistinguishedName,
        OperatingSystem,
        Enabled,
        @{Name = 'DC'; Expression = { $DC.HostName } },
        @{Name = 'LastLogon'; Expression = { [datetime]::FromFileTime($_.lastLogon) } },
        @{Name = 'PwdLastSet'; Expression = { [datetime]::FromFileTime($_.pwdLastSet) } }
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
        }
    }
}

# Beispiel: nur aktive Windows 10 Computer
Get-ADComputerLastLogon -Filter 'Enabled -eq $True -and OperatingSystem -like "*Windows*10*"' |
Out-GridView
