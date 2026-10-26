#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Entfernt TeamViewer restlos von einem lokalen Windows-Rechner.

.DESCRIPTION
    Stoppt zuerst die TeamViewer-Dienste (damit keine Prozesse neu gestartet werden), beendet
    danach die Prozesse, nutzt den offiziellen Silent-Uninstaller (falls vorhanden) und
    entfernt Dienste, Registry-Eintraege (HKLM sowie HKCU fuer ALLE Benutzerprofile, auch
    nicht geladene Hives), Programmordner, ProgramData, AppData-Reste, Verknuepfungen
    (Start-Menue, Desktop, OneDrive-Desktop), den TeamViewer-Drucker, geplante Aufgaben und
    Firewall-Regeln.

    Sicherheitsprinzip: Auf dem Desktop werden ausschliesslich Verknuepfungsdateien
    (.lnk/.url) direkt auf der obersten Ebene geloescht - niemals Ordner, Skripte oder
    Unterordner (Vorfall "Managementtools").

.PARAMETER LogPath
    Pfad zur Log-Datei. Standard: C:\Windows\Temp\TeamViewer_Removal_<Timestamp>.log

.PARAMETER Force
    Unterdrueckt alle Rueckfragen (ShouldProcess-Bestaetigungen).

.EXAMPLE
    .\Remove-TeamViewerComplete.ps1 -WhatIf
    Zeigt nur an, was entfernt wuerde, ohne etwas zu aendern.

.EXAMPLE
    .\Remove-TeamViewerComplete.ps1 -Force
    Fuehrt die Entfernung ohne Rueckfragen durch.

.NOTES
    Version : 1.1.0
    Aenderungen 1.1.0:
      - Dienste werden vor den Prozessen gestoppt (Neustart durch den Dienst verhindert)
      - Uninstaller mit Timeout (kein Haengenbleiben mehr)
      - Benutzerprofile werden nur noch einmal zentral ermittelt
      - Uninstall-Eintraege werden zusaetzlich ueber DisplayName gefunden
      - Desktop-Suche inkl. OneDrive-Desktop (Known Folder Move)
      - TeamViewer-Drucker und -Treiber werden entfernt
      - Fehler beim Beenden eines Prozesses stoppen nicht mehr die uebrigen
      - Rueckgabecode: 0 = sauber, 1 = Reste vorhanden
    Version 1.0.0: Erstfassung (Verknuepfungs-Logik ohne Recurse auf dem Desktop)
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$LogPath = (Join-Path $env:WINDIR "Temp\TeamViewer_Removal_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"),
    [switch]$Force
)

$ScriptVersion = '1.1.0'
$ErrorActionPreference = 'Continue'

if ($Force) {
    $ConfirmPreference = 'None'
}

#region Logging

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('Info', 'Warn', 'Error')] [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'Warn'  { Write-Host $line -ForegroundColor Yellow }
        'Error' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line }
    }

    try {
        $sw = [System.IO.StreamWriter]::new($LogPath, $true, [System.Text.UTF8Encoding]::new($false))
        try { $sw.WriteLine($line) } finally { $sw.Close() }
    }
    catch {
        # Logging darf den Lauf nicht abbrechen
    }
}

Write-Log "=== TeamViewer-Entfernung gestartet (Skriptversion $ScriptVersion) ==="
Write-Log "Log-Datei: $LogPath"

#endregion

#region Hilfsfunktionen

