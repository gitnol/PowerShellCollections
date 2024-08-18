# This function returns the logged in users on multiple remote computers and uses the process information of the explorer.exe
# It can differentiate between Console and RDP Sessions.
# Perhaps it would be better to do this with Invoke-Command

function Get-LoggedInUsers {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ComputerNames,
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )
    begin {

    }
    process {
        foreach ($ComputerName in $ComputerNames) {
            # Check if the computer is online
            if ((Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
                try {
                    # Query the Win32_Process CIM class to get all 'explorer.exe' processes
                    if ($Credential) {
                        $myCIMSession = New-CimSession -ComputerName $ComputerName -Credential $Credential
                    } else {
                        $myCIMSession = New-CimSession -ComputerName $ComputerName
                    }
                    if ((($env:COMPUTERNAME).ToLower() -eq $ComputerName.ToLower()) -or (-not $myCIMSession)) {
                        $processes = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" # -ComputerName $ComputerName
                    } else {
                        $processes = Get-CimInstance -CimSession $myCIMSession  -ClassName Win32_Process -Filter "Name = 'explorer.exe'" # -ComputerName $ComputerName
                    }

                    $logonType = "" 
                    foreach ($process in $processes) {
                        $processId = $process.ProcessId
                        if ((($env:COMPUTERNAME).ToLower() -eq $ComputerName.ToLower()) -or (-not $myCIMSession)) {
                            # There seems to be a bug within Get-CimInstance using a CimSession when the Host queried is the local Computer where the script is running
                            # beside that... the local query without cimsession is faster.
                            $logonSessions = Get-CimInstance -Query "Associators of {Win32_Process='$processId'} Where Resultclass = Win32_LogonSession Assocclass = Win32_SessionProcess" # -ComputerName $ComputerName
                        } else {
                            $logonSessions = Get-CimInstance -CimSession $myCIMSession -Query "Associators of {Win32_Process='$processId'} Where Resultclass = Win32_LogonSession Assocclass = Win32_SessionProcess" # -ComputerName $ComputerName
                        }
                        
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
                            ComputerName = $ComputerName
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
                        ComputerName = $ComputerName
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
                    ComputerName = $ComputerName
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
    end {
        if (Get-CimSession) {
            Get-CimSession | Remove-CimSession
        }
    }
}
