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

$EventIDs = 4801 # Workstation UnlockEvents, but you can use multiple Events which are joined in the next line.  $EventIDs = 4801,4800,4624,...
$computers = "MYHOSTNAME"

$EventIDFilter = "*[System[(EventID=$($EventIDs -join ' or EventID='))]]"

# Get-WinEvent -LogName Security -FilterXPath $Filter | Select-Object TimeCreated, Id, ProviderName, Message -First 20

$FilterXml = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">
      $EventIDFilter
    </Select>
  </Query>
</QueryList>
"@


$events = Get-WinEvent -FilterXml $filterXML -ComputerName $computers | Select-Object TimeCreated, Id, ProviderName, MachineName, Message -First 20
$events | ForEach-Object {
    [PSCustomObject]@{
        MachineName   = $_.MachineName
        EventID       = $_.Id
        TimeCreated   = $_.TimeCreated
        SicherheitsID = ($_ | Extract-MessageDetail -Detail 'Sicherheits-ID:') 
        Kontoname     = ($_ | Extract-MessageDetail -Detail 'Kontoname:')
        Kontodomäne   = ($_ | Extract-MessageDetail -Detail 'Kontodomäne:')
        SitzungsID    = ($_ | Extract-MessageDetail -Detail 'Sitzungs-ID:')
    }
}