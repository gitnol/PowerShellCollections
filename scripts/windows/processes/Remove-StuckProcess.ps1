function Remove-StuckProcess {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[string]$processName, # Define the process name and the time interval (in seconds)
		[int]$interval = 30 # Change this to the number of seconds you want between checks
	)
	
	begin {
		
	}
	
	process {
		
		$processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
		if ($processes) {
			foreach ($process in $processes) {
				# Get the initial RAM usage of the process
				$initialMemory = $process.WorkingSet64
				# Wait for the specified interval
				Start-Sleep -Seconds $interval
				# Get the RAM usage of the process again
				$finalMemory = (Get-Process -Id $process.Id).WorkingSet64

				# Compare the initial and final memory usage
				if ($initialMemory -ne $finalMemory) {
					Write-Host("Speicher hat sich verändert: {0} {1}" -f $initialMemory, $finalMemory) -ForegroundCOlor Green
					Write-Host($initialMemory)
					return $true
				} else {
					Write-Host("Speicher hat sich NICHT verändert: {0} {1}" -f $initialMemory, $finalMemory) -ForegroundCOlor Red
					# Kill the process if the memory usage hasn't changed
					& taskkill /PID $process.Id /F /T
					Write-Host ("Process {0} ({1}) has been killed due to no change in memory usage." -f $processName, $process.Id)
					return $false
				}
			}
		} else {
			Write-Host ("Process {0} not found " -f $processName) -ForegroundColor Yellow
			return $true
		}
	}
	
	end {
		
	}
}

$processName = "SLDWORKS"
Remove-StuckProcess -processName $processName