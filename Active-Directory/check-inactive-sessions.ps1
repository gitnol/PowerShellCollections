# I have added this script to reddit on 20240803

function Get-SessionIDReadIOCounts {
    # Query Win32_Process to get all processes and their session IDs
    $processes = Get-CimInstance -ClassName Win32_Process
    
    # Select and display unique session IDs
    $sessionIds = $processes | Select-Object -Unique SessionId
    $sessionIds = $sessionIds | Where-Object SessionId -ne 0 # Exclude Session 0
    
    $sessionIds | ForEach-Object {
        $sessionId = $_.SessionId
        # Query Win32_Process for the process named "csrss.exe" with the specified sessionId
        # source idea: https://www.autoitscript.com/forum/topic/160918-how-to-detect-user-idle-from-system-process-or-service/
        $colItems = Get-CimInstance -Query "SELECT * FROM Win32_Process WHERE Name='csrss.exe' AND SessionId=$sessionId"
    
        # Iterate through each item and return ReadOperationCount
        ForEach ($objItem In $colItems) {
            $myReadIOcount = $objItem.ReadOperationCount
        }
        return [psCustomObject]@{
            sessionID   = $sessionId
            ReadIOCount = $myReadIOcount
        }
    }
}
    
    
$timespan = 10
$firstCheck = Get-SessionIDReadIOCounts
Start-Sleep -Seconds $timespan
$secondCheck = Get-SessionIDReadIOCounts
$comparision = Compare-Object -ReferenceObject $firstCheck -DifferenceObject $secondCheck -Property sessionID, ReadIOCount
if (-not $comparision) {
    Write-Host("No User Interaction in all Sessions for {0} seconds" -f $timespan) -foregroundcolor Red
    # now do your evil stuff and shut down or restart the computer.
}