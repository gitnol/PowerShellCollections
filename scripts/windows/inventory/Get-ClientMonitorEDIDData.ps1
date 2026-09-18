function Get-ClientMonitorEDIDData {
    param (
        [string]$Computer = "localhost"
    )

    Try {
    $monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ComputerName $Computer -ErrorAction Stop
    $connections = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams -ComputerName $Computer -ErrorAction Stop

    $result = foreach ($monitor in $monitors) {
        $connection = $connections | Where-Object { $_.InstanceName -eq $monitor.InstanceName }
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
            ConnectionType         = Switch ($connection.VideoOutputTechnology) {
                -2 { "Uninitialized" }
                -1 { "Other" }
                 0 { "HD15 (VGA)" }
                 1 { "S-Video" }
                 2 { "Composite Video (RF)" }
                 3 { "Component Video (RCA/BNC)" }
                 4 { "DVI" }
                 5 { "HDMI" }
                 6 { "LVDS" }
                 8 { "D-JPN" }
                 9 { "SDI" }
                10 { "DisplayPort External" }
                11 { "DisplayPort Embedded" }
                12 { "UDI External" }
                13 { "UDI Embedded" }
                14 { "SDTV Dongle" }
                15 { "Miracast" }
                16 { "Indirect Wired" }
             0x80000000 { "Internal" }
                default { "Unknown" }
            }
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
            ConnectionType         = ""
            PSComputerName         = ""
        }
        return $result
    }
}

# Get-ClientMonitorEDIDData -Computer "MYHOSTNAME"

# Example to use the Scriptblock of the function for remote execution on one computer. On the Computer the script runs and the parameter Computer is then "localhost"
# Invoke-Command -ScriptBlock (Get-Command Get-ClientMonitorEDIDData).ScriptBlock -ComputerName MYHOST

# Use this knowledge to execute the function on many computers and then collect this for further analysis... (see Get-TasksAndServices.ps1)
# $allemonitore = @()
# $allemonitore += Invoke-Command -ComputerName ($computers | Where-Object {$_}) -ThrottleLimit $throttleLimit -ScriptBlock (Get-Command Get-ClientMonitorEDIDData).ScriptBlock -Credential $credentials