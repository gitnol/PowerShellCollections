#Requires -Version 5.1
<#
.SYNOPSIS
    Packt Ordner oder Dateien in monatliche 7z-Archive (z. B. 2025.10.7z) und loescht die Quellen
    optional erst, nachdem der Archivinhalt automatisch gegen die Quelle verglichen wurde.
.DESCRIPTION
    Je Monat: Archiv anlegen bzw. aktualisieren (7z u) -> Archiv testen (7z t) -> Archivinhalt auflisten
    und mit der Quelle vergleichen (Pfad und Groesse jeder Datei) -> nur mit -RemoveSource und nur bei
    erfolgreichem Vergleich die gepackten Quellen loeschen.

    Zwei Betriebsarten:
    - Ordner (Standard): direkte Unterordner von -SourcePath, Monat laut Datum im Ordnernamen
      (-NamePattern, Standard JJJJ.MM.TT ...). Ordner aus -ExcludeFolders werden nie angefasst.
    - Dateien (-ItemType File): Dateien direkt in -SourcePath (nicht rekursiv), gefiltert mit -Filter,
      Monat laut Aenderungsdatum (-GroupBy LastWriteTime ist hier der Standard).

    Der Lauf ist wiederholbar (7z u aktualisiert nur). Ein zweiter, gleichzeitiger Lauf wird verhindert.
    Mit -WhatIf wird nichts gepackt oder geloescht, nur protokolliert.
.PARAMETER SourcePath
    Quellordner (Pflichtparameter), z. B. D:\Data\Export
.PARAMETER ArchivePath
    Zielordner der Archive. Standard: <SourcePath>\gepackt
.PARAMETER LogPath
    Protokolldatei. Standard: <ArchivePath>\Compress-ItemsByMonth.log
.PARAMETER SevenZipPath
    Pfad zu 7z.exe. Standard: automatische Suche (Programme, PATH).
.PARAMETER ItemType
    Folder (Standard) oder File.
.PARAMETER GroupBy
    NameDate = Monat aus dem Datum im Namen (-NamePattern); LastWriteTime = Monat des Aenderungsdatums.
    Standard: NameDate bei Ordnern, LastWriteTime bei Dateien.
.PARAMETER Filter
    Platzhalterfilter auf den Namen (z. B. *.bak). Standard: *
.PARAMETER NamePattern
    Regulaerer Ausdruck mit den benannten Gruppen y, m, d (nur bei -GroupBy NameDate).
    Standard: ^(?<y>\d{4})\.(?<m>\d{2})\.(?<d>\d{2})(\s|$)   (Alias: FolderPattern)
.PARAMETER ExcludeFolders
    Ordnernamen, die nie angefasst werden (nur bei -ItemType Folder). Standard: gepackt
.PARAMETER MonthFormat
    Format des Archivnamens, nur y, M, Punkt, Bindestrich, Unterstrich. Standard: yyyy.MM
.PARAMETER MinAgeDays
    Nur Eintraege packen, deren Datum mindestens so viele ganze Tage zurueckliegt.
    Standard: 1 (heutige werden nicht gepackt). 0 = alle.
.PARAMETER CompressionLevel
    7z-Kompressionsstufe 0 bis 9. Standard: 5
.PARAMETER TimeoutSec
    Timeout je 7z-Aufruf (Packen, Testen, Auflisten) in Sekunden. Standard: 7200
.PARAMETER LogMaxMB
    Ab dieser Groesse wird die Protokolldatei beim Start umbenannt. Standard: 10
.PARAMETER RemoveSource
    Quellen nach erfolgreichem Packen, Testen UND Inhaltsvergleich loeschen.
.EXAMPLE
    .\Compress-ItemsByMonth.ps1 -SourcePath D:\Data\Export -WhatIf
.EXAMPLE
    .\Compress-ItemsByMonth.ps1 -SourcePath D:\Data\Export -RemoveSource
.EXAMPLE
    .\Compress-ItemsByMonth.ps1 -SourcePath D:\XML -ArchivePath D:\XML\gepackt -ItemType File -Filter '*.bak' -RemoveSource
