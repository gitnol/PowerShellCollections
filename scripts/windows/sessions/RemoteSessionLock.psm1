#Requires -Version 5.1
<#
    Modul      : RemoteSessionLock.psm1
    Zweck      : Benutzersitzungen auf lokalen und entfernten Windows-Rechnern abfragen und sperren.
    Funktionen : Get-RemoteSessionStatus, Lock-RemoteSession

    Technik
    - Sitzungen, Sperrzustand und Trennen ueber die WTS-API (wtsapi32.dll):
      sprachunabhaengig, kein Parsen der quser-Ausgabe, kein tsdiscon.exe noetig.
    - Sperrzustand ueber WTSSessionInfoEx (SessionFlags) statt LogonUI.exe-Heuristik.
    - Online-Pruefung per ICMP fuer alle Rechner gleichzeitig (asynchron, mit Timeout).
    - Remote-Ausfuehrung parallel ueber Invoke-Command (ThrottleLimit einstellbar).
    - Lokaler Rechner wird direkt ausgefuehrt, ohne WinRM-Loopback.

    Voraussetzungen
    - Windows 10/11 bzw. Windows Server 2016 oder neuer auf den Zielrechnern
      (unter Windows 7/Server 2008 R2 meldet die WTS-API den Sperrzustand vertauscht).
    - WinRM auf den Zielrechnern aktiv, ausfuehrendes Konto ist dort lokaler Administrator.
    - PowerShell im FullLanguage-Modus (Add-Type). Unter Constrained Language Mode
      (AppLocker/WDAC) schlaegt die Ausfuehrung mit einer Warnung je Rechner fehl.

    Hinweis zum "Sperren" entfernter Sitzungen
    - Eine fremde Sitzung kann nicht per LockWorkStation gesperrt werden. Sie wird getrennt
      (WTSDisconnectSession, entspricht tsdiscon). Die Sitzung bleibt mit allen Programmen
      erhalten, der Zugriff erfordert eine erneute Anmeldung.
    - Konsolensitzung: Der Bildschirm zeigt danach den Anmelde-/Sperrbildschirm.
    - RDP-Sitzung: Der RDP-Client des Benutzers wird getrennt, er kann sich neu verbinden.

    Die Datei ist bewusst reines ASCII (keine Umlaute), damit sie in Windows PowerShell 5.1
    und PowerShell 7 unabhaengig von der Dateikodierung korrekt geladen wird.
#>

Set-StrictMode -Version Latest

#region Native WTS-API (wird lokal und auf den Zielrechnern bei Bedarf kompiliert)

