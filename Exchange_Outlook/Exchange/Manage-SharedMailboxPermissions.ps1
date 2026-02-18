# HINWEIS: DIESE DATEI MUSS MIT DER KODIERUNG "UTF-8 mit BOM" GESPEICHERT WERDEN,
#          DAMIT DEUTSCHE UMLAUTE (ä, ö, ü, ß) KORREKT VERARBEITET WERDEN.
<#
.SYNOPSIS
    Verwaltet vollautomatisch 'FullAccess'-Berechtigungen für Exchange 2019 SharedMailboxes basierend auf Active Directory Gruppenmitgliedschaften.

.DESCRIPTION
    Dieses Skript ist eine robuste und performante Lösung, um die FullAccess-Berechtigungen von SharedMailboxes (Schema: 'SharedMailbox*')
    mit den Mitgliedern einer zugehörigen AD-Gruppe (Schema: 'SharedMailbox_Name_FullAccess') zu synchronisieren.

    Es behandelt alle relevanten Edge-Cases wie verwaiste Berechtigungen, deaktivierte Benutzer und System-Konten.
    Zur Maximierung der Stabilität beinhaltet es eine Retry-Logik für die Exchange-Verbindung, eine Validierung der Eingabe-Parameter,
    optionales Credential-Management und einen robusten, mehrstufigen Fallback-Mechanismus (DN -> SAMAccountName -> SID) zur
    Benutzeridentifikation, um Probleme durch AD-Replikationslatenz zu umgehen.

    Am Ende jedes Laufs wird eine detaillierte Zusammenfassung der durchgeführten Aktionen ausgegeben.

.PARAMETER ExchangeServer
    Der FQDN des Exchange Servers, zu dem eine Remote-Verbindung aufgebaut werden soll (z.B. 'srvex05.mycorp.local').

.PARAMETER LogPath
    Der vollständige Pfad zur Logdatei. Standardmäßig wird eine tägliche Logdatei in 'C:\_logs\' erstellt.

.PARAMETER DomainPrefix
    Der NetBIOS-Name der Domain (z.B. 'mycorp'), der für den Fallback zur Benutzerauflösung verwendet wird.

.PARAMETER Credential
    Optionale Anmeldeinformationen. Wenn nicht angegeben, wird die integrierte Authentifizierung (Kerberos) des ausführenden Benutzers verwendet.

.EXAMPLE
    .\Manage-SharedMailboxPermissions.ps1 -ExchangeServer 'srvex05.mycorp.local' -DomainPrefix 'mycorp'
    Führt das Skript im produktiven Modus aus.

.EXAMPLE
    .\Manage-SharedMailboxPermissions.ps1 -ExchangeServer 'srvex05.mycorp.local' -DomainPrefix 'mycorp' -WhatIf
    Simuliert alle Aktionen, ohne Änderungen vorzunehmen, und zeigt eine Vorschau in der Konsole an.

.EXAMPLE
    .\Manage-SharedMailboxPermissions.ps1 -ExchangeServer 'srvex05.mycorp.local' -DomainPrefix 'mycorp' -Debug
    Führt das Skript mit zusätzlicher, detaillierter Debug-Ausgabe auf der Konsole aus.

