<#
.SYNOPSIS
    Ermittelt die Laufzeit seit dem letzten Neustart aller eingeschalteten
    VMs.

.DESCRIPTION
    Fragt interaktiv nach vCenter und Anmeldedaten und liest je VM die
    Metrik sys.osuptime.latest aus.

    Beantwortet die Frage, welche Maschinen seit Monaten nicht neu gestartet
    wurden - also die, bei denen Updates noch nicht wirksam geworden sind.

.NOTES
    sys.osuptime kommt aus den VMware Tools. Auf VMs ohne oder mit veralteten
    Tools fehlt der Wert.

    Der Filter auf Windows-Gastsysteme ist im Skript auskommentiert und
    laesst sich bei Bedarf aktivieren.
#>

$cred = Get-Credential -Title "vcsa credentials" -UserName "administrator@vsphere.local"
$vcsahost = read-Host("vcsa hostname")
connect-VIServer -Server $vcsahost -Credential $cred -Force
$stat = 'sys.osuptime.latest'
$now = Get-Date
$vms = Get-VM | Where-Object { $_.PowerState -eq 'PoweredOn' } # -and $_.Guest.GuestFamily -match 'windows' }
# $vms = Get-VM | where{$_.PowerState -eq 'PoweredOn' -and $_.Guest.GuestFamily -match 'windows'}
Get-Stat -Entity $vms -Stat $stat -Realtime -MaxSamples 1 | Select-Object @{
    N = 'VM'; 
    E = { $_.Entity.Name } 
}, @{
    N = 'OS'; 
    E = { $_.Entity.ExtensionData.Guest.GuestFullName } 
}, @{
    N = 'LastOSBoot'; 
    E = { $now.AddSeconds(- $_.Value) } 
}, @{
    N = 'UptimeDays';
    E = { [math]::Floor($_.Value / (24 * 60 * 60)) } 
}, @{
    N = 'Notes'; 
    E = { $_.Entity.ExtensionData.Summary.Config.Annotation } 
} | Out-GridView