.NOTES
    Version  : 1.1.0
    Exitcodes: 0 = OK (auch wenn nichts zu tun war), 1 = allgemeiner Fehler, 2 = 7-Zip nicht gefunden,
               3 = Quell- oder Archivordner ungueltig, 4 = mindestens ein Monat/Eintrag fehlgeschlagen,
               5 = laeuft bereits
    Hinweise:
    - 7z u legt eine temporaere Datei neben dem Archiv an: freier Platz in Groesse des Monatsarchivs noetig.
    - Der Inhaltsvergleich prueft Pfad und Groesse jeder Quelldatei gegen das Archivlisting. Leere Ordner
      und Zeitstempel werden nicht verglichen. Zusaetzlich wird vor dem Loeschen geprueft, ob sich seit
      Packbeginn etwas geaendert hat.
    - Getestet mit 7-Zip 23.01 (Schalter -scsUTF-8 und -sccUTF-8 setzen eine neuere 7-Zip-Version voraus).
    Datei bewusst ASCII-only (PowerShell 5.1 liest UTF-8 ohne BOM sonst als ANSI).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$SourcePath,
    [string]$ArchivePath = (Join-Path -Path $SourcePath -ChildPath 'gepackt'),
    [string]$LogPath = (Join-Path -Path $ArchivePath -ChildPath 'Compress-ItemsByMonth.log'),
    [string]$SevenZipPath,
    [ValidateSet('Folder', 'File')][string]$ItemType = 'Folder',
    [ValidateSet('NameDate', 'LastWriteTime')][string]$GroupBy,
    [string]$Filter = '*',
    [Alias('FolderPattern')][string]$NamePattern = '^(?<y>\d{4})\.(?<m>\d{2})\.(?<d>\d{2})(\s|$)',
    [string[]]$ExcludeFolders = @('gepackt'),
    [ValidatePattern('^[yM\.\-_]+$')][string]$MonthFormat = 'yyyy.MM',
    [ValidateRange(0, 3650)][int]$MinAgeDays = 1,
    [ValidateRange(0, 9)][int]$CompressionLevel = 5,
    [ValidateRange(60, 86400)][int]$TimeoutSec = 7200,
    [ValidateRange(1, 1024)][int]$LogMaxMB = 10,
    [switch]$RemoveSource
)

$ErrorActionPreference = 'Stop'

if (-not $GroupBy) {
    if ($ItemType -eq 'File') { $GroupBy = 'LastWriteTime' } else { $GroupBy = 'NameDate' }
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    # Logging darf den Lauf nie abbrechen und wird auch mit -WhatIf geschrieben
    try {
        $dir = Split-Path -Path $LogPath -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            $null = New-Item -ItemType Directory -Path $dir -Force -WhatIf:$false
        }
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8 -WhatIf:$false
    }
    catch {
        Write-Host ('Protokolldatei nicht beschreibbar: {0}' -f $_.Exception.Message)
    }
}

function Find-SevenZip {
    param([string]$Explicit)
    $candidates = @()
    if ($Explicit) {
        $candidates += $Explicit
    }
    if ($env:ProgramFiles) {
        $candidates += (Join-Path -Path $env:ProgramFiles -ChildPath '7-Zip\7z.exe')
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath '7-Zip\7z.exe')
    }
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) {
            return $c
        }
    }
    foreach ($name in '7z.exe', '7z', '7zz') {
        $cmd = Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) {
            return $cmd.Source
        }
    }
    return $null
}

