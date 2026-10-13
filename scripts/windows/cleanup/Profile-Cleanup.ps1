<#
.SYNOPSIS
    Findet verwaiste und alte Windows-Benutzerprofile anhand des letzten Logins und loescht sie (mit WhatIf/Confirm).

.DESCRIPTION
    Funktionsbibliothek zur Analyse und Bereinigung von Benutzerprofilen auf lokalen und entfernten
    Windows-Systemen. Das Script wird per Dot-Sourcing geladen (. .\Profile-Cleanup.ps1) und stellt
    folgende Funktionen bereit:

    Get-UserProfileAge
        Liefert je Profil alle verfuegbaren Zeitstempel nebeneinander (LastUseTime, Registry-Ladezeit,
        Registry-Entladezeit, Aenderungszeit der NTUSER.DAT) und daraus das ermittelte letzte Login
        (LastLogon) samt verwendeter Quelle (Source) und Alter in Tagen (AgeDays). Eignet sich auch
        zur Diagnose, welcher Zeitstempel auf dem jeweiligen System plausibel ist.

    Get-StaleUserProfile
        Liefert Profile, die nicht geladen sind und deren letztes Login laenger als -OlderThanDays Tage
        zurueckliegt. Profile ohne jeden Zeitstempel werden NICHT als alt gewertet, aber per Warnung
        gemeldet.

    Remove-StaleUserProfile
        Loescht die uebergebenen Profile ueber Remove-CimInstance (Ordner und Registry-Eintrag).
        Unterstuetzt -WhatIf und -Confirm.

    Remove-OrphanedProfileFolder
        Loescht Ordner im Profilverzeichnis, die dem Namensmuster entsprechen (Standard: *BACKUP*),
        aber in Win32_UserProfile nicht mehr als Profil registriert sind. Unterstuetzt -WhatIf und
        -Confirm. Wird kein registriertes Profil gefunden, wird aus Sicherheitsgruenden nichts geloescht.

    Get-ProfileListInfo, Resolve-SID
        Hilfsfunktionen: Registry-ProfileList mit Kontonamen bzw. Aufloesung einer einzelnen SID.
        [UNKNOWN] bedeutet, dass die SID nicht zuordenbar ist (nicht zwingend, dass das Konto geloescht
        wurde, z. B. Entra-ID-Konten), [LOOKUP-ERROR] einen anderen Fehler (z. B. DC nicht erreichbar).

    Zeitquellen (-TimeSource):
        Auto          Registry-Ladezeit (letztes Login), sonst NTUSER.DAT, sonst LastUseTime (Standard)
        RegistryLoad  LocalProfileLoadTime aus der ProfileList
        NtUserDat     LastWriteTime der NTUSER.DAT (wird beim Abmelden geschrieben)
        LastUseTime   Win32_UserProfile.LastUseTime (kann durch Updates/Dienste verfaelscht sein)

.NOTES
    Version : 1.1.0
    Aenderungen 1.1.0:
        - Zeitquelle waehlbar; Standard ist das letzte Login (Registry-Ladezeit), LastUseTime nur als Fallback
        - Remote-Zugriff ueber Invoke-Command (Registry und NTUSER.DAT sind remote lesbar), -CimSession entfaellt
        - Neue Funktion Get-UserProfileAge fuer die Diagnose
    ACHTUNG : Die Remove-*-Funktionen loeschen Profile bzw. Ordner endgueltig. Immer zuerst mit -WhatIf
              ausfuehren, die Ausgabe pruefen und den Lauf auf einem Testrechner durchspielen.
    Hinweis : Profile von Dienstkonten oder Scheduled Tasks mit seltener Ausfuehrung ueber -ExcludeUser
              ausnehmen. Datei als UTF-8 mit BOM speichern.
    Voraussetzung: Windows PowerShell 5.1 oder neuer, lokale Administratorrechte auf dem Zielsystem,
              fuer Remote-Laeufe WinRM.

.EXAMPLE
    . .\Profile-Cleanup.ps1
    Get-UserProfileAge | Sort-Object LastLogon |
        Format-Table User, LocalPath, LastLogon, Source, LastUseTime, RegLoadTime, NtUserDatTime -AutoSize

    Diagnose: zeigt je Profil alle Zeitstempel und das daraus ermittelte letzte Login.