.NOTES
    Version:         3.5 (DEFINITIVE)
    Author:          Gemini & User Collaboration
    Creation Date:   2025-09-01
    Requires:        PowerShell 5.1+, ActiveDirectory-Modul, Exchange 2019 On-Premise.
                     Das ausführende Konto benötigt passende Berechtigungen in Exchange (Recipient Management) und AD (Read).

    Changelog:
    - 3.8 (2025-09-02): -contains Operator für Berechtigungsfilterauf -eq korrigiert bzgl. FullAccess. Ich setze nur FullAccess, also muss es exakt so gefiltert werden.
    - 3.7 (2025-09-01): Der Berechtigungsfilter wurde von '-match' auf den präziseren und performanteren '-contains' Operator umgestellt.
    - 3.6 (2025-09-01): Eine konfigurierbare Ignorier-Liste ($IgnoredPrincipals) hinzugefügt, um kritische System- und Admin-Konten zu schützen.
    - 3.5 (2025-09-01): Remove-MailboxPermission ebenfalls auf SID-basierte Logik umgestellt, um die Robustheit zu maximieren.
    - 3.4 (2025-09-01): Dritter Fallback für Add-MailboxPermission via SID hinzugefügt, um AD-Replikationsprobleme zu beheben.
    - 3.3 (2025-09-01): Die fehlerhafte manuelle WhatIf-Prüfung wurde entfernt. Die Statistik-Zählung funktioniert nun korrekt im WhatIf-Modus.
    - 3.2 (2025-09-01): Versuch, die WhatIf-Statistik zu korrigieren.
    - 3.1 (2025-09-01): Variable Scope für $script:StartTime korrigiert, um Fehler bei der Zeitmessung im 'finally'-Block zu verhindern.
    - 3.0 (2025-09-01): Finale Härtung des Skripts (Retry-Logik, Input-Validierung, Credentials, Statistiken, Konstanten).
    - 2.0 (2025-09-01): Finale Code-Review und Vergleich mit Vorgänger-Skript.
    - 1.0 - 1.9 (2025-09-01): Iterative Entwicklung und Behebung von Fehlern (Encoding, Parameter, Logik, Kompatibilität).
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "FQDN des Exchange Servers (z.B. srvex05.mycorp.local)")]
    [string]$ExchangeServer,

    [Parameter(Mandatory = $false, HelpMessage = "Pfad für die Logdateien.")]
    [string]$LogPath = "C:\_logs\SharedMailbox-$(Get-Date -f 'yyyy-MM-dd').log",

    [Parameter(Mandatory = $true, HelpMessage = "NetBIOS-Name der Domain (z.B. mycorp)")]
    [string]$DomainPrefix,

    [Parameter(Mandatory = $false, HelpMessage = "Alternative Anmeldeinformationen für die Exchange-Verbindung.")]
    [System.Management.Automation.PSCredential]$Credential
)

#================================================================================
# --- KONSTANTEN UND KONFIGURATION ---
#================================================================================
$script:RetryCount = 3
$script:RetryDelaySeconds = 15
$script:MailboxFilter = "Name -like 'SharedMailbox*'"
$script:AdGroupPrefix = "SharedMailbox_"
$script:AdGroupSuffix = "_FullAccess"
$script:SelfSid = "S-1-5-10" # NT AUTHORITY\SELF
$script:Stats = @{ MailboxesProcessed = 0; PermissionsAdded = 0; PermissionsRemoved = 0; ErrorsEncountered = 0 }

$script:IgnoredPrincipals = @(
    "$DomainPrefix\Administrator",
    "$DomainPrefix\Exchange Servers"
)

#================================================================================
# --- INITIALISIERUNG & PARAMETER-VALIDIERUNG ---
#================================================================================
$script:ExitCode = 0
$global:ProgressPreference = 'SilentlyContinue'
try {
    if ($ExchangeServer -notmatch '^[a-zA-Z0-9\.\-]+$') { throw "Der angegebene Exchange Server '$ExchangeServer' hat ein ungültiges Format." }
    if ([string]::IsNullOrWhiteSpace($DomainPrefix)) { throw "Der DomainPrefix darf nicht leer sein." }
    
    # Dynamisches Hinzufügen der domänenspezifischen Administrator-SID zur Ignorier-Liste
    try {
        $adminSid = (Get-ADUser -Identity 'Administrator' -ErrorAction Stop).SID.Value
        if ($adminSid) { $script:IgnoredPrincipals += $adminSid }
    }
    catch {
        Write-Warning "Das Administrator-Konto konnte nicht gefunden werden, um seine SID zur Ignorier-Liste hinzuzufügen."
    }

    $LogDir = Split-Path -Path $LogPath -Parent
    if (-not (Test-Path -Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force -WhatIf:$false | Out-Null }
    Start-Transcript -Path $LogPath -Append
}
catch {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; $errorMessage = "[$timestamp] [ERROR] Kritischer Initialisierungsfehler: $($_.Exception.Message) - Skript wird beendet."
    Write-Host $errorMessage -ForegroundColor Red; if ($global:Transcript) { Stop-Transcript }; exit 1
}

#================================================================================
# --- LOGGING-FUNKTIONEN ---
#================================================================================
function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message, [Parameter(Mandatory = $true)][ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'REMOVE', 'SUMMARY')]$Level, [Parameter(Mandatory = $false)][string]$ConsoleColor = 'White')
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; $formattedMessage = "[$timestamp] [$Level] $Message"
    Write-Host $formattedMessage -ForegroundColor $ConsoleColor
}
function Write-DebugLog {
    param([string]$Message)
    if ($PSBoundParameters.ContainsKey('Debug')) { $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; Write-Host "[$timestamp] [DEBUG] $Message" -ForegroundColor Gray }
}

