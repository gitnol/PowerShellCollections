<#
.SYNOPSIS
    Findet Rechner in der Domaene, die sich dieselbe Maschinen-SID teilen.

.DESCRIPTION
    Fragt per Invoke-Command jeden AD-Computer nach der SID seines lokalen
    Administratorkontos, kuerzt die RID ab und gruppiert das Ergebnis.
    Ausgegeben werden nur Gruppen mit mehr als einem Mitglied.

    Doppelte Maschinen-SIDs entstehen durch geklonte Installationen ohne
    Sysprep. Sie fuehren zu schwer zu findenden Problemen bei lokalen
    Berechtigungen, WSUS und einigen Verwaltungswerkzeugen.

.NOTES
    Braucht WinRM auf allen Zielrechnern. Nicht erreichbare Rechner fehlen im
    Ergebnis, ohne dass das auffaellt.
#>

function Get-MachineSID {
    $sid = (Get-LocalUser -Name "Administrator").SID
    $machineSID = $sid.Value.Substring(0, $sid.Value.LastIndexOf("-"))
    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        MachineSID   = $machineSID
    }
}

$machineSIDs = Invoke-Command -ComputerName (Get-ADComputer -Filter * | Select-Object -Expand Name) -ScriptBlock ${function:Get-MachineSID}

$machineSIDs | Group-Object -Property MachineSID | Where-Object Count -ge 2 | ForEach-Object { $machineSIDs | Where-Object MachineSID -eq $_.Name } | Out-GridView