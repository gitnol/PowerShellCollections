function Get-ADAuthEventsAllDCs {
    <#
    .SYNOPSIS
        Sammelt Anmelde-Events (fehlgeschlagen, Lockout, erfolgreich) von allen Domain Controllern inkl. Quell-IP.

    .DESCRIPTION
        Diese Funktion fragt alle Domain Controller in der aktuellen AD-Domäne parallel nach
        Sicherheits-Events zum Thema Authentifizierung ab:

            - 4625  Fehlgeschlagene Anmeldung (Standard, inkl. falsches Passwort)
            - 4740  Konto gesperrt (Lockout)                    -> optional per -IncludeLockouts
            - 4624  Erfolgreiche Anmeldung                      -> optional per -IncludeSuccessfulLogons
            - 4771  Kerberos-Pre-Authentication fehlgeschlagen   -> optional per -IncludeKerberosPreAuthFailures
                    (fängt Fehlversuche ab, die z.B. über UNC-Pfade/Mapped Drives laufen und
                     bei 4625 manchmal ohne verwertbare IP auftauchen)

        Anders als in der Vorgängerversion werden die Event-Daten NICHT mehr über feste
        Array-Indizes (Properties[n]) ausgelesen, sondern über den Attributnamen im XML
        (Data[Name='...']). Das ist deutlich robuster, weil sich die Reihenfolge/Anzahl der
        Felder je nach Windows-Version, Sprache und Event-ID unterscheiden kann - genau das
        war in der Vergangenheit schon die Fehlerquelle bei anderen Skripten (z.B. falsch
        gelesene Properties-Indizes bei Power-Event-Auswertungen).

        Zusätzlich wird der Status-/Substatus-Code bei 4625 automatisch in Klartext übersetzt
        (falsches Passwort, Konto gesperrt, Konto deaktiviert, unbekannter Benutzer, etc.),
        damit man nicht jeden Hex-Code selbst nachschlagen muss.

    .PARAMETER DaysBack
        Anzahl der Tage, die rückwirkend abgefragt werden sollen. Standard: 1

    .PARAMETER MaxEvents
        Maximale Anzahl Events pro Domain Controller und Event-ID. 0 = unbegrenzt.
        Standard: 1000

    .PARAMETER IncludeLockouts
        Zusätzlich Event ID 4740 (Konto gesperrt) mit abfragen.

    .PARAMETER IncludeSuccessfulLogons
        Zusätzlich Event ID 4624 (erfolgreiche Anmeldung) mit abfragen.

    .PARAMETER IncludeKerberosPreAuthFailures
        Zusätzlich Event ID 4771 (Kerberos Pre-Auth fehlgeschlagen) mit abfragen.

    .PARAMETER User
        Optionaler Filter auf einen bestimmten Benutzernamen (SamAccountName, ohne Domäne).
        Wird serverseitig als XPath-Filter angehängt, spart also Bandbreite/Zeit.

    .PARAMETER ExcludeLocalSource
        Blendet Events aus, bei denen die Quell-IP "-" bzw. "127.0.0.1" bzw. "::1" ist
        (typisch bei lokalen Diensten/Batch-Logons auf dem DC selbst, kein externer Rechner).

    .PARAMETER Credential
        PSCredential-Objekt für den Zugriff auf Domain Controller und Active Directory.
        Wenn nicht angegeben, wird der aktuelle Benutzerkontext verwendet.

    .OUTPUTS
        PSCustomObject[] mit u.a.:
        DC, EventId, EventName, Time, User, Domain, SourceIP, SourceHost, LogonType,
        StatusCode, SubStatusCode, FailureReason, Message

    .EXAMPLE
        Get-ADAuthEventsAllDCs | Format-Table -AutoSize

        Fehlgeschlagene Anmeldungen (4625) der letzten 24 Stunden von allen DCs.

    .EXAMPLE
        Get-ADAuthEventsAllDCs -DaysBack 7 -IncludeLockouts -ExcludeLocalSource -Verbose

        7 Tage rückwirkend, inkl. Lockout-Events, ohne lokale/leere Quell-IPs.

    .EXAMPLE
        Get-ADAuthEventsAllDCs -User "m.mueller" -DaysBack 3

        Nur Fehlversuche des Benutzers m.mueller der letzten 3 Tage (serverseitig gefiltert).

    .EXAMPLE
        Get-ADAuthEventsAllDCs -DaysBack 7 |
            Where-Object FailureReason -eq 'Falsches Passwort' |
            Group-Object SourceIP | Sort-Object Count -Descending

        Zeigt, von welcher Quell-IP die meisten Falsch-Passwort-Versuche kamen.

    .EXAMPLE
        $cred = Get-Credential
        Get-ADAuthEventsAllDCs -DaysBack 7 -Credential $cred -IncludeLockouts -IncludeKerberosPreAuthFailures

    .NOTES
        Autor: IT-Administration
        Version: 3.0
        Erfordert: PowerShell 3.0+, ActiveDirectory-Modul, Leserechte auf Security-Log aller DCs.
        Für 4625/4771 muss die Audit-Richtlinie "Anmelden/Abmelden -> Anmelden" (Fehler)
        bzw. "Kontoanmeldung -> Kerberos-Anmeldedienst" (Fehler) auf den DCs aktiv sein
        (siehe Test-ADAuthAuditPolicy weiter unten).

    .LINK
        Get-WinEvent
        Get-ADDomainController
    #>
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = "Anzahl Tage rückwirkend (Standard: 1)")]
        [ValidateRange(1, 365)]
        [int]$DaysBack = 1,

        [Parameter(HelpMessage = "Max. Events pro DC und Event-ID (0=unbegrenzt, Standard: 1000)")]
        [ValidateRange(0, 50000)]
        [int]$MaxEvents = 1000,

        [Parameter(HelpMessage = "Zusätzlich Lockout-Events (4740) abfragen")]
        [switch]$IncludeLockouts,

        [Parameter(HelpMessage = "Zusätzlich erfolgreiche Anmeldungen (4624) abfragen")]
        [switch]$IncludeSuccessfulLogons,

        [Parameter(HelpMessage = "Zusätzlich Kerberos-Pre-Auth-Fehler (4771) abfragen")]
        [switch]$IncludeKerberosPreAuthFailures,

        [Parameter(HelpMessage = "Filter auf einen bestimmten Benutzernamen")]
        [string]$User,

        [Parameter(HelpMessage = "Events mit lokaler/leerer Quell-IP ausblenden")]
        [switch]$ExcludeLocalSource,

        [Parameter(HelpMessage = "Credentials für DC-Zugriff (Standard: aktueller Benutzer)")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        $start = (Get-Date).AddDays(-$DaysBack)

        $eventIds = [System.Collections.Generic.List[int]]::new()
        $eventIds.Add(4625)
        if ($IncludeLockouts) { $eventIds.Add(4740) }
        if ($IncludeSuccessfulLogons) { $eventIds.Add(4624) }
        if ($IncludeKerberosPreAuthFailures) { $eventIds.Add(4771) }

        $eventNames = @{
            4625 = 'FehlgeschlageneAnmeldung'
            4740 = 'KontoGesperrt'
            4624 = 'ErfolgreicheAnmeldung'
            4771 = 'KerberosPreAuthFehler'
        }

        # Bekannte Status-/Substatus-Codes bei 4625 in Klartext übersetzen
        $failureReasons = @{
            '0XC000006A' = 'Falsches Passwort'
            '0XC0000064' = 'Unbekannter Benutzername'
            '0XC0000234' = 'Konto gesperrt'
            '0XC0000072' = 'Konto deaktiviert'
            '0XC0000193' = 'Konto abgelaufen'
            '0XC0000071' = 'Passwort abgelaufen'
            '0XC0000070' = 'Workstation-Einschränkung'
            '0XC0000224' = 'Passwortänderung erzwungen'
            '0XC0000015' = 'Ungültige logon hours'
            '0XC0000413' = 'Authentifizierung blockiert (Guest / Auth Policy)'
        }

        # Kerberos-Statuscodes (Event 4771), separat von den NTLM-Substatus-Codes oben,
        # da beide Wertebereiche unterschiedliche Bedeutungen tragen (z.B. 0x18 vs. 0xC000006A).
        $kerberosFailureReasons = @{
            '0X6'  = 'Unbekannter Benutzername (Client not found)'
            '0X12' = 'Konto zu diesem Zeitpunkt bereits gesperrt/deaktiviert (Client Revoked)'
            '0X17' = 'Passwort abgelaufen'
            '0X18' = 'Falsches Passwort (Kerberos)'
            '0X25' = 'Konto gesperrt (Clock Skew / Lockout je nach Kontext)'
            '0X32' = 'Ticket abgelaufen'
        }

        Write-Verbose "Suche nach Event-IDs $($eventIds -join ', ') seit $start"

        try {
            $dcParams = @{ Filter = '*'; ErrorAction = 'Stop' }
            if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
                $dcParams.Credential = $Credential
            }
            $dcs = Get-ADDomainController @dcParams | Select-Object -ExpandProperty HostName
            Write-Verbose "Gefundene DCs: $($dcs.Count)"
        }
        catch {
            Write-Error "Fehler beim Abrufen der Domain Controller: $_"
            return
        }

        $results = [System.Collections.ArrayList]::new()
    }

    process {
        $jobs = foreach ($dc in $dcs) {
            Start-Job -ScriptBlock {
                param($dc, $eventIds, $start, $MaxEvents, $Credential, $User, $eventNames, $failureReasons, $kerberosFailureReasons)

                # Holt ein einzelnes EventData-Feld über den Namen statt über einen festen Index
                function Get-EventField {
                    param($DataNodes, [string]$Name)
                    ($DataNodes | Where-Object { $_.Name -eq $Name }).'#text'
                }

                $dcResults = [System.Collections.ArrayList]::new()

                try {
                    # Wenn ein bestimmter Benutzer gesucht wird, direkt per XPath serverseitig
                    # filtern. Wichtig: Ohne das würde -MaxEvents auf ALLE Events der
                    # angegebenen IDs angewendet (über alle Benutzer hinweg) und erst DANACH
                    # lokal auf den Benutzer gefiltert - in einer Umgebung mit vielen 4625-
                    # Events kann der gesuchte Event dadurch schon vor dem Filtern aus der
                    # Ergebnismenge herausfallen, weil neuere fremde Events den Platz belegen.
                    if ($User) {
                        $startUtc  = $start.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                        $idsClause = ($eventIds | ForEach-Object { "EventID=$_" }) -join ' or '
                        $xpath     = "*[System[($idsClause) and TimeCreated[@SystemTime>='$startUtc']] and EventData[Data[@Name='TargetUserName']='$User']]"

                        $winEventParams = @{
                            ComputerName = $dc
                            LogName      = 'Security'
                            FilterXPath  = $xpath
                            ErrorAction  = 'Stop'
                        }
                    }
                    else {
                        $filterHashtable = @{
                            LogName   = 'Security'
                            Id        = @($eventIds)
                            StartTime = $start
                        }
                        $winEventParams = @{
                            ComputerName    = $dc
                            FilterHashtable = $filterHashtable
                            ErrorAction     = 'Stop'
                        }
                    }

                    if ($Credential -and $Credential -ne [System.Management.Automation.PSCredential]::Empty) {
                        $winEventParams.Credential = $Credential
                    }
                    if ($MaxEvents -gt 0) {
                        $winEventParams.MaxEvents = $MaxEvents
                    }

                    $events = Get-WinEvent @winEventParams

                    foreach ($winEvent in $events) {
                        try {
                            $xml  = [xml]$winEvent.ToXml()
                            $data = $xml.Event.EventData.Data

                            switch ($winEvent.Id) {
                                4625 {
                                    $targetUser = Get-EventField $data 'TargetUserName'
                                    if ($User -and $targetUser -ne $User) { continue }

                                    $statusCode    = Get-EventField $data 'Status'
                                    $subStatusCode = Get-EventField $data 'SubStatus'
                                    $reasonKey     = if ($subStatusCode -and $subStatusCode -ne '0x0') { $subStatusCode } else { $statusCode }
                                    $reasonKeyNorm = ($reasonKey -as [string]).ToUpperInvariant()
                                    $failureReason = if ($failureReasons.ContainsKey($reasonKeyNorm)) { $failureReasons[$reasonKeyNorm] } else { "Unbekannt ($reasonKey)" }

                                    $sourceIp = Get-EventField $data 'IpAddress'
                                    if ($sourceIp -and $sourceIp.StartsWith('::ffff:')) {
                                        $sourceIp = $sourceIp.Substring(7)
                                    }

                                    [void]$dcResults.Add([PSCustomObject]@{
                                        DC            = $dc
                                        EventId       = $winEvent.Id
                                        EventName     = $eventNames[[int]$winEvent.Id]
                                        Time          = $winEvent.TimeCreated
                                        Time_UTC      = $winEvent.TimeCreated.ToUniversalTime()
                                        User          = $targetUser
                                        Domain        = Get-EventField $data 'TargetDomainName'
                                        SourceIP      = $sourceIp
                                        SourceHost    = Get-EventField $data 'WorkstationName'
                                        LogonType     = Get-EventField $data 'LogonType'
                                        StatusCode    = $statusCode
                                        SubStatusCode = $subStatusCode
                                        FailureReason = $failureReason
                                        Message       = $winEvent.Message
                                    })
                                }
                                4740 {
                                    $targetUser = Get-EventField $data 'TargetUserName'
                                    if ($User -and $targetUser -ne $User) { continue }

                                    [void]$dcResults.Add([PSCustomObject]@{
                                        DC            = $dc
                                        EventId       = $winEvent.Id
                                        EventName     = $eventNames[[int]$winEvent.Id]
                                        Time          = $winEvent.TimeCreated
                                        Time_UTC      = $winEvent.TimeCreated.ToUniversalTime()
                                        User          = $targetUser
                                        Domain        = Get-EventField $data 'TargetDomainName'
                                        SourceIP      = $null
                                        SourceHost    = Get-EventField $data 'CallerComputerName'
                                        LogonType     = $null
                                        StatusCode    = $null
                                        SubStatusCode = $null
                                        FailureReason = 'Kontosperrung ausgelöst'
                                        Message       = $winEvent.Message
                                    })
                                }
                                4624 {
                                    $targetUser = Get-EventField $data 'TargetUserName'
                                    if ($User -and $targetUser -ne $User) { continue }

                                    $sourceIp = Get-EventField $data 'IpAddress'
                                    if ($sourceIp -and $sourceIp.StartsWith('::ffff:')) {
                                        $sourceIp = $sourceIp.Substring(7)
                                    }

                                    [void]$dcResults.Add([PSCustomObject]@{
                                        DC            = $dc
                                        EventId       = $winEvent.Id
                                        EventName     = $eventNames[[int]$winEvent.Id]
                                        Time          = $winEvent.TimeCreated
                                        Time_UTC      = $winEvent.TimeCreated.ToUniversalTime()
                                        User          = $targetUser
                                        Domain        = Get-EventField $data 'TargetDomainName'
                                        SourceIP      = $sourceIp
                                        SourceHost    = Get-EventField $data 'WorkstationName'
                                        LogonType     = Get-EventField $data 'LogonType'
                                        StatusCode    = $null
                                        SubStatusCode = $null
                                        FailureReason = 'Erfolgreiche Anmeldung'
                                        Message       = $winEvent.Message
                                    })
                                }
                                4771 {
                                    $targetUser = Get-EventField $data 'TargetUserName'
                                    if ($User -and $targetUser -ne $User) { continue }

                                    $sourceIp = Get-EventField $data 'IpAddress'
                                    if ($sourceIp -and $sourceIp.StartsWith('::ffff:')) {
                                        $sourceIp = $sourceIp.Substring(7)
                                    }
                                    $failureCode = Get-EventField $data 'Status'
                                    $failureCodeNorm = ($failureCode -as [string]).ToUpperInvariant()
                                    $kerbReason = if ($kerberosFailureReasons.ContainsKey($failureCodeNorm)) {
                                        $kerberosFailureReasons[$failureCodeNorm]
                                    } else {
                                        "Unbekannt ($failureCode)"
                                    }

                                    [void]$dcResults.Add([PSCustomObject]@{
                                        DC            = $dc
                                        EventId       = $winEvent.Id
                                        EventName     = $eventNames[[int]$winEvent.Id]
                                        Time          = $winEvent.TimeCreated
                                        Time_UTC      = $winEvent.TimeCreated.ToUniversalTime()
                                        User          = $targetUser
                                        Domain        = $null
                                        SourceIP      = $sourceIp
                                        SourceHost    = $null
                                        LogonType     = $null
                                        StatusCode    = $failureCode
                                        SubStatusCode = $null
                                        FailureReason = $kerbReason
                                        Message       = $winEvent.Message
                                    })
                                }
                            }
                        }
                        catch {
                            Write-Warning "Fehler beim Parsen eines Events auf $dc`: $_"
                        }
                    }
                }
                catch [System.Exception] {
                    # Get-WinEvent wirft eine Exception, wenn der Filter keine Treffer liefert.
                    # Das ist kein Fehlerzustand (DC nicht erreichbar o.ä.), sondern schlicht "0 Events".
                    if ($_.Exception.Message -match 'No events were found') {
                        return [System.Collections.ArrayList]::new()
                    }
                    return [PSCustomObject]@{
                        Error   = $true
                        DC      = $dc
                        Message = $_.Exception.Message
                    }
                }

                return $dcResults
            } -ArgumentList $dc, $eventIds, $start, $MaxEvents, $Credential, $User, $eventNames, $failureReasons, $kerberosFailureReasons
        }

        Write-Verbose "Warte auf Abschluss aller Jobs..."
        $allResults = $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job

        foreach ($result in $allResults) {
            if ($result.Error) {
                Write-Warning "Fehler beim Abfragen von $($result.DC): $($result.Message)"
            }
            elseif ($result -is [System.Collections.ArrayList]) {
                foreach ($item in $result) { [void]$results.Add($item) }
            }
            else {
                [void]$results.Add($result)
            }
        }
    }

    end {
        Write-Verbose "Insgesamt $($results.Count) Events gefunden"

        $output = $results
        if ($ExcludeLocalSource) {
            $output = $output | Where-Object {
                $_.SourceIP -and $_.SourceIP -ne '-' -and $_.SourceIP -ne '127.0.0.1' -and $_.SourceIP -ne '::1'
            }
        }

        return $output | Sort-Object Time -Descending
    }
}

