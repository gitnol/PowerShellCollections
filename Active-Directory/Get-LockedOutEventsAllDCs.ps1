function Get-LockedOutEventsAllDCs {
    <#
    .SYNOPSIS
        Sammelt Account-Lockout-Events von allen Domain Controllern in der Domäne.

    .DESCRIPTION
        Diese Funktion fragt alle Domain Controller in der aktuellen AD-Domäne nach Account-Lockout-Events (Event ID 4740) ab.
        Optional können auch erfolgreiche Anmeldungen (Event ID 4624) mit abgefragt werden.
        Die Abfrage erfolgt parallel für bessere Performance bei mehreren DCs.

    .PARAMETER DaysBack
        Anzahl der Tage, die rückwirkend abgefragt werden sollen.
        Standard: 1 Tag

    .PARAMETER MaxEvents
        Maximale Anzahl Events pro Domain Controller.
        0 = unbegrenzt (Vorsicht bei großen Umgebungen!)
        Standard: 1000

    .PARAMETER IncludeSuccessfulLogons
        Zusätzlich zu Lockout-Events auch erfolgreiche Anmeldungen (Event ID 4624) abfragen.
        Nützlich für forensische Analysen.

    .PARAMETER Credential
        PSCredential-Objekt für den Zugriff auf Domain Controller und Active Directory.
        Wenn nicht angegeben, wird der aktuelle Benutzerkontext verwendet.
        Nützlich wenn das Script unter einem anderen Account ausgeführt werden soll.

    .OUTPUTS
        PSCustomObject[]
        Array von Objekten mit folgenden Eigenschaften:
        - DC: Name des Domain Controllers
        - EventId: Event ID (4740 für Lockouts, 4624 für erfolgreiche Anmeldungen)
        - Time: Zeitpunkt des Events
        - User: Betroffener Benutzername
        - Caller: Aufrufender Computer/Prozess
        - SourceHost: Quell-Host der Anmeldung
        - Message: Vollständige Event-Message

    .EXAMPLE
        Get-LockedOutEventsAllDCs
        
        Fragt Lockout-Events der letzten 24 Stunden von allen DCs ab.

    .EXAMPLE
        Get-LockedOutEventsAllDCs -DaysBack 7 -Verbose
        
        Fragt Lockout-Events der letzten 7 Tage ab mit detaillierter Ausgabe.

    .EXAMPLE
        Get-LockedOutEventsAllDCs -DaysBack 3 -MaxEvents 500 | Where-Object User -like "*admin*"
        
        Sucht nach Lockout-Events von Admin-Accounts in den letzten 3 Tagen, begrenzt auf 500 Events pro DC.

    .EXAMPLE
        Get-LockedOutEventsAllDCs -IncludeSuccessfulLogons | Group-Object User | Sort-Object Count -Descending
        
        Gruppiert Events nach Benutzern und sortiert nach Häufigkeit (inkl. erfolgreiche Anmeldungen).

    .EXAMPLE
        $cred = Get-Credential
        Get-LockedOutEventsAllDCs -DaysBack 7 -Credential $cred
        
        Fragt Events mit spezifischen Credentials ab.

    .EXAMPLE
        Get-LockedOutEventsAllDCs -Credential (Get-Credential) -IncludeSuccessfulLogons
        
        Interaktive Credential-Eingabe für erweiterte Analyse.

    .NOTES
        Autor: IT-Administration
        Version: 2.0
        Erfordert: PowerShell 3.0+, ActiveDirectory-Modul, entsprechende Berechtigungen auf DCs
        
        Hinweise:
        - Erfordert Leseberechtigung auf Security-Log aller Domain Controller
        - Bei großen Umgebungen kann die Abfrage länger dauern
        - Verwendet parallele Jobs für bessere Performance
        - Sortiert Ergebnisse automatisch nach Zeit (neueste zuerst)

    .LINK
        Get-WinEvent
        Get-ADDomainController
    #>
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = "Anzahl Tage rückwirkend (Standard: 1)")]
        [ValidateRange(1, 365)]
        [int]$DaysBack = 1,
        
        [Parameter(HelpMessage = "Max. Events pro DC (0=unbegrenzt, Standard: 1000)")]
        [ValidateRange(0, 10000)]
        [int]$MaxEvents = 1000,
        
        [Parameter(HelpMessage = "Auch erfolgreiche Anmeldungen (4624) abfragen")]
        [switch]$IncludeSuccessfulLogons,
        
        [Parameter(HelpMessage = "Credentials für DC-Zugriff (Standard: aktueller Benutzer)")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    $start = (Get-Date).AddDays(-$DaysBack)
    $eventIds = if ($IncludeSuccessfulLogons) { @(4740, 4624) } else { @(4740) }
    $logName = 'Security'

    Write-Verbose "Suche nach Events seit: $start"
    
    # Effizientere DC-Abfrage mit ErrorAction
    try {
        if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
            $dcs = Get-ADDomainController -Filter * -Credential $Credential -ErrorAction Stop | 
            Select-Object -ExpandProperty HostName
        }
        else {
            $dcs = Get-ADDomainController -Filter * -ErrorAction Stop | 
            Select-Object -ExpandProperty HostName
        }
        Write-Verbose "Gefundene DCs: $($dcs.Count)"
    }
    catch {
        Write-Error "Fehler beim Abrufen der Domain Controller: $_"
        return
    }

    # Verwende ArrayList für bessere Performance
    $results = [System.Collections.ArrayList]::new()

    # Parallel processing für bessere Performance
    $jobs = foreach ($dc in $dcs) {
        Start-Job -ScriptBlock {
            param($dc, $logName, $eventIds, $start, $MaxEvents, $Credential)
            
            $dcResults = [System.Collections.ArrayList]::new()
            
            try {
                $filterHashtable = @{
                    LogName   = $logName
                    Id        = $eventIds
                    StartTime = $start
                }
                
                # Get-WinEvent Parameter je nach Credential
                $winEventParams = @{
                    ComputerName    = $dc
                    FilterHashtable = $filterHashtable
                    ErrorAction     = 'Stop'
                }
                
                if ($Credential -and $Credential -ne [System.Management.Automation.PSCredential]::Empty) {
                    $winEventParams.Credential = $Credential
                }
                
                if ($MaxEvents -gt 0) {
                    $winEventParams.MaxEvents = $MaxEvents
                }
                
                $events = Get-WinEvent @winEventParams

                foreach ($event in $events) {
                    try {
                        $xml = [xml]$event.ToXml()
                        $eventData = $xml.Event.EventData.Data
                        
                        $eventObject = [PSCustomObject]@{
                            DC         = $dc
                            EventId    = $event.Id
                            Time       = $event.TimeCreated
                            User       = $eventData[0].'#text'
                            Caller     = $eventData[1].'#text'
                            SourceHost = if ($eventData.Count -gt 4) { $eventData[4].'#text' } else { 'N/A' }
                            Message    = $event.Message
                        }
                        
                        [void]$dcResults.Add($eventObject)
                    }
                    catch {
                        Write-Warning "Fehler beim Parsen des Events auf $dc`: $_"
                    }
                }
            }
            catch [System.Exception] {
                return [PSCustomObject]@{
                    Error   = $true
                    DC      = $dc
                    Message = $_.Exception.Message
                }
            }
            
            return $dcResults
        } -ArgumentList $dc, $logName, $eventIds, $start, $MaxEvents, $Credential
    }

    # Warte auf alle Jobs und sammle Ergebnisse
    Write-Verbose "Warte auf Abschluss aller Jobs..."
    $allResults = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    # Verarbeite Ergebnisse und handle Fehler
    foreach ($result in $allResults) {
        if ($result.Error) {
            Write-Warning "Fehler beim Abfragen von $($result.DC): $($result.Message)"
        }
        elseif ($result -is [System.Collections.ArrayList]) {
            foreach ($item in $result) {
                [void]$results.Add($item)
            }
        }
        else {
            [void]$results.Add($result)
        }
    }

    Write-Verbose "Insgesamt $($results.Count) Events gefunden"
    
    # Sortiere nach Zeit (neueste zuerst)
    return $results | Sort-Object Time -Descending
}

