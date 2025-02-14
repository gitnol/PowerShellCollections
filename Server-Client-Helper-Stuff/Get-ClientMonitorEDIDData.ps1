function Get-ClientMonitorEDIDData {
    param (
        [string]$Computer = "localhost"
    )

    Try {
    $monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ComputerName $Computer -ErrorAction Stop

    $result = foreach ($monitor in $monitors) {
        [PSCustomObject]@{
            Active                 = $monitor.Active
            InstanceName           = $monitor.InstanceName
            Manufacturer           = ([System.Text.Encoding]::ASCII.GetString($monitor.ManufacturerName) -replace '\x00')
            ProductCode            = ([System.Text.Encoding]::ASCII.GetString($monitor.ProductCodeID) -replace '\x00')
            SerialNumber           = ([System.Text.Encoding]::ASCII.GetString($monitor.SerialNumberID) -replace '\x00')
            UserFriendlyName       = ([System.Text.Encoding]::ASCII.GetString($monitor.UserFriendlyName) -replace '\x00')
            UserFriendlyNameLength = $monitor.UserFriendlyNameLength
            WeekOfManufacture      = $monitor.WeekOfManufacture
            YearOfManufacture      = $monitor.YearOfManufacture
            PSComputerName         = $monitor.PSComputerName
        }
    }
    return $result
    } catch {
        $result = [PSCustomObject]@{
            Active                 = ""
            InstanceName           = ""
            Manufacturer           = ""
            ProductCode            = ""
            SerialNumber           = ""
            UserFriendlyName       = ""
            UserFriendlyNameLength = ""
            WeekOfManufacture      = ""
            YearOfManufacture      = ""
            PSComputerName         = ""
        }
        return $result
    }
}

# Get-ClientMonitorEDIDData -Computer "MYHOSTNAME"