function Export-ADAuthEvents {
    <#
    .SYNOPSIS
        Exportiert Auth-Events (Get-ADAuthEventsAllDCs) in eine CSV-Datei.

    .EXAMPLE
        Export-ADAuthEvents -DaysBack 7 -IncludeLockouts
    #>
    [CmdletBinding()]
    param(
        [int]$DaysBack = 1,
        [string]$OutputPath = "AuthEvents_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
        [switch]$IncludeLockouts,
        [switch]$IncludeSuccessfulLogons,
        [switch]$IncludeKerberosPreAuthFailures,
        [switch]$ExcludeLocalSource
    )

    $events = Get-ADAuthEventsAllDCs -DaysBack $DaysBack `
        -IncludeLockouts:$IncludeLockouts `
        -IncludeSuccessfulLogons:$IncludeSuccessfulLogons `
        -IncludeKerberosPreAuthFailures:$IncludeKerberosPreAuthFailures `
        -ExcludeLocalSource:$ExcludeLocalSource `
        -Verbose

    if ($events.Count -gt 0) {
        $events | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "Events exportiert nach: $OutputPath" -ForegroundColor Green
        Write-Host "Anzahl Events: $($events.Count)" -ForegroundColor Green
    }
    else {
        Write-Warning "Keine Events gefunden"
    }
}

function Show-ADAuthEventsSummary {
    <#
    .SYNOPSIS
        Zeigt eine zusammenfassende Analyse der Auth-Events an (Top-User, Top-Quell-IPs, Gründe).

    .EXAMPLE
        Show-ADAuthEventsSummary -DaysBack 7 -ExcludeLocalSource
    #>
    [CmdletBinding()]
    param(
        [int]$DaysBack = 1,
        [switch]$IncludeLockouts,
        [switch]$IncludeSuccessfulLogons,
        [switch]$IncludeKerberosPreAuthFailures,
        [switch]$ExcludeLocalSource
    )

    $events = Get-ADAuthEventsAllDCs -DaysBack $DaysBack `
        -IncludeLockouts:$IncludeLockouts `
        -IncludeSuccessfulLogons:$IncludeSuccessfulLogons `
        -IncludeKerberosPreAuthFailures:$IncludeKerberosPreAuthFailures `
        -ExcludeLocalSource:$ExcludeLocalSource

    if ($events.Count -eq 0) {
        Write-Host "Keine Events gefunden" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Auth-Events Summary (letzte $DaysBack Tage):" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Top Benutzer mit Fehlversuchen:" -ForegroundColor Yellow
    $events | Where-Object EventId -eq 4625 | Group-Object User | Sort-Object Count -Descending |
        Select-Object Name, Count | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Top Quell-IPs mit Fehlversuchen:" -ForegroundColor Yellow
    $events | Where-Object EventId -eq 4625 | Group-Object SourceIP | Sort-Object Count -Descending |
        Select-Object Name, Count | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Verteilung nach Fehlergrund:" -ForegroundColor Yellow
    $events | Where-Object EventId -eq 4625 | Group-Object FailureReason | Sort-Object Count -Descending |
        Select-Object Name, Count | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Events pro Domain Controller:" -ForegroundColor Yellow
    $events | Group-Object DC | Sort-Object Count -Descending |
        Select-Object Name, Count | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Zeitliche Verteilung (nach Stunde):" -ForegroundColor Yellow
    $events | Group-Object { $_.Time.Hour } | Sort-Object Name |
        Select-Object @{Name = 'Stunde'; Expression = { $_.Name } }, Count | Format-Table -AutoSize
}

function Watch-ADAuthEvents {
    <#
    .SYNOPSIS
        Überwacht Auth-Events für einen Benutzer live, in konsistenter UTC-Zeitbasis.

    .DESCRIPTION
        Fragt Get-ADAuthEventsAllDCs in einer Schleife ab und zeigt nur neu hinzugekommene
        Events an. Anders als ein naiver Loop mit "letzter Abfragezeitpunkt = jetzt" wird
        hier der Zeitstempel des zuletzt tatsächlich GESEHENEN Events als Cutoff verwendet.
        Das verhindert, dass ein Event durch Replikations-/Verarbeitungsverzögerung zwischen
        den Domain Controllern stillschweigend übersprungen wird, nur weil es etwas später
        im Log auftaucht, als die Wanduhrzeit beim letzten Poll bereits war.

        Alle Zeiten werden explizit in UTC angezeigt, um Verwechslungen zwischen lokaler
        Zeit (Get-WinEvent, GMT+2) und UTC (Exchange-Protokoll-Logs) von vornherein
        auszuschließen - das war in der Praxis die größte Fehlerquelle bei der zeitlichen
        Korrelation zwischen AD-Events und Exchange-SMTP-Logs.

    .PARAMETER User
        Der zu überwachende Benutzername (SamAccountName).

    .PARAMETER PollIntervalSeconds
        Abfrageintervall in Sekunden. Standard: 5

    .PARAMETER IncludeLockouts
        Zusätzlich Event ID 4740 (Konto gesperrt) mit überwachen.

    .PARAMETER IncludeSuccessfulLogons
        Zusätzlich Event ID 4624 (erfolgreiche Anmeldung) mit überwachen.

    .PARAMETER IncludeKerberosPreAuthFailures
        Zusätzlich Event ID 4771 (Kerberos Pre-Auth fehlgeschlagen) mit überwachen.

    .PARAMETER Credential
        Credentials für den Zugriff auf die Domain Controller.

    .EXAMPLE
        Watch-ADAuthEvents -User "m.mustermann" -Credential $cred -IncludeLockouts -IncludeKerberosPreAuthFailures

        Läuft, bis mit Strg+C abgebrochen wird. Zeigt jeden neuen Fehlversuch/Lockout sofort an.

    .NOTES
        Läuft endlos, bis der Benutzer mit Strg+C abbricht - gedacht für die aktive
        Begleitung eines akuten Vorfalls (z.B. während eines Tests wie "Konto entsperren
        und beobachten, woher die nächste Sperrung kommt").
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$User,

        [ValidateRange(1, 300)]
        [int]$PollIntervalSeconds = 5,

        [switch]$IncludeLockouts,
        [switch]$IncludeSuccessfulLogons,
        [switch]$IncludeKerberosPreAuthFailures,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    $lastSeenUtc = (Get-Date).ToUniversalTime().AddSeconds(-1)

    Write-Host "Überwache Auth-Events für '$User' (UTC-Zeitbasis, Strg+C zum Beenden)"
    Write-Host "Start: $($lastSeenUtc.ToString('yyyy-MM-dd HH:mm:ss')) UTC"

    while ($true) {
        $neu = Get-ADAuthEventsAllDCs -User $User -DaysBack 1 -Credential $Credential `
            -IncludeLockouts:$IncludeLockouts `
            -IncludeSuccessfulLogons:$IncludeSuccessfulLogons `
            -IncludeKerberosPreAuthFailures:$IncludeKerberosPreAuthFailures |
            Where-Object { $_.Time.ToUniversalTime() -gt $lastSeenUtc } |
            Sort-Object Time

        if ($neu) {
            foreach ($ev in $neu) {
                $timeUtc = $ev.Time.ToUniversalTime().ToString('HH:mm:ss')
                $farbe = switch ($ev.EventName) {
                    'KontoGesperrt'             { 'Red' }
                    'FehlgeschlageneAnmeldung'  { 'Yellow' }
                    'KerberosPreAuthFehler'     { 'Yellow' }
                    default                     { 'Gray' }
                }
                Write-Host "$timeUtc UTC | $($ev.DC) | $($ev.SourceIP) | $($ev.FailureReason)" -ForegroundColor $farbe
            }
            $lastSeenUtc = ($neu | Sort-Object Time -Descending | Select-Object -First 1).Time.ToUniversalTime()
        }

        Start-Sleep -Seconds $PollIntervalSeconds
    }
}

