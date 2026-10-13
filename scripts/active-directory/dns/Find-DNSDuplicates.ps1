<#
.SYNOPSIS
    Bereinigt veraltete und doppelte dynamische DNS-Einträge (A und optional PTR)
    im IP-Pool der FortiGate-IPsec-VPN-Clients.

.DESCRIPTION
    Hintergrund:
    Die FortiGate vergibt Mode-Config-Adressen nach dem Prinzip "erste freie Adresse".
    Ein getrennter VPN-Client kann seinen DNS-Eintrag nicht mehr löschen, die IP geht an
    den nächsten Client, und mehrere Hostnamen zeigen auf dieselbe IP. Verbindungen per
    Name (WinRM/Kerberos) landen dann beim falschen Rechner.

    Ablauf in drei Phasen:
      1. Erfassen   - Dynamische A-Einträge (mit -IncludePtr auch PTR-Einträge) sammeln,
                      deren IP in -IpPattern liegt. Statische Einträge (ohne Zeitstempel)
                      und AD-kritische Namen werden nie berücksichtigt.
      2. Bewerten   - Pro IP wird genau ein gültiger Eintrag bestimmt:
                        * mehrere A-Einträge    -> der neueste bleibt, ältere werden entfernt
                        * gleicher Zeitstempel  -> nicht entscheidbar, wird übersprungen
                        * IP laut FortiGate nicht aktiv (nur mit -FortiGateUrl)
                                                -> alle Einträge gelten als verwaist
                        * PTR                   -> es bleibt der PTR, der zum gültigen
                                                   A-Eintrag passt
      3. Bereinigen - Nur mit -Remove. Vorher werden die betroffenen Einträge als CSV
                      gesichert. Bei mehr als -MaxRemove Löschungen bricht das Skript ab.

    Ohne -Remove erzeugt das Skript nur einen Bericht und ändert nichts.
    -WhatIf und -Confirm werden unterstützt.

.PARAMETER ComputerName
    DNS-Server, gegen den gearbeitet wird. Standard: lokaler Rechner.

.PARAMETER ZoneName
    Forward-Zone(n), die durchsucht werden. Ohne Angabe werden alle primären
    Forward-Zonen außer _msdcs.*, TrustAnchors und automatisch erzeugten Zonen verwendet.

.PARAMETER IpPattern
    Wildcard-Muster für den VPN-Pool, z. B. '192.0.2.*'. Mehrere Muster sind möglich.
    Nur Einträge mit passender IP werden betrachtet.

.PARAMETER ExcludeHostName
    Zusätzliche Hostnamen, die nie verändert werden. '@', 'DomainDnsZones',
    'ForestDnsZones' und 'gc' sind immer ausgeschlossen.

.PARAMETER IncludePtr
    Bezieht PTR-Einträge aus den primären Reverse-Zonen (*.in-addr.arpa) mit ein.

.PARAMETER FortiGateUrl
    Basis-URL der FortiGate, z. B. https://fw01.contoso.local:8443.
    Wenn angegeben, werden die aktiven VPN-IPs per REST-API abgefragt. Damit lassen sich
    auch einzelne verwaiste Einträge erkennen, die kein Duplikat sind.

.PARAMETER FortiGateTokenFile
    Datei mit dem API-Token eines REST-API-Admins (nur Lesezugriff nötig).

.PARAMETER FortiGateTunnelName
    Name der Dialup-Phase1 (z. B. 'VPN-Dialup'). Die Client-Instanzen heißen auf der
    FortiGate <Name> plus Index; nur diese Tunnel werden ausgewertet.

.PARAMETER FortiGateVdom
    VDOM der Abfrage. Standard: root.

.PARAMETER SkipCertificateCheck
    Zertifikatsprüfung der FortiGate deaktivieren (nur bei selbstsigniertem Zertifikat).

.PARAMETER OrphanMinAgeHours
    Mindestalter in Stunden, ab dem ein verwaister Eintrag gelöscht wird. Schützt Clients,
    die sich zwischen API-Abfrage und Löschung neu verbunden haben. Standard: 2.

.PARAMETER Remove
    Führt die Bereinigung tatsächlich aus. Ohne diesen Schalter wird nur berichtet.

.PARAMETER MaxRemove
    Obergrenze für Löschungen pro Lauf. Wird sie überschritten, bricht das Skript ohne
    Änderungen ab. Standard: 50.

