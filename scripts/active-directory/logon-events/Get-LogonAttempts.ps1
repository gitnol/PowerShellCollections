# This Script enables you to find failed logonattempts. (on german PCs... you have to adjust it to english words in the function Extract-MessageDetail)

function Get-ComputerWinEvents {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilterXML,
        [Parameter(Mandatory = $true)]
        [array]$Computers,
        [Parameter(Mandatory = $false)]
        [pscredential]$credentials = $null
    )

    $logonAttempts = @()

    foreach ($computer in $Computers) {
        Write-Host "Verarbeite $($computer) ..." -ForegroundColor Green
        if ($null -eq $credentials) {
            $events = Get-WinEvent -ComputerName $computer -FilterXml $FilterXML -ErrorAction SilentlyContinue
        } else {
            $events = Get-WinEvent -ComputerName $computer -FilterXml $FilterXML -Credential $credentials -ErrorAction SilentlyContinue
        }

        $logonAttempts += $events | ForEach-Object {
            [PSCustomObject]@{
                Domaincontroller        = $computer.HostName
                EventID                 = $_.Id
                LogonTime               = $_.TimeCreated
                Quellnetzwerkadresse    = ($_ | Extract-MessageDetail -Detail 'Quellnetzwerkadresse:')
                Arbeitsstationsname     = ($_ | Extract-MessageDetail -Detail 'Arbeitsstationsname:')
                Kontoname               = ($_ | Extract-Kontoname)
                Fehlerursache           = ($_ | Extract-MessageDetail -Detail 'Fehlerursache:')
                Anmeldeprozess          = ($_ | Extract-MessageDetail -Detail 'Anmeldeprozess:')
                Authentifizierungspaket = ($_ | Extract-MessageDetail -Detail 'Authentifizierungspaket:')
                Status                  = ($_ | Extract-MessageDetail -Detail 'Status:')
                Unterstatus             = ($_ | Extract-MessageDetail -Detail 'Unterstatus:')
            }
        }
    }
    return $logonAttempts
}

function Extract-MessageDetail {
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [PSCustomObject]$Event,
        [Parameter(Mandatory = $true)]
        [string]$Detail
    )
    process {
        if ($Event.Message -match "$Detail\s+(.*)") {
            return $matches[1].Trim()
        }
        return "N/A"
    }
}

function Extract-Kontoname {
    param (
        [Parameter(ValueFromPipeline = $true)]
        [object]$Event
    )
    $pattern = 'Kontoname:\s+(.+)'
    $result = $Event.Message -split "`n" | Select-String -Pattern $pattern | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    if ($null -ne $result[1]) { return $result[1] } else { return "N/A" }
}


function Get-SecurityEventsFilterXML {
    param (
        [string]$TargetUserName ="",
        [int]$Days = 1,
        [int[]]$EventIDs = @(4625)
    )
    
    $timeDiff = $Days * 24 * 60 * 60 * 1000
    $userFilter = ""
    if (($TargetUserName.Trim() -eq "") -or ($TargetUserName.Trim() -eq '*')) {
        $userFilter = ""
    } else {
        $userFilter = "and *[EventData[Data[@Name='TargetUserName']='$TargetUserName']]"
    }
    $EventIDFilter = ($EventIDs | ForEach-Object { "(EventID=$($_))" }) -join " or "
    $FilterXml = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">
      *[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and $EventIDFilter ]]
and
*[System[TimeCreated[timediff(@SystemTime) &lt;= '$timeDiff']]]
$userFilter
    </Select>
  </Query>
</QueryList>
"@
return $FilterXml
}


$username = (Read-Host -Prompt "Enter the username (default: *)").Trim()
if (-not $username) { $username = '*' }

$days = [int](Read-Host -Prompt "Enter the number of days backward (default: 1)")
if (-not $days) { $days = 1 }

$eventOption = [int](Read-Host -Prompt "Which EventIDs? [1] Successful Logons, [2] Errors, [3] Both (default: 2)")
switch ($eventOption) {
    0 { $eventIDs = 4625 }
    1 { $eventIDs = 4624 }
    2 { $eventIDs = 4625 }
    3 { $eventIDs = 4624,4625 }
    default { $eventIDs = 4625 }
}

$filterXML = Get-SecurityEventsFilterXML -Days 2 -EventIDs $eventIDs -TargetUserName $username

# $computers = @("MYHOSTNAME1","MYHOSTNAME2")
# $logonAttempts = Get-ComputerWinEvents -FilterXML $filterXML -Computers $computers
# # Show results
# $logonAttempts | Sort-Object -Property LogonTime -Descending | Out-GridView -Title "Logon Events for $($computers -join ",")"

# Get Domain Controllers and get Events
$computers = (Get-ADDomainController -Filter *).HostName
$credentials = (Get-Credential -Message "Please input admin credentials for $($computers -join ",")")
$logonAttempts = Get-ComputerWinEvents -FilterXML $filterXML -Computers $computers -credentials $credentials

# Show results
$logonAttempts | Sort-Object -Property LogonTime -Descending | Out-GridView -Title "Logon Events for $($computers -join ",")"

Read-Host -Prompt "Enter drücken zum beenden"

