#Requires -Version 5.1
<#
.SYNOPSIS
    Erstellt eine vollständige Aktivitäts-Timeline eines oder mehrerer Rechner aus dem Windows-Eventlog.

.DESCRIPTION
    Erfasst folgende Ereigniskategorien in einer einheitlichen, sortierten Timeline:

    SYSTEMLOG  (kein besonderes Audit nötig):
        6005          Eventlog-Dienst gestartet       → Systemstart abgeschlossen
        6006          Eventlog-Dienst gestoppt        → Reguläres Herunterfahren
        6008          Unerwartetes Herunterfahren     → Stromausfall / Harter Reset
        6009          Prozessorinfo beim Boot
        6013          Uptime in Sekunden
        12            OS gestartet (Kernel-General)   → zuverlässigerer Startup-Indikator
        13            OS-Shutdown eingeleitet (Kernel-General)
        1074          Geplantes Herunterfahren/Neustart (Prozess + Benutzer + Grund)
        1076          Herunterfahren mit Admin-Begründung
        41            Kernel-Power: Unerwarteter Neustart (Absturz / Stromausfall)
        42            Kernel-Power: Schlafzustand-Übergang
                          Properties[0]=SleepReason, Properties[4]=S-State
                          Properties[4]: 3=S3(Sleep/RAM), 4=S4(Hibernate/Disk)
                          HINWEIS: Windows 10/11 Fast Startup = Hybrid-Shutdown → erscheint als S4!
                          HINWEIS: Modern Standby (S0ix) erscheint als S0 – andere Hardware/Events!
        107           Kernel-Power: System aus Sleep/Hibernate aufgewacht
        1             Power-Troubleshooter: Wake mit Wake-Quelle (WoL, Timer, Tastatur, ...)
        1001          Windows Error Reporting: BSOD / BugCheck (Minidump)

    SECURITY-LOG (erfordert entsprechende Audit-Richtlinien!):
        4624          Erfolgreiche Anmeldung         → Audit: Logon/Logoff > Logon
        4625          Fehlgeschlagene Anmeldung      → Audit: Logon/Logoff > Logon
        4634          Sitzung beendet                → Audit: Logon/Logoff > Logoff
        4647          Benutzer-initiierte Abmeldung  → Audit: Logon/Logoff > Logoff
        4648          Explizite Anmeldedaten (runas) → Audit: Logon/Logoff > Logon
        4672          Privilegierte Anmeldung (Admin)→ Audit: Logon/Logoff > Special Logon
        4778          RDP-Sitzung wiederverbunden    → Audit: Logon/Logoff > Other Logon/Logoff
        4779          RDP-Sitzung getrennt           → Audit: Logon/Logoff > Other Logon/Logoff
        4800          Workstation gesperrt           → Audit: Logon/Logoff > Other Logon/Logoff
        4801          Workstation entsperrt          → Audit: Logon/Logoff > Other Logon/Logoff
        4802          Bildschirmschoner aktiviert    → Audit: Logon/Logoff > Other Logon/Logoff
        4803          Bildschirmschoner deaktiviert  → Audit: Logon/Logoff > Other Logon/Logoff

    LOGON-TYPEN (4624 / 4625 / 4634):
        2   Interaktiv (Konsole)
        3   Netzwerk (sehr häufig, viel Rauschen → -NurInteraktiv empfohlen)
        4   Batch
        5   Dienst
        7   Entsperrung  (entspricht 4801, liefert aber andere Details wie LogonID)
        8   Netzwerk Klartext
        10  Remoteinteraktiv (RDP)
        11  Cached Interactive (Offline-Domänenanmeldung)

.PARAMETER ComputerName
    Zielrechner. Mehrere Rechner möglich. Standard: lokaler Rechner.
    Für Remote-Zugriff muss WinRM auf dem Zielrechner aktiv sein.

.PARAMETER TageRueckwaerts
    Wie viele Tage rückwirkend abgefragt werden. Standard: 7.

.PARAMETER NurInteraktiv
    Schränkt Anmeldungs-/Abmeldungsereignisse auf interaktive Typen ein
    (Konsole=2, Entsperrung=7, RDP=10, Cached=11).
    Empfohlen, um Netzwerk-Logon-Rauschen (Typ 3) zu unterdrücken.

