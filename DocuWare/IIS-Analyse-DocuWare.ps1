function Get-IISLogFull {
    <#
    .SYNOPSIS
    Gibt alle IIS-Logzeilen der letzten X Minuten als PSCustomObject zurück (alle Felder).
    
    .DESCRIPTION
    Liest IIS-Logdateien und konvertiert UTC-Zeitstempel in lokale Zeit.
    Unterstützt große Dateien durch Stream-basiertes Lesen.
    Kann auch Dateien lesen, die aktuell von IIS verwendet werden.
    
    .PARAMETER LogPath
    Pfad zum IIS-Log-Verzeichnis (z.B. W3SVC1 Ordner oder übergeordneter LogFiles Ordner)
    
    .PARAMETER Minutes
    Anzahl der Minuten in der Vergangenheit, die ausgewertet werden sollen
    
    .PARAMETER ConvertFromUTC
    Konvertiert UTC-Zeitstempel zu lokaler Zeit (Standard: $true)
    
    .EXAMPLE
    Get-IISLogFull -Minutes 60
    Get-IISLogFull -LogPath "C:\inetpub\logs\LogFiles" -Minutes 120
    #>
    [CmdletBinding()]
    param(
        [string]$LogPath = "$env:SystemDrive\inetpub\logs\LogFiles\W3SVC1",
        [int]$Minutes = 60,
        [switch]$ConvertFromUTC = $true
    )
    
    begin {
        # Zeitgrenze berechnen (für Dateifilter in lokaler Zeit)
        $sinceLocal = (Get-Date).AddMinutes(-$Minutes)
        # Für Zeilenfilter in UTC
        $sinceUTC = $sinceLocal.ToUniversalTime()
        
        Write-Verbose "Suche nach Dateien geändert seit: $($sinceLocal.ToString('yyyy-MM-dd HH:mm:ss')) Local"
        Write-Verbose "Suche nach Log-Einträgen seit: $($sinceUTC.ToString('yyyy-MM-dd HH:mm:ss')) UTC"
        
        # Prüfen ob Pfad existiert
        if (-not (Test-Path $LogPath)) {
            Write-Error "Pfad nicht gefunden: $LogPath"
            return
        }
        
        # Bestimmen ob es ein Verzeichnis oder eine Datei ist
        $item = Get-Item $LogPath
        
        if ($item.PSIsContainer) {
            # Prüfen ob wir bereits in einem W3SVC* Verzeichnis sind oder im übergeordneten LogFiles Ordner
            if ($item.Name -match '^W3SVC\d+$') {
                # Wir sind bereits in einem Site-spezifischen Verzeichnis
                Write-Verbose "Durchsuche Site-Verzeichnis: $($item.Name)"
                $logFiles = Get-ChildItem $item.FullName -Filter *.log -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -ge $sinceLocal }
            }
            else {
                # Wir sind im übergeordneten Verzeichnis - suche in allen W3SVC* Unterverzeichnissen
                Write-Verbose "Durchsuche übergeordnetes Verzeichnis nach W3SVC* Ordnern"
                $logFiles = Get-ChildItem $item.FullName -Directory -Filter "W3SVC*" | ForEach-Object {
                    Write-Verbose "Prüfe Unterverzeichnis: $($_.Name)"
                    Get-ChildItem $_.FullName -Filter *.log -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -ge $sinceLocal }
                }
                
                # Falls keine W3SVC* Verzeichnisse gefunden, suche direkt nach .log Dateien
                if (-not $logFiles) {
                    Write-Verbose "Keine W3SVC* Verzeichnisse gefunden, suche direkt nach .log Dateien"
                    $logFiles = Get-ChildItem $item.FullName -Filter *.log -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -ge $sinceLocal }
                }
            }
        }
        else {
            # Einzelne Datei
            $logFiles = @($item) | Where-Object { $_.Extension -eq '.log' }
        }
        
        if (-not $logFiles) {
            Write-Warning "Keine Logdateien gefunden für den angegebenen Zeitraum (letzte $Minutes Minuten)"
            Write-Verbose "Gesucht in: $LogPath"
            
            # Debug-Info ausgeben
            $allLogs = Get-ChildItem $LogPath -Filter *.log -ErrorAction SilentlyContinue | 
            Select-Object Name, LastWriteTime | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 5
            
            if ($allLogs) {
                Write-Verbose "Neueste Logdateien im Verzeichnis:"
                $allLogs | ForEach-Object {
                    Write-Verbose "  $($_.Name) - Letzte Änderung: $($_.LastWriteTime)"
                }
            }
            return
        }
        
        $logFiles = $logFiles | Sort-Object LastWriteTime -Descending
        Write-Verbose "Verarbeite $($logFiles.Count) Logdatei(en)"
    }
    
    process {
        foreach ($file in $logFiles) {
            Write-Verbose "Verarbeite: $($file.Name) (Größe: $([math]::Round($file.Length/1MB,2)) MB)"
            
            # Site-ID aus Pfad extrahieren
            $siteId = if ($file.Directory.Name -match 'W3SVC\d+') {
                $file.Directory.Name
            }
            else {
                'Unknown'
            }
            
            # FileStream mit FileShare.ReadWrite für Dateien die von IIS noch verwendet werden
            $fileStream = $null
            $reader = $null
            $processedLines = 0
            $outputLines = 0
            
            try {
                # Öffne Datei mit Shared Read/Write Access
                $fileStream = [System.IO.FileStream]::new(
                    $file.FullName,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::ReadWrite
                )
                
                $reader = [System.IO.StreamReader]::new($fileStream)
                $fields = @()
                $lineNumber = 0
                
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    $lineNumber++
                    
                    # Felder-Definition extrahieren
                    if ($line -match '^#Fields:\s+(.+)$') {
                        $fields = $matches[1] -split '\s+'
                        Write-Verbose "  Felder gefunden in Zeile $lineNumber : $($fields.Count) Felder"
                        continue
                    }
                    
                    # Kommentare und leere Zeilen überspringen
                    if ($line -match '^#' -or [string]::IsNullOrWhiteSpace($line)) {
                        continue
                    }
                    
                    # Keine Felder definiert - Datei überspringen
                    if (-not $fields) {
                        Write-Warning "Keine Feld-Definition in $($file.Name) gefunden"
                        break
                    }
                    
                    $processedLines++
                    
                    # Zeile parsen
                    $values = $line -split ' '
                    if ($values.Count -ne $fields.Count) {
                        Write-Debug "Zeile $lineNumber hat falsche Anzahl Felder: erwartet $($fields.Count), gefunden $($values.Count)"
                        continue
                    }
                    
                    # Datum/Zeit parsen und prüfen
                    try {
                        # IIS speichert normalerweise in UTC
                        $dateIndex = [Array]::IndexOf($fields, 'date')
                        $timeIndex = [Array]::IndexOf($fields, 'time')
                        
                        if ($dateIndex -ge 0 -and $timeIndex -ge 0) {
                            # Parse als UTC Zeit
                            $utcTime = [datetime]::Parse("$($values[$dateIndex]) $($values[$timeIndex])")
                            $utcTime = [datetime]::SpecifyKind($utcTime, [System.DateTimeKind]::Utc)
                            
                            # Zeitfilter prüfen (in UTC)
                            if ($utcTime -lt $sinceUTC) {
                                continue
                            }
                            
                            $outputLines++
                            
                            # Objekt erstellen
                            $obj = [ordered]@{
                                'SiteId'  = $siteId
                                'LogFile' = $file.Name
                            }
                            
                            # Alle Felder hinzufügen
                            for ($i = 0; $i -lt $fields.Count; $i++) {
                                $fieldName = $fields[$i]
                                $value = $values[$i]
                                
                                # Original-Wert speichern
                                $obj[$fieldName] = if ($value -eq '-') { $null } else { $value }
                            }
                            
                            # Zeit in lokale Zeit konvertieren, wenn gewünscht
                            if ($ConvertFromUTC) {
                                $localTime = $utcTime.ToLocalTime()
                                $obj['LocalDateTime'] = $localTime
                                $obj['LocalDate'] = $localTime.ToString('yyyy-MM-dd')
                                $obj['LocalTime'] = $localTime.ToString('HH:mm:ss')
                            }
                            
                            # Zusätzliche nützliche Felder
                            if ($obj['sc-status']) {
                                $obj['StatusCategory'] = switch -Regex ($obj['sc-status']) {
                                    '^2\d{2}$' { 'Success' }
                                    '^3\d{2}$' { 'Redirect' }
                                    '^4\d{2}$' { 'ClientError' }
                                    '^5\d{2}$' { 'ServerError' }
                                    default { 'Unknown' }
                                }
                            }
                            
                            # Response-Zeit in Millisekunden, falls vorhanden
                            if ($obj['time-taken']) {
                                try {
                                    $obj['ResponseTimeMs'] = [int]$obj['time-taken']
                                }
                                catch { }
                            }
                            
                            # Ausgabe
                            [PSCustomObject]$obj
                        }
                    }
                    catch {
                        Write-Debug "Fehler beim Parsen der Zeile $lineNumber : $_"
                        continue
                    }
                }
                
                Write-Verbose "  Datei abgeschlossen: $processedLines Zeilen verarbeitet, $outputLines Zeilen ausgegeben"
            }
            catch {
                Write-Error "Fehler beim Lesen der Datei $($file.Name): $_"
            }
            finally {
                if ($reader) {
                    $reader.Dispose()
                }
                if ($fileStream) {
                    $fileStream.Dispose()
                }
            }
        }
    }
}