$script:WtsTypeDefinition = @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace RemoteSessionLock
{
    public class WtsSession
    {
        public int SessionId;
        public string WinStationName;
        public string UserName;
        public string DomainName;
        public int State;       // WTS_CONNECTSTATE_CLASS: 0 = Aktiv, 4 = Getrennt, ...
        public int LockState;   // 0 = gesperrt, 1 = entsperrt, -1 = unbekannt
    }

    public static class NativeMethods
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct WTS_SESSION_INFO
        {
            public int SessionId;
            public IntPtr pWinStationName;
            public int State;
        }

        [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool WTSEnumerateSessions(IntPtr hServer, int reserved, int version, out IntPtr ppSessionInfo, out int pCount);

        [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool WTSQuerySessionInformation(IntPtr hServer, int sessionId, int wtsInfoClass, out IntPtr ppBuffer, out int pBytesReturned);

        [DllImport("wtsapi32.dll")]
        private static extern void WTSFreeMemory(IntPtr pMemory);

        [DllImport("wtsapi32.dll", SetLastError = true)]
        private static extern bool WTSDisconnectSession(IntPtr hServer, int sessionId, bool bWait);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool LockWorkStation();

        private static readonly IntPtr CurrentServer = IntPtr.Zero;
        private const int WTSUserName      = 5;
        private const int WTSDomainName    = 7;
        private const int WTSSessionInfoEx = 25;

        private static string QueryString(int sessionId, int infoClass)
        {
            IntPtr buffer;
            int bytes;
            if (!WTSQuerySessionInformation(CurrentServer, sessionId, infoClass, out buffer, out bytes))
            {
                return null;
            }
            try
            {
                return Marshal.PtrToStringUni(buffer);
            }
            finally
            {
                WTSFreeMemory(buffer);
            }
        }

        private static int QueryLockState(int sessionId)
        {
            IntPtr buffer;
            int bytes;
            if (!WTSQuerySessionInformation(CurrentServer, sessionId, WTSSessionInfoEx, out buffer, out bytes))
            {
                return -1;
            }
            try
            {
                // WTSINFOEX: Level (4 Byte) + Ausrichtung der Union auf 8 Byte (4 Byte)
                //            + SessionId (4) + SessionState (4) -> SessionFlags ab Offset 16
                if (bytes < 20 || Marshal.ReadInt32(buffer, 0) != 1)
                {
                    return -1;
                }
                int flags = Marshal.ReadInt32(buffer, 16);
                return (flags == 0 || flags == 1) ? flags : -1;
            }
            finally
            {
                WTSFreeMemory(buffer);
            }
        }

        public static List<WtsSession> GetSessions()
        {
            List<WtsSession> result = new List<WtsSession>();
            IntPtr pInfo;
            int count;

            if (!WTSEnumerateSessions(CurrentServer, 0, 1, out pInfo, out count))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            try
            {
                int size = Marshal.SizeOf(typeof(WTS_SESSION_INFO));
                for (int i = 0; i < count; i++)
                {
                    IntPtr entry = new IntPtr(pInfo.ToInt64() + ((long)i * size));
                    WTS_SESSION_INFO raw = (WTS_SESSION_INFO)Marshal.PtrToStructure(entry, typeof(WTS_SESSION_INFO));

                    WtsSession session = new WtsSession();
                    session.SessionId      = raw.SessionId;
                    session.WinStationName = Marshal.PtrToStringUni(raw.pWinStationName);
                    session.State          = raw.State;
                    session.UserName       = QueryString(raw.SessionId, WTSUserName);
                    session.DomainName     = QueryString(raw.SessionId, WTSDomainName);
                    session.LockState      = QueryLockState(raw.SessionId);
                    result.Add(session);
                }
            }
            finally
            {
                WTSFreeMemory(pInfo);
            }

            return result;
        }

        public static void DisconnectSession(int sessionId)
        {
            if (!WTSDisconnectSession(CurrentServer, sessionId, true))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
        }

        public static void LockCurrentWorkstation()
        {
            if (!LockWorkStation())
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
        }
    }
}
'@

#endregion

#region Kernlogik (laeuft lokal per Aufruf oder remote per Invoke-Command)

# Bewusst mit param() statt $using:, damit derselbe Block lokal und remote laeuft.
$script:SessionCore = {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TypeDefinition,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Status', 'Lock', 'LockWorkstation')]
        [string]$Mode,

        # Schluessel: Rechnername (GROSS, ohne Domaene) oder IP; Wert: '*' oder Liste von Session-IDs
        [hashtable]$TargetMap,

        [string]$UserFilter,

        [string]$DomainFilter
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if (-not ('RemoteSessionLock.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition $TypeDefinition
    }

    if ($Mode -eq 'LockWorkstation') {
        [RemoteSessionLock.NativeMethods]::LockCurrentWorkstation()
        [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            Benutzer     = $env:USERNAME
            SessionID    = (Get-Process -Id $PID).SessionId
            Aktion       = 'Gesperrt (LockWorkStation)'
        }
        return
    }

    $StateNames = @{
        0 = 'Aktiv'; 1 = 'Verbunden'; 2 = 'Verbindungsabfrage'; 3 = 'Spiegelung'; 4 = 'Getrennt'
        5 = 'Leerlauf'; 6 = 'Lauscht'; 7 = 'Zurueckgesetzt'; 8 = 'Inaktiv'; 9 = 'Initialisierung'
    }

    # Nur Sitzungen mit angemeldetem Benutzer (schliesst Session 0 und RDP-Listener aus)
    $UserSessions = @([RemoteSessionLock.NativeMethods]::GetSessions() |
        Where-Object { -not [string]::IsNullOrEmpty($_.UserName) })

    if ($Mode -eq 'Status') {
        if ($UserSessions.Count -eq 0) {
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Benutzer     = '-'
                Domaene      = '-'
                SessionID    = $null
                Sitzung      = '-'
                Status       = 'Keine Sitzung'
                Gesperrt     = $null
            }
            return
        }

        foreach ($Session in $UserSessions) {
            # Getrennte Sitzungen sind ohne erneute Anmeldung nicht zugaenglich -> gelten als gesperrt
            $IsLocked = $null
            if ($Session.State -eq 4 -or $Session.LockState -eq 0) {
                $IsLocked = $true
            } elseif ($Session.LockState -eq 1) {
                $IsLocked = $false
            }

            $StateName = $StateNames[$Session.State]
            if ($null -eq $StateName) {
                $StateName = "Unbekannt ($($Session.State))"
            }

            $SessionName = $Session.WinStationName
            if ([string]::IsNullOrEmpty($SessionName)) {
                $SessionName = '-'
            }

            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Benutzer     = $Session.UserName
                Domaene      = $Session.DomainName
                SessionID    = $Session.SessionId
                Sitzung      = $SessionName
                Status       = $StateName
                Gesperrt     = $IsLocked
            }
        }
        return
    }

    # --- Modus 'Lock' ---------------------------------------------------------
    # Eigenen Eintrag in der Zielzuordnung suchen (NetBIOS-Name, DNS-Hostname, IP-Adressen)
    $OwnNames = [System.Collections.Generic.List[string]]::new()
    $OwnNames.Add($env:COMPUTERNAME.ToUpperInvariant())
    $OwnNames.Add(([System.Net.Dns]::GetHostName() -split '\.')[0].ToUpperInvariant())
    try {
        foreach ($Address in [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName())) {
            $OwnNames.Add($Address.ToString())
        }
    } catch {
        Write-Verbose "IP-Adressen von $env:COMPUTERNAME konnten nicht ermittelt werden: $($_.Exception.Message)"
    }

    $Allowed = $null
    if ($null -ne $TargetMap) {
        foreach ($Name in $OwnNames) {
            if ($TargetMap.ContainsKey($Name)) {
                $Allowed = $TargetMap[$Name]
                break
            }
        }
    }

    # Sichere Voreinstellung: ohne eindeutige Zuordnung wird nichts gesperrt
    if ($null -eq $Allowed) {
        [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            Benutzer     = '-'
            SessionID    = $null
            Aktion       = 'Fehler: Rechner nicht eindeutig zuordenbar, nichts gesperrt'
        }
        return
    }

    $LockAll = ($Allowed -is [string]) -and ($Allowed -eq '*')
    $AllowedIds = @()
    if (-not $LockAll) {
        $AllowedIds = @($Allowed | ForEach-Object { [int]$_ })
    }

    $Matched = 0
    foreach ($Session in $UserSessions) {
        if (-not $LockAll -and ($AllowedIds -notcontains $Session.SessionId)) {
            continue
        }
        if (-not [string]::IsNullOrEmpty($UserFilter) -and ($Session.UserName -notlike $UserFilter)) {
            continue
        }
        if (-not [string]::IsNullOrEmpty($DomainFilter) -and ($Session.DomainName -notlike $DomainFilter)) {
            continue
        }
        # Nur aktive Sitzungen sind offen; getrennte Sitzungen sind bereits geschuetzt
        if ($Session.State -ne 0) {
            continue
        }

        $Matched++
        $Result = [ordered]@{
            ComputerName = $env:COMPUTERNAME
            Benutzer     = $Session.UserName
            SessionID    = $Session.SessionId
            Aktion       = $null
        }

        if ($Session.LockState -eq 0) {
            $Result.Aktion = 'Uebersprungen (bereits gesperrt)'
        } else {
            try {
                [RemoteSessionLock.NativeMethods]::DisconnectSession($Session.SessionId)
                $Result.Aktion = 'Gesperrt (Sitzung getrennt)'
            } catch {
                $Result.Aktion = "Fehler: $($_.Exception.GetBaseException().Message)"
            }
        }

        [PSCustomObject]$Result
    }

    if ($Matched -eq 0) {
        [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            Benutzer     = '-'
            SessionID    = $null
            Aktion       = 'Keine passende aktive Sitzung'
        }
    }
}

