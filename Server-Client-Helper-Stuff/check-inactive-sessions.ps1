# I have added this script to reddit on 20240803
# https://www.reddit.com/r/PowerShell/comments/8r56tr/getting_idle_time_for_logged_on_domain_users/

# Also added it as answer here:
# https://stackoverflow.com/questions/1219050/getlastinputinfo-is-user-specific-is-there-something-similar-which-gives-machi/78827409#78827409

# You can use an indirect method and use ReadOperationCount from the csrss.exe process in respect to the session id
# csrss will change its IO Reads with input to the keyboard or mouse
# I have created sample code, in which you measure the ReadOperationCount of all sessions at two specific points in time and then compare the two objects.
# If something has changed, at least one session was NOT idle.
# If nothing has changed, ALL sessions were idle.

# You must have administrative priviledges

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
} else {
    Write-Host("User Interaction in at least one Sessions detected") -foregroundcolor Green
}