function Get-LocalUserProfiles {
    # Liefert alle echten Benutzerprofile (S-1-5-21-...), keine Dienstkonten.
    $result = New-Object System.Collections.Generic.List[object]
    try {
        $listKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
        foreach ($item in (Get-ChildItem -Path $listKey -ErrorAction Stop)) {
            $sid = $item.PSChildName
            if ($sid -notmatch '^S-1-5-21-') { continue }

            $imagePath = (Get-ItemProperty -Path $item.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
            if (-not $imagePath) { continue }

            $imagePath = [Environment]::ExpandEnvironmentVariables($imagePath)
            $result.Add([PSCustomObject]@{
                Sid         = $sid
                ProfilePath = $imagePath
                NtUserDat   = Join-Path $imagePath 'NTUSER.DAT'
                Exists      = (Test-Path -LiteralPath $imagePath)
            })
        }
    }
    catch {
        Write-Log "Fehler beim Ermitteln der Benutzerprofile: $($_.Exception.Message)" -Level Error
    }
    return $result
}

function Remove-TeamViewerRegistryItems {
    # Entfernt TeamViewer-Eintraege (Run, Uninstall) unterhalb eines Hive-Roots
    # (HKLM:\ oder gemountetes HKU). $Root zeigt auf den Pfad vor "SOFTWARE".
    param(
        [Parameter(Mandatory)] [string]$Root,
        [switch]$IncludeWow64
    )

    $runKeys = @("$Root\SOFTWARE\Microsoft\Windows\CurrentVersion\Run")
    $uninstallBases = @("$Root\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")
    if ($IncludeWow64) {
        $runKeys += "$Root\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
        $uninstallBases += "$Root\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    }

    foreach ($runKey in $runKeys) {
        try {
            if (Test-Path $runKey) {
                $prop = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
                if ($prop -and $prop.PSObject.Properties['TeamViewer']) {
                    if ($PSCmdlet.ShouldProcess("$runKey\TeamViewer", "Run-Eintrag entfernen")) {
                        Remove-ItemProperty -Path $runKey -Name 'TeamViewer' -Force -ErrorAction Stop
                        Write-Log "Run-Eintrag entfernt: $runKey\TeamViewer"
                    }
                }
            }
        }
        catch {
            Write-Log "Fehler bei Run-Eintrag in '$runKey': $($_.Exception.Message)" -Level Warn
        }
    }

    foreach ($base in $uninstallBases) {
        try {
            if (Test-Path $base) {
                Get-ChildItem -Path $base -ErrorAction SilentlyContinue |
                    Where-Object {
                        $displayName = (Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue).DisplayName
                        ($_.PSChildName -like '*TeamViewer*') -or ($displayName -like 'TeamViewer*')
                    } |
                    ForEach-Object {
                        if ($PSCmdlet.ShouldProcess($_.PSPath, "Uninstall-Eintrag entfernen")) {
                            Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                            Write-Log "Uninstall-Eintrag entfernt: $($_.PSChildName)"
                        }
                    }
            }
        }
        catch {
            Write-Log "Fehler bei Uninstall-Eintraegen in '$base': $($_.Exception.Message)" -Level Warn
        }
    }
}

$userProfiles = @(Get-LocalUserProfiles)

#endregion

#region Dienste stoppen (zuerst, damit Prozesse nicht neu gestartet werden)

Write-Log "--- Schritt 1: Dienste stoppen ---"

try {
    $services = Get-Service -Name 'TeamViewer*' -ErrorAction SilentlyContinue
    foreach ($svc in $services) {
        if ($svc.Status -ne 'Stopped') {
            if ($PSCmdlet.ShouldProcess($svc.Name, "Dienst stoppen")) {
                try {
                    Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                    Write-Log "Dienst gestoppt: $($svc.Name)"
                }
                catch {
                    Write-Log "Dienst '$($svc.Name)' liess sich nicht stoppen: $($_.Exception.Message)" -Level Warn
                }
            }
        }
    }
}
catch {
    Write-Log "Fehler beim Ermitteln der Dienste: $($_.Exception.Message)" -Level Error
}

#endregion

#region Prozesse beenden

Write-Log "--- Schritt 2: Prozesse beenden ---"

$processPatterns = @('TeamViewer*', 'tv_w32', 'tv_x64', 'TVGina')

foreach ($pattern in $processPatterns) {
    $procs = Get-Process -Name $pattern -ErrorAction SilentlyContinue
    foreach ($proc in $procs) {
        try {
            if ($PSCmdlet.ShouldProcess("$($proc.ProcessName) (PID $($proc.Id))", "Prozess beenden")) {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                Write-Log "Prozess beendet: $($proc.ProcessName) (PID $($proc.Id))"
            }
        }
        catch {
            Write-Log "Fehler beim Beenden von '$($proc.ProcessName)' (PID $($proc.Id)): $($_.Exception.Message)" -Level Warn
        }
    }
}

#endregion

#region Offiziellen Uninstaller versuchen

Write-Log "--- Schritt 3: Offizieller Silent-Uninstaller ---"

$uninstallTimeoutSeconds = 120

$uninstallCandidates = @(
    (Join-Path $env:ProgramFiles 'TeamViewer\uninstall.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'TeamViewer\uninstall.exe')
) | Where-Object { $_ -and (Test-Path $_) }

foreach ($uninstaller in $uninstallCandidates) {
    try {
        if ($PSCmdlet.ShouldProcess($uninstaller, "Silent-Uninstall ausfuehren")) {
            Write-Log "Starte Silent-Uninstall: $uninstaller /S (Timeout $uninstallTimeoutSeconds s)"
            $uninstProc = Start-Process -FilePath $uninstaller -ArgumentList '/S' -PassThru -ErrorAction Stop

            if ($uninstProc.WaitForExit($uninstallTimeoutSeconds * 1000)) {
                Write-Log "Uninstaller beendet mit Exit-Code $($uninstProc.ExitCode)"
            }
            else {
                Write-Log "Uninstaller nach $uninstallTimeoutSeconds s nicht beendet - wird abgebrochen" -Level Warn
                Stop-Process -Id $uninstProc.Id -Force -ErrorAction SilentlyContinue
            }
            Start-Sleep -Seconds 3
        }
    }
    catch {
        Write-Log "Uninstaller '$uninstaller' fehlgeschlagen: $($_.Exception.Message)" -Level Warn
    }
}

if (-not $uninstallCandidates) {
    Write-Log "Kein offizieller Uninstaller gefunden - fahre mit manueller Bereinigung fort" -Level Warn
}

#endregion

#region Dienste entfernen

Write-Log "--- Schritt 4: Dienste entfernen ---"

try {
    $services = Get-Service -Name 'TeamViewer*' -ErrorAction SilentlyContinue
    foreach ($svc in $services) {
        if ($PSCmdlet.ShouldProcess($svc.Name, "Dienst entfernen")) {
            try {
                if ($svc.Status -ne 'Stopped') {
                    Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                }
                $null = & sc.exe delete $svc.Name
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Dienst entfernt: $($svc.Name)"
                }
                else {
                    Write-Log "sc.exe delete '$($svc.Name)' lieferte Exit-Code $LASTEXITCODE" -Level Warn
                }
            }
            catch {
                Write-Log "Fehler bei Dienst '$($svc.Name)': $($_.Exception.Message)" -Level Error
            }
        }
    }
}
catch {
    Write-Log "Fehler beim Ermitteln der Dienste: $($_.Exception.Message)" -Level Error
}

#endregion

#region Drucker und Druckertreiber

Write-Log "--- Schritt 5: TeamViewer-Drucker ---"

try {
    Get-Printer -Name '*TeamViewer*' -ErrorAction SilentlyContinue | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.Name, "Drucker entfernen")) {
            Remove-Printer -Name $_.Name -ErrorAction SilentlyContinue
            Write-Log "Drucker entfernt: $($_.Name)"
        }
    }
    Get-PrinterDriver -Name '*TeamViewer*' -ErrorAction SilentlyContinue | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.Name, "Druckertreiber entfernen")) {
            Remove-PrinterDriver -Name $_.Name -ErrorAction SilentlyContinue
            Write-Log "Druckertreiber entfernt: $($_.Name)"
        }
    }
}
catch {
    Write-Log "Fehler bei Druckerbereinigung: $($_.Exception.Message)" -Level Warn
}

