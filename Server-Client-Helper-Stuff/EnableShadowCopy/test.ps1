$volume = Get-CimInstance -Query "SELECT * FROM Win32_Volume WHERE DriveLetter = 'C:' AND FileSystem = 'NTFS'"
$deviceID = $volume.DeviceID


# $shadowStorage = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ShadowStorage
# $shadowStorage | Where {$_.Volume.DeviceID -eq $deviceID}

$shadowCopiesFromVolumeC = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.VolumeName -eq $deviceID }

$shadowCopiesFromVolumeC | Select-Object ID, VolumeName, DeviceObject, InstallDate

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