function Test-ADDomainControllerTimeSync {
    <#
    .SYNOPSIS
        Prüft die Uhrzeit-Abweichung zwischen allen Domain Controllern und dem lokalen Rechner.

    .DESCRIPTION
        Bei der zeitlichen Korrelation von Events über mehrere DCs hinweg (z.B. "welches
        Event kam zuerst") kann selbst ein kleiner Uhrzeit-Versatz zwischen den DCs zu
        falschen Schlussfolgerungen führen - zusätzlich zu der bereits bekannten Falle,
        lokale Zeit mit UTC zu verwechseln (siehe Time_UTC-Feld in Get-ADAuthEventsAllDCs).

        Diese Funktion fragt auf jedem DC per Invoke-Command die aktuelle Systemzeit ab
        und vergleicht sie mit der lokalen Zeit des ausführenden Rechners. Domain Controller
        sollten durch W32Time/Kerberos-Toleranz ohnehin auf wenige Sekunden synchron sein
        (Kerberos akzeptiert standardmäßig max. 5 Minuten Skew) - eine Abweichung deutlich
        über wenigen Sekunden ist meist ein Hinweis auf ein defektes/fehlkonfiguriertes
        Zeitsynchronisierungs-Setup und sollte separat untersucht werden.

    .PARAMETER ThresholdSeconds
        Ab welcher Abweichung (in Sekunden) eine Warnung ausgegeben wird. Standard: 5

    .PARAMETER Credential
        Credentials für den Remote-Zugriff auf die Domain Controller.

    .EXAMPLE
        Test-ADDomainControllerTimeSync -Credential $cred
    #>
    [CmdletBinding()]
    param(
        [int]$ThresholdSeconds = 5,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    $dcs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName
    $localTime = Get-Date

    $invokeParams = @{ ComputerName = $dcs; ErrorAction = 'Stop' }
    if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
        $invokeParams.Credential = $Credential
    }

    $results = Invoke-Command @invokeParams -ScriptBlock {
        [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            RemoteTime   = Get-Date
        }
    }

    foreach ($r in $results) {
        $driftSeconds = [math]::Round((($r.RemoteTime) - $localTime).TotalSeconds, 2)
        $status = if ([math]::Abs($driftSeconds) -gt $ThresholdSeconds) { 'ABWEICHUNG!' } else { 'OK' }

        [PSCustomObject]@{
            DC             = $r.PSComputerName
            RemoteTime     = $r.RemoteTime
            LocalTime      = $localTime
            DriftSeconds   = $driftSeconds
            Status         = $status
        }
    }
}

function Test-ADAuthEventsCoverage {
    <#
    .SYNOPSIS
        Prüft pro Domain Controller, ob die Rohdatenmenge nahe an -MaxEvents herankommt
        (Risiko einer stillen Truncation, bevor der -User-Filter greift).

    .DESCRIPTION
        Get-ADAuthEventsAllDCs begrenzt die Abfrage pro DC mit -MaxEvents. Wird KEIN -User
        angegeben, wird diese Grenze auf ALLE Events der gewählten IDs angewendet, bevor
        irgendeine weitere Filterung stattfindet. In einer Umgebung mit viel Anmelde-Rauschen
        kann das dazu führen, dass ältere - eigentlich relevante - Events durch neuere,
        irrelevante Events aus der Ergebnismenge verdrängt werden, ohne dass ein Fehler
        oder eine Warnung erscheint (genau das ist in einer früheren Untersuchung passiert).

        Diese Funktion zählt die tatsächliche Rohtrefferzahl pro DC (ohne -MaxEvents-Limit)
        und vergleicht sie mit dem konfigurierten -MaxEvents-Wert, um vorab zu erkennen,
        ob eine Abfrage im "General-Survey"-Modus (ohne -User) truncation-gefährdet ist.

    .PARAMETER DaysBack
        Zeitraum wie bei Get-ADAuthEventsAllDCs. Standard: 1

    .PARAMETER MaxEvents
        Der MaxEvents-Wert, gegen den geprüft werden soll. Standard: 1000

    .PARAMETER IncludeLockouts
        4740 mit einbeziehen, wie bei Get-ADAuthEventsAllDCs.

    .PARAMETER IncludeSuccessfulLogons
        4624 mit einbeziehen, wie bei Get-ADAuthEventsAllDCs.

    .PARAMETER IncludeKerberosPreAuthFailures
        4771 mit einbeziehen, wie bei Get-ADAuthEventsAllDCs.

    .PARAMETER Credential
        Credentials für den DC-Zugriff.

    .EXAMPLE
        Test-ADAuthEventsCoverage -DaysBack 7 -MaxEvents 1000 -Credential $cred

        Zeigt pro DC die tatsächliche Rohtrefferzahl und warnt, falls sie sich
        der konfigurierten MaxEvents-Grenze nähert oder sie überschreitet.
    #>
    [CmdletBinding()]
    param(
        [int]$DaysBack = 1,
        [int]$MaxEvents = 1000,
        [switch]$IncludeLockouts,
        [switch]$IncludeSuccessfulLogons,
        [switch]$IncludeKerberosPreAuthFailures,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    $start = (Get-Date).AddDays(-$DaysBack)
    $eventIds = [System.Collections.Generic.List[int]]::new()
    $eventIds.Add(4625)
    if ($IncludeLockouts) { $eventIds.Add(4740) }
    if ($IncludeSuccessfulLogons) { $eventIds.Add(4624) }
    if ($IncludeKerberosPreAuthFailures) { $eventIds.Add(4771) }

    $dcs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName

    foreach ($dc in $dcs) {
        try {
            $winEventParams = @{
                ComputerName    = $dc
                FilterHashtable = @{ LogName = 'Security'; Id = $eventIds.ToArray(); StartTime = $start }
                ErrorAction     = 'Stop'
            }
            if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
                $winEventParams.Credential = $Credential
            }

            # Bewusst OHNE -MaxEvents, um die tatsächliche Rohtrefferzahl zu ermitteln
            $rawCount = (Get-WinEvent @winEventParams).Count

            $risiko = if ($rawCount -ge $MaxEvents) { 'TRUNCATION WAHRSCHEINLICH' }
                      elseif ($rawCount -ge ($MaxEvents * 0.8)) { 'Nahe an MaxEvents - Vorsicht' }
                      else { 'OK' }

            [PSCustomObject]@{
                DC            = $dc
                RawEventCount = $rawCount
                MaxEvents     = $MaxEvents
                Risiko        = $risiko
            }
        }
        catch {
            if ($_.Exception.Message -match 'No events were found') {
                [PSCustomObject]@{
                    DC            = $dc
                    RawEventCount = 0
                    MaxEvents     = $MaxEvents
                    Risiko        = 'OK (0 Events)'
                }
            }
            else {
                Write-Warning "Fehler beim Abfragen von $dc`: $_"
            }
        }
    }
}

function Test-ADAuthAuditPolicy {
    <#
    .SYNOPSIS
        Prüft auf einem oder mehreren Domain Controllern, ob die nötigen Audit-Richtlinien
        für 4625/4740/4771 aktiv sind (Diagnose vorab, bevor man auf leere Ergebnisse trifft).

    .DESCRIPTION
        Fragt "auditpol /get" für die relevanten Subkategorien remote ab (per Invoke-Command).
        Wichtig: Ohne aktivierte Fehler-Audits laufen 4625/4771 NIE ins Security-Log,
        auch wenn Get-WinEvent technisch fehlerfrei durchläuft - das Ergebnis ist dann einfach leer.

    .PARAMETER ComputerName
        Ein oder mehrere Domain Controller. Standard: alle DCs der Domäne.

    .PARAMETER Credential
        Credentials für den Remote-Zugriff (WinRM muss auf den DCs aktiv sein).

    .EXAMPLE
        Test-ADAuthAuditPolicy

    .EXAMPLE
        Test-ADAuthAuditPolicy -ComputerName DC01.contoso.local
    #>
    [CmdletBinding()]
    param(
        [string[]]$ComputerName,
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    if (-not $ComputerName) {
        $ComputerName = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName
    }

    $invokeParams = @{ ComputerName = $ComputerName; ErrorAction = 'Stop' }
    if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
        $invokeParams.Credential = $Credential
    }

    Invoke-Command @invokeParams -ScriptBlock {
        # Subkategorie-Namen sind je nach Sprachversion des Windows lokalisiert
        # ("Anmelden" vs. "Logon" vs. weitere Sprachen) - die GUIDs sind dagegen
        # auf jedem Windows identisch. Deshalb wird hier über GUID gefiltert,
        # nicht über den (unzuverlässigen) lokalisierten Namen.
        $targetGuids = @(
            '{0CCE9215-69AE-11D9-BED3-505054503030}'  # Logon / Anmelden
            '{0CCE9217-69AE-11D9-BED3-505054503030}'  # Account Lockout / Kontosperrung
            '{0CCE9242-69AE-11D9-BED3-505054503030}'  # Kerberos Authentication Service
            '{0CCE9240-69AE-11D9-BED3-505054503030}'  # Kerberos Service Ticket Operations
        )
        $guidLabels = @{
            '{0CCE9215-69AE-11D9-BED3-505054503030}' = 'Anmelden (Logon) - für 4624/4625'
            '{0CCE9217-69AE-11D9-BED3-505054503030}' = 'Kontosperrung (Account Lockout) - für 4740'
            '{0CCE9242-69AE-11D9-BED3-505054503030}' = 'Kerberos-Authentifizierungsdienst - für 4771/4768'
            '{0CCE9240-69AE-11D9-BED3-505054503030}' = 'Kerberos-Dienstticketvorgänge - für 4769'
        }

        # auditpol-CSV-Kopfzeile ist ebenfalls lokalisiert -> feste Header vergeben
        # und die erste (echte) Zeile überspringen, statt uns auf Spaltennamen zu verlassen.
        $rawLines = auditpol /get /category:* /r
        $rows = $rawLines | Select-Object -Skip 1 | ConvertFrom-Csv -Header `
            'MachineName', 'PolicyTarget', 'Subcategory', 'SubcategoryGuid', 'InclusionSetting', 'ExclusionSetting'

        $relevant = $rows | Where-Object { $targetGuids -contains $_.SubcategoryGuid } | ForEach-Object {
            [PSCustomObject]@{
                Kategorie = $guidLabels[$_.SubcategoryGuid]
                Einstellung = $_.InclusionSetting
            }
        }

        [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            Policies     = $relevant
        }
    }
}

# =====================================================================
# Verwendungsbeispiele
# =====================================================================
<#
# Standard: fehlgeschlagene Anmeldungen (4625) der letzten 24 Stunden, alle DCs
Get-ADAuthEventsAllDCs | Format-Table DC, Time, User, SourceIP, SourceHost, FailureReason -AutoSize

# Nur "falsches Passwort", letzte 7 Tage, ohne lokale/leere Quell-IPs
Get-ADAuthEventsAllDCs -DaysBack 7 -ExcludeLocalSource |
    Where-Object FailureReason -eq 'Falsches Passwort' |
    Format-Table DC, Time, User, SourceIP, SourceHost -AutoSize

# Zusätzlich Lockouts und Kerberos-Pre-Auth-Fehler mit einbeziehen
Get-ADAuthEventsAllDCs -DaysBack 3 -IncludeLockouts -IncludeKerberosPreAuthFailures

# Export als CSV
Export-ADAuthEvents -DaysBack 7 -IncludeLockouts

# Zusammenfassung / Statistik
Show-ADAuthEventsSummary -DaysBack 7 -ExcludeLocalSource

# Vorab prüfen, ob die Audit-Richtlinien überhaupt Events erzeugen
Test-ADAuthAuditPolicy

# Live-Überwachung eines Kontos während eines akuten Vorfalls
Watch-ADAuthEvents -User "m.mustermann" -Credential $cred -IncludeLockouts -IncludeKerberosPreAuthFailures

# Diagnose: Uhrzeit-Synchronisation zwischen den DCs prüfen
Test-ADDomainControllerTimeSync -Credential $cred

# Diagnose: Truncation-Risiko prüfen, bevor eine breite Abfrage (ohne -User) gefahren wird
Test-ADAuthEventsCoverage -DaysBack 7 -MaxEvents 1000 -Credential $cred
#>
