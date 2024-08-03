# File to which the processes should be exported to in "json" format.
$global:mylogfileJson = "C:\install\test.json"


$action = {
    param ($EnableRaisingEvents, $event)
    $logfileJson = $global:mylogfileJson

    if ($event.NewEvent.ToString() -eq "__InstanceCreationEvent") {
        foreach ($item in ($event.NewEvent.TargetInstance | Select-Object -Property *)) {
            Write-Host("Prozess gestartet {0}" -f $item.ProcessName) -ForegroundColor Green
            # Write-Host($item | Select -Property * | Format-Table -Property * | Out-String) -ForegroundColor Green
            # Write-Host($item | Select -Property * | Format-List -Property * | Out-String) -ForegroundColor Green
            $item | Select-Object -Property @{Name = "EventType"; Expression = { "__InstanceCreationEvent" } }, * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue | Out-File -Append -FilePath $logfileJson -Encoding utf8
        }	
    }
    if ($event.NewEvent.ToString() -eq "__InstanceDeletionEvent") {
        foreach ($item in ($event.NewEvent.TargetInstance | Select-Object -Property *)) {
            Write-Host("Prozess entfernt {0}" -f $item.ProcessName) -ForegroundColor Red
            # Write-Host($item | Select -Property * |Format-Table -Property *| Out-String) -ForegroundColor Red
            # Write-Host($item | Select -Property * |Format-List -Property *  | Out-String) -ForegroundColor Red
            $item | Select-Object -Property @{Name = "EventType"; Expression = { "__InstanceDeletionEvent" } }, * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue | Out-File -Append -FilePath $logfileJson -Encoding utf8
        }
    }
}

# Register event for process creation
Register-CimIndicationEvent -Namespace root/cimv2 -Query "SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_Process'" -SourceIdentifier ProcessCreation -Action $action

# Register event for process termination
Register-CimIndicationEvent -Namespace root/cimv2 -Query "SELECT * FROM __InstanceDeletionEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_Process'" -SourceIdentifier ProcessDeletion -Action $action

# # Keep the script running to listen for events
Write-Host("Listening for process start and stop events. Press Any Key to exit.")
Write-Host("LogFile: $logfileJson")

$sec = 0 
do {
    Write-Host -ForegroundColor Green "$sec Sec"
    Start-Sleep -Seconds 1
    $sec++    
} until ([System.Console]::KeyAvailable)

# Remove the registered Events
Get-EventSubscriber | Unregister-Event

# Einlesen
$Allprocesses = @(); Get-Content -Path $logfileJson | ForEach-Object { $Allprocesses += $_ | ConvertFrom-Json }
$Allprocesses | Out-GridView
