$volume = Get-CimInstance -Query "SELECT * FROM Win32_Volume WHERE DriveLetter = 'C:' AND FileSystem = 'NTFS'"
$deviceID = $volume.DeviceID


# $shadowStorage = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ShadowStorage
# $shadowStorage | Where {$_.Volume.DeviceID -eq $deviceID}

$shadowCopiesFromVolumeC = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.VolumeName -eq $deviceID }


function Convert-WmiDateTime {
    param (
        [string]$WmiDate
    )
    if ($WmiDate -match '^(\d{14})') {
        $dt = [datetime]::ParseExact($Matches[1], 'yyyyMMddHHmmss', $null)
        return $dt.ToString('yyyyMMdd_HHmmss')
    }
    return $null
}

$shadowCopiesFromVolumeC | Select-Object ID, VolumeName, DeviceObject, @{
    Name       = 'ErstelltAm'
    Expression = { Convert-WmiDateTime $_.InstallDate }
}



# # Get the snapshot object (replace with your specific query)
# $snapshot = Get-CimInstance -ClassName Win32_ShadowCopy | Where-Object { $_.ID -eq "your_snapshot_id" }

# # Delete the snapshot
# if ($snapshot) {
#     $snapshot | Remove-CimInstance
#     Write-Host "Snapshot deleted."
# }
# else {
#     Write-Host "Snapshot not found."
# }


# $deviceObject = $snapshot.DeviceObject + "\"
# Write-Host "Snapshot erstellt unter: $deviceObject"

# Write-Host "Erstelle symbolischen Link unter $LinkPath ..."
# cmd.exe /c "mklink /d `"$LinkPath`" `"$deviceObject`"" | Out-Null

# Write-Host "Schattenkopie ist bereit unter $LinkPath. Vorgang abschließen und beliebige Eingabetaste drücken ..."
# Pause

# Write-Host "Entferne symbolischen Link ..."
# [System.IO.Directory]::Delete($LinkPath, $true)

# Write-Host "Lösche VSS-Instanz ..."
# $snapshot.Delete() | Out-Null

# Write-Host "Fertig."