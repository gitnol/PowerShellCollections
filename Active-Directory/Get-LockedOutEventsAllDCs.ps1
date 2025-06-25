function Get-LockedOutEventsAllDCs {
    [CmdletBinding()]
    param(
        [int]$DaysBack = 1,
        [int]$MaxEvents = 1000,
        [switch]$IncludeSuccessfulLogons
    )

    $start = (Get-Date).AddDays(-$DaysBack)
    $eventIds = if ($IncludeSuccessfulLogons) { @(4740, 4624) } else { @(4740) }
    $logName = 'Security'

    Write-Verbose "Suche nach Events seit: $start"
    
    # Effizientere DC-Abfrage mit ErrorAction
    try {
        $dcs = Get-ADDomainController -Filter * -ErrorAction Stop | 
        Select-Object -ExpandProperty HostName
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
            param($dc, $logName, $eventIds, $start, $MaxEvents)
            
            $dcResults = [System.Collections.ArrayList]::new()
            
            try {
                $filterHashtable = @{
                    LogName   = $logName
                    Id        = $eventIds
                    StartTime = $start
                }
                
                if ($MaxEvents -gt 0) {
                    $events = Get-WinEvent -ComputerName $dc -FilterHashtable $filterHashtable -MaxEvents $MaxEvents -ErrorAction Stop
                }
                else {
                    $events = Get-WinEvent -ComputerName $dc -FilterHashtable $filterHashtable -ErrorAction Stop
                }

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
        } -ArgumentList $dc, $logName, $eventIds, $start, $MaxEvents
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
    [CmdletBinding()]
    param(
        [int]$DaysBack = 1,
        [string]$OutputPath = "LockoutEvents_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
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
    [CmdletBinding()]
    param(
        [int]$DaysBack = 1,
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