# Erweiterte Hilfsfunktionen
function Export-LockedOutEvents {
    <#
    .SYNOPSIS
        Exportiert Account-Lockout-Events von allen Domain Controllern in eine CSV-Datei.

    .DESCRIPTION
        Hilfsfunktion die Get-LockedOutEventsAllDCs aufruft und das Ergebnis automatisch 
        in eine CSV-Datei mit Zeitstempel exportiert.

    .PARAMETER DaysBack
        Anzahl der Tage, die rückwirkend abgefragt werden sollen. Standard: 1

    .PARAMETER OutputPath
        Pfad zur Ausgabedatei. Standard: LockoutEvents_YYYYMMDD_HHMMSS.csv

    .PARAMETER IncludeSuccessfulLogons
        Auch erfolgreiche Anmeldungen exportieren.

    .EXAMPLE
        Export-LockedOutEvents -DaysBack 7
        
        Exportiert Lockout-Events der letzten 7 Tage.

    .EXAMPLE
        Export-LockedOutEvents -OutputPath "C:\Reports\Lockouts.csv" -IncludeSuccessfulLogons
        
        Exportiert Events inkl. erfolgreiche Anmeldungen in spezifische Datei.
    #>
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = "Anzahl Tage rückwirkend")]
        [int]$DaysBack = 1,
        
        [Parameter(HelpMessage = "Pfad zur CSV-Ausgabedatei")]
        [string]$OutputPath = "LockoutEvents_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
        
        [Parameter(HelpMessage = "Auch erfolgreiche Anmeldungen exportieren")]
        [switch]$IncludeSuccessfulLogons
    )
    
    $events = Get-LockedOutEventsAllDCs -DaysBack $DaysBack -IncludeSuccessfulLogons:$IncludeSuccessfulLogons -Verbose
    
    if ($events.Count -gt 0) {
        $events | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "Events exportiert nach: $OutputPath" -ForegroundColor Green
        Write-Host "Anzahl Events: $($events.Count)" -ForegroundColor Green
    }
    else {
        Write-Warning "Keine Events gefunden"
    }
}