.EXAMPLE
    Get-StaleUserProfile -OlderThanDays 7 -ExcludeUser 'Administrator' | Select-Object User, LocalPath, LastLogon, AgeDays

    Zeigt lokale Profile an, deren letztes Login laenger als eine Woche zurueckliegt (nur Anzeige).

.EXAMPLE
    $cred = Get-Credential
    Get-StaleUserProfile -OlderThanDays 7 -ComputerName 'SRV01','SRV02' -Credential $cred |
        Remove-StaleUserProfile -Credential $cred -WhatIf

    Simuliert das Loeschen alter Profile auf zwei Servern. Ohne -WhatIf wird je Profil nachgefragt.

.EXAMPLE
    Remove-OrphanedProfileFolder -ComputerName 'SRV01' -Credential $cred -Pattern '*.BACKUP*' -WhatIf

    Simuliert das Loeschen verwaister Ordner mit dem Muster *.BACKUP* auf SRV01.
#>

#Requires -Version 5.1

function ConvertFrom-ProfileTime {
    <#
    .SYNOPSIS
        Wandelt High-/Low-DWORD eines FILETIME-Werts aus der ProfileList in ein DateTime um.
    .DESCRIPTION
        Gibt $null zurueck, wenn ein Teilwert fehlt oder das Ergebnis nicht groesser als 0 ist.
    #>
    [CmdletBinding()]
    param(
        $High,
        $Low
    )

    if ($null -eq $High -or $null -eq $Low) { return $null }
    $ticks = ([int64]$High -shl 32) -bor ($Low -band 0xFFFFFFFFL)
    if ($ticks -le 0) { return $null }
    [datetime]::FromFileTime($ticks)
}

function Get-ProfileListInfo {
    <#
    .SYNOPSIS
        Listet alle Eintraege der ProfileList inkl. Kontoname, Pfad sowie Lade- und Entladezeit.
    .EXAMPLE
        Get-ProfileListInfo | Where-Object User -eq '[UNKNOWN]'
    #>
    [CmdletBinding()]
    param()

    $base = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'

    foreach ($key in Get-ChildItem -Path $base) {
        $sid   = $key.PSChildName
        $props = Get-ItemProperty -Path $key.PSPath

        $user = try {
            [System.Security.Principal.SecurityIdentifier]::new($sid).
                Translate([System.Security.Principal.NTAccount]).Value
        }
        catch [System.Security.Principal.IdentityNotMappedException] { '[UNKNOWN]' }
        catch { '[LOOKUP-ERROR]' }

        [pscustomobject][ordered]@{
            User        = $user
            SID         = $sid
            ProfilePath = $props.ProfileImagePath
            LoadTime    = ConvertFrom-ProfileTime -High $props.LocalProfileLoadTimeHigh   -Low $props.LocalProfileLoadTimeLow
            UnloadTime  = ConvertFrom-ProfileTime -High $props.LocalProfileUnloadTimeHigh -Low $props.LocalProfileUnloadTimeLow
        }
    }
}

function Resolve-SID {
    <#
    .SYNOPSIS
        Loest eine SID in den Kontonamen auf.
    .EXAMPLE
        Resolve-SID S-1-5-21-123456789-1234567890-1234567890-500
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string]$Sid
    )
    process {
        try {
            [System.Security.Principal.SecurityIdentifier]::new($Sid).
                Translate([System.Security.Principal.NTAccount]).Value
        }
        catch [System.Security.Principal.IdentityNotMappedException] { '[UNKNOWN]' }
        catch { '[LOOKUP-ERROR]' }
    }
}

