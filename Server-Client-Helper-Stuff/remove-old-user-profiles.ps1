Get-WmiObject -Class Win32_NetworkLoginProfile | Select-Object Name, FullName, @{Name="LastLogon"; Expression={[System.Management.ManagementDateTimeConverter]::ToDateTime($_.LastLogon).ToString("dd MMMM yyyy HH:mm:ss")}} | Format-Table

Get-CimInstance -ClassName Win32_UserProfile -ComputerName C335B0-M | Where-Object { !$_.Special } | select -Property LocalPath,Loaded,PSComputerName | ft -AutoSize
Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special } | Where {$_.CreationTime -lt (get-date).adddays(-60)}| where {$_.Loaded -eq $false} | select -Property LocalPath,Loaded,PSComputerName | ft -AutoSize

Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special -and $_.CreationTime -lt (get-date).adddays(-60) -and $_.Loaded -eq $false} | select -Property LocalPath,LastUseTime 

Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special } | Where {$_.CreationTime -lt (get-date).adddays(-60)}| where {$_.Loaded -eq $false} | Remove-CimInstance -Verbose #-Confirm:$false
Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special -and $_.CreationTime -lt (get-date).adddays(-60) -and $_.Loaded -eq $false} | Remove-CimInstance -Verbose #-Confirm:$false