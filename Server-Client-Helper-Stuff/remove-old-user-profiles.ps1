function Get-ProfileListInfos() {
    $profilelist = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    $result = @()

    foreach ($p in $profilelist) {
        try {
            $objUser = (New-Object System.Security.Principal.SecurityIdentifier($p.PSChildName)).Translate([System.Security.Principal.NTAccount]).value
        }
        catch {
            $objUser = "[UNKNOWN]"
        }

        Remove-Variable -Force LTH, LTL, UTH, UTL -ErrorAction SilentlyContinue
        $LTH = '{0:X8}' -f (Get-ItemProperty -Path $p.PSPath -Name LocalProfileLoadTimeHigh -ErrorAction SilentlyContinue).LocalProfileLoadTimeHigh
        $LTL = '{0:X8}' -f (Get-ItemProperty -Path $p.PSPath -Name LocalProfileLoadTimeLow -ErrorAction SilentlyContinue).LocalProfileLoadTimeLow
        $UTH = '{0:X8}' -f (Get-ItemProperty -Path $p.PSPath -Name LocalProfileUnloadTimeHigh -ErrorAction SilentlyContinue).LocalProfileUnloadTimeHigh
        $UTL = '{0:X8}' -f (Get-ItemProperty -Path $p.PSPath -Name LocalProfileUnloadTimeLow -ErrorAction SilentlyContinue).LocalProfileUnloadTimeLow

        $LoadTime = if ($LTH -and $LTL) {
            [datetime]::FromFileTime("0x$LTH$LTL")
        }
        else {
            $null
        }
        $UnloadTime = if ($UTH -and $UTL) {
            [datetime]::FromFileTime("0x$UTH$UTL")
        }
        else {
            $null
        }
        $result += [pscustomobject][ordered]@{
            User       = $objUser
            SID        = $p.PSChildName
            Loadtime   = $LoadTime
            UnloadTime = $UnloadTime
        }
    }
    return $result
}


function Resolve-SID {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$sid
    )
    $objUser = (New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount]).value
    return $objUser
}



function Remove-UserProfiles {
    [CmdletBinding(SupportsShouldProcess=$true)]    
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]]$server,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)]
        [PSCredential]$credentials
    )
    $allObj = @()
    
    $test = $WhatIfPreference # Bei WhatIf ist es True, ansonsten False
        
    $allObj += Invoke-Command -ComputerName $server -Credential $credentials -ScriptBlock {
        $computer = $env:COMPUTERNAME
        $testmodus = $using:test
        # Löschen der ungültigen Profile
        $myVALIDLocalPaths = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special } | Select-Object -Property @{Name = "FullName"; Expression = { $_.LocalPath } };
        if ($myVALIDLocalPaths) {
            Get-ChildItem -LiteralPath 'C:\Users' -Directory -Force | Where-Object Name -like "*BACKUP*" | Select-Object FullName  | ForEach-Object { 
                if ($_.FullName -in $myVALIDLocalPaths.FullName) {
                    Write-Host($computer+ ": " + $_.FullName + " is Valid... do not delete") 
                } else {
                    Write-Host($computer + ": " + $_.FullName + "is NOT VALID. Trying to delete...") -ForegroundColor Red
                    Remove-Item $_.FullName -Force -Recurse -WhatIf:$testmodus
                } 
            }
        }
    } 
}

Get-ProfileListInfos
Remove-UserProfiles -server $server -credentials $cred -WhatIf

# Holt einen Username anhand der SID
# Resolve-SID S-1-5-21-123456789-1234567890-1234567890-500

# Funktioniert nicht richtig
# Get-CimInstance -Class Win32_NetworkLoginProfile | Select-Object Name, FullName, @{Name = "LastLogon"; Expression = { [System.Management.ManagementDateTimeConverter]::ToDateTime($_.LastLogon).ToString("dd MMMM yyyy HH:mm:ss") } } | Format-Table

Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special } | Select-Object -Property LocalPath, Loaded, LastUseTime | Format-Table -AutoSize

# Zusammen mit der Funktion Resolve-SID
Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special } | Select-Object -Property LocalPath, LastUseTime, @{Name = "ResolvedSID"; Expression = { Resolve-SID $_.SID } }

# Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special } | Where-Object { $_.CreationTime -lt (get-date).adddays(-60) } | Where-Object { $_.Loaded -eq $false } | Select-Object -Property LocalPath, Loaded | Format-Table -AutoSize
# Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special } | Where-Object { $_.CreationTime -lt (get-date).adddays(-60) } | Where-Object { $_.Loaded -eq $false } | Remove-CimInstance -Verbose #-Confirm:$false

Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special -and $_.LastUseTime -lt (get-date).adddays(-60) -and $_.Loaded -eq $false } | Select-Object -Property LocalPath, LastUseTime 
# Get-CimInstance -ClassName Win32_UserProfile | Select-Object -Property LocalPath, LastUseTime , Special
Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special -and $_.LastUseTime -lt (get-date).adddays(-60) -and $_.Loaded -eq $false } | ForEach-Object { $_.LocalPath + ";" + $_.SID; Remove-CimInstance $_ -Verbose -WhatIf}

# # Löschen der ungültigen Profile (Nur Lokal)
# $myVALIDLocalPaths = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { !$_.Special } | Select-Object -Property @{Name = "FullName"; Expression = { $_.LocalPath } };
# if ($myVALIDLocalPaths) {
#     Get-ChildItem -LiteralPath 'C:\Users' -Directory -Force | Where-Object Name -like "*BACKUP*" | Select-Object FullName  | ForEach-Object { 
#         if ($_.FullName -in $myVALIDLocalPaths.FullName) {
#             Write-Host($_.FullName + " is Valid... do not delete") 
#         } else {
#             Write-Host($_.FullName + "is NOT VALID. Try to delete...") -ForegroundColor Red
#             Remove-Item $_.FullName -Force -Recurse 
#         } 
#     }
# }



