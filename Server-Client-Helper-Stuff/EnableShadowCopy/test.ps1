$volume = Get-CimInstance -Query "SELECT * FROM Win32_Volume WHERE DriveLetter = 'C:' AND FileSystem = 'NTFS'"
$deviceID = $volume.DeviceID


# $shadowStorage = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ShadowStorage
# $shadowStorage | Where {$_.Volume.DeviceID -eq $deviceID}

$shadowCopiesFromVolumeC = Get-WmiObject Win32_ShadowCopy | Where-Object {$_.VolumeName -eq $deviceID}


