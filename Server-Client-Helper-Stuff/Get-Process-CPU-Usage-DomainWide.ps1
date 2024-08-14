# This script queries remotely the top X process and collect these. 
# You get a view and maybe see processes which have unnormal high cpu usage on the computers
# just sort by the process name and / or the cpu usage
# this was just a Proof-Of-Concept.

# Powershell 7 is mandatory

# Import the Active Directory module if not already imported
Import-Module ActiveDirectory


# Define the credentials to use for authentication
if (-not $credential) {
	$credential = Get-Credential
}

# Hole die hungrigsten Prozesse von den Servern / Rechnern
# Define the number of top CPU-consuming processes to display
$topN = 10

# Clients
$mycomputers = Get-ADComputer -Filter {OperatingSystem -notlike '*Server*' -and operatingSystem -like '*Windows*' -and Enabled -eq 'True'} -Property OperatingSystem, IPv4Address,Name | Select-Object -ExpandProperty Name
# Server
$mycomputers = Get-ADComputer -Filter {OperatingSystem -like '*Server*'} -Property OperatingSystem, IPv4Address
# $mycomputers  = $mycomputers | Where {($_.Name -like "SVRCXVAD0*") -or ($_.Name -like "SVR*XEN*")}

# # Get all AD computers with a server operating system
# $servers = Get-ADComputer -Filter {OperatingSystem -like '*Server*'} -Property OperatingSystem, IPv4Address

# Computernames which are currently Online or Offline.
$mycomputersOnline = @()

# Array to hold online servers as AD Computer Object, with which is being worked
$onlineServers = @()

# $mycomputersOnline = $mycomputers | ForEach-Object -Parallel {
# Test-Connection -ComputerName $_ -Count 1 -Quiet -TimeoutSeconds 1 -ErrorAction SilentlyContinue
# }
# # Get all AD computers with a server operating system
# $servers = Get-ADComputer -Filter {OperatingSystem -like '*Server*'} -Property OperatingSystem, IPv4Address

# # Loop through each server and check if it's online
# foreach ($server in $servers) {
# #Write-Host("Try: $server.Name") -ForegroundColor Yellow
# if (Test-Connection -ComputerName $server.Name -Count 1 -Quiet -TimeoutSeconds 1) {
	# $onlineServers += $server
# Write-Host("Try: $($server.Name)") -ForegroundColor Green
# } else {
# Write-Host("Try: $($server.Name)") -ForegroundColor Red
# }
# }

# # Output the list of online servers
# $onlineServers | Select-Object Name, OperatingSystem, IPv4Address
# # Define the list of remote servers
# $remoteServers = $onlineServers.DNSHostName

# $mycomputersOnline = $mycomputers | ForEach-Object -Parallel {
# [pscustomobject]@{Name=$_;Online=Test-Connection -ComputerName $_ -Count 1 -Quiet -TimeoutSeconds 1 -ErrorAction SilentlyContinue}
# } #-ThrottleLimit 10

# # Get DNSHostNames from the AD
# $onlineServers = (($mycomputersOnline | Where-Object Online -eq $True).Name | Get-ADComputer)
$mycomputersOnline = $mycomputers | ForEach-Object -Parallel {
	[pscustomobject]@{Name=$_;Online=Test-Connection -ComputerName $_.DNSHostName -Count 1 -Quiet -TimeoutSeconds 1}
} #-ThrottleLimit 10
	
# Get DNSHostNames from the AD
$onlineServers = (($mycomputersOnline | Where-Object Online -eq $True).Name).DistinguishedName | Get-ADComputer

if ($PSVersionTable.PSVersion.Major -ne 7) {
	Write-Error("Bitte Powershell Version 7 nutzen")
	Exit(1)
} else {

	# Script block to get top CPU-consuming processes
	$scriptBlock = {
		param($topN)
		

	Try {
		# Retrieve process information
		$processes = Get-CimInstance -ClassName Win32_Process
		} catch {
			Write-Error ("Fehler bei Get-CimInstance -ClassName Win32_Process bei : " + $env:computername)
		}

	Try {
		# Retrieve CPU usage information
		$cpuUsage = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process
		} catch {
			Write-Error ("Fehler bei Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process bei : " + $env:computername)
		}

	if ($processes -and $cpuUsage) {
		# Combine the data
		$results = $processes | ForEach-Object {
			$process = $_
			$cpu = $cpuUsage | Where-Object { $_.IDProcess -eq $process.ProcessId }
			try {
				$cpuwert=if($cpu){$cpu.PercentProcessorTime} else {0}
				[PSCustomObject]@{
					ProcessName = $process.Name
					ProcessId = $process.ProcessId
					CPUUsage = [int]$cpuwert
				}
			} catch {}
		} # Ende ForEach-Object

		# Output the results
		$results | Where-Object CPUUsage -gt 0 |Sort-Object -Descending -Property CPUUsage,ProcessName,ProcessId -Unique | Select-Object -First $topN
		} else {
			[PSCustomObject]@{
				ProcessName = "FEHLER"
				ProcessId = 0
				CPUUsage = 9999
			}
		}
	} # Ende Scriptblock

	# Run the script block on all servers in parallel
	$results = Invoke-Command -ComputerName ($onlineServers.DNSHostName) -Credential $credential -ScriptBlock $scriptBlock -ArgumentList $topN

	# Display the results
	$results | Out-GridView
}