#endregion

#region Registry - HKLM (systemweit)

Write-Log "--- Schritt 6: Registry HKLM ---"

$hklmKeys = @(
    'HKLM:\SOFTWARE\TeamViewer',
    'HKLM:\SOFTWARE\WOW6432Node\TeamViewer',
    'HKLM:\SYSTEM\CurrentControlSet\Services\TeamViewer',
    'HKLM:\SYSTEM\CurrentControlSet\Services\TeamViewer_service'
)

foreach ($key in $hklmKeys) {
    try {
        if (Test-Path $key) {
            if ($PSCmdlet.ShouldProcess($key, "Registry-Schluessel entfernen")) {
                Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
                Write-Log "Entfernt: $key"
            }
        }
    }
    catch {
        Write-Log "Fehler bei '$key': $($_.Exception.Message)" -Level Error
    }
}

# Run- und Uninstall-Eintraege (systemweit, beide Wow-Ebenen)
Remove-TeamViewerRegistryItems -Root 'HKLM:' -IncludeWow64

#endregion

#region Registry - pro Benutzerprofil (HKCU aller Benutzer, auch nicht geladene Hives)

Write-Log "--- Schritt 7: Registry pro Benutzerprofil ---"

function Remove-TeamViewerUserRegistry {
    param(
        [Parameter(Mandatory)] [string]$UserSid,
        [Parameter(Mandatory)] [string]$NtUserDatPath
    )

    $hiveMountName = "TVCleanup_$($UserSid -replace '[^a-zA-Z0-9]', '_')"
    $mountedByUs = $false
    $hiveRoot = $null

    try {
        if (Test-Path "Registry::HKEY_USERS\$UserSid") {
            # Hive ist bereits geladen (Benutzer angemeldet)
            $hiveRoot = "Registry::HKEY_USERS\$UserSid"
        }
        else {
            if (-not (Test-Path -LiteralPath $NtUserDatPath)) {
                Write-Log "NTUSER.DAT nicht gefunden fuer SID $UserSid" -Level Warn
                return
            }
            $loadResult = & reg.exe load "HKU\$hiveMountName" "$NtUserDatPath" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Konnte Hive nicht laden ($NtUserDatPath): $loadResult" -Level Warn
                return
            }
            $mountedByUs = $true
            $hiveRoot = "Registry::HKEY_USERS\$hiveMountName"
        }

        $userKey = "$hiveRoot\SOFTWARE\TeamViewer"
        if (Test-Path $userKey) {
            if ($PSCmdlet.ShouldProcess($userKey, "Registry-Schluessel entfernen")) {
                Remove-Item -Path $userKey -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Entfernt: $userKey"
            }
        }

        Remove-TeamViewerRegistryItems -Root $hiveRoot
    }
    catch {
        Write-Log "Fehler bei Registry-Bereinigung fuer SID $UserSid : $($_.Exception.Message)" -Level Error
    }
    finally {
        if ($mountedByUs) {
            [gc]::Collect()
            [gc]::WaitForPendingFinalizers()
            Start-Sleep -Milliseconds 500
            $unloadResult = & reg.exe unload "HKU\$hiveMountName" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Konnte Hive HKU\$hiveMountName nicht entladen: $unloadResult" -Level Warn
            }
        }
    }
}

