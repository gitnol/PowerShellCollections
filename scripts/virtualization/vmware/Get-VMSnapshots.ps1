<#
.SYNOPSIS
    Findet virtuelle Maschinen mit vorhandenen Snapshots.

.DESCRIPTION
    Geht die VMs im angemeldeten vCenter durch und meldet die, an denen noch
    ein Snapshot haengt. Der Betriebszustand laesst sich ueber -PowerState
    einschraenken, Vorgabe ist PoweredOn.

    Vergessene Snapshots sind ein klassischer Speicherfresser: die Delta-Datei
    waechst weiter, und ab einer gewissen Groesse dauert das Zusammenfuehren
    so lange, dass es nur noch im Wartungsfenster geht.

.NOTES
    Setzt eine bestehende Verbindung ueber Connect-VIServer voraus und
    braucht das Modul VMware.PowerCLI.
#>

function Get-VMsWithSnapshots {
    param(
        [ValidateSet('PoweredOn', 'PoweredOff', 'Suspended')]
        [string] $PowerState = 'PoweredOn'
    )
    if ($global:defaultviserver.Count -ge 0) {
        Get-VM | Where-Object {
            $_.PowerState -eq $PowerState -and ($_ | Get-Snapshot -ErrorAction SilentlyContinue)
        } | ForEach-Object {
            $vm = $_
            Get-Snapshot -VM $vm | ForEach-Object {
                [PSCustomObject]@{
                    VMName       = $vm.Name
                    SnapshotName = $_.Name
                    Created      = $_.Created
                    Description  = $_.Description
                }
            }
        }
    }
    else {
        Write-Error "No vSphere server connected. Please connect to a vSphere server using Connect-VIServer."
    }
}