function Get-UserProfileAge {
    <#
    .SYNOPSIS
        Liefert je Profil alle Zeitstempel und das ermittelte letzte Login.
    .DESCRIPTION
        Wertet auf dem Zielsystem Win32_UserProfile, die Registry-ProfileList und die NTUSER.DAT aus.
        Ausgabe je Profil: ComputerName, User, SID, LocalPath, Loaded, LastLogon, Source, AgeDays,
        LastUseTime, RegLoadTime, RegUnloadTime, NtUserDatTime. Special-Profile werden ausgelassen.
        Ohne -ComputerName wird lokal gearbeitet, mit -ComputerName per Invoke-Command (WinRM).
    .PARAMETER ComputerName
        Zielsystem(e). Ohne Angabe lokal.
    .PARAMETER Credential
        Optionale Anmeldeinformationen fuer Remote-Zugriff.
    .PARAMETER TimeSource
        Auto (Standard), RegistryLoad, NtUserDat oder LastUseTime. Siehe Beschreibung der Datei.
    .EXAMPLE
        Get-UserProfileAge -ComputerName 'SRV01' -Credential $cred | Sort-Object LastLogon
    #>
    [CmdletBinding()]
    param(
        [string[]]$ComputerName,

        [PSCredential]$Credential,

        [ValidateSet('Auto', 'RegistryLoad', 'NtUserDat', 'LastUseTime')]
        [string]$TimeSource = 'Auto'
    )

    # Der Block muss eigenstaendig sein, weil er auch remote ausgefuehrt wird.
    $block = {
        param([string]$TimeSource)

        $toTime = {
            param($High, $Low)
            if ($null -eq $High -or $null -eq $Low) { return $null }
            $ticks = ([int64]$High -shl 32) -bor ($Low -band 0xFFFFFFFFL)
            if ($ticks -le 0) { return $null }
            [datetime]::FromFileTime($ticks)
        }

        $listKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
        $now     = Get-Date

        foreach ($p in Get-CimInstance -ClassName Win32_UserProfile) {
            if ($p.Special) { continue }

            $reg = Get-ItemProperty -Path "$listKey\$($p.SID)" -ErrorAction SilentlyContinue
            $load = $null
            $unload = $null
            if ($reg) {
                $load   = & $toTime $reg.LocalProfileLoadTimeHigh   $reg.LocalProfileLoadTimeLow
                $unload = & $toTime $reg.LocalProfileUnloadTimeHigh $reg.LocalProfileUnloadTimeLow
            }

            $ntuser = $null
            if ($p.LocalPath) {
                $dat = Get-Item -LiteralPath (Join-Path $p.LocalPath 'NTUSER.DAT') -Force -ErrorAction SilentlyContinue
                if ($dat) { $ntuser = $dat.LastWriteTime }
            }

            $user = try {
                [System.Security.Principal.SecurityIdentifier]::new($p.SID).
                    Translate([System.Security.Principal.NTAccount]).Value
            }
            catch [System.Security.Principal.IdentityNotMappedException] { '[UNKNOWN]' }
            catch { '[LOOKUP-ERROR]' }

            $lastLogon = $null
            $source    = 'None'
            switch ($TimeSource) {
                'RegistryLoad' { if ($load)           { $lastLogon = $load;           $source = 'RegistryLoad' } }
                'NtUserDat'    { if ($ntuser)         { $lastLogon = $ntuser;         $source = 'NtUserDat' } }
                'LastUseTime'  { if ($p.LastUseTime)  { $lastLogon = $p.LastUseTime;  $source = 'LastUseTime' } }
                default {
                    if     ($load)          { $lastLogon = $load;          $source = 'RegistryLoad' }
                    elseif ($ntuser)        { $lastLogon = $ntuser;        $source = 'NtUserDat' }
                    elseif ($p.LastUseTime) { $lastLogon = $p.LastUseTime; $source = 'LastUseTime' }
                }
            }

            [pscustomobject][ordered]@{
                ComputerName  = $env:COMPUTERNAME
                User          = $user
                SID           = $p.SID
                LocalPath     = $p.LocalPath
                Loaded        = [bool]$p.Loaded
                LastLogon     = $lastLogon
                Source        = $source
                AgeDays       = if ($lastLogon) { [int][math]::Floor(($now - $lastLogon).TotalDays) } else { $null }
                LastUseTime   = $p.LastUseTime
                RegLoadTime   = $load
                RegUnloadTime = $unload
                NtUserDatTime = $ntuser
            }
        }
    }

    $icm = @{ ScriptBlock = $block; ArgumentList = $TimeSource }
    if ($ComputerName) {
        $icm.ComputerName = $ComputerName
        if ($Credential) { $icm.Credential = $Credential }
    }
    Invoke-Command @icm
}