# Schnell-Check Funktion für aktuelle Logs
function Get-IISLogRecent {
    <#
    .SYNOPSIS
    Zeigt die letzten N Log-Einträge an (Standard: 50)
    #>
    param(
        [string]$LogPath = "$env:SystemDrive\inetpub\logs\LogFiles\W3SVC1",
        [int]$Last = 50
    )
    
    Get-IISLogFull -LogPath $LogPath -Minutes 1440 | 
    Select-Object -Last $Last |
    Select-Object LocalDateTime, 'c-ip', 'cs-method', 'cs-uri-stem', 'sc-status', ResponseTimeMs |
    Format-Table -AutoSize
}

# Funktion für Live-Monitoring (ähnlich wie tail -f)
function Watch-IISLog {
    <#
    .SYNOPSIS
    Live-Monitoring der IIS-Logs (ähnlich wie tail -f)
    #>
    param(
        [string]$LogPath = "$env:SystemDrive\inetpub\logs\LogFiles\W3SVC1",
        [int]$RefreshSeconds = 5
    )
    
    $lastPosition = @{}
    
    Write-Host "Live-Monitoring gestartet. Drücke Ctrl+C zum Beenden." -ForegroundColor Green
    Write-Host "Aktualisierung alle $RefreshSeconds Sekunden..." -ForegroundColor Yellow
    Write-Host ""
    
    while ($true) {
        $logs = Get-IISLogFull -LogPath $LogPath -Minutes 2 | 
        Where-Object { 
            $key = "$($_.LogFile):$($_.date):$($_.time)"
            if ($lastPosition.ContainsKey($key)) {
                $false
            }
            else {
                $lastPosition[$key] = $true
                $true
            }
        } |
        Select-Object LocalDateTime, 'c-ip', 'cs-method', 'cs-uri-stem', 'sc-status', ResponseTimeMs
        
        if ($logs) {
            $logs | ForEach-Object {
                $statusColor = switch ($_.StatusCategory) {
                    'Success' { 'Green' }
                    'Redirect' { 'Yellow' }
                    'ClientError' { 'Magenta' }
                    'ServerError' { 'Red' }
                    default { 'White' }
                }
                
                Write-Host "$($_.LocalDateTime) " -NoNewline
                Write-Host "$($_.'sc-status') " -ForegroundColor $statusColor -NoNewline
                Write-Host "$($_.'cs-method') $($_.'cs-uri-stem') " -NoNewline
                Write-Host "[$($_.'c-ip')] " -ForegroundColor Cyan -NoNewline
                if ($_.ResponseTimeMs -gt 1000) {
                    Write-Host "$($_.ResponseTimeMs)ms" -ForegroundColor Red
                }
                else {
                    Write-Host "$($_.ResponseTimeMs)ms"
                }
            }
        }
        
        Start-Sleep -Seconds $RefreshSeconds
    }
}