#================================================================================
# --- VERBINDUNGS-MANAGEMENT MIT RETRY-LOGIK ---
#================================================================================
function Connect-To-Exchange {
    param([System.Management.Automation.PSCredential]$Cred)
    Write-DebugLog "Prüfe auf vorhandene Exchange-Verbindungen..."
    if (Get-Command Get-Mailbox -ErrorAction SilentlyContinue) { Write-Log -Level INFO -Message "Exchange Management Shell SnapIn bereits geladen. Nutze lokale Verbindung." -ConsoleColor Green; return $null }
    for ($attempt = 1; $attempt -le $script:RetryCount; $attempt++) {
        try {
            Write-Log -Level INFO -Message "Baue Remote-Session zum Exchange Server '$ExchangeServer' auf... (Versuch $attempt von $($script:RetryCount))" -ConsoleColor Cyan
            $sessionParams = @{ ConfigurationName = 'Microsoft.Exchange'; ConnectionUri = "http://$ExchangeServer/PowerShell/"; SessionOption = New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck; ErrorAction = 'Stop' }
            if ($Cred) { $sessionParams.Credential = $Cred } else { $sessionParams.Authentication = 'Kerberos' }
            $session = New-PSSession @sessionParams; Import-PSSession $session -DisableNameChecking -AllowClobber | Out-Null
            Write-Log -Level SUCCESS -Message "Remote-Session zum Exchange Server erfolgreich hergestellt." -ConsoleColor Green
            return $session
        }
        catch {
            Write-Log -Level WARN -Message "Verbindung fehlgeschlagen: $($_.Exception.Message)" -ConsoleColor Yellow
            if ($attempt -lt $script:RetryCount) { Write-Log -Level INFO -Message "Warte $($script:RetryDelaySeconds) Sekunden vor dem nächsten Versuch..." -ConsoleColor Cyan; Start-Sleep -Seconds $script:RetryDelaySeconds } 
            else { throw "Verbindung zum Exchange Server '$ExchangeServer' nach $($script:RetryCount) Versuchen endgültig fehlgeschlagen." }
        }
    }
}
function Disconnect-From-Exchange {
    param([System.Management.Automation.Runspaces.PSSession]$Session)
    Write-DebugLog "Schließe und entferne die Remote-Session."; Get-PSSession | Where-Object { $_.InstanceId -eq $Session.InstanceId } | Remove-PSSession
    Write-Log -Level INFO -Message "Remote-Session zum Exchange Server wurde ordnungsgemäß getrennt." -ConsoleColor Cyan
}

