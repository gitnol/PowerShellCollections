# This Script returns all logon events of specific EventIDs or user names
# within a specific time frame (days backwards)
function get-DC-WinEvents {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$filterXML,
        [array]$domainControllers
    )
    # Iterate through each domain controller and retrieve logon attempts
    foreach ($dc in $domainControllers) {
        $dcName = $dc.HostName
        Write-Host("Verarbeite $dcName ...") -ForegroundColor Green

        $events = Get-WinEvent -ComputerName $dc.HostName -FilterXml $filterXML -ErrorAction SilentlyContinue


        # Extract specific columns and return them as a custom object
        $logonAttempts += $events | ForEach-Object {
            # Extract Fehlerursache from the Message property
            $Fehlerursache = if ($_.Message -match 'Fehlerursache:\s+(.*)') {
                $matches[1].Trim()
            } else {
                "N/A"
            }

            $Anmeldeprozess = if ($_.Message -match 'Anmeldeprozess:\s+(.*)') {
                $matches[1].Trim()
            } else {
                "N/A"
            }

            $Arbeitsstationsname = if ($_.Message -match 'Arbeitsstationsname:\s+(.*)') {
                $matches[1].Trim()
            } else {
                "N/A"
            }

            $Quellnetzwerkadresse = if ($_.Message -match 'Quellnetzwerkadresse:\s+(.*)') {
                $matches[1].Trim()
            }  else {
                "N/A"
            }

            $Authentifizierungspaket = if ($_.Message -match 'Authentifizierungspaket:\s+(.*)') {
                $matches[1].Trim()
            } else {
                "N/A"
            }

            $Status = if ($_.Message -match 'Status:\s+(.*)') {
                $matches[1].Trim()
            } else {
                "N/A"
            }

            $Unterstatus = if ($_.Message -match 'Unterstatus::\s+(.*)') {
                $matches[1].Trim()
            } else {
                "N/A"
            }

            $pattern = 'Kontoname:\s+(.+)'
            $erg = $_.Message -split "`n" | Select-String -Pattern $pattern | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
            $Kontoname = if ($erg[1]) { $erg[1] } else { "N/A" }


            [PSCustomObject]@{
                "Domaincontroller"        = $dcName
                "EventID"                 = $_.Id
                "LogonTime"               = $_.TimeCreated
                "Quellnetzwerkadresse"    = $Quellnetzwerkadresse
                "Arbeitsstationsname"     = $Arbeitsstationsname
                "Kontoname"               = $Kontoname
                "Fehlerursache"           = $Fehlerursache
                "Anmeldeprozess"          = $Anmeldeprozess
                "Authentifizierungspaket" = $Authentifizierungspaket
                "Status"                  = $Status
                "Unterstatus"             = $Unterstatus
            }
        }
    }
        # Output the custom object
        return $logonAttempts #| Sort-Object -Property LogonTime -Descending | Out-GridView -Title "4624 (Erfolgreich) oder 4625 (Fehler) zum Filtern eingeben"
}

# Initialize an empty array to store logon attempts
$logonAttempts = @()

# Prompt user for username input
$username = Read-Host -Prompt "Enter the username without domainname ([Alle User = * Standard)"
if (-not $username) {
    $username = '*'
}
$username = $username.Trim()

if ($username -ne '*') {
    $userxml = @"
and
*[EventData[Data[@Name='TargetUserName']='$username']]
"@
} else {
    $userxml = ""
}

# Prompt user for number of days backward and convert it to an integer
$days = Read-Host -Prompt "Enter the number of days backward (1 = Standard)"
if (-not $days) {
    $days = 1
} else {
    $days = [int]$days  # Convert input to an integer
}

# Calculate time difference in milliseconds
$timeDiff = $days * 24 * 60 * 60 * 1000  # days * hours/day * minutes/hour * seconds/minute * milliseconds/second

$eventids = Read-Host -Prompt "Which EventIDs? [1] 4624=Only Successful Logons, [2] 4625=Only Errors, [3] Both (2 = Standard)"
if (-not $eventids) {
    $eventids = 2
}

if ([int]$eventids -eq 3) {
    $eventxml = "EventID=4624 or EventID=4625"
}
if ([int]$eventids -eq 2) {
    $eventxml = "EventID=4625"
}
if ([int]$eventids -eq 1) {
    $eventxml = "EventID=4624"
}

Write-Host("User: $username") -ForegroundColor Yellow
Write-Host("Days: $days") -ForegroundColor Yellow
Write-Host("Eventids: $eventxml") -ForegroundColor Yellow

if (($eventids -in (1, 2, 3)) -and ($days -ge 1) -and ($username -ne "")) {

    # Construct the filter for the event log query
    $filterXML = @"
<QueryList>
<Query Id="0" Path="Security">
<Select Path="Security">
*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and ($eventxml)]]
$userxml
and
*[System[TimeCreated[timediff(@SystemTime) &lt;= '$timeDiff']]]
</Select>
</Query>
</QueryList>
"@

    Write-Host($filterXML) -ForegroundColor Magenta

    # Get all domain controllers in the domain
    $domainControllers = Get-ADDomainController -Filter *    
    $logonAttempts = get-DC-WinEvents -filterXML $filterXML -domainControllers $domainControllers
    $logonAttempts | Sort-Object -Property LogonTime -Descending | Out-GridView -Title "input 4624 (successful) oder 4625 (error) or search for something else "

}

