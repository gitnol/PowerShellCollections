
# Bug in Powershell for Version 7 (checked on Version 7.4.4) : https://github.com/PowerShell/PowerShell/issues/20829

# This function returns the logged in users on multiple remote computers and uses the process information of the explorer.exe
# It can differentiate between Console and RDP Sessions.
# This is the Invoke-Command alternative... in my opinion this is better... you do not need to establish a CIMSession with Credentials first... so the function is leaner

$mysb = {
    try {
        # Query the Win32_Process CIM class to get all 'explorer.exe' processes
        $processes = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop 
        $logonType = "" 
        $myresults = @()
        foreach ($process in $processes) {
            $processId = $process.ProcessId

            $logonIDofSessionProcess = (gcim Win32_SessionProcess | Where-Object Dependent -like "*$($processid)*").Antecedent.LogonID
            $logonTypeLogonSession = (gcim Win32_LogonSession | Where-Object LogonId -eq $logonIDofSessionProcess)

            # $logonSessions = Get-CimInstance -Query "Associators of {Win32_Process='$processId'} Where Resultclass = Win32_LogonSession Assocclass = Win32_SessionProcess"
            # Determine the LogonType (e.g., Interactive, Network, Batch, etc.)
            switch ($logonTypeLogonSession.LogonType) {
                2 { $logonType = "Interactive (Console)" }
                3 { $logonType = "Network" }
                4 { $logonType = "Batch" }
                5 { $logonType = "Service" }
                7 { $logonType = "Unlock" }
                8 { $logonType = "NetworkCleartext" }
                9 { $logonType = "NewCredentials" }
                10 { $logonType = "RemoteInteractive (RDP)" }
                11 { $logonType = "CachedInteractive" }
                default { $logonType = "Unknown" }
            }
            # Get the owner of the process: 
            $ownerInfo = $process | Invoke-CimMethod -MethodName GetOwner
                
            # Write the pscustomobject to the pipeline
            $myresults += [pscustomobject]@{
                userDomain = $ownerInfo.Domain
                userName   = $ownerInfo.User
                SessionID  = $process.SessionID
                logonType  = $logonType
                StartTime  = $logonTypeLogonSession.StartTime
                online     = $true
                success    = $true
            }
        }
        return ($myresults | Sort-Object -Unique -Property SessionID)
    } catch {
        # If an error occurs, return an empty string
        Write-Error "Exception Message: $($_.Exception.Message)"
        Write-Error "Inner Exception: $($_.Exception.InnerException)"
        Write-Error "Inner Exception Message: $($_.Exception.InnerException.Message)"
        [pscustomobject]@{
            userDomain = ""
            userName   = ""
            SessionID  = ""
            logonType  = ""
            StartTime  = ""
            online     = $true
            success    = $false
        }
    }
}

# $ComputerNames = @("SERVERONE","SERVERTWO")
$ComputerNames = Get-ADComputer -Filter {OperatingSystem -like '*Windows*' -and Enabled -eq 'True'} -Property OperatingSystem, IPv4Address,Name,DNSHostName | Select-Object Name,OperatingSystem,IPv4Address,DNSHostName

# # Only Powershell 7
# $mycomputersOnline = $ComputerNames | ForEach-Object -Parallel {
# 	[pscustomobject]@{DNSHostName=$_.DNSHostName;Online=Test-Connection -ComputerName $_.DNSHostName -Count 1 -Quiet -TimeoutSeconds 1}
# } #-ThrottleLimit 10
# $onlineServers = $mycomputersOnline | Where-Object Online -eq $True | Select-Object DNSHostName

if (!$credential){
    $credential = Get-Credential
}
if($credential -and $ComputerNames){
    $results = Invoke-Command -ComputerName $ComputerNames -Credential $credential -ScriptBlock $mysb 
    $results | Out-GridView 
}