function Show-LockedOutEventsSummary {
    <#
    .SYNOPSIS
        Zeigt eine zusammenfassende Analyse der Account-Lockout-Events an.

    .DESCRIPTION
        Erstellt verschiedene Gruppierungen und Statistiken der Lockout-Events:
        - Top Benutzer mit den meisten Lockouts
        - Top Source Hosts
        - Verteilung nach Domain Controller
        - Zeitliche Verteilung nach Stunden

    .PARAMETER DaysBack
        Anzahl der Tage, die rückwirkend analysiert werden sollen. Standard: 1

    .PARAMETER IncludeSuccessfulLogons
        Auch erfolgreiche Anmeldungen in die Analyse einbeziehen.

    .EXAMPLE
        Show-LockedOutEventsSummary -DaysBack 7
        
        Zeigt Zusammenfassung der letzten 7 Tage an.

    .EXAMPLE
        Show-LockedOutEventsSummary -IncludeSuccessfulLogons
        
        Zeigt Analyse inkl. erfolgreicher Anmeldungen an.
    #>
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = "Anzahl Tage rückwirkend")]
        [int]$DaysBack = 1,
        
        [Parameter(HelpMessage = "Auch erfolgreiche Anmeldungen analysieren")]
        [switch]$IncludeSuccessfulLogons
    )
    
    $events = Get-LockedOutEventsAllDCs -DaysBack $DaysBack -IncludeSuccessfulLogons:$IncludeSuccessfulLogons
    
    if ($events.Count -eq 0) {
        Write-Host "Keine Events gefunden" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nLockout Events Summary (letzte $DaysBack Tage):" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    # Zusammenfassung nach Benutzer
    $userSummary = $events | Group-Object User | Sort-Object Count -Descending
    Write-Host "`nTop Benutzer mit Lockouts:" -ForegroundColor Yellow
    $userSummary | Select-Object Name, Count | Format-Table -AutoSize
    
    # Zusammenfassung nach Source Host
    $hostSummary = $events | Group-Object SourceHost | Sort-Object Count -Descending
    Write-Host "`nTop Source Hosts:" -ForegroundColor Yellow
    $hostSummary | Select-Object Name, Count | Format-Table -AutoSize
    
    # Zusammenfassung nach DC
    $dcSummary = $events | Group-Object DC | Sort-Object Count -Descending
    Write-Host "`nEvents pro Domain Controller:" -ForegroundColor Yellow
    $dcSummary | Select-Object Name, Count | Format-Table -AutoSize
    
    # Zeitliche Verteilung
    Write-Host "`nZeitliche Verteilung (nach Stunden):" -ForegroundColor Yellow
    $events | Group-Object { $_.Time.Hour } | Sort-Object Name | 
    Select-Object @{Name = 'Stunde'; Expression = { $_.Name } }, Count | 
    Format-Table -AutoSize
}

# Verwendungsbeispiele:
<#
# Standard-Verwendung
Get-LockedOutEventsAllDCs | Format-Table -AutoSize

# Mit erweiterten Parametern
Get-LockedOutEventsAllDCs -DaysBack 7 -MaxEvents 500 -Verbose

# Export mit Zeitstempel
Export-LockedOutEvents -DaysBack 3

# Detaillierte Zusammenfassung
Show-LockedOutEventsSummary -DaysBack 7

# Alle Events der letzten 24 Stunden anzeigen
Get-LockedOutEventsAllDCs -DaysBack 1 | 
    Select-Object Time, User, SourceHost, DC | 
    Format-Table -AutoSize
#>