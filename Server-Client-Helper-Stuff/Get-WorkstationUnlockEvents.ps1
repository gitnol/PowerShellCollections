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

    $eventIDsSecurity = 4800,4801,4624,4625,4647
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


# | Event ID | Bedeutung                                                                                                                                   |
# | -------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
# | **41**   | Unerwartetes Herunterfahren („Kernel-Power“): System wurde ohne regulären Shutdown neu gestartet (z. B. Stromausfall, Absturz).             |
# | **1074** | Geplantes Herunterfahren oder Neustart durch Benutzer oder Anwendung (z. B. Windows Update, Benutzeraktion).                                |
# | **1076** | Manuelles Herunterfahren mit Angabe eines Grundes (Shutdown durch Administrator z. B. über RDP mit Grund).                                  |
# | **6005** | Der Ereignisprotokollierungsdienst wurde gestartet – entspricht sinngemäß einem "Systemstart" (Eventlog = „Start“).                         |
# | **6006** | Der Ereignisprotokollierungsdienst wurde ordnungsgemäß beendet – entspricht sinngemäß einem "regulären Herunterfahren" (Eventlog = „Stop“). |
# | **6008** | Unerwartetes Herunterfahren – z. B. Stromverlust, Crash, keine reguläre 6006 vor dem Neustart.                                              |
# | **6009** | Anzeige der verwendeten BIOS-Version bzw. Prozessorinformationen beim Systemstart.                                                          |
# | **6013** | Systemlaufzeit (Uptime) seit dem letzten Neustart in Sekunden – selten verwendet.                                                           |

# | Event ID | Bedeutung                                                                      |
# | -------- | ------------------------------------------------------------------------------ |
# | **4800** | Workstation wurde gesperrt (z. B. Benutzer sperrt per Windows+L oder Timeout). |
# | **4801** | Workstation wurde entsperrt (Benutzer hat sich nach Sperre wieder angemeldet). |
# | **4624** | Erfolgreiche Anmeldung (Logon).                                                |
# | **4625** | Fehlgeschlagene Anmeldung.                                                     |
# | **4647** | Benutzer hat sich explizit abgemeldet.                                         |
# | **4634** | Eine Anmeldungssitzung wurde beendet (z. B. durch Abmeldung oder Timeout).     |
# | **4672** | Spezielle Rechte wurden zugewiesen bei Anmeldung (z. B. Admin-Anmeldung).      |
# | **4778** | RDP-Sitzung wurde wieder verbunden (Reconnect).                                |
# | **4779** | RDP-Sitzung wurde getrennt (Disconnect).                                       |
# | **4768** | Kerberos-TGT wurde angefordert (Initiale Anmeldung bei AD).                    |
# | **4769** | Kerberos-Ticket für Dienst wurde angefordert.                                  |
# | **4776** | NTLM-Anmeldeversuch.                                                           |
# | **4964** | Sichere Anmeldung über Credential Manager.                                     |
