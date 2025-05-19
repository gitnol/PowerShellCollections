function Extract-MessageDetail {
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [PSCustomObject]$Event,

        [Parameter(Mandatory = $true)]
        [string]$Detail,

        [Parameter(Mandatory = $true)]
        [string]$Computer
    )
    process {
        if ($Event.Message -match "$Detail\s+(.*)") {
            return $matches[1].Trim()
        }
        return "N/A"
    }
}

function Get-EventDetails {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Computer,

        [int]$MaxEvents = 9999
    )

    $eventIDsSecurity = 4800,4801
    $eventIDsSystem   = 41,1074,1076,6005,6006,6008,6009,6013

    $filterSecurity = "*[System[(EventID=$($eventIDsSecurity -join ' or EventID='))]]"
    $filterSystem   = "*[System[(EventID=$($eventIDsSystem   -join ' or EventID='))]]"

    $filterXmlSecurity = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">
      $filterSecurity
    </Select>
  </Query>
</QueryList>
"@

    $filterXmlSystem = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">
      $filterSystem
    </Select>
  </Query>
</QueryList>
"@

    $eventsSecurity = Get-WinEvent -FilterXml $filterXmlSecurity -ComputerName $Computer | Select-Object TimeCreated, Id, ProviderName, MachineName, Message -First $MaxEvents
    $eventsSystem   = Get-WinEvent -FilterXml $filterXmlSystem   -ComputerName $Computer | Select-Object TimeCreated, Id, ProviderName, MachineName, Message -First $MaxEvents

    $securityDetails = $eventsSecurity | ForEach-Object {
        [PSCustomObject]@{
            MachineName   = $_.MachineName
            EventID       = $_.Id
            TimeCreated   = $_.TimeCreated
            SicherheitsID = ($_ | Extract-MessageDetail -Detail 'Sicherheits-ID:' -Computer $Computer)
            Kontoname     = ($_ | Extract-MessageDetail -Detail 'Kontoname:'     -Computer $Computer)
            Kontodomäne   = ($_ | Extract-MessageDetail -Detail 'Kontodomäne:'   -Computer $Computer)
            SitzungsID    = ($_ | Extract-MessageDetail -Detail 'Sitzungs-ID:'   -Computer $Computer)
        }
    }

    $systemDetails = $eventsSystem | ForEach-Object {
        [PSCustomObject]@{
            MachineName   = $_.MachineName
            EventID       = $_.Id
            TimeCreated   = $_.TimeCreated
            SicherheitsID = ($_ | Extract-MessageDetail -Detail 'Sicherheits-ID:' -Computer $Computer)
            Kontoname     = ($_ | Extract-MessageDetail -Detail 'Kontoname:'     -Computer $Computer)
            Kontodomäne   = ($_ | Extract-MessageDetail -Detail 'Kontodomäne:'   -Computer $Computer)
            SitzungsID    = ($_ | Extract-MessageDetail -Detail 'Sitzungs-ID:'   -Computer $Computer)
        }
    }

    $securityDetails | Out-GridView -Title "Security Events - $Computer"
    $systemDetails   | Out-GridView -Title "System Events - $Computer"
}

# Beispielaufruf
Get-EventDetails -Computer "RemotePCName"