.PARAMETER OhneRauschen
    Unterdrückt zusätzlich: 4672 (sehr häufig), 6009, 6013, Typ-3-Logoffs.

.PARAMETER MaxSecurityEvents
    Maximale Anzahl Security-Log-Ereignisse pro Computer. Standard: 50000.
    Auf DC oder stark genutzten Servern ggf. reduzieren.

.PARAMETER Credential
    Anmeldedaten für Remote-Zugriff.

.PARAMETER GridView
    Öffnet das Ergebnis in Out-GridView.

.EXAMPLE
    # Lokaler Rechner, letzte 7 Tage, interaktive Ereignisse, Anzeige als GridView
    .\Get-PCActivityTimeline.ps1 -NurInteraktiv -GridView

.EXAMPLE
    # Remote, letzte 14 Tage, Admin-Creds
    .\Get-PCActivityTimeline.ps1 -ComputerName "PC01","PC02" -TageRueckwaerts 14 -Credential (Get-Credential) -GridView

.EXAMPLE
    # Ergebnis in CSV exportieren
    .\Get-PCActivityTimeline.ps1 -NurInteraktiv -OhneRauschen |
        Export-Csv -Path "C:\Temp\Timeline.csv" -NoTypeInformation -Encoding UTF8
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
    [string[]]$ComputerName = @($env:COMPUTERNAME),

    [Parameter(Mandatory = $false)]
    [int]$TageRueckwaerts = 7,

    [Parameter(Mandatory = $false)]
    [switch]$NurInteraktiv,

    [Parameter(Mandatory = $false)]
    [switch]$OhneRauschen,

    [Parameter(Mandatory = $false)]
    [int]$MaxSecurityEvents = 50000,

    [Parameter(Mandatory = $false)]
    [pscredential]$Credential,

    [Parameter(Mandatory = $false)]
    [switch]$GridView
)

