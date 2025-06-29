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

$onlyServers = (Get-ADComputer -Filter { OperatingSystem -like '*Windows*' -and OperatingSystem -like '*Server*' -and Enabled -eq 'True' } -Property DNSHostName).DNSHostName
$onlyServersonlineStatus = Get-ComputerOnlineStatus -Computers ($onlyServers) -numberConcurrentJobs 20 -pingCounts 1
$onlyServersonlineStatus | Where-Object Online -eq $true |  Out-GridView

$onlyClients = (Get-ADComputer -Filter { OperatingSystem -like '*Windows*' -and OperatingSystem -notlike '*Server*' -and Enabled -eq 'True' } -Property DNSHostName).DNSHostName
$onlyClientsonlineStatus = Get-ComputerOnlineStatus -Computers ($onlyClients) -numberConcurrentJobs 20 -pingCounts 1
# $onlineStatus = Get-ComputerOnlineStatus -Computers ($computers | Select-Object -first 10) -numberConcurrentJobs 10 -pingCounts 1
$onlyClientsonlineStatus | Where-Object Online -eq $true |  Out-GridView

# this function is a huge win against this here:
# $onlyClients | ForEach-Object {
#         $a = Test-Connection -ComputerName $_ -Count 1 -TimeoutSeconds 1 -IPv4 -ErrorAction SilentlyContinue; 
#         if ($a.Status -eq "Success") {
#             $a | Select-Object -Property Source, Destination, Address, Status
#         }
#     }