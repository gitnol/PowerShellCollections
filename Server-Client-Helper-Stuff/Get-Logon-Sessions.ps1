# This function returns the logged in users on multiple remote computers and uses the process information of the explorer.exe
# It can differentiate between Console and RDP Sessions.
function Get-LoggedInUsers {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ComputerNames
    )
    foreach ($ComputerName in $ComputerNames) {
        # Check if the computer is online
        if ((Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
            try {
                # Query the Win32_Process CIM class to get all 'explorer.exe' processes
                $processes = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop -ComputerName $ComputerName
                $logonType = "" 
                foreach ($process in $processes) {
                    $processId = $process.ProcessId
                    $logonSessions = Get-CimInstance -Query "Associators of {Win32_Process='$processId'} Where Resultclass = Win32_LogonSession Assocclass = Win32_SessionProcess" -ComputerName $ComputerName
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
        } else {
            [pscustomobject]@{
                userDomain = ""
                userName   = ""
                SessionID  = ""
                logonType  = ""
                online     = $false
                success    = $false
            }
            # If the computer is not online, return an error message
            Write-Error "ERROR: Computer is not pingable"
        }
    }
}
