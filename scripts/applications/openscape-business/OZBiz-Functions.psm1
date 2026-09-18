# OSBiz-WSI.psm1
# PowerShell-Modul für OSBiz WSI API
# Alle Funktionen enthalten eine kurze Synopsis und nutzen Invoke-RestMethod
# Source: https://wiki.unify.com/wiki/OpenScape_Business_Interfaces
# https://wiki.unify.com/images/f/fd/OSBiz_WSI.pdf

# This scripts demonstrates how to log in, make a call, and log out using the OpenScape Business API.
# Ensure you have the necessary permissions and the API is accessible.

# Example: 
# Import-Module "path-to-file\OSBiz-WSI.psm1"
# $base = "https://10.1.2.3:8802"
# $login = Invoke-OSBizLogin -BaseUrl $base -User 123 -Pass 123456
# Invoke-OSBizMakeCall -BaseUrl $base -SessionID $login.SessionID -CallingDevice 123 -CalledDirectoryNumber 456
# Invoke-OSBizLogout -BaseUrl $base -SessionID $login.SessionID


function Invoke-OSBizLogin {
    <#
.SYNOPSIS
Meldet sich an der OSBiz API an und gibt die Session-ID zurück.
#>
    param(
        [string]$BaseUrl,
        [string]$User,
        [string]$Pass
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=Login&gsUser=$User&gsPass=$Pass"
    [xml]$resp = Invoke-RestMethod -Uri $url -SkipCertificateCheck
    if ($resp.LOGIN.ID -and $resp.LOGIN.ID -ne '0') {
        [PSCustomObject]@{
            SessionID = $resp.LOGIN.ID
            Count     = $resp.LOGIN.CNT
        }
    }
    else {
        throw "Login fehlgeschlagen: $($resp.LOGIN.ERROR)"
    }
}

function Invoke-OSBizLogout {
    <#
.SYNOPSIS
Meldet die Session bei der OSBiz API ab.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=Logout&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck | Out-Null
}

function Invoke-OSBizMakeCall {
    <#
.SYNOPSIS
Startet einen Anruf synchron, Antwort nach Ausführung.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$CallingDevice,
        [string]$CalledDirectoryNumber
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=MakeCall&callingDevice=$CallingDevice&calledDirectoryNumber=$CalledDirectoryNumber&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizMkCall {
    <#
.SYNOPSIS
Startet einen Anruf asynchron, Antwort erfolgt sofort.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$CallingDevice,
        [string]$CalledDirectoryNumber
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=MkCall&callingDevice=$CallingDevice&calledDirectoryNumber=$CalledDirectoryNumber&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizConsultationCall {
    <#
.SYNOPSIS
Führt ein Beratungsgespräch während eines aktiven Gesprächs.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID,
        [string]$ConsultNumber
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=ConsultationCall&deviceID=$DeviceID&consultNumber=$ConsultNumber&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizAlternateCall {
    <#
.SYNOPSIS
Wechselt zwischen gehaltenem und aktivem Gespräch.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=AlternateCall&deviceID=$DeviceID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizReconnectCall {
    <#
.SYNOPSIS
Stellt Verbindung zum gehaltenen Teilnehmer wieder her.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=ReconnectCall&deviceID=$DeviceID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizConferenceCall {
    <#
.SYNOPSIS
Startet eine Dreierkonferenz zwischen aktivem und gehaltenem Gespräch.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=ConferenceCall&deviceID=$DeviceID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizEndConference {
    <#
.SYNOPSIS
Beendet eine Dreierkonferenz (nur Master).
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=EndConference&deviceID=$DeviceID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizTransferCall {
    <#
.SYNOPSIS
Führt eine Blind-Weiterleitung aus.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID,
        [string]$TargetDevice
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=TransferCall&deviceID=$DeviceID&targetDevice=$TargetDevice&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizAttendedTransfer {
    <#
.SYNOPSIS
Führt eine betreute Weiterleitung aus.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=AttendedTransfer&deviceID=$DeviceID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizGetServerParam {
    <#
.SYNOPSIS
Liest Systemwählparameter vom Server.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=GetServerParam&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizClearDisplay {
    <#
.SYNOPSIS
Löscht angezeigten Text auf einem Gerätedisplay.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=ClearDisplay&deviceID=$DeviceID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizSetDisplay {
    <#
.SYNOPSIS
Setzt statischen Text auf einem Gerätedisplay.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID,
        [string]$Text
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=SetDisplay&deviceID=$DeviceID&text=$([uri]::EscapeDataString($Text))&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizGetDoNotDisturb {
    <#
.SYNOPSIS
Liest aktuellen "Nicht stören"-Status (veraltet).
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=GetDoNotDisturb&deviceID=$DeviceID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizGetForwarding {
    <#
.SYNOPSIS
Liest aktuelle Anrufweiterleitung (veraltet).
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=GetForwarding&deviceID=$DeviceID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizGetEvents {
    <#
.SYNOPSIS
Ruft Ereignisse für ein Gerät ab.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=GetEvents&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizEventStart {
    <#
.SYNOPSIS
Startet Event-Monitoring für ein Gerät.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=EventStart&deviceID=$DeviceID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizEventStop {
    <#
.SYNOPSIS
Stoppt Event-Monitoring für ein Gerät.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$DeviceID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=EventStop&deviceID=$DeviceID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizSetPresence {
    <#
.SYNOPSIS
Setzt den Präsenzstatus eines Benutzers.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$UserID,
        [string]$PresenceState
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=SetPresence&user=$UserID&presenceState=$PresenceState&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizSetCallMe {
    <#
.SYNOPSIS
Aktiviert "Call Me" für einen Benutzer.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$UserID,
        [bool]$Enable
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=SetCallMe&user=$UserID&enable=$($Enable.ToString().ToLower())&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizGetPresenceXML {
    <#
.SYNOPSIS
Ruft Präsenzstatus als XML ab.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$UserID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=GetPresenceXML&user=$UserID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizPresenceDBGet {
    <#
.SYNOPSIS
Liest Einträge aus der Präsenzdatenbank.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=PresenceDBGet&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizPresenceDBSet {
    <#
.SYNOPSIS
Schreibt Einträge in die Präsenzdatenbank.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$Data
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=PresenceDBSet&data=$([uri]::EscapeDataString($Data))&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizJournalRead {
    <#
.SYNOPSIS
Liest Einträge aus dem Anrufjournal.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$UserID,
        [int]$Count = 10,
        [string]$Type
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=JournalRead&user=$UserID&count=$Count&gsSession=$SessionID"
    if ($Type) { $url += "&type=$Type" }
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizJournalGroupByDate {
    <#
.SYNOPSIS
Liest Journal-Einträge gruppiert nach Datum.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$UserID,
        [int]$Count = 10
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=JournalGroupByDate&user=$UserID&count=$Count&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizJournalFetch {
    <#
.SYNOPSIS
Ruft Journal-Einträge anhand einer ID oder Kriterien ab.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$UserID,
        [string]$JID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=JournalFetch&user=$UserID&gsSession=$SessionID"
    if ($JID) { $url += "&jid=$JID" }
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizPhBookSearch {
    <#
.SYNOPSIS
Sucht im Telefonbuch nach Einträgen.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$SearchTerm
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=PhBookSearch&searchTerm=$([uri]::EscapeDataString($SearchTerm))&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizPhBookDetail {
    <#
.SYNOPSIS
Liest Detailinformationen zu einem Telefonbucheintrag.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$EntryID
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=PhBookDetail&entryID=$EntryID&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}

function Invoke-OSBizPhBookLookup {
    <#
.SYNOPSIS
Führt eine Rückwärtssuche im Telefonbuch durch.
#>
    param(
        [string]$BaseUrl,
        [string]$SessionID,
        [string]$PhoneNumber
    )
    $url = "$BaseUrl/cgi-bin/gadgetapi?cmd=PhBookLookup&phoneNumber=$PhoneNumber&gsSession=$SessionID"
    Invoke-RestMethod -Uri $url -SkipCertificateCheck
}


function Show-OSBizHelp {
    <#
.SYNOPSIS
Zeigt alle OSBiz-WSI-Befehle mit Kurzbeschreibung an.
#>
    $functions = @(
        @{Name = 'Invoke-OSBizMkCall'; Synopsis = 'Startet einen Anruf asynchron, Antwort erfolgt sofort, Ergebnis kommt über Event-Kanal.' },
        @{Name = 'Invoke-OSBizConsultationCall'; Synopsis = 'Führt ein Beratungsgespräch während eines aktiven Gesprächs mit einer dritten Nummer.' },
        @{Name = 'Invoke-OSBizAlternateCall'; Synopsis = 'Wechselt zwischen gehaltenem und aktivem Gespräch.' },
        @{Name = 'Invoke-OSBizReconnectCall'; Synopsis = 'Stellt Verbindung zum gehaltenen Teilnehmer nach einem Beratungsgespräch wieder her.' },
        @{Name = 'Invoke-OSBizConferenceCall'; Synopsis = 'Startet eine Dreierkonferenz zwischen aktivem und gehaltenem Gespräch.' },
        @{Name = 'Invoke-OSBizEndConference'; Synopsis = 'Beendet eine Dreierkonferenz (nur vom Konferenz-Master möglich).' },
        @{Name = 'Invoke-OSBizTransferCall'; Synopsis = 'Führt eine Blind-Weiterleitung zu einem Zielgerät aus.' },
        @{Name = 'Invoke-OSBizAttendedTransfer'; Synopsis = 'Führt eine betreute Weiterleitung zwischen aktivem und gehaltenem Gespräch aus.' },
        @{Name = 'Invoke-OSBizGetServerParam'; Synopsis = 'Liest Systemwählparameter vom Server.' },
        @{Name = 'Invoke-OSBizClearDisplay'; Synopsis = 'Löscht angezeigten Text auf einem Gerätedisplay.' },
        @{Name = 'Invoke-OSBizSetDisplay'; Synopsis = 'Setzt statischen Text auf einem Gerätedisplay.' },
        @{Name = 'Invoke-OSBizGetDoNotDisturb'; Synopsis = 'Liest aktuellen "Nicht stören"-Status (veraltet).' },
        @{Name = 'Invoke-OSBizGetForwarding'; Synopsis = 'Liest aktuelle Anrufweiterleitung (veraltet).' },
        @{Name = 'Invoke-OSBizGetEvents'; Synopsis = 'Ruft Ereignisse (z. B. HookState, Presence) für ein Gerät ab.' },
        @{Name = 'Invoke-OSBizEventStart'; Synopsis = 'Startet Event-Monitoring für ein Gerät.' },
        @{Name = 'Invoke-OSBizEventStop'; Synopsis = 'Stoppt Event-Monitoring für ein Gerät.' },
        @{Name = 'Invoke-OSBizSetPresence'; Synopsis = 'Setzt den Präsenzstatus eines Benutzers.' },
        @{Name = 'Invoke-OSBizSetCallMe'; Synopsis = 'Aktiviert "Call Me"-Funktion für einen Benutzer.' },
        @{Name = 'Invoke-OSBizGetPresenceXML'; Synopsis = 'Ruft Präsenzstatus als XML ab.' },
        @{Name = 'Invoke-OSBizPresenceDBGet'; Synopsis = 'Liest Einträge aus der Präsenzdatenbank.' },
        @{Name = 'Invoke-OSBizPresenceDBSet'; Synopsis = 'Schreibt Einträge in die Präsenzdatenbank.' },
        @{Name = 'Invoke-OSBizJournalRead'; Synopsis = 'Liest Einträge aus dem Anrufjournal.' },
        @{Name = 'Invoke-OSBizJournalGroupByDate'; Synopsis = 'Liest Journal-Einträge gruppiert nach Datum.' },
        @{Name = 'Invoke-OSBizJournalFetch'; Synopsis = 'Ruft Journal-Einträge anhand einer ID oder Kriterien ab.' },
        @{Name = 'Invoke-OSBizPhBookSearch'; Synopsis = 'Sucht im Telefonbuch nach Einträgen.' },
        @{Name = 'Invoke-OSBizPhBookDetail'; Synopsis = 'Liest Detailinformationen zu einem Telefonbucheintrag.' },
        @{Name = 'Invoke-OSBizPhBookLookup'; Synopsis = 'Führt eine Rückwärtssuche im Telefonbuch durch (z. B. Nummer → Name).' }
    )

    $functions | ForEach-Object {
        [PSCustomObject]@{
            Funktion     = $_.Name
            Beschreibung = $_.Synopsis
        }
    } | Format-Table -AutoSize


    $infos = @'
Import-Module "path-to-file\OSBiz-WSI.psm1"
$base = "https://10.1.2.3:8802"
$login = Invoke-OSBizLogin -BaseUrl $base -User 123 -Pass 123456
Invoke-OSBizMakeCall -BaseUrl $base -SessionID $login.SessionID -CallingDevice 123 -CalledDirectoryNumber 456
Invoke-OSBizLogout -BaseUrl $base -SessionID $login.SessionID
}
'@

$infos
}

Export-ModuleMember -Function *