.PARAMETER BackupPath
    Ordner für die CSV-Sicherung der gelöschten Einträge. Standard: .\Backup neben dem Skript.

.PARAMETER LogPath
    Ordner für ein Transcript-Log. Ohne Angabe wird kein Log geschrieben.

.PARAMETER ReportCsv
    Pfad einer CSV-Datei, in die der vollständige Bericht geschrieben wird.

.EXAMPLE
    .\Find-DNSDuplicates.ps1 | Where-Object Action -ne 'Keep' | Format-Table

    Bericht für den Standard-Pool 192.0.2.*. Zeigt nur Einträge, die entfernt oder
    übersprungen würden. Es wird nichts geändert.

.EXAMPLE
    .\Find-DNSDuplicates.ps1 -IncludePtr -Remove -WhatIf

    Vorschau der Bereinigung einschließlich PTR-Einträgen.

.EXAMPLE
    .\Find-DNSDuplicates.ps1 -IncludePtr -Remove -LogPath C:\Scripts\Logs | Format-Table

    Bereinigung mit Sicherung und Transcript-Log.

.EXAMPLE
    .\Find-DNSDuplicates.ps1 -IncludePtr -Remove -Confirm:$false `
        -FortiGateUrl https://fw01.contoso.local -FortiGateTokenFile C:\Secure\fgt-api.token `
        -FortiGateTunnelName 'VPN-Dialup' -LogPath C:\Scripts\Logs

    Vollständiger Abgleich mit der FortiGate, geeignet für einen geplanten Task
    (z. B. alle 5 Minuten). Exit-Code 0 = OK, 1 = Abbruch, 2 = einzelne Löschungen fehlgeschlagen.

.EXAMPLE
    .\Find-DNSDuplicates.ps1 -IpPattern '192.0.2.*','198.51.100.*' -ComputerName DC01

    Bericht für einen erweiterten Pool, remote gegen DC01.

.EXAMPLE
    .\Find-DNSDuplicates.ps1 -IpPattern '*' -Remove -MaxRemove 10000 -WhatIf | Format-Table

    Entspricht der Version 1.x ("$DuplicatesByIP | Remove-OldestDnsDuplicate -WhatIf"):
    alle IPs in allen primären Forward-Zonen, pro IP bleibt der neueste Eintrag.
    Ohne -WhatIf wird gelöscht. Abweichungen zu 1.x: Gruppen mit gleichem
    Zeitstempel werden übersprungen statt zufällig bereinigt, automatisch erzeugte
    Zonen sind ausgeschlossen, vor dem Löschen wird eine CSV-Sicherung angelegt.
    ACHTUNG: Betrifft alle Netze, auch IPs mit absichtlich mehreren dynamischen
    Namen (z. B. Cluster). Nur als Vergleichslauf mit -WhatIf empfohlen.

.INPUTS
    Keine.

.OUTPUTS
    PSCustomObject je Eintrag mit Ip, Type, HostName, Fqdn, Zone, Timestamp, Action
    (Keep/Remove/Skip), Reason und Result.

.NOTES
    Name     : Find-DNSDuplicates.ps1
    Version  : 2.0.1
    Stand    : 2026-10-13
    Autor    : IT-Administration

    Voraussetzungen:
      * Windows PowerShell 5.1 oder neuer, RSAT-Modul DnsServer
      * Rechte: DnsAdmins (bzw. Domänen-Admin) auf dem DNS-Server
      * Aging auf den Zonen aktiviert (Set-DnsServerZoneAging -Aging $true),
        sonst sind die Zeitstempel nicht verlässlich
      * FortiGate: ip-delay-interval >= 3600 in der Dialup-Phase1. DNS-Zeitstempel sind
        auf volle Stunden gerundet; ohne Delay entstehen häufig nicht entscheidbare
        Gleichstände (Action = Skip)
      * Für -FortiGateUrl: REST-API-Admin mit Lesezugriff, Trusted Hosts gesetzt.
        Die Feldnamen der API-Antwort (proxyid / proxy_dst / subnet) einmalig mit
        -Verbose gegen "diagnose vpn tunnel list" prüfen.

    Wiederherstellung aus der Sicherung (Einträge werden mit -AgeRecord wieder dynamisch):
      Import-Csv <Backup.csv> -Delimiter ';' | ForEach-Object {
          if ($_.Type -eq 'A') {
              Add-DnsServerResourceRecordA -ComputerName <DNS> -ZoneName $_.Zone -Name $_.HostName -IPv4Address $_.Ip -AgeRecord
          } else {
              Add-DnsServerResourceRecordPtr -ComputerName <DNS> -ZoneName $_.Zone -Name $_.HostName -PtrDomainName $_.Fqdn -AgeRecord
          }
      }

    Änderungen:
      2.0.1  Beispiel für das Verhalten der Version 1.x ergänzt.
      2.0.0  Auf VPN-Pool beschränkt (-IpPattern); Schutz bei gleichem Zeitstempel;
             PTR-Bereinigung; optionaler FortiGate-Abgleich für verwaiste Einträge;
             -Remove statt Löschung im Skriptkörper; CSV-Sicherung, MaxRemove-Grenze,
             Transcript, Exit-Codes; -ComputerName durchgängig; Ausgabe als Objekte.
             Find-DuplicateDnsByName entfernt (Hosts haben legitim mehrere IPs: LAN/WLAN/VPN).
      1.x    Ursprüngliche Version: Duplikate je IP über alle Zonen, neuester bleibt.