function Get-StaleUserProfile {
    <#
    .SYNOPSIS
        Liefert nicht geladene Benutzerprofile, deren letztes Login laenger als die angegebene Zeit zurueckliegt.
    .DESCRIPTION
        Basiert auf Get-UserProfileAge. Profile ohne ermittelbaren Zeitstempel werden nie als alt gewertet,
        sondern per Warnung gemeldet. Geladene (angemeldete) Profile werden ausgelassen.
    .PARAMETER OlderThanDays
        Mindestalter in Tagen seit dem letzten Login (Standard: 60).
    .PARAMETER ExcludeUser
        Profilordnernamen, die nie als alt gelten (Standard: Administrator).
    .PARAMETER ComputerName
        Zielsystem(e). Ohne Angabe lokal.
    .PARAMETER Credential
        Optionale Anmeldeinformationen fuer Remote-Zugriff.
    .PARAMETER TimeSource
        Auto (Standard), RegistryLoad, NtUserDat oder LastUseTime.
    .EXAMPLE
        Get-StaleUserProfile -OlderThanDays 7 -ExcludeUser 'Administrator','svc_task'
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1, 3650)]
        [int]$OlderThanDays = 60,

        [string[]]$ExcludeUser = @('Administrator'),

        [string[]]$ComputerName,

        [PSCredential]$Credential,

        [ValidateSet('Auto', 'RegistryLoad', 'NtUserDat', 'LastUseTime')]
        [string]$TimeSource = 'Auto'
    )

    $ageParams = @{ TimeSource = $TimeSource }
    if ($ComputerName) { $ageParams.ComputerName = $ComputerName }
    if ($Credential)   { $ageParams.Credential   = $Credential }

    $limit = (Get-Date).AddDays(-$OlderThanDays)

    $profiles = @(
        Get-UserProfileAge @ageParams | Where-Object {
            -not $_.Loaded -and (Split-Path -Path $_.LocalPath -Leaf) -notin $ExcludeUser
        }
    )

    foreach ($unknown in ($profiles | Where-Object { -not $_.LastLogon })) {
        Write-Warning ('{0}: {1} - kein Zeitstempel ermittelbar, Profil wird uebersprungen.' -f $unknown.ComputerName, $unknown.LocalPath)
    }

    $profiles | Where-Object { $_.LastLogon -and $_.LastLogon -lt $limit }
}

function Remove-StaleUserProfile {
    <#
    .SYNOPSIS
        Loescht Benutzerprofile (Ordner und Registry-Eintrag) ueber Remove-CimInstance.
    .DESCRIPTION
        Erwartet Objekte aus Get-StaleUserProfile bzw. Get-UserProfileAge. Das Profil wird auf dem Zielsystem
        anhand der SID erneut abgefragt; geladene und Special-Profile werden nicht geloescht.
        Unterstuetzt -WhatIf und -Confirm.
    .PARAMETER Credential
        Optionale Anmeldeinformationen, wenn die Profile von einem entfernten System stammen.
    .EXAMPLE
        Get-StaleUserProfile -OlderThanDays 7 | Remove-StaleUserProfile -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject]$InputObject,

        [PSCredential]$Credential
    )
    begin {
        $removeBlock = {
            param([string]$Sid)

            $prof = Get-CimInstance -ClassName Win32_UserProfile -Filter "SID='$Sid'"
            if (-not $prof)                     { throw "Profil $Sid nicht gefunden." }
            if ($prof.Special -or $prof.Loaded) { throw "Profil $Sid ist Special oder geladen." }
            Remove-CimInstance -InputObject $prof -ErrorAction Stop
        }
    }
    process {
        $remote   = [bool]$InputObject.PSComputerName
        $computer = if ($remote) { $InputObject.PSComputerName } else { $env:COMPUTERNAME }
        $target   = '{0}: {1}' -f $computer, $InputObject.LocalPath

        if ($InputObject.SID -notmatch '^S-1-[0-9-]+$') {
            Write-Error "Ungueltige SID bei ${target}: '$($InputObject.SID)'"
            return
        }
        if ($InputObject.Loaded) {
            Write-Warning "$target uebersprungen (Profil ist geladen)."
            return
        }

        $result = 'WhatIf'
        if ($PSCmdlet.ShouldProcess($target, 'Benutzerprofil loeschen')) {
            $icm = @{ ScriptBlock = $removeBlock; ArgumentList = $InputObject.SID; ErrorAction = 'Stop' }
            if ($remote) {
                $icm.ComputerName = $computer
                if ($Credential) { $icm.Credential = $Credential }
            }
            try {
                Invoke-Command @icm
                $result = 'Deleted'
            }
            catch {
                $result = 'Error: ' + $_.Exception.Message
                Write-Error "Fehler bei ${target}: $_"
            }
        }

        [pscustomobject][ordered]@{
            Computer = $computer
            Path     = $InputObject.LocalPath
            SID      = $InputObject.SID
            Result   = $result
        }
    }
}