#endregion

#region Private Hilfsfunktionen

function Test-IsLocalComputer {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (@('.', 'localhost', '127.0.0.1') -contains $Name) {
        return $true
    }

    # Eigene IP-Adressen (LAN, Loopback) ebenfalls als lokal erkennen
    $IpAddress = $null
    if ([System.Net.IPAddress]::TryParse($Name, [ref]$IpAddress)) {
        if ([System.Net.IPAddress]::IsLoopback($IpAddress)) {
            return $true
        }
        try {
            $LocalAddresses = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName())
            return [bool](@($LocalAddresses | Where-Object { $_.Equals($IpAddress) }).Count -gt 0)
        } catch {
            return $false
        }
    }

    $ShortName = ($Name -split '\.')[0]
    $LocalHost = ([System.Net.Dns]::GetHostName() -split '\.')[0]
    return ($ShortName -eq $env:COMPUTERNAME) -or ($ShortName -eq $LocalHost)
}

function ConvertTo-TargetKey {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (Test-IsLocalComputer -Name $Name) {
        return $env:COMPUTERNAME.ToUpperInvariant()
    }

    $IpAddress = $null
    if ([System.Net.IPAddress]::TryParse($Name, [ref]$IpAddress)) {
        return $IpAddress.ToString()
    }

    return ($Name -split '\.')[0].ToUpperInvariant()
}

