function Get-DiskTypes {
    $BusTypeMap = @{
        0 = 'Unbekannt'; 1 = 'SCSI'; 2 = 'ATAPI'; 3 = 'ATA'; 4 = 'IEEE1394'; 5 = 'SSA'; 6 = 'FibreChannel'
        7 = 'USB'; 8 = 'RAID'; 9 = 'iSCSI'; 10 = 'SAS'; 11 = 'SATA'; 12 = 'SD'; 13 = 'MMC'
        14 = 'Virtual'; 15 = 'FileBackedVirtual'; 16 = 'Spaces'; 17 = 'NVMe'; 18 = 'MSReserved'
    }
    $MediaTypeMap = @{
        0 = 'Unspecified'; 3 = 'HDD'; 4 = 'SSD'; 5 = 'SCM'
    }

    Get-CimInstance -Namespace root/Microsoft/Windows/Storage -ClassName MSFT_PhysicalDisk |
    ForEach-Object {
        $mediaRaw = $_.MediaType
        $busRaw = $_.BusType

        # robust: Strings/UInt* -> int cast
        $mediaKey = if ($null -ne $mediaRaw) { [int]$mediaRaw } else { $null }
        $busKey = if ($null -ne $busRaw) { [int]$busRaw }   else { $null }

        $mediaTxt = if ($MediaTypeMap.ContainsKey($mediaKey)) { $MediaTypeMap[$mediaKey] } else { "MediaType($mediaRaw)" }
        $busTxt = if ($BusTypeMap.ContainsKey($busKey)) { $BusTypeMap[$busKey] }     else { "BusType($busRaw)" }

        $type = switch ($busKey) {
            17 { if ($mediaKey -eq 4) { 'NVMe SSD' } else { 'NVMe HDD' } }
            11 { if ($mediaKey -eq 4) { 'SATA SSD' } else { 'SATA HDD' } }
            10 { if ($mediaKey -eq 4) { 'SAS SSD' }  else { 'SAS HDD' } }
            7 { if ($mediaKey -eq 4) { 'USB SSD' }  else { 'USB HDD' } }
            default { "$busTxt $mediaTxt" }
        }

        [PSCustomObject]@{
            DeviceId     = $_.DeviceId
            FriendlyName = $_.FriendlyName
            MediaType    = $mediaTxt
            BusType      = $busTxt
            Type         = $type
        }
    }
}