function Remove-OrphanedProfileFolder {
    <#
    .SYNOPSIS
        Loescht Ordner im Profilverzeichnis, die zum Muster passen, aber kein registriertes Profil sind.
    .DESCRIPTION
        Ermittelt je Zielsystem das Profilverzeichnis aus der Registry (ProfilesDirectory) und vergleicht
        die Unterordner mit den LocalPath-Werten aus Win32_UserProfile. Ordner, die dem Muster entsprechen
        und nicht als Profil registriert sind, werden nach Bestaetigung geloescht. Liefert Win32_UserProfile
        keine Eintraege, wird nichts geloescht (Sicherheitsnetz). Unterstuetzt -WhatIf und -Confirm.
    .PARAMETER ComputerName
        Zielsystem(e). Ohne Angabe wird der lokale Rechner verwendet.
    .PARAMETER Credential
        Optionale Anmeldeinformationen fuer Invoke-Command.
    .PARAMETER Pattern
        Namensmuster der Kandidatenordner (Standard: *BACKUP*). Moeglichst eng waehlen.
    .EXAMPLE
        Remove-OrphanedProfileFolder -ComputerName 'SRV01' -Credential $cred -Pattern '*.BACKUP*' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [PSCredential]$Credential,

        [ValidateNotNullOrEmpty()]
        [string]$Pattern = '*BACKUP*'
    )

    $listBlock = {
        param($Pattern)

        $reg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
        $profilesDir = [Environment]::ExpandEnvironmentVariables($reg.ProfilesDirectory)

        $valid = @(
            Get-CimInstance -ClassName Win32_UserProfile |
                Where-Object { -not $_.Special } |
                ForEach-Object { $_.LocalPath }
        )
        if (-not $valid) { return }   # Sicherheitsnetz: ohne registrierte Profile nichts loeschen

        Get-ChildItem -LiteralPath $profilesDir -Directory -Force |
            Where-Object { $_.Name -like $Pattern -and $_.FullName -notin $valid } |
            ForEach-Object {
                [pscustomobject]@{
                    Computer    = $env:COMPUTERNAME
                    Path        = $_.FullName
                    ProfilesDir = $profilesDir
                }
            }
    }

    $deleteBlock = {
        param($Path, $ProfilesDir)

        # Erneute Pruefung: nur direkte Unterordner des Profilverzeichnisses loeschen.
        if ((Split-Path -Path $Path -Parent) -ne $ProfilesDir) {
            throw "Pfad '$Path' liegt nicht direkt unter '$ProfilesDir'."
        }
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }

    $icm = @{}
    if ($Credential) { $icm.Credential = $Credential }

    foreach ($computer in $ComputerName) {
        try {
            $candidates = @(Invoke-Command -ComputerName $computer @icm -ScriptBlock $listBlock `
                    -ArgumentList $Pattern -ErrorAction Stop)
        }
        catch {
            Write-Error "Ermittlung auf ${computer} fehlgeschlagen: $_"
            continue
        }

        foreach ($item in $candidates) {
            $target = '{0}: {1}' -f $item.Computer, $item.Path
            $result = 'WhatIf'

            if ($PSCmdlet.ShouldProcess($target, 'Verwaisten Profilordner loeschen')) {
                try {
                    Invoke-Command -ComputerName $computer @icm -ScriptBlock $deleteBlock `
                        -ArgumentList $item.Path, $item.ProfilesDir -ErrorAction Stop
                    $result = 'Deleted'
                }
                catch {
                    $result = 'Error: ' + $_.Exception.Message
                    Write-Error "Fehler bei ${target}: $_"
                }
            }

            [pscustomobject][ordered]@{
                Computer = $item.Computer
                Path     = $item.Path
                Result   = $result
            }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host 'Profile-Cleanup.ps1 ist eine Funktionsbibliothek. Laden mit: . .\Profile-Cleanup.ps1' -ForegroundColor Yellow
    Write-Host 'Funktionen: Get-UserProfileAge, Get-StaleUserProfile, Remove-StaleUserProfile, Remove-OrphanedProfileFolder, Get-ProfileListInfo, Resolve-SID' -ForegroundColor Yellow
}