function Test-ComputerOnline {
    <#
        Pingt alle Rechner gleichzeitig an und gibt die erreichbaren Namen zurueck.
        Gesamtdauer ~ TimeoutMs statt Anzahl x Timeout wie bei sequenziellem Test-Connection.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ComputerName,

        [ValidateRange(100, 10000)]
        [int]$TimeoutMs = 1000
    )

    $Pending = foreach ($Computer in $ComputerName) {
        $Ping = [System.Net.NetworkInformation.Ping]::new()
        $Task = $null
        $StartError = $null
        try {
            $Task = $Ping.SendPingAsync($Computer, $TimeoutMs)
        } catch {
            $StartError = $_.Exception.GetBaseException().Message
        }
        [PSCustomObject]@{
            ComputerName = $Computer
            Ping         = $Ping
            Task         = $Task
            StartError   = $StartError
        }
    }

    foreach ($Item in $Pending) {
        try {
            if ($null -ne $Item.StartError) {
                Write-Warning "Rechner '$($Item.ComputerName)' nicht erreichbar ($($Item.StartError)) - uebersprungen."
                continue
            }

            $Reply = $Item.Task.GetAwaiter().GetResult()
            if ($Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $Item.ComputerName
            } else {
                Write-Warning "Rechner '$($Item.ComputerName)' antwortet nicht auf ICMP ($($Reply.Status)) - uebersprungen."
            }
        } catch {
            Write-Warning "Rechner '$($Item.ComputerName)' nicht erreichbar ($($_.Exception.GetBaseException().Message)) - uebersprungen."
        } finally {
            $Item.Ping.Dispose()
        }
    }
}

