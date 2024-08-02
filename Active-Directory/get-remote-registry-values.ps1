# Get the remote registry Value of online computers, 
# which have logged on to the domain at least once in the last xxx days

# Import the Active Directory module
Import-Module ActiveDirectory

$ergebnis = @()
$online = @()
$regPath = "HKLM:\SOFTWARE\SolidWorks\Applications\PDMWorks Enterprise"
$regName = "PTID"

# Define the time range (last 3 days)
$timeLimit = (Get-Date).AddDays(-30)


# Nothing has to be changed below this line
$computers = Get-ADComputer -Filter 'operatingSystem -like "Windows*" -and Enabled -eq "True"' -Property Name, LastLogonTimestamp, DNSHostName | Where-Object {
    $_.LastLogonTimestamp -ne $null -and ([datetime]::FromFileTime($_.LastLogonTimestamp) -gt $timeLimit)
} # | Where-Object Name -eq "mycomputer-to-test"

$computers.DNSHostName | ForEach-Object {
    If ((Test-NetConnection $_ -InformationLevel Quiet)) { # TODO: This should be done in parallel.
        
        $machineName = $_
        $IP2Host = ""
        $hostEntry = ""
        $ipAddress = ""
        $hostEntry = [System.Net.Dns]::GetHostByName($machineName)
        $ipAddress = $hostEntry.AddressList[0].IPAddressToString
        $IP2Host = [System.Net.Dns]::GetHostByAddress($ipAddress).Hostname

        Write-Host("Processing " + $machineName) -ForegroundColor Green

        if ($IP2Host.ToLower() -ne $machineName.ToLower()) {
            # Prevent DNS Problems. Lookup host to ip and ip to host... 
            Write-Host($machineName + " has the IP-Address " + $ipAddress) -ForegroundColor Red
            Write-Host("The IP-Address is resolvable to  " + $IP2Host + "") -ForegroundColor Red
        } else {
            $online += $_
            $ergebnis += Invoke-Command -ComputerName $_ -ScriptBlock { 
                [PSCustomObject]@{
                    Computername = $env:COMPUTERNAME
                    RegValue    = (Get-ItemProperty -Path $Using:regPath -Name $Using:regName -ErrorAction SilentlyContinue)."$Using:regName"
                }
            }
        }
        Write-Host("Processing " + $machineName + "... Finished!") -ForegroundColor Green
    }
}

$ergebnis | Out-GridView -Title "Registry Values of the computers"
$online | Out-GridView -Title "Online Computers"