#================================================================================
# --- HAUPTSKRIPT-LOGIK ---
#================================================================================
$ExchSession = $null
try {
    $script:StartTime = Get-Date
    Write-Log -Level INFO -Message "Skript gestartet." -ConsoleColor Cyan; Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log -Level INFO -Message "Active Directory Modul erfolgreich geladen." -ConsoleColor Green
    $ExchSession = Connect-To-Exchange -Cred $Credential
    Write-Log -Level INFO -Message "Suche nach SharedMailboxes mit dem Schema '$($script:MailboxFilter -replace ('Name -like ',''))'..." -ConsoleColor Cyan
    $sharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -Filter $script:MailboxFilter -ResultSize Unlimited -ErrorAction Stop
    if (-not $sharedMailboxes) { Write-Log -Level WARN -Message "Keine passenden SharedMailboxes gefunden." -ConsoleColor Yellow } 
    else {
        Write-Log -Level INFO -Message "$($sharedMailboxes.Count) passende SharedMailbox(es) gefunden." -ConsoleColor Cyan; Write-Host "---"
        foreach ($mailbox in $sharedMailboxes) {
            $script:Stats.MailboxesProcessed++; Write-Log -Level INFO -Message "Verarbeite Mailbox: $($mailbox.DisplayName) ($($mailbox.PrimarySmtpAddress))" -ConsoleColor White
            $adGroupName = ($mailbox.Name -replace '^SharedMailbox', $script:AdGroupPrefix) + $script:AdGroupSuffix; Write-DebugLog "Erwarteter AD Gruppenname: $adGroupName"
            $desiredState = @{}
            try {
                $adGroup = Get-ADGroup -Identity $adGroupName -ErrorAction Stop
                $adMembers = Get-ADGroupMember -Identity $adGroup -Recursive -ErrorAction Stop | Where-Object { $_.objectClass -eq 'user' }
                if ($adMembers) { $adMembers | Get-ADUser -Properties Name, SamAccountName, SID, DistinguishedName, Enabled | ForEach-Object { $desiredState[$_.SID.Value] = $_ }; Write-DebugLog "Gruppe '$adGroupName' hat $($desiredState.Count) gültige Benutzer-Mitglieder." } 
                else { Write-Log -Level INFO -Message "Die zugehörige AD-Gruppe '$adGroupName' ist leer oder enthält keine direkten Benutzer." -ConsoleColor Yellow }
            }
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { Write-Log -Level WARN -Message "Die erwartete AD-Gruppe '$adGroupName' wurde nicht gefunden. Diese Mailbox wird übersprungen." -ConsoleColor Yellow; $script:Stats.ErrorsEncountered++; Write-Host "---"; continue } 
            catch { Write-Log -Level ERROR -Message "Ein Fehler ist beim Abrufen der AD-Gruppenmitglieder für '$adGroupName' aufgetreten: $($_.Exception.Message)" -ConsoleColor Red; $script:Stats.ErrorsEncountered++; Write-Host "---"; continue }
            
            Write-DebugLog "Ermittle aktuelle FullAccess-Berechtigungen für $($mailbox.Name)."
            $currentState, $orphanedPermissions = @{}, @()
            # KORREKTUR: Operator auf -contains umgestellt
            $currentPermissions = Get-MailboxPermission -Identity $mailbox.Identity | Where-Object { 
                ($_.AccessRights -eq 'FullAccess') -and 
                $_.IsInherited -eq $false -and 
                $_.User.ToString() -notlike 'NT AUTHORITY\*' -and
                $_.User.SecurityIdentifier.Value -ne $script:SelfSid -and
                $_.User.ToString() -notin $script:IgnoredPrincipals -and
                $_.User.SecurityIdentifier.Value -notin $script:IgnoredPrincipals
            }
            
            foreach ($perm in $currentPermissions) { try { if ($adUser = Get-ADUser -Identity $perm.User.SecurityIdentifier -ErrorAction Stop) { $currentState[$adUser.SID.Value] = $perm } else { $orphanedPermissions += $perm } } catch { $orphanedPermissions += $perm } }
            Write-DebugLog "$($currentState.Count) gültige und $($orphanedPermissions.Count) verwaiste Berechtigungen gefunden."

            foreach ($sid in $currentState.Keys) {
                if (-not $desiredState.ContainsKey($sid)) {
                    $userIdentifier = try { (Get-ADUser -Identity $sid).SamAccountName }catch { $sid }
                    if ($PSCmdlet.ShouldProcess("Benutzer '$userIdentifier' von Mailbox '$($mailbox.Name)'", "Remove-MailboxPermission")) {
                        $script:Stats.PermissionsRemoved++; Write-Log -Level REMOVE -Message "FullAccess für '$userIdentifier' (SID: $sid) wird entzogen." -ConsoleColor Red
                        try { Remove-MailboxPermission -Identity $mailbox.Identity -User $sid -AccessRights FullAccess -InheritanceType All -Confirm:$false -ErrorAction Stop } catch { Write-Log -Level ERROR -Message "Fehler beim Entfernen der Berechtigung für '$userIdentifier': $($_.Exception.Message)" -ConsoleColor Red; $script:Stats.ErrorsEncountered++ }
                    }
                }
            }
            foreach ($orphan in $orphanedPermissions) {
                if ($PSCmdlet.ShouldProcess("Verwaiste SID '$($orphan.User.SecurityIdentifier.Value)' von Mailbox '$($mailbox.Name)'", "Remove-MailboxPermission")) {
                    $script:Stats.PermissionsRemoved++; Write-Log -Level REMOVE -Message "Verwaiste FullAccess-Berechtigung für '$($orphan.User)' wird entfernt." -ConsoleColor Red
                    try { Remove-MailboxPermission -Identity $mailbox.Identity -User $orphan.User.SecurityIdentifier.Value -AccessRights FullAccess -InheritanceType All -Confirm:$false -ErrorAction Stop } catch { Write-Log -Level ERROR -Message "Fehler beim Entfernen der verwaisten Berechtigung für '$($orphan.User)': $($_.Exception.Message)" -ConsoleColor Red; $script:Stats.ErrorsEncountered++ }
                }
            }

            foreach ($sid in $desiredState.Keys) {
                if (-not $currentState.ContainsKey($sid)) {
                    $userToAdd = $desiredState[$sid]
                    if (-not $userToAdd.Enabled) { Write-Log -Level WARN -Message "Benutzer '$($userToAdd.SamAccountName)' ist deaktiviert. Keine Berechtigung möglich." -ConsoleColor Yellow; continue }
                    if ($PSCmdlet.ShouldProcess("Benutzer '$($userToAdd.SamAccountName)' zu Mailbox '$($mailbox.Name)'", "Add-MailboxPermission")) {
                        $script:Stats.PermissionsAdded++; Write-Log -Level SUCCESS -Message "FullAccess für '$($userToAdd.Name)' (SAM: $($userToAdd.SamAccountName)) wird erteilt." -ConsoleColor Green
                        try { Add-MailboxPermission -Identity $mailbox.Identity -User $userToAdd.DistinguishedName -AccessRights FullAccess -AutoMapping $true -InheritanceType All -ErrorAction Stop } catch {
                            Write-Log -Level WARN -Message "Hinzufügen via DN für '$($userToAdd.SamAccountName)' fehlgeschlagen. Versuche Fallback via SAMAccountName..." -ConsoleColor Yellow
                            try { Add-MailboxPermission -Identity $mailbox.Identity -User "$DomainPrefix\$($userToAdd.SamAccountName)" -AccessRights FullAccess -AutoMapping $true -InheritanceType All -ErrorAction Stop } catch {
                                Write-Log -Level WARN -Message "Hinzufügen via SAMAccountName für '$($userToAdd.SamAccountName)' fehlgeschlagen. Versuche finalen Fallback via SID..." -ConsoleColor Yellow
                                try { Add-MailboxPermission -Identity $mailbox.Identity -User $userToAdd.SID.Value -AccessRights FullAccess -AutoMapping $true -InheritanceType All -ErrorAction Stop } 
                                catch { Write-Log -Level ERROR -Message "Fehler beim Hinzufügen der Berechtigung für '$($userToAdd.SamAccountName)': $($_.Exception.Message)" -ConsoleColor Red; $script:Stats.ErrorsEncountered++ }
                            }
                        }
                    }
                }
                else { Write-DebugLog "Berechtigung für '$($desiredState[$sid].SamAccountName)' existiert bereits. Überspringe." }
            }
            Write-Host "---"
        }
    }
}
catch {
    $script:Stats.ErrorsEncountered++; Write-Log -Level ERROR -Message "Ein fataler Fehler ist im Skript aufgetreten: $($_.Exception.Message)" -ConsoleColor Red
    $_.Exception.StackTrace; $script:ExitCode = 1
}
finally {
    if ($null -ne $ExchSession) { Disconnect-From-Exchange -Session $ExchSession }
    $endTime = Get-Date; $duration = New-TimeSpan -Start $script:StartTime -End $endTime
    Write-Host "=============================================================================="
    Write-Log -Level SUMMARY -Message "ZUSAMMENFASSUNG DER AUSFÜHRUNG" -ConsoleColor Cyan
    Write-Log -Level SUMMARY -Message "---------------------------------" -ConsoleColor Cyan
    Write-Log -Level SUMMARY -Message "Verarbeitete Postfächer: $($script:Stats.MailboxesProcessed)" -ConsoleColor Cyan
    Write-Log -Level SUMMARY -Message "Berechtigungen Hinzugefügt: $($script:Stats.PermissionsAdded) (geplant bei WhatIf)" -ConsoleColor Green
    Write-Log -Level SUMMARY -Message "Berechtigungen Entfernt:    $($script:Stats.PermissionsRemoved) (geplant bei WhatIf)" -ConsoleColor Red
    Write-Log -Level SUMMARY -Message "Aufgetretene Fehler:      $($script:Stats.ErrorsEncountered)" -ConsoleColor Yellow
    Write-Log -Level SUMMARY -Message "Gesamtdauer:                $([math]::Round($duration.TotalSeconds, 2)) Sekunden" -ConsoleColor Cyan
    Write-Host "=============================================================================="
    if ($global:Transcript) { Stop-Transcript }; exit $script:ExitCode
}