#>

#Requires -Version 5.1
#Requires -Modules DnsServer

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'DnsOnly')]
param(
    [string]$ComputerName = $env:COMPUTERNAME,

    [string[]]$ZoneName,

    [ValidateNotNullOrEmpty()]
    [string[]]$IpPattern = @('192.0.2.*'),

    [string[]]$ExcludeHostName = @(),

    [switch]$IncludePtr,

    [Parameter(ParameterSetName = 'FortiGate', Mandatory)]
    [uri]$FortiGateUrl,

    [Parameter(ParameterSetName = 'FortiGate', Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$FortiGateTokenFile,

    [Parameter(ParameterSetName = 'FortiGate', Mandatory)]
    [string]$FortiGateTunnelName,

    [Parameter(ParameterSetName = 'FortiGate')]
    [string]$FortiGateVdom = 'root',

    [Parameter(ParameterSetName = 'FortiGate')]
    [switch]$SkipCertificateCheck,

    [Parameter(ParameterSetName = 'FortiGate')]
    [ValidateRange(1, 168)]
    [int]$OrphanMinAgeHours = 2,

    [switch]$Remove,

    [ValidateRange(1, 10000)]
    [int]$MaxRemove = 50,

    [string]$BackupPath,

    [string]$LogPath,

    [string]$ReportCsv
)

$ScriptVersion = '2.0.1'

#region Hilfsfunktionen ---------------------------------------------------------------

function Test-IpPattern {
    param([string]$Ip, [string[]]$Pattern)
    foreach ($p in $Pattern) { if ($Ip -like $p) { return $true } }
    return $false
}

function ConvertFrom-PtrName {
    # '2' in Zone '2.0.192.in-addr.arpa' -> '192.0.2.2'
    param([string]$HostName, [string]$Zone)
    $labels = @(("$HostName." + ($Zone -replace '\.in-addr\.arpa$', '')) -split '\.')
    if ($labels.Count -ne 4) { return $null }
    [array]::Reverse($labels)
    return ($labels -join '.')
}

function New-DnsEntry {
    param($Type, $Zone, $HostName, $Fqdn, $Ip, $Timestamp, $Record)
    $obj = [pscustomobject]@{
        Ip        = $Ip
        Type      = $Type
        HostName  = $HostName
        Fqdn      = $Fqdn
        Zone      = $Zone
        Timestamp = $Timestamp
        Action    = 'Keep'
        Reason    = ''
        Result    = ''
        Record    = $Record
    }
    $display = New-Object Management.Automation.PSPropertySet('DefaultDisplayPropertySet',
        [string[]]@('Ip', 'Type', 'HostName', 'Zone', 'Timestamp', 'Action', 'Reason', 'Result'))
    $obj | Add-Member -MemberType MemberSet -Name PSStandardMembers `
        -Value ([Management.Automation.PSMemberInfo[]]@($display))
    return $obj
}

function Set-Decision {
    param($Entry, [ValidateSet('Keep', 'Remove', 'Skip')][string]$Action, [string]$Reason)
    $Entry.Action = $Action
    $Entry.Reason = $Reason
}

function Get-FortiGateActiveVpnIp {
    param([uri]$Url, [string]$TokenFile, [string]$TunnelName, [string]$Vdom,
          [switch]$SkipCertificateCheck, [string[]]$Pattern)

    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if ($SkipCertificateCheck) {
        [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }

    $token = (Get-Content -LiteralPath $TokenFile -Raw).Trim()
    $uri   = '{0}/api/v2/monitor/vpn/ipsec?vdom={1}' -f $Url.AbsoluteUri.TrimEnd('/'), $Vdom
    $resp  = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop `
                -Headers @{ Authorization = "Bearer $token" }

    if ($resp.status -ne 'success') { throw "FortiGate-API antwortet mit Status '$($resp.status)'." }

    # Nur Client-Instanzen der Dialup-Phase1 mit Phase2-Selektoren
    $tunnels = @($resp.results | Where-Object { $_.name -like "$TunnelName*" -and $_.proxyid })

    $ips = foreach ($t in $tunnels) {
        foreach ($p in @($t.proxyid)) {
            foreach ($d in @($p.proxy_dst)) {
                # Formate: '192.0.2.2-192.0.2.2' oder '192.0.2.2/255.255.255.255'
                if ($d.subnet) { ($d.subnet -split '[-/ ]')[0] }
            }
        }
    }
    $ips = @($ips | Where-Object { $_ -and (Test-IpPattern $_ $Pattern) } | Sort-Object -Unique)

    # Plausibilität: Tunnel vorhanden, aber keine IP gelesen -> Feldnamen passen nicht.
    if ($tunnels.Count -gt 0 -and $ips.Count -eq 0) {
        throw ("FortiGate meldet $($tunnels.Count) Tunnel '$TunnelName*', aber keine IP im Muster. " +
               "JSON-Felder (proxyid/proxy_dst/subnet) prüfen. Abbruch ohne Änderungen.")
    }
    Write-Verbose ("FortiGate: {0} Client-Tunnel, aktive VPN-IPs: {1}" -f $tunnels.Count, ($ips -join ', '))
    return , $ips
}

#endregion

#region Hauptteil ---------------------------------------------------------------------

$exitCode     = 0
$transcriptOn = $false
$exclude      = @('@', 'DomainDnsZones', 'ForestDnsZones', 'gc') + $ExcludeHostName
$useFortiGate = $PSCmdlet.ParameterSetName -eq 'FortiGate'
$stamp        = Get-Date -Format 'yyyyMMdd-HHmmss'
$scriptDir    = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

try {
    if ($LogPath) {
        New-Item -ItemType Directory -Path $LogPath -Force -WhatIf:$false | Out-Null
        Start-Transcript -Path (Join-Path $LogPath "DNS-VPN-Cleanup-$stamp.log") -WhatIf:$false | Out-Null
        $transcriptOn = $true
    }
    Write-Verbose "Find-DNSDuplicates $ScriptVersion | Server: $ComputerName | Muster: $($IpPattern -join ', ') | Remove: $Remove"

    # --- Phase 0: aktive IPs von der FortiGate (vor jeder DNS-Aktion; Fehler = Abbruch)
    $activeIps = @()
    if ($useFortiGate) {
        $activeIps = Get-FortiGateActiveVpnIp -Url $FortiGateUrl -TokenFile $FortiGateTokenFile `
            -TunnelName $FortiGateTunnelName -Vdom $FortiGateVdom `
            -SkipCertificateCheck:$SkipCertificateCheck -Pattern $IpPattern
    }

    # --- Zonen ermitteln
    $allZones = @(Get-DnsServerZone -ComputerName $ComputerName -ErrorAction Stop)
    $fwdZones = if ($ZoneName) { @($ZoneName) } else {
        @($allZones | Where-Object {
            -not $_.IsReverseLookupZone -and $_.ZoneType -eq 'Primary' -and -not $_.IsAutoCreated -and
            $_.ZoneName -notlike '_msdcs.*' -and $_.ZoneName -ne 'TrustAnchors'
        } | Select-Object -ExpandProperty ZoneName)
    }
    $revZones = @()
    if ($IncludePtr) {
        $revZones = @($allZones | Where-Object {
            $_.IsReverseLookupZone -and $_.ZoneType -eq 'Primary' -and -not $_.IsAutoCreated -and
            $_.ZoneName -like '*.in-addr.arpa'
        } | Select-Object -ExpandProperty ZoneName)
    }

    foreach ($z in $fwdZones + $revZones) {
        $aging = Get-DnsServerZoneAging -ComputerName $ComputerName -Name $z -ErrorAction SilentlyContinue
        if ($aging -and -not $aging.AgingEnabled) {
            Write-Warning "Aging ist auf Zone '$z' deaktiviert - Zeitstempel sind nicht verlässlich."
        }
    }

    # --- Phase 1: erfassen
    $entries = New-Object System.Collections.Generic.List[object]

    foreach ($z in $fwdZones) {
        foreach ($r in @(Get-DnsServerResourceRecord -ComputerName $ComputerName -ZoneName $z -RRType A -ErrorAction Stop)) {
            if (-not $r.Timestamp -or $exclude -contains $r.HostName) { continue }
            $ip = $r.RecordData.IPv4Address.IPAddressToString
            if (-not (Test-IpPattern $ip $IpPattern)) { continue }
            $entries.Add((New-DnsEntry 'A' $z $r.HostName "$($r.HostName).$z" $ip $r.Timestamp $r))
        }
    }

    foreach ($z in $revZones) {
        foreach ($r in @(Get-DnsServerResourceRecord -ComputerName $ComputerName -ZoneName $z -RRType Ptr -ErrorAction Stop)) {
            if (-not $r.Timestamp -or $r.HostName -eq '@') { continue }
            $ip = ConvertFrom-PtrName $r.HostName $z
            if (-not $ip -or -not (Test-IpPattern $ip $IpPattern)) { continue }
            $entries.Add((New-DnsEntry 'PTR' $z $r.HostName $r.RecordData.PtrDomainName.TrimEnd('.') $ip $r.Timestamp $r))
        }
    }
    Write-Verbose "Erfasst: $(@($entries | Where-Object Type -eq 'A').Count) A, $(@($entries | Where-Object Type -eq 'PTR').Count) PTR"

    # --- Phase 2: bewerten
    $now        = Get-Date
    $validFqdn  = @{}   # IP -> FQDN des gültigen A-Eintrags
    $zoneSuffix = @(foreach ($z in $fwdZones) { ".$z" })   # kein ForEach-Object: wird bei -WhatIf übersprungen

    $isOrphanIp = { param($ip) $useFortiGate -and ($activeIps -notcontains $ip) }
    $markOrphan = {
        param($list)
        foreach ($e in $list) {
            if (($now - $e.Timestamp).TotalHours -ge $OrphanMinAgeHours) {
                Set-Decision $e 'Remove' 'IP laut FortiGate nicht aktiv (verwaist)'
            } else {
                Set-Decision $e 'Keep' "Verwaist, aber jünger als $OrphanMinAgeHours h"
            }
        }
    }

    foreach ($g in @($entries | Where-Object Type -eq 'A' | Group-Object Ip)) {
        $sorted = @($g.Group | Sort-Object Timestamp -Descending)
        if (& $isOrphanIp $g.Name) { & $markOrphan $sorted; continue }

        if ($sorted.Count -eq 1) {
            Set-Decision $sorted[0] 'Keep' 'Einziger Eintrag'
        } elseif ($sorted[0].Timestamp -eq $sorted[1].Timestamp) {
            foreach ($e in $sorted) { Set-Decision $e 'Skip' 'Gleicher Zeitstempel - manuell prüfen' }
            continue
        } else {
            Set-Decision $sorted[0] 'Keep' 'Neuester Eintrag'
            foreach ($e in @($sorted | Select-Object -Skip 1)) {
                Set-Decision $e 'Remove' "Älter als $($sorted[0].HostName)"
            }
        }
        $validFqdn[$g.Name] = $sorted[0].Fqdn
    }

    foreach ($g in @($entries | Where-Object Type -eq 'PTR' | Group-Object Ip)) {
        $sorted = @($g.Group | Sort-Object Timestamp -Descending)
        if (& $isOrphanIp $g.Name) { & $markOrphan $sorted; continue }

        $target = $validFqdn[$g.Name]
        if ($target) {
            $match = @($sorted | Where-Object { $_.Fqdn -eq $target })
            $keep  = if ($match.Count) { $match[0] } else { $null }
            foreach ($e in $sorted) {
                if ($e -eq $keep) {
                    Set-Decision $e 'Keep' 'Passt zum gültigen A-Eintrag'
                } elseif (@($zoneSuffix | Where-Object { $e.Fqdn -like "*$_" }).Count) {
                    Set-Decision $e 'Remove' "Zeigt nicht auf gültigen A-Eintrag ($target)"
                } else {
                    Set-Decision $e 'Skip' 'Ziel liegt in nicht durchsuchter Zone'
                }
            }
            continue
        }

        # Kein gültiger A-Eintrag bekannt: Regel "neuester bleibt"
        if ($sorted.Count -eq 1) {
            Set-Decision $sorted[0] 'Keep' 'Einziger Eintrag (kein A-Abgleich möglich)'
        } elseif ($sorted[0].Timestamp -eq $sorted[1].Timestamp) {
            foreach ($e in $sorted) { Set-Decision $e 'Skip' 'Gleicher Zeitstempel - manuell prüfen' }
        } else {
            Set-Decision $sorted[0] 'Keep' 'Neuester Eintrag'
            foreach ($e in @($sorted | Select-Object -Skip 1)) { Set-Decision $e 'Remove' 'Älterer PTR' }
        }
    }

    $toRemove = @($entries | Where-Object Action -eq 'Remove')
    $toSkip   = @($entries | Where-Object Action -eq 'Skip')
    foreach ($e in $toSkip) { Write-Warning "Übersprungen: $($e.Type) $($e.Fqdn) -> $($e.Ip) ($($e.Reason))" }

    # --- Phase 3: bereinigen
    $failed = 0
    if ($Remove -and $toRemove.Count -gt 0) {
        if ($toRemove.Count -gt $MaxRemove) {
            throw "Geplant sind $($toRemove.Count) Löschungen, erlaubt sind $MaxRemove (-MaxRemove). Abbruch ohne Änderungen."
        }

        if (-not $WhatIfPreference) {
            $backupDir = if ($BackupPath) { $BackupPath } else { Join-Path $scriptDir 'Backup' }
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            $backupFile = Join-Path $backupDir "DNS-VPN-Backup-$stamp.csv"
            $toRemove | Select-Object Type, Zone, HostName, Fqdn, Ip, Timestamp, Reason |
                Export-Csv -LiteralPath $backupFile -Delimiter ';' -NoTypeInformation -Encoding UTF8
            Write-Verbose "Sicherung: $backupFile"
        }

        foreach ($e in $toRemove) {
            $target = "$($e.Type) $($e.Fqdn) -> $($e.Ip) [Zone $($e.Zone)]"
            if ($PSCmdlet.ShouldProcess($target, 'DNS-Eintrag entfernen')) {
                try {
                    Remove-DnsServerResourceRecord -ComputerName $ComputerName -ZoneName $e.Zone `
                        -InputObject $e.Record -Force -ErrorAction Stop
                    $e.Result = 'Removed'
                } catch {
                    $e.Result = "Fehler: $($_.Exception.Message)"
                    Write-Warning "Löschen fehlgeschlagen: $target - $($_.Exception.Message)"
                    $failed++
                }
            } else {
                $e.Result = 'WhatIf'
            }
        }
    }
    if ($failed -gt 0) { $exitCode = 2 }

    $summary = 'Find-DNSDuplicates {0}: {1} Einträge, {2} zu entfernen, {3} übersprungen, {4} entfernt, {5} Fehler{6}' -f `
        $ScriptVersion, $entries.Count, $toRemove.Count, $toSkip.Count,
        @($entries | Where-Object Result -eq 'Removed').Count, $failed,
        $(if (-not $Remove) { ' (nur Bericht, -Remove nicht gesetzt)' })
    Write-Information -MessageData $summary -InformationAction Continue

    if ($ReportCsv) {
        $entries | Select-Object Ip, Type, HostName, Fqdn, Zone, Timestamp, Action, Reason, Result |
            Export-Csv -LiteralPath $ReportCsv -Delimiter ';' -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    }

    $entries | Sort-Object { [version]$_.Ip }, Type, @{ Expression = 'Timestamp'; Descending = $true }
}
catch {
    Write-Error -ErrorRecord $_
    $exitCode = 1
}
finally {
    if ($transcriptOn) { Stop-Transcript | Out-Null }
}

exit $exitCode

#endregion