foreach ($p in $userProfiles) {
    Write-Log "Bearbeite Benutzerprofil: $($p.ProfilePath) (SID $($p.Sid))"
    Remove-TeamViewerUserRegistry -UserSid $p.Sid -NtUserDatPath $p.NtUserDat
}

#endregion

#region Dateien und Ordner

Write-Log "--- Schritt 8: Dateien und Ordner ---"

$folderCandidates = New-Object System.Collections.Generic.List[string]

foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if ($base) { $folderCandidates.Add((Join-Path $base 'TeamViewer')) }
}
$folderCandidates.Add((Join-Path $env:ProgramData 'TeamViewer'))

foreach ($p in $userProfiles | Where-Object { $_.Exists }) {
    $folderCandidates.Add((Join-Path $p.ProfilePath 'AppData\Roaming\TeamViewer'))
    $folderCandidates.Add((Join-Path $p.ProfilePath 'AppData\Local\TeamViewer'))
    $folderCandidates.Add((Join-Path $p.ProfilePath 'AppData\Local\Temp\TeamViewer'))
}

foreach ($folder in $folderCandidates) {
    try {
        if (Test-Path -LiteralPath $folder) {
            if ($PSCmdlet.ShouldProcess($folder, "Ordner rekursiv loeschen")) {
                Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction Stop
                Write-Log "Ordner entfernt: $folder"
            }
        }
    }
    catch {
        Write-Log "Fehler beim Loeschen von '$folder': $($_.Exception.Message)" -Level Error
    }
}

