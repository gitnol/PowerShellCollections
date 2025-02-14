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

# Example to use the Scriptblock of the function for remote execution on one computer. On the Computer the script runs and the parameter Computer is then "localhost"
# Invoke-Command -ScriptBlock (Get-Command Get-ClientMonitorEDIDData).ScriptBlock -ComputerName PRDEDV15

# Use this knowledge to execute the function on many computers and then collect this for further analysis... (see Get-TasksAndServices.ps1)
# $allemonitore = @()
# $allemonitore += Invoke-Command -ComputerName ($computers | Where-Object {$_}) -ThrottleLimit $throttleLimit -ScriptBlock (Get-Command Get-ClientMonitorEDIDData).ScriptBlock -Credential $credentials