# ─── ScriptBlock (läuft lokal ODER per Invoke-Command remote) ────────────────
$CollectScriptBlock = {
    param(
        [int]  $TageRueckwaerts,
        [bool] $NurInteraktiv,
        [bool] $OhneRauschen,
        [int]  $MaxSecurityEvents
    )

    $seit      = (Get-Date).AddDays(-$TageRueckwaerts)
    $ergebnis  = [System.Collections.Generic.List[PSCustomObject]]::new()

    # ── Hilfsfunktion: Properties-Zugriff ohne Exception ─────────────────────
    function Get-SafeProp {
        param([object[]]$Props, [int]$Index)
        if ($null -ne $Props -and $Index -lt $Props.Count) {
            try { return [string]$Props[$Index].Value } catch {}
        }
        return ''
    }

    # ─────────────────────────────────────────────────────────────────────────
    # SYSTEM LOG
    # ─────────────────────────────────────────────────────────────────────────
    $systemIDs = @(41, 42, 107, 1001, 1074, 1076, 6005, 6006, 6008, 6009, 6013)

    $allSystemEvents = [System.Collections.Generic.List[object]]::new()

    try {
        $evts = Get-WinEvent -FilterHashtable @{
            LogName   = 'System'
            Id        = $systemIDs
            StartTime = $seit
        } -ErrorAction SilentlyContinue
        if ($evts) { $allSystemEvents.AddRange([object[]]$evts) }
    } catch {}

    # ID 12/13 nur vom Kernel-General-Provider — ohne Provider-Filter
    # kämen diese IDs auch von Disk, VSS, Time-Service, TPM usw.
    try {
        $evts = Get-WinEvent -FilterHashtable @{
            LogName      = 'System'
            ProviderName = 'Microsoft-Windows-Kernel-General'
            Id           = @(12, 13)
            StartTime    = $seit
        } -ErrorAction SilentlyContinue
        if ($evts) { $allSystemEvents.AddRange([object[]]$evts) }
    } catch {}

    # Power-Troubleshooter EventID 1 = Wake from Sleep (eigener Provider, gleicher Log)
    try {
        $evts = Get-WinEvent -FilterHashtable @{
            LogName      = 'System'
            ProviderName = 'Microsoft-Windows-Power-Troubleshooter'
            Id           = 1
            StartTime    = $seit
        } -ErrorAction SilentlyContinue
        if ($evts) { $allSystemEvents.AddRange([object[]]$evts) }
    } catch {}

    foreach ($ev in $allSystemEvents) {
        $kategorie    = ''
        $beschreibung = ''
        $benutzer     = '-'
        $p            = $ev.Properties

        switch ($ev.Id) {
            6005 {
                $kategorie    = 'System-Start'
                $beschreibung = 'Eventlog-Dienst gestartet — Systemstart abgeschlossen'
            }
            6006 {
                $kategorie    = 'System-Stop'
                $beschreibung = 'Eventlog-Dienst beendet — reguläres Herunterfahren'
            }
            6008 {
                $ts  = Get-SafeProp $p 0
                $dat = Get-SafeProp $p 1
                $kategorie    = 'Unerwartetes Herunterfahren'
                $beschreibung = "Letzter bekannter Zeitpunkt: $dat $ts"
            }
            6009 {
                if ($OhneRauschen) { break }
                $kategorie    = 'System-Start'
                $beschreibung = "Prozessor-Info beim Boot: $(Get-SafeProp $p 0)"
            }
            6013 {
                if ($OhneRauschen) { break }
                # Verifiziert: Sekunden liegen bei Properties[4], nicht [0]
                # [0]-[3] sind leer, [4]=Sekunden, [5]=TZ-Offset, [6]=TZ-Name
                $secRaw = Get-SafeProp $p 4
                $kategorie = 'System-Info'
                if (-not [string]::IsNullOrWhiteSpace($secRaw)) {
                    $ts           = [TimeSpan]::FromSeconds([long]$secRaw)
                    $beschreibung = "Uptime: $($ts.Days)d $($ts.Hours)h $($ts.Minutes)m $($ts.Seconds)s"
                } else {
                    $beschreibung = 'Uptime: Unbekannt (Event-Properties unvollständig)'
                }
            }
            12 {
                # Microsoft-Windows-Kernel-General: OS started
                $kategorie    = 'System-Start'
                $beschreibung = "OS gestartet (Kernel-General). StartType: $(Get-SafeProp $p 0)"
            }
            13 {
                # Microsoft-Windows-Kernel-General: OS shutdown started
                $kategorie    = 'System-Stop'
                $beschreibung = 'OS-Shutdown eingeleitet (Kernel-General)'
            }
            1074 {
                # Geplantes Herunterfahren / Neustart
                $process   = Get-SafeProp $p 0   # Prozess/EXE der den Shutdown initiiert hat
                $message   = Get-SafeProp $p 2   # Optionale Meldung
                $reasonStr = Get-SafeProp $p 5   # Lesbarer Grund-String
                $benutzer  = Get-SafeProp $p 6   # DOMAIN\User
                $kategorie    = 'System-Stop'
                $beschreibung = "Geplantes Herunterfahren/Neustart | Initiiert von: $process | Grund: $reasonStr"
                if ($message -and $message.Trim() -ne '') {
                    $beschreibung += " | Kommentar: $message"
                }
            }
            1076 {
                # Herunterfahren mit Administrator-Begründung
                $benutzer     = Get-SafeProp $p 3
                $kategorie    = 'System-Stop'
                $beschreibung = "Herunterfahren mit Admin-Begründung: $(Get-SafeProp $p 2)"
            }
            41 {
                # Kernel-Power: Unerwarteter Neustart
                $bugcode   = Get-SafeProp $p 1
                $kategorie    = 'Absturz'
                $beschreibung = "Kernel-Power: Unerwarteter Neustart (Stromausfall/Absturz). BugcheckCode: $bugcode"
            }
            42 {
                # Kernel-Power: Sleep/Hibernate-Übergang
                # Verifiziert: [0]=SleepReason (6=...), [4]=RequestedSleepState (S3/S4/...)
                # Beispiel aus Diagnose: [0]=6, [1]=5, [2]=4, [3]=0, [4]=3 → S3 (Standbymodus)
                $sleepReason = Get-SafeProp $p 0
                $stateVal    = [int](Get-SafeProp $p 4)
                $stateName   = switch ($stateVal) {
                    0 { 'S0 / Modern Standby (Connected Standby — neuere Hardware)' }
                    1 { 'S1 — Leichter Standby' }
                    2 { 'S2 — Standby' }
                    3 { 'S3 — Sleep (RAM aktiv, CPU aus)' }
                    4 { 'S4 — Hibernate (RAM auf Disk) ⚠ auch Fast-Startup!' }
                    5 { 'S5 — Soft-Off (Shutdown über ACPI)' }
                    default { "Energiezustand S$stateVal (unbekannt)" }
                }
                $kategorie    = 'Sleep/Hibernate'
                $beschreibung = "System wechselt in $stateName (SleepReason: $sleepReason)"
            }
            107 {
                # Kernel-Power: System resumed
                $kategorie    = 'Wake'
                $beschreibung = 'System aus Schlaf/Ruhezustand aufgewacht (Kernel-Power 107)'
            }
            1001 {
                # Windows Error Reporting / BugCheck
                $bugcode   = Get-SafeProp $p 0
                $kategorie    = 'Absturz'
                $beschreibung = "BSOD / BugCheck. Fehlercode: $bugcode"
            }
            1 {
                # Power-Troubleshooter: Wake from Sleep (nur dieser Provider!)
                # Verifiziert: [0]=Zeitpunkt Einschlafen, [1]=Zeitpunkt Aufwachen
                # [2]-[n] sind interne Zähler/Metriken, keine lesbare Wake-Quelle
                $sleepTime = Get-SafeProp $p 0
                $wakeTime  = Get-SafeProp $p 1
                $kategorie    = 'Wake'
                $beschreibung = "System aufgewacht (Power-Troubleshooter). Eingeschlafen: $sleepTime | Aufgewacht: $wakeTime"
            }
        }

        if ($kategorie -ne '') {
            $ergebnis.Add([PSCustomObject]@{
                Rechner      = $env:COMPUTERNAME
                Zeitpunkt    = $ev.TimeCreated
                Kategorie    = $kategorie
                EventID      = $ev.Id
                Benutzer     = $benutzer
                Beschreibung = $beschreibung
            })
        }
    }

    # ─────────────────────────────────────────────────────────────────────────
    # SECURITY LOG
    # ─────────────────────────────────────────────────────────────────────────
    $securityIDs = @(4624, 4625, 4634, 4647, 4648, 4672, 4778, 4779, 4800, 4801, 4802, 4803)

    $allSecEvents = @()
    try {
        $allSecEvents = Get-WinEvent -FilterHashtable @{
            LogName   = 'Security'
            Id        = $securityIDs
            StartTime = $seit
        } -MaxEvents $MaxSecurityEvents -ErrorAction SilentlyContinue
    } catch {}

    foreach ($ev in $allSecEvents) {
        $kategorie    = ''
        $beschreibung = ''
        $benutzer     = '-'
        $p            = $ev.Properties

        switch ($ev.Id) {

            4624 {
                # Erfolgreiche Anmeldung
                # Properties: [5]=TargetUser, [6]=TargetDomain, [8]=LogonType,
                #             [11]=Workstation, [18]=IpAddress
                $logonType = [int](Get-SafeProp $p 8)
                if ($NurInteraktiv -and $logonType -notin @(2, 7, 10, 11)) { break }
                $typName = switch ($logonType) {
                    2  { 'Interaktiv (Konsole)' }
                    3  { 'Netzwerk' }
                    4  { 'Batch' }
                    5  { 'Dienst' }
                    7  { 'Entsperrung (Typ 7)' }
                    8  { 'Netzwerk Klartext' }
                    10 { 'Remoteinteraktiv (RDP)' }
                    11 { 'Cached Interactive (Offline)' }
                    default { "Typ $logonType" }
                }
                $benutzer     = "$(Get-SafeProp $p 5)@$(Get-SafeProp $p 6)"
                $workstation  = Get-SafeProp $p 11
                $ipAddr       = Get-SafeProp $p 18
                $kategorie    = 'Anmeldung'
                $beschreibung = "Erfolgreiche Anmeldung ($typName)"
                if ($ipAddr -and $ipAddr -notin @('', '-', '::1', '127.0.0.1', '-')) {
                    $beschreibung += " | IP: $ipAddr"
                }
                if ($workstation -and $workstation -notin @('', '-')) {
                    $beschreibung += " | Workstation: $workstation"
                }
            }

            4625 {
                # Fehlgeschlagene Anmeldung
                # Properties: [5]=TargetUser, [6]=TargetDomain, [7]=Status,
                #             [9]=SubStatus, [10]=LogonType, [19]=IpAddress
                $logonType = [int](Get-SafeProp $p 10)
                $benutzer  = "$(Get-SafeProp $p 5)@$(Get-SafeProp $p 6)"
                $status    = Get-SafeProp $p 7
                $subStatus = Get-SafeProp $p 9
                $ipAddr    = Get-SafeProp $p 19
                $kategorie    = 'Anmeldung-Fehler'
                $beschreibung = "Fehlgeschlagene Anmeldung. Typ: $logonType | Status: $status | SubStatus: $subStatus"
                if ($ipAddr -and $ipAddr -notin @('', '-', '::1', '127.0.0.1')) {
                    $beschreibung += " | IP: $ipAddr"
                }
            }

            4634 {
                # Sitzung beendet (System-seitig)
                # Properties: [1]=TargetUser, [2]=TargetDomain, [4]=LogonType
                $logonType = [int](Get-SafeProp $p 4)
                if ($NurInteraktiv -and $logonType -notin @(2, 7, 10, 11)) { break }
                $benutzer     = "$(Get-SafeProp $p 1)@$(Get-SafeProp $p 2)"
                $kategorie    = 'Abmeldung'
                $beschreibung = "Sitzung beendet (Anmeldetyp $logonType)"
            }

            4647 {
                # Benutzer-initiierte Abmeldung (Start > Abmelden)
                # Properties: [1]=TargetUser, [2]=TargetDomain
                $benutzer     = "$(Get-SafeProp $p 1)@$(Get-SafeProp $p 2)"
                $kategorie    = 'Abmeldung'
                $beschreibung = 'Benutzer-initiierte Abmeldung (Start > Abmelden)'
            }

            4648 {
                # Explizite Anmeldedaten (runas / elevation / Netzlaufwerk)
                # Properties: [1]=SubjectUser, [2]=SubjectDomain, [5]=TargetUser,
                #             [8]=TargetServer
                $benutzer     = "$(Get-SafeProp $p 1)@$(Get-SafeProp $p 2)"
                $zielUser     = Get-SafeProp $p 5
                $zielServer   = Get-SafeProp $p 8
                $kategorie    = 'Anmeldung'
                $beschreibung = "Explizite Anmeldedaten verwendet (runas/elevation). Ziel: $zielUser @ $zielServer"
            }

            4672 {
                # Privilegierte Anmeldung — SEHR häufig auf DCs, ggf. Rauschen
                if ($OhneRauschen) { break }
                # Properties: [1]=SubjectUser, [2]=SubjectDomain
                $benutzer     = "$(Get-SafeProp $p 1)@$(Get-SafeProp $p 2)"
                $kategorie    = 'Anmeldung'
                $beschreibung = 'Privilegierte Anmeldung — Administrator-Rechte zugewiesen'
            }

            4778 {
                # RDP-Sitzung wiederverbunden (Reconnect)
                # Properties: [0]=AccountName, [1]=AccountDomain, [3]=SessionName,
                #             [4]=ClientName, [5]=ClientAddress
                $benutzer     = "$(Get-SafeProp $p 0)@$(Get-SafeProp $p 1)"
                $session      = Get-SafeProp $p 3
                $client       = Get-SafeProp $p 4
                $clientIP     = Get-SafeProp $p 5
                $kategorie    = 'RDP-Reconnect'
                $beschreibung = "RDP-Sitzung wiederverbunden. Session: $session | Client: $client ($clientIP)"
            }

            4779 {
                # RDP-Sitzung getrennt (Disconnect)
                # Properties: [0]=AccountName, [1]=AccountDomain, [3]=SessionName,
                #             [4]=ClientName, [5]=ClientAddress
                $benutzer     = "$(Get-SafeProp $p 0)@$(Get-SafeProp $p 1)"
                $session      = Get-SafeProp $p 3
                $client       = Get-SafeProp $p 4
                $clientIP     = Get-SafeProp $p 5
                $kategorie    = 'RDP-Disconnect'
                $beschreibung = "RDP-Sitzung getrennt. Session: $session | Client: $client ($clientIP)"
            }

            4800 {
                # Workstation gesperrt (Win+L / Timeout)
                # Properties: [1]=TargetUser, [2]=TargetDomain, [3]=SessionID
                $benutzer     = "$(Get-SafeProp $p 1)@$(Get-SafeProp $p 2)"
                $sessID       = Get-SafeProp $p 3
                $kategorie    = 'Sperrung'
                $beschreibung = "Workstation gesperrt. SessionID: $sessID"
            }

            4801 {
                # Workstation entsperrt
                # Properties: [1]=TargetUser, [2]=TargetDomain, [3]=SessionID
                $benutzer     = "$(Get-SafeProp $p 1)@$(Get-SafeProp $p 2)"
                $sessID       = Get-SafeProp $p 3
                $kategorie    = 'Entsperrung'
                $beschreibung = "Workstation entsperrt. SessionID: $sessID"
            }

            4802 {
                # Bildschirmschoner aktiviert
                # Properties: [1]=TargetUser, [2]=TargetDomain
                $benutzer     = "$(Get-SafeProp $p 1)@$(Get-SafeProp $p 2)"
                $kategorie    = 'Bildschirmschoner'
                $beschreibung = 'Bildschirmschoner aktiviert'
            }

            4803 {
                # Bildschirmschoner deaktiviert
                # Properties: [1]=TargetUser, [2]=TargetDomain
                $benutzer     = "$(Get-SafeProp $p 1)@$(Get-SafeProp $p 2)"
                $kategorie    = 'Bildschirmschoner'
                $beschreibung = 'Bildschirmschoner deaktiviert'
            }
        }

        if ($kategorie -ne '') {
            $ergebnis.Add([PSCustomObject]@{
                Rechner      = $env:COMPUTERNAME
                Zeitpunkt    = $ev.TimeCreated
                Kategorie    = $kategorie
                EventID      = $ev.Id
                Benutzer     = $benutzer
                Beschreibung = $beschreibung
            })
        }
    }

    return $ergebnis | Sort-Object Zeitpunkt -Descending
}