#endregion

#region Verknuepfungen (Start-Menue und Desktop)

Write-Log "--- Schritt 9: Verknuepfungen ---"

$startMenuBases = New-Object System.Collections.Generic.List[string]
$startMenuBases.Add((Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'))

$desktopBases = New-Object System.Collections.Generic.List[string]
$desktopBases.Add((Join-Path $env:PUBLIC 'Desktop'))

foreach ($p in $userProfiles | Where-Object { $_.Exists }) {
    $startMenuBases.Add((Join-Path $p.ProfilePath 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs'))
    $desktopBases.Add((Join-Path $p.ProfilePath 'Desktop'))

    # OneDrive Known Folder Move: Desktop kann nach <Profil>\OneDrive*\Desktop umgeleitet sein
    Get-ChildItem -LiteralPath $p.ProfilePath -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue |
        ForEach-Object { $desktopBases.Add((Join-Path $_.FullName 'Desktop')) }
}

# Start Menue: dort liegen ausschliesslich Programm-Verknuepfungen/-Ordner, daher darf
# hier rekursiv in Vendor-Unterordner (z.B. "TeamViewer\TeamViewer.lnk") gesucht werden.
# Es wird aber ausschliesslich nach Verknuepfungsdateien (.lnk/.url) gefiltert.
foreach ($base in $startMenuBases) {
    try {
        if (Test-Path -LiteralPath $base) {
            Get-ChildItem -LiteralPath $base -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in @('.lnk', '.url') -and $_.BaseName -like '*TeamViewer*' } |
                ForEach-Object {
                    if ($PSCmdlet.ShouldProcess($_.FullName, "Verknuepfung entfernen")) {
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                        Write-Log "Verknuepfung entfernt: $($_.FullName)"
                    }
                }

            # Programmordner direkt unterhalb von Start Menu\Programs, z.B. "TeamViewer"
            Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like 'TeamViewer*' } |
                ForEach-Object {
                    if ($PSCmdlet.ShouldProcess($_.FullName, "Start-Menue-Ordner entfernen")) {
                        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log "Start-Menue-Ordner entfernt: $($_.FullName)"
                    }
                }
        }
    }
    catch {
        Write-Log "Fehler beim Durchsuchen von '$base': $($_.Exception.Message)" -Level Warn
    }
}

# Desktop: hier koennen beliebige Benutzerordner mit eigenen Skripten/Tools liegen
# (siehe Vorfall: ein Ordner "Managementtools" mit selbstgebauten .bat-Dateien).
# Deshalb explizit KEIN -Recurse und nur echte Verknuepfungsdateien (.lnk/.url)
# direkt auf dem Desktop selbst - keine Unterordner, keine .bat/.exe/Ordner.
foreach ($base in $desktopBases) {
    try {
        if (Test-Path -LiteralPath $base) {
            Get-ChildItem -LiteralPath $base -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in @('.lnk', '.url') -and $_.BaseName -like '*TeamViewer*' } |
                ForEach-Object {
                    if ($PSCmdlet.ShouldProcess($_.FullName, "Verknuepfung entfernen")) {
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                        Write-Log "Verknuepfung entfernt: $($_.FullName)"
                    }
                }
        }
    }
    catch {
        Write-Log "Fehler beim Durchsuchen von '$base': $($_.Exception.Message)" -Level Warn
    }
}

#endregion

#region Geplante Aufgaben

Write-Log "--- Schritt 10: Geplante Aufgaben ---"

try {
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like '*TeamViewer*' }
    foreach ($task in $tasks) {
        try {
            if ($PSCmdlet.ShouldProcess($task.TaskName, "Geplante Aufgabe entfernen")) {
                Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
                Write-Log "Geplante Aufgabe entfernt: $($task.TaskPath)$($task.TaskName)"
            }
        }
        catch {
            Write-Log "Fehler bei Aufgabe '$($task.TaskName)': $($_.Exception.Message)" -Level Warn
        }
    }
}
catch {
    Write-Log "Fehler beim Ermitteln der geplanten Aufgaben: $($_.Exception.Message)" -Level Warn
}

