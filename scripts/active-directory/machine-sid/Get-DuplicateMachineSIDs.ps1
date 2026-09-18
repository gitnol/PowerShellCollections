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