function Invoke-SevenZip {
    # Startet 7z mit Timeout. Liefert ExitCode, TimedOut und die letzten Ausgabezeilen (fuers Log).
    # Mit -OutputPath wird die komplette Standardausgabe dort abgelegt (Aufrufer raeumt auf).
    param(
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [string]$OutputPath
    )
    $keepOut = [bool]$OutputPath
    if ($keepOut) { $outFile = $OutputPath } else { $outFile = [System.IO.Path]::GetTempFileName() }
    $errFile  = [System.IO.Path]::GetTempFileName()
    $timedOut = $false
    try {
        $p = Start-Process -FilePath $script:SevenZip -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru -NoNewWindow
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            $timedOut = $true
            try { $p.Kill() } catch { }
        }
        else {
            # Stellt sicher, dass ExitCode final gesetzt ist. Nach einem Timeout bewusst nicht aufrufen:
            # Es wuerde auf Kindprozesse warten, die noch die Ausgabekanaele halten.
            $p.WaitForExit()
        }
        $tail = @()
        if (-not $keepOut) {
            $tail = @(Get-Content -LiteralPath $outFile -Tail 12 -ErrorAction SilentlyContinue)
        }
        $tail += @(Get-Content -LiteralPath $errFile -Tail 12 -ErrorAction SilentlyContinue)
        $exit = -1
        if (-not $timedOut) {
            $exit = $p.ExitCode
        }
        return [pscustomobject]@{
            ExitCode = $exit
            TimedOut = $timedOut
            Tail     = @($tail | Where-Object { $_ -and $_.Trim() })
        }
    }
    finally {
        if (-not $keepOut) {
            Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
}

function New-SizeMap {
    return , (New-Object -TypeName 'System.Collections.Generic.Dictionary[string,long]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase))
}

function Get-ArchiveFileSizes {
    # Dateieintraege eines Archivs (Pfad mit / -> Groesse) per "7z l -slt". Verzeichnisse werden ignoriert.
    param([Parameter(Mandatory)][string]$Archive)
    $listOut = [System.IO.Path]::GetTempFileName()
    try {
        $r = Invoke-SevenZip -WorkingDirectory (Split-Path -Path $Archive -Parent) -OutputPath $listOut `
            -ArgumentList @('l', '-slt', '-ba', '-bd', '-sccUTF-8', ('"{0}"' -f $Archive))
        if ($r.TimedOut -or ($r.ExitCode -ne 0)) {
            foreach ($t in $r.Tail) { Write-Log ('  7z: {0}' -f $t) 'WARN' }
            throw ('Archivlisting fehlgeschlagen (Exitcode {0}{1}).' -f $r.ExitCode, $(if ($r.TimedOut) { ', Timeout' } else { '' }))
        }
        $map   = (New-SizeMap)
        $path  = $null
        $size  = [long]0
        $isDir = $false
        foreach ($line in [System.IO.File]::ReadLines($listOut, [System.Text.Encoding]::UTF8)) {
            if ($line.StartsWith('Path = ')) {
                if (($null -ne $path) -and -not $isDir) { $map[$path] = $size }
                $path  = $line.Substring(7).Replace('\', '/')
                $size  = [long]0
                $isDir = $false
            }
            elseif ($line.StartsWith('Size = ')) {
                $parsed = [long]0
                if ([long]::TryParse($line.Substring(7), [ref]$parsed)) { $size = $parsed }
            }
            elseif ($line.StartsWith('Folder = ')) {
                $isDir = ($line.Substring(9).Trim() -eq '+')
            }
            elseif ($line.StartsWith('Attributes = ')) {
                if ($line.Substring(13).TrimStart().StartsWith('D')) { $isDir = $true }
            }
        }
        if (($null -ne $path) -and -not $isDir) { $map[$path] = $size }
        return , $map
    }
    finally {
        Remove-Item -LiteralPath $listOut -Force -ErrorAction SilentlyContinue
    }
}

function Get-SourceFileSizes {
    # Dateien der Quelle in der Form, wie sie im Archiv stehen muessen (Ordnername/relativer Pfad bzw. Dateiname).
    param([Parameter(Mandatory)][object[]]$Items)
    $map = (New-SizeMap)
    foreach ($it in $Items) {
        if ($it.IsFolder) {
            $base = $it.FullName.TrimEnd('\', '/')
            foreach ($f in @(Get-ChildItem -LiteralPath $it.FullName -Recurse -File -Force)) {
                $rel = $f.FullName.Substring($base.Length).TrimStart('\', '/').Replace('\', '/')
                $map[('{0}/{1}' -f $it.Name, $rel)] = $f.Length
            }
        }
        else {
            $map[$it.Name] = (Get-Item -LiteralPath $it.FullName -Force).Length
        }
    }
    return , $map
}

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    return ('{0:N0} KB' -f ($Bytes / 1KB))
}

$failCode = 1    # Exitcode, falls im aktuellen Schritt ein Fehler auftritt
$mutex    = $null
$hasLock  = $false
try {
    $started = Get-Date

    # Protokoll rotieren, falls zu gross
    try {
        if ((Test-Path -LiteralPath $LogPath) -and ((Get-Item -LiteralPath $LogPath).Length -gt ($LogMaxMB * 1MB))) {
            Move-Item -LiteralPath $LogPath -Destination ('{0}.{1}' -f $LogPath, (Get-Date -Format 'yyyyMMdd-HHmmss')) -WhatIf:$false
        }
    }
    catch { }

    Write-Log ('Start. Quelle: {0} | Archive: {1} | Typ: {2} | Gruppierung: {3} | Filter: {4} | MinAgeDays: {5} | Loeschen: {6}{7}' -f `
        $SourcePath, $ArchivePath, $ItemType, $GroupBy, $Filter, $MinAgeDays, $RemoveSource.IsPresent, $(if ($WhatIfPreference) { ' | WHATIF' } else { '' }))

    # ---- Vorpruefungen ----
    $failCode = 3
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw ('Quellordner nicht gefunden: {0}' -f $SourcePath)
    }
    $sourceFull = (Resolve-Path -LiteralPath $SourcePath).ProviderPath.TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath $ArchivePath -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $ArchivePath -Force -WhatIf:$false
    }
    $archiveFull = (Resolve-Path -LiteralPath $ArchivePath).ProviderPath.TrimEnd('\', '/')
    if ($archiveFull -eq $sourceFull) {
        throw 'Archivordner darf nicht gleich dem Quellordner sein.'
    }

    $failCode = 2
    $script:SevenZip = Find-SevenZip -Explicit $SevenZipPath
    if (-not $script:SevenZip) {
        throw '7-Zip (7z.exe) nicht gefunden. Pfad per -SevenZipPath angeben.'
    }
    Write-Log ('7-Zip: {0}' -f $script:SevenZip)

    # ---- Mehrfachstart verhindern ----
    $failCode = 5
    $hash      = [System.Security.Cryptography.SHA1]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($archiveFull.ToLowerInvariant()))
    $mutexName = 'Global\Compress-ItemsByMonth-' + ([BitConverter]::ToString($hash) -replace '-', '')
    $mutex     = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, $mutexName
    try {
        $hasLock = $mutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $hasLock = $true    # frueherer Lauf wurde hart beendet
    }
    if (-not $hasLock) {
        throw 'Ein anderer Lauf fuer dieses Archivverzeichnis ist noch aktiv.'
    }

    # ---- Kandidaten ermitteln ----
    $failCode = 1
    $excluded   = New-Object -TypeName System.Collections.Generic.List[string]
    $tooNew     = New-Object -TypeName System.Collections.Generic.List[string]
    $candidates = New-Object -TypeName System.Collections.Generic.List[object]
    $cutoff     = (Get-Date).Date.AddDays(-$MinAgeDays)
    $isFolder   = ($ItemType -eq 'Folder')
    if ($isFolder) {
        $found = @(Get-ChildItem -LiteralPath $sourceFull -Directory -Force -Filter $Filter)
    }
    else {
        $found = @(Get-ChildItem -LiteralPath $sourceFull -File -Force -Filter $Filter)
    }
    foreach ($d in $found) {
        if ($isFolder -and (($ExcludeFolders -contains $d.Name) -or ($d.FullName.TrimEnd('\', '/') -eq $archiveFull))) {
            $excluded.Add($d.Name)
            continue
        }
        if ($GroupBy -eq 'NameDate') {
            $m = [regex]::Match($d.Name, $NamePattern)
            if (-not $m.Success) {
                $excluded.Add($d.Name)
                continue
            }
            try {
                $date = [datetime]::ParseExact(('{0}.{1}.{2}' -f $m.Groups['y'].Value, $m.Groups['m'].Value, $m.Groups['d'].Value), 'yyyy.MM.dd', [System.Globalization.CultureInfo]::InvariantCulture)
            }
            catch {
                Write-Log ('Uebersprungen (ungueltiges Datum im Namen): {0}' -f $d.Name) 'WARN'
                continue
            }
        }
        else {
            $date = $d.LastWriteTime.Date
        }
        if ($date -gt $cutoff) {
            $tooNew.Add($d.Name)
            continue
        }
        $candidates.Add([pscustomobject]@{
            Name     = $d.Name
            FullName = $d.FullName
            IsFolder = $isFolder
            Month    = $date.ToString($MonthFormat, [System.Globalization.CultureInfo]::InvariantCulture)
        })
    }
    if ($excluded.Count -gt 0) {
        Write-Log ('Nicht beruecksichtigt (ausgeschlossen bzw. Name passt nicht): {0}' -f ($excluded -join ', '))
    }
    if ($tooNew.Count -gt 0) {
        Write-Log ('Noch zu neu (MinAgeDays {0}): {1} Eintraege' -f $MinAgeDays, $tooNew.Count)
    }
    Write-Log ('Zu packen: {0} Eintraege' -f $candidates.Count)

    # ---- Je Monat packen, pruefen, vergleichen, ggf. loeschen ----
    $monthsDone = 0
    $packed     = 0
    $removed    = 0
    $errors     = 0
    foreach ($group in @($candidates | Group-Object -Property Month | Sort-Object -Property Name)) {
        $month   = $group.Name
        $folders = @($group.Group)
        $archive = Join-Path -Path $archiveFull -ChildPath ('{0}.7z' -f $month)
        Write-Log ('Monat {0}: {1} Eintraege -> {2}' -f $month, $folders.Count, $archive)
        foreach ($f in $folders) {
            Write-Log ('  {0}' -f $f.Name)
        }
        if (-not $PSCmdlet.ShouldProcess($archive, ('{0} Eintraege packen' -f $folders.Count))) {
            continue
        }

        $listFile = [System.IO.Path]::GetTempFileName()
        $monthOk  = $false
        try {
            Remove-Item -LiteralPath ($archive + '.tmp') -Force -ErrorAction SilentlyContinue    # Rest eines abgebrochenen Laufs
            [System.IO.File]::WriteAllLines($listFile, [string[]]@($folders | ForEach-Object { $_.Name }), (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false))
            $sizeBefore = 0
            if (Test-Path -LiteralPath $archive) {
                $sizeBefore = (Get-Item -LiteralPath $archive).Length
            }

            $packStart = Get-Date
            Write-Log ('Packe (max. {0} s) ...' -f $TimeoutSec)
            $r = Invoke-SevenZip -WorkingDirectory $sourceFull -ArgumentList @(
                'u', '-t7z', ('-mx={0}' -f $CompressionLevel), '-mmt=on', '-bd', '-y', '-scsUTF-8',
                ('"{0}"' -f $archive), ('"@{0}"' -f $listFile))
            if ($r.TimedOut -or ($r.ExitCode -ne 0)) {
                foreach ($t in $r.Tail) { Write-Log ('  7z: {0}' -f $t) 'WARN' }
                throw ('Packen fehlgeschlagen (Exitcode {0}{1}).' -f $r.ExitCode, $(if ($r.TimedOut) { ', Timeout' } else { '' }))
            }
            Write-Log ('Archiv aktualisiert: {0} -> {1} ({2:N0} s)' -f (Format-Size $sizeBefore), (Format-Size (Get-Item -LiteralPath $archive).Length), ((Get-Date) - $packStart).TotalSeconds)

            Write-Log ('Teste Archiv (max. {0} s) ...' -f $TimeoutSec)
            $r = Invoke-SevenZip -WorkingDirectory $archiveFull -ArgumentList @('t', '-bd', '-y', ('"{0}"' -f $archive))
            if ($r.TimedOut -or ($r.ExitCode -ne 0)) {
                foreach ($line in $r.Tail) { Write-Log ('  7z: {0}' -f $line) 'WARN' }
                throw ('Archivtest fehlgeschlagen (Exitcode {0}{1}).' -f $r.ExitCode, $(if ($r.TimedOut) { ', Timeout' } else { '' }))
            }
            Write-Log 'Archivtest: OK'

            # Automatischer Inhaltsvergleich: Jede Quelldatei muss mit gleichem Pfad und gleicher Groesse im Archiv stehen.
            Write-Log 'Vergleiche Archivinhalt mit der Quelle ...'
            $archived = Get-ArchiveFileSizes -Archive $archive
            $expected = Get-SourceFileSizes -Items $folders
            $missing  = New-Object -TypeName System.Collections.Generic.List[string]
            $differs  = New-Object -TypeName System.Collections.Generic.List[string]
            foreach ($key in $expected.Keys) {
                $actual = [long]0
                if (-not $archived.TryGetValue($key, [ref]$actual)) {
                    $missing.Add($key)
                }
                elseif ($actual -ne $expected[$key]) {
                    $differs.Add(('{0} (Quelle {1} Bytes, Archiv {2} Bytes)' -f $key, $expected[$key], $actual))
                }
            }
            Write-Log ('Inhaltsvergleich: {0} Dateien in der Quelle, {1} Eintraege im Archiv, {2} fehlen, {3} mit abweichender Groesse' -f $expected.Count, $archived.Count, $missing.Count, $differs.Count)
            if (($missing.Count -gt 0) -or ($differs.Count -gt 0)) {
                foreach ($x in @($missing | Select-Object -First 10)) { Write-Log ('  fehlt im Archiv: {0}' -f $x) 'WARN' }
                foreach ($x in @($differs | Select-Object -First 10)) { Write-Log ('  Groesse abweichend: {0}' -f $x) 'WARN' }
                throw 'Inhaltsvergleich fehlgeschlagen: Archiv und Quelle stimmen nicht ueberein.'
            }
            Write-Log 'Inhaltsvergleich: OK'
            $monthOk = $true
            $monthsDone++
            $packed += $folders.Count
        }
        catch {
            $errors++
            Write-Log ('Monat {0}: {1} Quellen bleiben unveraendert.' -f $month, $_.Exception.Message) 'ERROR'
            Remove-Item -LiteralPath ($archive + '.tmp') -Force -ErrorAction SilentlyContinue
        }
        finally {
            Remove-Item -LiteralPath $listFile -Force -ErrorAction SilentlyContinue
        }
        if (-not $monthOk) {
            continue
        }

        if (-not $RemoveSource) {
            continue
        }
        foreach ($f in $folders) {
            $full = $f.FullName
            if ((Split-Path -Path $full -Parent).TrimEnd('\', '/') -ne $sourceFull) {
                Write-Log ('Nicht geloescht (liegt nicht direkt in der Quelle): {0}' -f $full) 'WARN'
                continue
            }
            # Zusaetzlich: wurde seit Packbeginn etwas veraendert (z. B. Inhalt mit gleicher Groesse ueberschrieben)?
            $itemTime = (Get-Item -LiteralPath $full -Force).LastWriteTime
            $newest   = $null
            if ($f.IsFolder) {
                $newest = (Get-ChildItem -LiteralPath $full -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property LastWriteTime -Maximum).Maximum
            }
            if (($newest -and ($newest -gt $packStart)) -or ($itemTime -gt $packStart)) {
                Write-Log ('Nicht geloescht (waehrend des Packens veraendert, wird beim naechsten Lauf erneut gepackt): {0}' -f $f.Name) 'WARN'
                continue
            }
            if ($PSCmdlet.ShouldProcess($full, 'Loeschen')) {
                try {
                    if ($f.IsFolder) {
                        Remove-Item -LiteralPath $full -Recurse -Force
                    }
                    else {
                        Remove-Item -LiteralPath $full -Force
                    }
                    $removed++
                    Write-Log ('Geloescht: {0}' -f $f.Name)
                }
                catch {
                    $errors++
                    Write-Log ('Loeschen fehlgeschlagen: {0} ({1})' -f $f.Name, $_.Exception.Message) 'ERROR'
                }
            }
        }
    }

    Write-Log ('Fertig: {0} Monat(e), {1} Eintraege gepackt, {2} geloescht, {3} Fehler, Dauer {4:N0} s' -f `
        $monthsDone, $packed, $removed, $errors, ((Get-Date) - $started).TotalSeconds)
    if ($errors -gt 0) {
        $failCode = 4
        exit $failCode
    }
    exit 0
}
catch {
    Write-Log ('Fehler: {0}' -f $_.Exception.Message) 'ERROR'
    exit $failCode
}
finally {
    if ($hasLock -and $mutex) {
        $mutex.ReleaseMutex()
    }
    if ($mutex) {
        $mutex.Dispose()
    }
}