function Get-IISLogStatistics {
    <#
    .SYNOPSIS
    Erstellt eine detaillierte Statistik der IIS-Logs mit formatierter Ausgabe
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject[]]$LogEntries,
        [switch]$ShowDetails
    )
    
    begin {
        $stats = @{
            TotalRequests = 0
            StatusCodes   = @{}
            TopPaths      = @{}
            TopClientIPs  = @{}
            Errors        = @()
            SlowRequests  = @()
            UserAgents    = @{}
            ErrorsByPath  = @{}
        }
        $startTime = $null
        $endTime = $null
    }
    
    process {
        foreach ($entry in $LogEntries) {
            $stats.TotalRequests++
            
            # Zeitraum ermitteln
            if ($entry.LocalDateTime) {
                if ($null -eq $startTime -or $entry.LocalDateTime -lt $startTime) {
                    $startTime = $entry.LocalDateTime
                }
                if ($null -eq $endTime -or $entry.LocalDateTime -gt $endTime) {
                    $endTime = $entry.LocalDateTime
                }
            }
            
            # Status-Codes zählen
            if ($entry.'sc-status') {
                $status = $entry.'sc-status'
                if (-not $stats.StatusCodes.ContainsKey($status)) {
                    $stats.StatusCodes[$status] = 0
                }
                $stats.StatusCodes[$status]++
                
                # Fehler sammeln (4xx und 5xx)
                if ($status -match '^[45]\d{2}$') {
                    $stats.Errors += $entry
                    
                    # Fehler nach Pfad gruppieren
                    $path = $entry.'cs-uri-stem'
                    if ($path) {
                        if (-not $stats.ErrorsByPath.ContainsKey($path)) {
                            $stats.ErrorsByPath[$path] = @{
                                Count       = 0
                                StatusCodes = @{}
                            }
                        }
                        $stats.ErrorsByPath[$path].Count++
                        if (-not $stats.ErrorsByPath[$path].StatusCodes.ContainsKey($status)) {
                            $stats.ErrorsByPath[$path].StatusCodes[$status] = 0
                        }
                        $stats.ErrorsByPath[$path].StatusCodes[$status]++
                    }
                }
            }
            
            # Langsame Requests (> 5 Sekunden)
            if ($entry.ResponseTimeMs -and $entry.ResponseTimeMs -gt 5000) {
                $stats.SlowRequests += $entry
            }
            
            # Top-Pfade
            if ($entry.'cs-uri-stem') {
                $path = $entry.'cs-uri-stem'
                if (-not $stats.TopPaths.ContainsKey($path)) {
                    $stats.TopPaths[$path] = 0
                }
                $stats.TopPaths[$path]++
            }
            
            # Top Client-IPs
            if ($entry.'c-ip') {
                $ip = $entry.'c-ip'
                if (-not $stats.TopClientIPs.ContainsKey($ip)) {
                    $stats.TopClientIPs[$ip] = 0
                }
                $stats.TopClientIPs[$ip]++
            }
            
            # User Agents
            if ($entry.'cs(User-Agent)' -and $entry.'cs(User-Agent)' -ne '-') {
                $ua = $entry.'cs(User-Agent)'
                if (-not $stats.UserAgents.ContainsKey($ua)) {
                    $stats.UserAgents[$ua] = 0
                }
                $stats.UserAgents[$ua]++
            }
        }
    }
    
    end {
        # Übersicht
        Write-Host "==================== IIS LOG STATISTIK ====================" -ForegroundColor Cyan
        Write-Host "Zeitraum: " -NoNewline
        if ($startTime -and $endTime) {
            Write-Host "$($startTime.ToString('dd.MM.yyyy HH:mm:ss')) - $($endTime.ToString('dd.MM.yyyy HH:mm:ss'))" -ForegroundColor Yellow
            $duration = $endTime - $startTime
            Write-Host "Dauer: $([math]::Round($duration.TotalMinutes, 1)) Minuten"
        }
        Write-Host "Gesamt-Requests: $($stats.TotalRequests)" -ForegroundColor Yellow
        
        # Status-Code Verteilung
        Write-Host "=== STATUS CODES ===" -ForegroundColor Cyan
        $stats.StatusCodes.GetEnumerator() | 
        Sort-Object Value -Descending | 
        ForEach-Object {
            $percent = [math]::Round(($_.Value / $stats.TotalRequests) * 100, 1)
            $color = switch -Regex ($_.Key) {
                '^2\d{2}$' { 'Green' }
                '^3\d{2}$' { 'Yellow' }
                '^4\d{2}$' { 'Magenta' }
                '^5\d{2}$' { 'Red' }
                default { 'White' }
            }
            Write-Host "  $($_.Key): " -NoNewline
            Write-Host "$($_.Value)" -ForegroundColor $color -NoNewline
            Write-Host " ($percent%)"
        }
        
        # Fehlerhafte Pfade
        if ($stats.ErrorsByPath.Count -gt 0) {
            Write-Host "=== TOP FEHLERHAFTE PFADE ===" -ForegroundColor Red
            $stats.ErrorsByPath.GetEnumerator() | 
            Sort-Object { $_.Value.Count } -Descending |
            Select-Object -First 10 |
            ForEach-Object {
                Write-Host "  $($_.Value.Count)x " -ForegroundColor Red -NoNewline
                Write-Host $_.Key -NoNewline
                Write-Host " (" -NoNewline
                $_.Value.StatusCodes.GetEnumerator() | ForEach-Object {
                    Write-Host "$($_.Key):$($_.Value) " -NoNewline -ForegroundColor Yellow
                }
                Write-Host ")"
            }
        }
        
        # Top Pfade
        Write-Host "=== TOP 10 PFADE ===" -ForegroundColor Cyan
        $stats.TopPaths.GetEnumerator() | 
        Sort-Object Value -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            $percent = [math]::Round(($_.Value / $stats.TotalRequests) * 100, 1)
            Write-Host "  $($_.Value)x ($percent%) $($_.Key)"
        }
        
        # Top IPs
        Write-Host "=== TOP 10 CLIENT IPS ===" -ForegroundColor Cyan
        $stats.TopClientIPs.GetEnumerator() | 
        Sort-Object Value -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            $percent = [math]::Round(($_.Value / $stats.TotalRequests) * 100, 1)
            Write-Host "  $($_.Value)x ($percent%) " -NoNewline
            Write-Host $_.Key -ForegroundColor Yellow
        }
        
        # Langsame Requests
        if ($stats.SlowRequests.Count -gt 0) {
            Write-Host "=== LANGSAME REQUESTS (>5 Sek) ===" -ForegroundColor Red
            Write-Host "Anzahl: $($stats.SlowRequests.Count)"
            $stats.SlowRequests |
            Sort-Object ResponseTimeMs -Descending |
            Select-Object -First 10 |
            ForEach-Object {
                Write-Host "  $([math]::Round($_.ResponseTimeMs/1000, 1))s " -ForegroundColor Red -NoNewline
                Write-Host "$($_.'cs-method') $($_.'cs-uri-stem') " -NoNewline
                Write-Host "[$($_.'c-ip')]" -ForegroundColor Cyan
            }
        }
        
        # Details wenn gewünscht
        if ($ShowDetails) {
            Write-Host "=== LETZTE 20 FEHLER ===" -ForegroundColor Red
            $stats.Errors |
            Sort-Object LocalDateTime -Descending |
            Select-Object -First 20 |
            ForEach-Object {
                Write-Host "$($_.LocalDateTime) " -NoNewline
                Write-Host "$($_.'sc-status') " -ForegroundColor Red -NoNewline
                Write-Host "$($_.'cs-method') $($_.'cs-uri-stem') " -NoNewline
                Write-Host "[$($_.'c-ip')] " -ForegroundColor Cyan -NoNewline
                Write-Host "$($_.ResponseTimeMs)ms"
            }
        }
        
        # Rückgabe-Objekt für weitere Verarbeitung
        [PSCustomObject]@{
            TotalRequests          = $stats.TotalRequests
            TimeRange              = if ($startTime -and $endTime) { 
                "$($startTime.ToString('yyyy-MM-dd HH:mm:ss')) - $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" 
            }
            else { "Unknown" }
            Duration               = if ($startTime -and $endTime) { $endTime - $startTime } else { $null }
            StatusCodeDistribution = $stats.StatusCodes
            ErrorsByPath           = $stats.ErrorsByPath
            TopPaths               = $stats.TopPaths.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20
            TopClientIPs           = $stats.TopClientIPs.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20
            RecentErrors           = $stats.Errors | Sort-Object LocalDateTime -Descending | Select-Object -First 50
            SlowRequests           = $stats.SlowRequests | Sort-Object ResponseTimeMs -Descending | Select-Object -First 50
        }
    }
}

