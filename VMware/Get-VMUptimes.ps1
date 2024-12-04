$cred = Get-Credential -Title "vcsa credentials" -UserName "administrator@vsphere.local"
$vcsahost = read-Host("vcsa hostname")
connect-VIServer -Server $vcsahost -Credential $cred -Force
$stat = 'sys.osuptime.latest'
$now = Get-Date
$vms = Get-VM
# $vms = Get-VM | where{$_.PowerState -eq 'PoweredOn' -and $_.Guest.GuestFamily -match 'windows'}
Get-Stat -Entity $vms -Stat $stat -Realtime -MaxSamples 1 | Select-Object @{N = 'VM'; E = { $_.Entity.Name } }, @{N = 'OS'; E = { $_.Entity.ExtensionData.Guest.GuestFullName } }, @{N = 'LastOSBoot'; E = { $now.AddSeconds(- $_.Value) } }, @{N = 'UptimeDays'; E = { [math]::Floor($_.Value / (24 * 60 * 60)) } }, @{N = 'Notes'; E = { $_.Entity.ExtensionData.Summary.Config.Annotation } } | Out-GridView