function Invoke-SessionCore {
    <#
        Fuehrt die Kernlogik lokal direkt und remote parallel per Invoke-Command aus.
        Verbindungs- und Ausfuehrungsfehler werden als Warnung je Rechner gemeldet.
    #>
    [CmdletBinding()]
    param (
        [string]$LocalComputer,

        [string[]]$RemoteComputers,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [object[]]$ArgumentList,

        [int]$ThrottleLimit = 32,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    if (-not [string]::IsNullOrEmpty($LocalComputer)) {
        try {
            & $script:SessionCore @ArgumentList
        } catch {
            Write-Warning "Lokaler Rechner '$LocalComputer': $($_.Exception.GetBaseException().Message)"
        }
    }

    if ($null -eq $RemoteComputers -or $RemoteComputers.Count -eq 0) {
        return
    }

    $InvokeParams = @{
        ComputerName  = $RemoteComputers
        ScriptBlock   = $script:SessionCore
        ArgumentList  = $ArgumentList
        ThrottleLimit = $ThrottleLimit
        ErrorAction   = 'SilentlyContinue'
        ErrorVariable = 'RemoteErrors'
    }
    if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
        $InvokeParams.Credential = $Credential
    }

    $RemoteErrors = $null
    Invoke-Command @InvokeParams |
        Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName

    foreach ($ErrorRecord in @($RemoteErrors)) {
        if ($null -eq $ErrorRecord) {
            continue
        }
        $Origin = $ErrorRecord.TargetObject
        $OriginInfo = $ErrorRecord.PSObject.Properties['OriginInfo']
        if ($null -ne $OriginInfo -and $null -ne $OriginInfo.Value) {
            $Origin = $OriginInfo.Value.PSComputerName
        }
        Write-Warning "Rechner '$Origin': $($ErrorRecord.Exception.GetBaseException().Message)"
    }
}

#endregion

#region Oeffentliche Funktionen

function Get-RemoteSessionStatus {
    <#
    .SYNOPSIS
        Zeigt die angemeldeten Benutzersitzungen und ihren Sperrzustand an.

    .DESCRIPTION
        Ermittelt je Rechner alle Sitzungen mit angemeldetem Benutzer inklusive Session-ID,
        Sitzungsname, Verbindungsstatus und Sperrzustand. Offline-Rechner werden vorab per
        ICMP aussortiert, die Abfrage selbst laeuft parallel ueber Invoke-Command.

        Gesperrt = $true  : Bildschirm gesperrt oder Sitzung getrennt
        Gesperrt = $false : Sitzung aktiv und offen
        Gesperrt = $null  : Zustand unbekannt bzw. keine Sitzung

    .PARAMETER ComputerName
        Ein oder mehrere Rechnernamen (NetBIOS, FQDN oder IPv4). Standard: lokaler Rechner.

    .PARAMETER Credential
        Optionale Anmeldedaten fuer die Remote-Verbindung.

    .PARAMETER ThrottleLimit
        Maximale Anzahl gleichzeitiger Remote-Verbindungen (Standard 32).

    .PARAMETER PingTimeoutMs
        Timeout der Online-Pruefung in Millisekunden (Standard 1000).

    .EXAMPLE
        Get-RemoteSessionStatus -ComputerName PC01, RDS01 | Format-Table -AutoSize

    .EXAMPLE
        Get-RemoteSessionStatus -ComputerName PC01, PC02 | Where-Object { $_.Gesperrt -eq $false }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('CN', 'Name', 'DNSHostName')]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^(\.|[A-Za-z0-9][A-Za-z0-9.\-]{0,253})$')]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 32,

        [ValidateRange(100, 10000)]
        [int]$PingTimeoutMs = 1000
    )

    begin {
        $Targets = [ordered]@{}
    }

    process {
        foreach ($Computer in $ComputerName) {
            $Name = $Computer.Trim()
            $Key = ConvertTo-TargetKey -Name $Name
            if (-not $Targets.Contains($Key)) {
                $Targets[$Key] = $Name
            }
        }
    }

    end {
        $LocalComputer = $null
        $RemoteCandidates = [System.Collections.Generic.List[string]]::new()

        foreach ($Key in $Targets.Keys) {
            $Name = $Targets[$Key]
            if (Test-IsLocalComputer -Name $Name) {
                $LocalComputer = $env:COMPUTERNAME
            } else {
                $RemoteCandidates.Add($Name)
            }
        }

        $RemoteOnline = @()
        if ($RemoteCandidates.Count -gt 0) {
            $RemoteOnline = @(Test-ComputerOnline -ComputerName $RemoteCandidates -TimeoutMs $PingTimeoutMs)
        }

        if ($null -eq $LocalComputer -and $RemoteOnline.Count -eq 0) {
            return
        }

        $CoreParams = @{
            LocalComputer   = $LocalComputer
            RemoteComputers = $RemoteOnline
            ArgumentList    = @($script:WtsTypeDefinition, 'Status', @{}, '', '')
            ThrottleLimit   = $ThrottleLimit
            Credential      = $Credential
        }
        Invoke-SessionCore @CoreParams |
            Select-Object -Property ComputerName, Benutzer, Domaene, SessionID, Sitzung, Status, Gesperrt
    }
}

