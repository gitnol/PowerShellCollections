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


