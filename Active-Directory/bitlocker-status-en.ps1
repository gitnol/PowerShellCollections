# Force Usage of Powershell Version 6 or Higher
if ($PSVersionTable.PSVersion.Major -le 6) {
    pwsh $MyInvocation.InvocationName
} else {
    # Last Change: 20230309
    # Added essential info to $AD_Bitlocker_Information
    $CompList = @()
    $AD_Bitlocker_Information = @()
    $CompList = Get-ADComputer -Filter 'operatingSystem -like "Windows*" -and Enabled -eq "True"' -Properties *
    #$CompList = Get-ADComputer 980A1C-M 

    # Step 1: Collect BitLocker information from the ACTIVE DIRECTORY for all active Windows computers
    Foreach ($CL in $CompList) {
        # For each computer, get the recovery info (can be multiple recovery passwords).
        $Bitlocker_Object = Get-ADObject -Filter { objectclass -eq 'msFVE-RecoveryInformation' } -SearchBase $CL.DistinguishedName -Properties 'msFVE-RecoveryPassword'
        # $Bitlocker_Object | ogv
        # Create a separate entry in $AD_Bitlocker_Information for each recovery password.
        $Bitlocker_Object | ForEach-Object {
            $keyCount = $Bitlocker_Object.'msFVE-RecoveryPassword'.Count
            $AD_Bitlocker_Information += [PSCustomObject]@{
                ComputerName                  = $CL.Name
                Description                   = $CL.description
                BitlockerKeyCount             = $keyCount
                BitlockerKeyRecoveryPasswords = $_.'msFVE-RecoveryPassword'
                ComputerDistinguishedName     = $CL.DistinguishedName
                msFVE_DN_KeyID                = ((($_.DistinguishedName).split(",")[0]).split('{')[1]).split('}')[0]
                msFVE_DN_TimeStamp            = $date = [DateTime]::Parse(((($_.DistinguishedName).split(",")[0]).split('{')[0]).split('=')[1].replace('\', ''))
            }
        }
    }

    # Step 2: Collect BitLocker information LOCALLY from all active Windows computers that are online
    $OnlineComputerBitlockerInfos = @()
    # All computers with BitLocker!
    # $AD_Bitlocker_Information | Where {$_.BitlockerKeyCount -gt 0}
    # Execute for all computers with BitLocker info in AD
    $OnlineComputerBitlockerInfos += (($AD_Bitlocker_Information | Where-Object { $_.BitlockerKeyCount -gt 0 }).ComputerName | Sort-Object -Unique) | ForEach-Object -Parallel {	
        if (Test-Connection -BufferSize 32 -Count 1 -ComputerName $_ -Quiet) {
            Write-Host("Processing $_") -ForegroundColor Green
            # These computers are online. Now get the local password of the computer and return it.
            [PSCustomObject]@{
                ComputerName           = $_
                Local_RecoveryPassword = (Invoke-Command -ComputerName $_ -ScriptBlock { (Get-BitLockerVolume -MountPoint C:).KeyProtector.RecoveryPassword } | Where-Object { $_ })
                VolumeStatus_C         = (Invoke-Command -ComputerName $_ -ScriptBlock { (Get-BitLockerVolume -MountPoint C:).VolumeStatus }).Value
            }
            Write-Host("Processing $_ ... DONE!!!") -ForegroundColor Green
        } else {
            Write-Host("Host Offline $_") -ForegroundColor Red
        }
    }

    # Step 3: Compare the information from LOCAL and AD and output it
    $result = @()
    $OnlineComputerBitlockerInfos | ForEach-Object {
        $current_computer = $_.ComputerName
        $current_bitlocker_password = $_.Local_RecoveryPassword | Where-Object { $_ }
        $current_VolumeStatus_C = $_.VolumeStatus_C
        # Write-Host ($current_computer,$current_bitlocker_password) -ForegroundColor Green
        # Filter the recovery passwords for the respective computer and add the local recovery password to the result array.
        $AD_Bitlocker_Information | Where-Object { $_.ComputerName -eq $current_computer } | ForEach-Object {
            $_ | ForEach-Object {
                $currentBitlockerKeyRecoveryPassword = $_.BitlockerKeyRecoveryPasswords
                $currentmsFVE_DN_KeyID = $_.msFVE_DN_KeyID
                $currentmsFVE_DN_TimeStamp = $_.msFVE_DN_TimeStamp
                $result += [PSCustomObject]@{
                    ComputerName            = $current_computer
                    AD_Bitlocker_Password   = $currentBitlockerKeyRecoveryPassword
                    Local_BitlockerPassword = $current_bitlocker_password
                    Identical               = ($currentBitlockerKeyRecoveryPassword -eq $current_bitlocker_password)
                    VolumeStatus_C          = $current_VolumeStatus_C
                    msFVE_DN_KeyID          = $currentmsFVE_DN_KeyID
                    msFVE_DN_TimeStamp      = $currentmsFVE_DN_TimeStamp
                }
            }
        } 
    }

    $AD_Bitlocker_Information | Out-GridView -Title "All BitLocker Information from AD"
    $result | Out-GridView -Title "Comparison Table between Local and AD Information"
    $OnlineComputerBitlockerInfos | Out-GridView -Title "All BitLocker Information from ONLINE Computers"
}
