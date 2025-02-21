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

$MaxNumberOfEvents = 9999 # Change this to limit the events to the top X elements
$EventIDsSecurity = 4800,4801 # Workstation Lock and UnlockEvents, but you can use multiple Events which are joined in the next line.  $EventIDs = 4801,4800,4624,...
$EventIDsSystem = 41,1074,1076,6005,6006,6008,6009,6013 # Boot and Reboot Events
$computers = "MYHOSTNAME"

$EventIDFilterSecurity = "*[System[(EventID=$($EventIDsSecurity -join ' or EventID='))]]"
$EventIDFilterSystem = "*[System[(EventID=$($EventIDsSystem -join ' or EventID='))]]"

# Get-WinEvent -LogName Security -FilterXPath $Filter | Select-Object TimeCreated, Id, ProviderName, Message -First 20

$FilterXmlSecurity = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">
      $EventIDFilterSecurity
    </Select>
  </Query>
</QueryList>
"@

$FilterXmlSystem = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">
      $EventIDFilterSystem
    </Select>
  </Query>
</QueryList>
"@

$eventsSecurity = Get-WinEvent -FilterXml $FilterXmlSecurity -ComputerName $computers | Select-Object TimeCreated, Id, ProviderName, MachineName, Message -First $MaxNumberOfEvents
$eventsSystem = Get-WinEvent -FilterXml $filterXMLSystem -ComputerName $computers | Select-Object TimeCreated, Id, ProviderName, MachineName, Message -First $MaxNumberOfEvents

$eventsSecurity | ForEach-Object {
  [PSCustomObject]@{
      MachineName   = $_.MachineName
      EventID       = $_.Id
      TimeCreated   = $_.TimeCreated
      SicherheitsID = ($_ | Extract-MessageDetail -Detail 'Sicherheits-ID:') 
      Kontoname     = ($_ | Extract-MessageDetail -Detail 'Kontoname:')
      Kontodomäne   = ($_ | Extract-MessageDetail -Detail 'Kontodomäne:')
      SitzungsID    = ($_ | Extract-MessageDetail -Detail 'Sitzungs-ID:')
  }
} | Out-GridView -Title "Security Events"

$eventsSystem | ForEach-Object {
  [PSCustomObject]@{
      MachineName   = $_.MachineName
      EventID       = $_.Id
      TimeCreated   = $_.TimeCreated
      SicherheitsID = ($_ | Extract-MessageDetail -Detail 'Sicherheits-ID:') 
      Kontoname     = ($_ | Extract-MessageDetail -Detail 'Kontoname:')
      Kontodomäne   = ($_ | Extract-MessageDetail -Detail 'Kontodomäne:')
      SitzungsID    = ($_ | Extract-MessageDetail -Detail 'Sitzungs-ID:')
  }
} | Out-GridView -Title "System Events"
