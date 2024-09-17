function Set-ServiceStartupType {
    param (
        [string]$ServiceName,
        [ValidateSet('Manual', 'Automatic', 'AutomaticDelayedStart', 'Disabled', 'm', 'a', 'ad', 'd')]
        [string]$StartupType
    )

    # Mapping of abbreviations to full names
    switch ($StartupType.ToLower()) {
        'm' { $startMode = 'demand' }
        'manual' { $startMode = 'demand' }
        'a' { $startMode = 'auto' }
        'automatic' { $startMode = 'auto' }
        'ad' { $startMode = 'delayed-auto' }
        'automaticdelayedstart' { $startMode = 'delayed-auto' }
        'd' { $startMode = 'disabled' }
        'disabled' { $startMode = 'disabled' }
    }

    # Execute sc.exe and capture the output and exit code
    $process = Start-Process "sc.exe" -ArgumentList "config $ServiceName start= $startMode" -NoNewWindow -Wait -PassThru
    $exitCode = $process.ExitCode

    # Return exit code
    return $exitCode
}

# Usage examples:
# $exitCode = Set-ServiceStartupType -ServiceName "wuauserv" -StartupType "m"
# Write-Output "Exit Code: $exitCode"

# # Usage examples:
# Set-ServiceStartupType -ServiceName "wuauserv" -StartupType "m"       # Set to Manual
# Set-ServiceStartupType -ServiceName "wuauserv" -StartupType "a"       # Set to Automatic
# Set-ServiceStartupType -ServiceName "wuauserv" -StartupType "ad"      # Set to Automatic (Delayed Start)
# Set-ServiceStartupType -ServiceName "wuauserv" -StartupType "d"       # Set to Disabled

# Set-ServiceStartupType -ServiceName "wuauserv" -StartupType "manual"  # Set to Manual
# Set-ServiceStartupType -ServiceName "wuauserv" -StartupType "automatic" # Set to Automatic
# Set-ServiceStartupType -ServiceName "wuauserv" -StartupType "automaticdelayedstart" # Set to Automatic (Delayed Start)
# Set-ServiceStartupType -ServiceName "wuauserv" -StartupType "disabled"  # Set to Disabled
