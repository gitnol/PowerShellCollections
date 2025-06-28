function Invoke-RunAsElevated {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$User
    )
    & runas.exe /noprofile /user:$User `
        'pwsh -ExecutionPolicy Bypass -NoProfile -Command "& { Start-Process pwsh -Verb RunAs }"'
}

function elevate {
    Invoke-RunAsElevated -User 'MYDOMAIN\MYUSER' | Out-Null
}

# Manuelle Option: OneLiner (aus Powershell): 
# & runas.exe /env /user:MYDOMAIN\MYUSER 'pwsh -ExecutionPolicy Bypass -NoProfile -Command "& { Start-Process pwsh -Verb RunAs }"'

# Zweite Option: OneLiner aus cmd:
# start "Start Powershell Elevated" pwsh -ExecutionPolicy Bypass -NoProfile -Command "& { Start-Process pwsh -Verb RunAs }"