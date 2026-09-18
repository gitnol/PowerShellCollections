# # This is also functioning for powershell 5 where "foreach-object -parallel" is missing

# In Powershell > 6 this function makes it easier
function Test-ConnectionInParallel {
    # Only Powershell 6 and above (because of ForEach-Object -Parallel)
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 0)]
        [string[]]$ComputerNames,
        [Parameter(Mandatory = $false)]
        [int]$throttlelimit = 10
    )
    $ComputerNames | ForEach-Object -Parallel {
        Write-Progress -Activity "Checking computer online status" -Status "$_"
        [pscustomobject]@{ComputerName = $_; Online = Test-Connection -ComputerName $_ -Count 1 -Quiet -TimeoutSeconds 1; IP = (Test-Connection -ComputerName $_ -Count 1 -TimeoutSeconds 1 -ErrorAction SilentlyContinue).Address.IPAddressToString }
    } -ThrottleLimit $throttlelimit
}

function Get-ComputerOnlineStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false)]
        [string[]]$Computers,
        [Parameter(Mandatory = $False, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$numberConcurrentJobs = 12,
        [Parameter(Mandatory = $False, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$pingCounts = 2
    )

    # Initialize an array to hold jobs
    $jobs = @()
    $totalComputers = $Computers.Count
    $jobsStarted = 0

    # Loop through each computer and create a job to check the online status
    foreach ($computer in $Computers) {
        # Throttling mechanism to ensure no more than 6 jobs run at a time
        while ((Get-Job -State Running).Count -ge $numberConcurrentJobs) {
            $runningJobsCount = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
            Write-Host ("# of jobs still running: {0} (Waiting for one job to complete)" -f $runningJobsCount)
            $now = Get-Date
            foreach ($job in (Get-Job -State Running)) {
                # Check if the job has been running for more than 2 minutes
                if ($now - (Get-Job -Id $job.Id).PSBeginTime -gt [TimeSpan]::FromMinutes(2)) {
                    Stop-Job $job
                    Write-Host "Stopped job $($job.Id) due to timeout."
                }
            }
            # Pause to prevent rapid polling
            Start-Sleep -Seconds 1
        }

        Write-Host ("Start-Job for computer {0}" -f $computer)
        # Start the job and add it to the jobs array
        $jobs += Start-Job -ScriptBlock {
            [pscustomobject]@{
                Computer = $using:computer
                Online   = Test-Connection -ComputerName $using:computer -Count $using:pingCounts -Quiet
                IP       = (Test-Connection -ComputerName $using:computer -Count 1 -IPv4).Address.IPAddressToString
            }
        }

        # Increment the jobsStarted counter
        $jobsStarted++

        # Update progress
        Write-Progress -Activity "Checking computer online status" `
            -Status "Starting job $jobsStarted of $totalComputers" `
            -PercentComplete (($jobsStarted / $totalComputers) * 100)
    }

    # Monitor the remaining jobs until they complete
    While ($jobs | Where-Object { $_.State -eq 'Running' }) {
        $runningJobsCount = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
        Write-Host ("# of jobs still running: {0}" -f $runningJobsCount)

        # Throttling check during remaining job monitoring
        $now = Get-Date
        foreach ($job in @(Get-Job -State Running)) {
            if ($now - (Get-Job -Id $job.Id).PSBeginTime -gt [TimeSpan]::FromMinutes(2)) {
                Stop-Job $job
                Write-Host "Stopped job $($job.Id) due to timeout."
            }
        }

        # Pause to prevent rapid polling
        Start-Sleep -Seconds 2
    }

    # Collect and display the results
    $results = $jobs | Receive-Job

    # Clean up the jobs
    $jobs | Remove-Job

    # Return the results
    return $results | Select-Object Computer, Online, IP
}

# Example usage:
# $computers = @('Computer1', 'Computer2', 'Computer3', 'Computer4', 'Computer5', 'Computer6', 'Computer7', 'Computer8')

# $computers = (Get-ADComputer -Filter { OperatingSystem -like '*Windows*' -and Enabled -eq 'True' } -Property DNSHostName).DNSHostName
# $onlineStatus = Get-ComputerOnlineStatus -Computers $computers

$allServers = (Get-ADComputer -Filter { OperatingSystem -like '*Windows*' -and OperatingSystem -like '*Server*' -and Enabled -eq 'True' } -Property DNSHostName, Description)
$onlyServers = $allServers.DNSHostName
$onlyServersonlineStatus = Get-ComputerOnlineStatus -Computers ($onlyServers) -numberConcurrentJobs 20 -pingCounts 1

$allClients = (Get-ADComputer -Filter { OperatingSystem -like '*Windows*' -and OperatingSystem -notlike '*Server*' -and Enabled -eq 'True' } -Property DNSHostName, Description)
$onlyClients = $allClients.DNSHostName
$onlyClientsonlineStatus = Get-ComputerOnlineStatus -Computers ($onlyClients) -numberConcurrentJobs 32 -pingCounts 1
# $onlineStatus = Get-ComputerOnlineStatus -Computers ($computers | Select-Object -first 10) -numberConcurrentJobs 10 -pingCounts 1

# this function is a huge win against this here:
# $onlyClients | ForEach-Object {
#         $a = Test-Connection -ComputerName $_ -Count 1 -TimeoutSeconds 1 -IPv4 -ErrorAction SilentlyContinue; 
#         if ($a.Status -eq "Success") {
#             $a | Select-Object -Property Source, Destination, Address, Status
#         }
#     }


# Iteriere durch jedes Element in $onlyClientsonlineStatus
foreach ($client in $onlyClientsonlineStatus) {
    # Finde den passenden Computer in $allClients basierend auf dem Computer-Namen
    $matchingClient = $allClients | Where-Object { $_.DNSHostName -eq $client.Computer }

    # Wenn ein passender Computer gefunden wurde, füge die Description hinzu
    if ($matchingClient) {
        # Erstelle ein neues PSCustomObject mit der Description
        $client | Add-Member -MemberType NoteProperty -Name "Description" -Value $matchingClient.Description
    }
}

# online Servers
$onlyServersonlineStatus | Where-Object Online -eq $true |  Out-GridView

# offline Servers? please check
$onlyServersonlineStatus | Where-Object Online -ne $true |  Out-GridView


# online clients (at weekends should be powered off, shouldn't they?)
$onlyClientsonlineStatus | Where-Object Online -eq $true |  Out-GridView

# offline clients
$onlyClientsonlineStatus | Where-Object Online -ne $true |  Out-GridView


# # Should the clients be powered off?
# $scriptBlock = {Stop-Computer -Force -WhatIf}
# # Scriptblock könnte auch sowas sein wie check-inactive-idle-sessions.ps1, damit man die Idle Zeit prüft vorher.

# $arbeitsliste = $onlyClientsonlineStatus | Where-Object Online -eq $true |  Out-GridView -PassThru
# Invoke-Command -ComputerName $arbeitsliste.Computer -ScriptBlock $scriptBlock


$computers = ($onlyClientsonlineStatus | Where-Object Online -eq $true).Computer
# Define the throttle limit for parallel execution
$throttleLimit = 32
# Define the script block to get network cards information
$credentials = Get-Credential -Message "Please enter credentials for remote access to the computers"

# This script block will be executed on each remote computer to get network card information
$scriptBlockNetworkCards = {
    Get-NetAdapter |
    Where-Object { $_.Status -eq 'Up' } |
    Select-Object -Property Name, MacAddress |
    ForEach-Object {
        [PSCustomObject]@{
            AdapterName = $_.Name
            MACAddress  = $_.MacAddress
        }
    }
}

$allenetzwerkkarten = @()
$allenetzwerkkarten += Invoke-Command -ComputerName ($computers | Where-Object { $_ }) -ThrottleLimit $throttleLimit -ScriptBlock $scriptBlockNetworkCards -Credential $credentials