# Spezialisierte Fehleranalyse
function Get-IISLogErrors {
    param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject[]]$LogEntries,
        [int[]]$StatusCodes = @(400, 401, 403, 404, 500, 502, 503)
    )
    
    process {
        $LogEntries | Where-Object { $_.'sc-status' -in $StatusCodes }
    }
}

# DocuWare-spezifische Analyse (da du DocuWare nutzt)
function Get-DocuWareErrors {
    param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject[]]$LogEntries
    )
    
    begin {
        Write-Host "=== DOCUWARE FEHLER-ANALYSE ===" -ForegroundColor Cyan
        $docuwareErrors = @{}
    }
    
    process {
        $LogEntries | 
        Where-Object { $_.'cs-uri-stem' -like '/DocuWare/*' -and $_.'sc-status' -ge 400 } |
        ForEach-Object {
            $service = if ($_.'cs-uri-stem' -match '/DocuWare/([^/]+)') { $matches[1] } else { 'Unknown' }
            if (-not $docuwareErrors.ContainsKey($service)) {
                $docuwareErrors[$service] = @{
                    Count       = 0
                    Errors      = @()
                    StatusCodes = @{}
                }
            }
            $docuwareErrors[$service].Count++
            $docuwareErrors[$service].Errors += $_
                
            $status = $_.'sc-status'
            if (-not $docuwareErrors[$service].StatusCodes.ContainsKey($status)) {
                $docuwareErrors[$service].StatusCodes[$status] = 0
            }
            $docuwareErrors[$service].StatusCodes[$status]++
        }
    }
    
    end {
        $docuwareErrors.GetEnumerator() | 
        Sort-Object { $_.Value.Count } -Descending |
        ForEach-Object {
            Write-Host "Service: " -NoNewline
            Write-Host $_.Key -ForegroundColor Yellow
            Write-Host "  Fehler gesamt: " -NoNewline
            Write-Host $_.Value.Count -ForegroundColor Red
            Write-Host "  Status Codes: " -NoNewline
            $_.Value.StatusCodes.GetEnumerator() | ForEach-Object {
                Write-Host "$($_.Key):$($_.Value) " -NoNewline -ForegroundColor Magenta
            }
            Write-Host ""
                
            # Letzte 3 Fehler dieses Services
            Write-Host "  Letzte Fehler:"
            $_.Value.Errors | 
            Sort-Object LocalDateTime -Descending |
            Select-Object -First 3 |
            ForEach-Object {
                Write-Host "    $($_.LocalDateTime) - $($_.'sc-status') - $($_.'cs-uri-stem')"
            }
        }
    }
}

# Beispielnutzung:
$logs = Get-IISLogFull -Minutes 600 -Verbose

# Übersichtliche Statistik anzeigen
# $logs | Get-IISLogStatistics

# Mit Details (zeigt auch die letzten Fehler)
$logs | Get-IISLogStatistics -ShowDetails

# Nur Fehler analysieren
# $logs | Get-IISLogErrors | Format-Table LocalDateTime, sc-status, cs-uri-stem, c-ip -AutoSize

# DocuWare-spezifische Fehleranalyse
$logs | Get-DocuWareErrors