function Lock-RemoteSession {
    <#
    .SYNOPSIS
        Sperrt aktive Benutzersitzungen auf lokalen oder entfernten Rechnern.

    .DESCRIPTION
        Ohne Filter werden alle aktiven, nicht gesperrten Sitzungen der Zielrechner gesperrt.
        Mit -SessionId bzw. -UserName nur die passenden Sitzungen.

        Entfernte bzw. fremde Sitzungen werden getrennt (WTSDisconnectSession, wie tsdiscon):
        Programme laufen weiter, der Zugriff erfordert eine erneute Anmeldung.
        Der lokale Rechner ohne Filter wird per LockWorkStation gesperrt (eigene Sitzung).

        Bereits gesperrte und getrennte Sitzungen werden nicht angefasst.
        ConfirmImpact ist High: ohne -Confirm:$false fragt die Funktion vor dem Sperren nach.

        Per Pipeline von Get-RemoteSessionStatus werden ComputerName und SessionID paarweise
        uebernommen, es werden also genau die uebergebenen Sitzungen gesperrt.

    .PARAMETER ComputerName
        Ein oder mehrere Rechnernamen (NetBIOS, FQDN oder IPv4). Standard: lokaler Rechner.

    .PARAMETER SessionId
        Eine oder mehrere Session-IDs (1-65535). Gilt fuer alle angegebenen Rechner.

    .PARAMETER UserName
        Benutzername, optional mit Domaene (DOMAENE\benutzer). Platzhalter * und ? sind erlaubt.

    .PARAMETER Credential
        Optionale Anmeldedaten fuer die Remote-Verbindung.

    .PARAMETER ThrottleLimit
        Maximale Anzahl gleichzeitiger Remote-Verbindungen (Standard 32).

    .PARAMETER PingTimeoutMs
        Timeout der Online-Pruefung in Millisekunden (Standard 1000).

    .EXAMPLE
        Lock-RemoteSession -ComputerName PC01, PC02 -WhatIf

    .EXAMPLE
        Lock-RemoteSession -ComputerName RDS01 -SessionId 4 -Confirm:$false

    .EXAMPLE
        Get-RemoteSessionStatus -ComputerName RDS01 |
            Where-Object { $_.Gesperrt -eq $false -and $_.Benutzer -like 'azubi*' } |
            Lock-RemoteSession
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('CN', 'Name', 'DNSHostName')]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^(\.|[A-Za-z0-9][A-Za-z0-9.\-]{0,253})$')]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        # Kein ValidateRange: Platzhalterzeilen aus Get-RemoteSessionStatus liefern $null.
        # Die Pruefung erfolgt im process-Block.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [int[]]$SessionId,

        [ValidatePattern('^([A-Za-z0-9.\-_]{1,64}\\)?[A-Za-z0-9.\-_ $*?]{1,64}$')]
        [string]$UserName,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 32,

        [ValidateRange(100, 10000)]
        [int]$PingTimeoutMs = 1000
    )

    begin {
        # Schluessel -> @{ Name = <Verbindungsname>; All = <bool>; Ids = List[int] }
        $Targets = [ordered]@{}

        $UserFilter = ''
        $DomainFilter = ''
        if (-not [string]::IsNullOrEmpty($UserName)) {
            $Parts = $UserName -split '\\', 2
            if ($Parts.Count -eq 2) {
                $DomainFilter = $Parts[0]
                $UserFilter = $Parts[1]
            } else {
                $UserFilter = $Parts[0]
            }
        }
    }

    process {
        $Ids = @()
        if ($null -ne $SessionId) {
            $Ids = @($SessionId)
            foreach ($Id in $Ids) {
                if ($Id -lt 1 -or $Id -gt 65535) {
                    throw "Ungueltige Session-ID '$Id'. Erlaubt sind Werte von 1 bis 65535."
                }
            }
        }

        foreach ($Computer in $ComputerName) {
            $Name = $Computer.Trim()
            $Key = ConvertTo-TargetKey -Name $Name

            if (-not $Targets.Contains($Key)) {
                $Targets[$Key] = @{
                    Name = $Name
                    All  = $false
                    Ids  = [System.Collections.Generic.List[int]]::new()
                }
            }

            if ($Ids.Count -eq 0) {
                $Targets[$Key].All = $true
            } else {
                foreach ($Id in $Ids) {
                    if (-not $Targets[$Key].Ids.Contains($Id)) {
                        $Targets[$Key].Ids.Add($Id)
                    }
                }
            }
        }
    }

    end {
        $LocalEntry = $null
        $LocalKey = $env:COMPUTERNAME.ToUpperInvariant()
        $RemoteCandidates = [System.Collections.Generic.List[string]]::new()
        $TargetMap = @{}

        foreach ($Key in $Targets.Keys) {
            $Entry = $Targets[$Key]
            if ($Entry.All) {
                $TargetMap[$Key] = '*'
            } else {
                $TargetMap[$Key] = [int[]]$Entry.Ids.ToArray()
            }

            if ($Key -eq $LocalKey) {
                $LocalEntry = $Entry
            } else {
                $RemoteCandidates.Add($Entry.Name)
            }
        }

        # 1. Lokaler Rechner
        if ($null -ne $LocalEntry) {
            $UseLockWorkstation = $LocalEntry.All -and [string]::IsNullOrEmpty($UserName)
            if ($UseLockWorkstation) {
                if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Eigene Sitzung per LockWorkStation sperren')) {
                    Invoke-SessionCore -LocalComputer $env:COMPUTERNAME -ArgumentList @($script:WtsTypeDefinition, 'LockWorkstation', @{}, '', '')
                }
            } else {
                if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Passende lokale Sitzung(en) trennen und damit sperren')) {
                    $LocalMap = @{ $LocalKey = $TargetMap[$LocalKey] }
                    Invoke-SessionCore -LocalComputer $env:COMPUTERNAME -ArgumentList @($script:WtsTypeDefinition, 'Lock', $LocalMap, $UserFilter, $DomainFilter)
                }
            }
        }

        # 2. Entfernte Rechner
        if ($RemoteCandidates.Count -eq 0) {
            return
        }

        $RemoteOnline = @(Test-ComputerOnline -ComputerName $RemoteCandidates -TimeoutMs $PingTimeoutMs)
        if ($RemoteOnline.Count -eq 0) {
            return
        }

        $TargetText = '{0} Rechner: {1}' -f $RemoteOnline.Count, ($RemoteOnline -join ', ')
        if ($PSCmdlet.ShouldProcess($TargetText, 'Passende aktive Sitzung(en) trennen und damit sperren')) {
            $CoreParams = @{
                RemoteComputers = $RemoteOnline
                ArgumentList    = @($script:WtsTypeDefinition, 'Lock', $TargetMap, $UserFilter, $DomainFilter)
                ThrottleLimit   = $ThrottleLimit
                Credential      = $Credential
            }
            Invoke-SessionCore @CoreParams |
                Select-Object -Property ComputerName, Benutzer, SessionID, Aktion
        }
    }
}

#endregion

Export-ModuleMember -Function Get-RemoteSessionStatus, Lock-RemoteSession
