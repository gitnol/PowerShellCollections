function Get-InstalledUpdatesFromEventLog {
    $filterXml = @'
    <QueryList>
      <Query Id="0" Path="System">
        <Select Path="System">
          *[System[Provider[@Name='Microsoft-Windows-WindowsUpdateClient']]]
        </Select>
      </Query>
    </QueryList>
'@

    Get-WinEvent -FilterXPath $filterXml -LogName System |
    ForEach-Object {
        [pscustomobject]@{
            EventId      = $_.Id
            UpdateGuid   = $_.Properties[1].Value
            InstalledOn  = $_.TimeCreated
            UpdateTitle  = $_.Properties[0].Value
        }
    }
}

# Execute the function
# Get-InstalledUpdatesFromEventLog | Sort-Object -Property InstalledOn,EventID -Descending | Out-GridView

# Successful Installs = 19
Get-InstalledUpdatesFromEventLog | Where-Object EventID -eq 19 |  Sort-Object -Property InstalledOn -Descending | Out-GridView -Title "Successful Installs = 19"

# Not Successful Installs = 20
Get-InstalledUpdatesFromEventLog | Where-Object EventID -eq 20 |  Sort-Object -Property InstalledOn -Descending | Out-GridView -Title "Not Successful Installs = 20"

# Feature Updates / Cumulative Updates  = 43
Get-InstalledUpdatesFromEventLog | Where-Object EventID -eq 43 |  Sort-Object -Property InstalledOn -Descending | Out-GridView -Title "Feature Updates / Cumulative Updates  = 43"

# Download has started Installs = 44
Get-InstalledUpdatesFromEventLog | Where-Object EventID -eq 44 |  Sort-Object -Property InstalledOn -Descending | Out-GridView -Title "Download has started Installs = 44"