#endregion

#region Firewall-Regeln

Write-Log "--- Schritt 11: Firewall-Regeln ---"

try {
    $rules = Get-NetFirewallRule -DisplayName '*TeamViewer*' -ErrorAction SilentlyContinue
    foreach ($rule in $rules) {
        try {
            if ($PSCmdlet.ShouldProcess($rule.DisplayName, "Firewall-Regel entfernen")) {
                Remove-NetFirewallRule -Name $rule.Name -ErrorAction Stop
                Write-Log "Firewall-Regel entfernt: $($rule.DisplayName)"
            }
        }
        catch {
            Write-Log "Fehler bei Firewall-Regel '$($rule.DisplayName)': $($_.Exception.Message)" -Level Warn
        }
    }
}
catch {
    Write-Log "Fehler bei Firewall-Regeln: $($_.Exception.Message)" -Level Warn
}

#endregion

#region Abschluss und Restvalidierung

Write-Log "=== TeamViewer-Entfernung abgeschlossen ==="
Write-Log "Details siehe Log-Datei: $LogPath"

$remaining = @()
if (Get-Process -Name 'TeamViewer*' -ErrorAction SilentlyContinue) { $remaining += 'Prozesse' }
if (Get-Service -Name 'TeamViewer*' -ErrorAction SilentlyContinue) { $remaining += 'Dienste' }
if (Test-Path 'HKLM:\SOFTWARE\TeamViewer') { $remaining += 'HKLM-Registry' }
if (Test-Path 'HKLM:\SOFTWARE\WOW6432Node\TeamViewer') { $remaining += 'HKLM-Registry (Wow64)' }
if (Test-Path (Join-Path $env:ProgramFiles 'TeamViewer')) { $remaining += 'Programmordner' }
if (Test-Path (Join-Path $env:ProgramData 'TeamViewer')) { $remaining += 'ProgramData' }
if (Get-NetAdapter -InterfaceDescription '*TeamViewer*' -ErrorAction SilentlyContinue) { $remaining += 'VPN-Netzwerkadapter (ggf. Neustart noetig)' }

if ($WhatIfPreference) {
    Write-Log "WhatIf-Lauf: es wurde nichts geaendert, Restpruefung entfaellt."
}
elseif ($remaining.Count -gt 0) {
    Write-Log "Achtung - moeglicherweise noch vorhanden: $($remaining -join ', ')" -Level Warn
    exit 1
}
else {
    Write-Log "Keine offensichtlichen TeamViewer-Reste mehr gefunden."
    exit 0
}

#endregion