# ─── HAUPTLOGIK ──────────────────────────────────────────────────────────────
$alleErgebnisse = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($computer in $ComputerName) {
    Write-Host "[$computer] Verarbeite ..." -ForegroundColor Cyan

    $argList = @(
        $TageRueckwaerts,
        ([bool]$NurInteraktiv),
        ([bool]$OhneRauschen),
        $MaxSecurityEvents
    )

    # Lokale Ausführung ohne Invoke-Command (kein WinRM nötig)
    $istLokal = ($computer -eq $env:COMPUTERNAME) -or
                ($computer -eq 'localhost')        -or
                ($computer -eq '127.0.0.1')        -or
                ($computer -eq '.')

    try {
        $result = if ($istLokal) {
            & $CollectScriptBlock @argList
        } else {
            $params = @{
                ComputerName = $computer
                ScriptBlock  = $CollectScriptBlock
                ArgumentList = $argList
                ErrorAction  = 'Stop'
            }
            if ($Credential) { $params['Credential'] = $Credential }
            Invoke-Command @params
        }

        if ($result) {
            $alleErgebnisse.AddRange([PSCustomObject[]]$result)
            Write-Host "[$computer] $($result.Count) Ereignisse gefunden." -ForegroundColor Green
        } else {
            Write-Host "[$computer] Keine Ereignisse im gewählten Zeitraum." -ForegroundColor Yellow
        }
    } catch {
        Write-Warning "[$computer] Fehler: $_"
    }
}

$alleErgebnisse = $alleErgebnisse | Sort-Object Zeitpunkt -Descending

if ($GridView) {
    $alleErgebnisse |
        Select-Object Rechner, Zeitpunkt, Kategorie, EventID, Benutzer, Beschreibung |
        Out-GridView -Title "PC-Aktivitäts-Timeline — $($ComputerName -join ', ') — letzte $TageRueckwaerts Tage"
} else {
    $alleErgebnisse | Select-Object Rechner, Zeitpunkt, Kategorie, EventID, Benutzer, Beschreibung
}
