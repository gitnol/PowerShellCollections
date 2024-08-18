# This function returns the logged in users on multiple remote computers and uses the process information of the explorer.exe
# It can differentiate between Console and RDP Sessions.
# This is the Invoke-Command alternative... in my opinion this is better... you do not need to establish a CIMSession with Credentials first... so the function is leaner

$mysb = {
    try {
        # Query the Win32_Process CIM class to get all 'explorer.exe' processes
        $processes = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop 
        $logonType = "" 
        foreach ($process in $processes) {
            $processId = $process.ProcessId
            $logonSessions = Get-CimInstance -Query "Associators of {Win32_Process='$processId'} Where Resultclass = Win32_LogonSession Assocclass = Win32_SessionProcess"
            foreach ($session in $logonSessions) {
                # Determine the LogonType (e.g., Interactive, Network, Batch, etc.)
                switch ($session.LogonType) {
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
            }
            # Get the owner of the process
            $ownerInfo = $process | Invoke-CimMethod -MethodName GetOwner
                
            # Write the pscustomobject to the pipeline
            [pscustomobject]@{
                userDomain = $ownerInfo.Domain
                userName   = $ownerInfo.User
                SessionID  = $process.SessionID
                logonType  = $logonType
                online     = $true
                success    = $true
            }
        }
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
            online     = $true
            success    = $false
        }
    }
}

$ComputerNames = @("SERVERONE","SERVERTWO")
if (!$credential){
    $credential = Get-Credential
}
if($credential -and $ComputerNames){
    $results = Invoke-Command -ComputerName $ComputerNames -Credential $credential -ScriptBlock $mysb 
    $results | Out-GridView 
}
