function Invoke-RunAsElevated {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$User
    )
    
    # What does this function do?
    # 1. Determine the PowerShell executable that is currently running the script.
    # 2. Prepare a command (new powershell or pwsh.exe) to start a new PowerShell session with elevated privileges.
    # 3. Encode the command (new powershell or pwsh.exe) to be run in the elevated session.
    # 4. Use runas.exe to start a new PowerShell session with the specified user.
    # 5. The new session will run the command with elevated privileges.

    # Which PowerShell is running this script?
    # This is needed to ensure that the correct PowerShell executable is used when starting a new elevated session.
    # This is especially important when running this script from a non-elevated PowerShell session
    $wp = '"' + (Get-Process -Id $PID).Path + '"'
    # If the script is running in a PowerShell Core session, use pwsh instead of powershell
    if ($wp -like '*pwsh.exe*') {
        Write-Host "pwsh.exe detected: $wp"
    } elseif ($wp -like '*powershell.exe*') {
        Write-Host "powershell.exe detected: $wp"
    } else {
        Write-Error "Unknown PowerShell executable: $wp"
        return
    }
    # Prepare the command to be run in the elevated session
    # We will use Start-Process to start a new PowerShell session with the -Verb RunAs option
    # This will prompt the user for elevation if the current session is not elevated
    $cmd = 'Start-Process ' + $wp + ' -Verb RunAs'
    
    # Encode the command to be run in the elevated session
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    
    # Prepare the runas command with the encoded command
    # Note: runas.exe does not support -EncodedCommand, so we need to use a workaround
    # We will use runas.exe to start a new PowerShell session with the specified user
    $runasCommand = $wp + ' -EncodedCommand ' + $encoded
    
    # Start the runas command with the specified user
    # We will use the /noprofile option to avoid loading the user's profile, becuause it is not needed
    & runas.exe /noprofile /user:$User $runasCommand
}

function Invoke-RunAsElevatedPwsh {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$User
    )
    & runas.exe /noprofile /user:$User `
        'pwsh -ExecutionPolicy Bypass -NoProfile -Command "& { Start-Process pwsh -Verb RunAs }"'
}

function Invoke-RunAsElevatedPowershell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$User
    )
    & runas.exe /noprofile /user:$User `
        'powershell -ExecutionPolicy Bypass -NoProfile -Command "& { Start-Process powershell -Verb RunAs }"'
}

function elevate {
    Invoke-RunAsElevated -User 'MYDOMAIN\MYUSER' | Out-Null
}

# Manuelle Option: OneLiner (aus Powershell): 
# & runas.exe /env /user:MYDOMAIN\MYUSER 'pwsh -ExecutionPolicy Bypass -NoProfile -Command "& { Start-Process pwsh -Verb RunAs }"'

# Zweite Option: OneLiner aus cmd:
# start "Start Powershell Elevated" pwsh -ExecutionPolicy Bypass -NoProfile -Command "& { Start-Process pwsh -Verb RunAs }"