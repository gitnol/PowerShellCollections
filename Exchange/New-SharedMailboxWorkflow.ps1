# HINWEIS: DIESE DATEI MUSS MIT DER KODIERUNG "UTF-8 mit BOM" GESPEICHERT WERDEN.
<#
.SYNOPSIS
    Erstellt standardisierte Shared Mailboxes und die dazugehörigen AD-Sicherheitsgruppen für Berechtigungen.

.DESCRIPTION
    Dieses Skript automatisiert den kompletten Prozess zur Erstellung einer oder mehrerer Shared Mailboxes.
    Für jeden angegebenen Namen führt es die folgenden Schritte aus:
    1. Erstellt eine AD-Sicherheitsgruppe nach dem Schema 'SharedMailbox_Name_FullAccess' in der definierten OU.
    2. Erstellt eine Shared Mailbox nach dem Schema 'SharedMailboxName' in der definierten OU.
    3. Konfiguriert die primäre SMTP-Adresse der neuen Mailbox (z.B. 'name@domain.com') und deaktiviert die E-Mail-Adressrichtlinie.

    Das Skript ist robust, prüft auf bereits existierende Objekte und behandelt AD-Replikationsverzögerungen intelligent.

.PARAMETER MailboxNames
    Ein oder mehrere Namen für die zu erstellenden Shared Mailboxes (z.B. "Vertrieb", "Marketing").

.PARAMETER ADGroupOU
    Der Distinguished Name der OU, in der die AD-Sicherheitsgruppen erstellt werden sollen.

.PARAMETER MailboxOU
    Der Distinguished Name der OU, in der die AD-Benutzerkonten für die Shared Mailboxes erstellt werden sollen.

.PARAMETER PrimarySmtpDomain
    Die E-Mail-Domäne für die primäre SMTP-Adresse (z.B. "mycorp.com").

.PARAMETER UPNDomain
    Die Domäne für den UserPrincipalName der Postfach-Konten (z.B. "mycorp.local").

.PARAMETER ExchangeServer
    Der FQDN des Exchange Servers für die Remote-Verbindung.

.PARAMETER Credential
    Optionale Anmeldeinformationen für die Exchange-Verbindung.

.EXAMPLE
    .\New-SharedMailboxWorkflow.ps1 -MailboxNames "Vertrieb", "Marketing" -ADGroupOU "OU=SharedMailbox_Permission,OU=EXCHANGE,OU=ITMGMT,DC=mycorp,DC=local" -MailboxOU "OU=SharedMailbox,OU=EXCHANGE,OU=ITMGMT,DC=mycorp,DC=local" -PrimarySmtpDomain "mycorp.com" -UPNDomain "mycorp.local" -ExchangeServer "srvex05.mycorp.local"

.EXAMPLE
    .\New-SharedMailboxWorkflow.ps1 -MailboxNames "Buchhaltung" -ADGroupOU "OU=Groups,DC=domain,DC=local" -MailboxOU "OU=Shared,DC=domain,DC=local" -PrimarySmtpDomain "company.com" -UPNDomain "domain.local" -ExchangeServer "exchange.domain.local" -WhatIf
    Simuliert die Erstellung und zeigt alle geplanten Aktionen an, ohne Änderungen vorzunehmen.

.NOTES
    Version:         1.2
    Author:          Gemini
    Creation Date:   2025-09-02
    Changelog:
    - 1.2 (2025-09-02): Formatierungsfehler in der Write-Log Funktion behoben, der zu fehlerhafter Konsolenausgabe führte.
    - 1.1 (2025-09-02): Fehler beim Trennen der Session bei lokaler Ausführung behoben.
    - 1.0 (2025-09-02): Initiale Version.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$MailboxNames,

    [Parameter(Mandatory = $true)]
    [string]$ADGroupOU,

    [Parameter(Mandatory = $true)]
    [string]$MailboxOU,

    [Parameter(Mandatory = $true)]
    [string]$PrimarySmtpDomain,
    
    [Parameter(Mandatory = $true)]
    [string]$UPNDomain,

    [Parameter(Mandatory = $true)]
    [string]$ExchangeServer,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential
)

#================================================================================
# --- KONSTANTEN UND KONFIGURATION ---
#================================================================================
$script:ADGroupPrefix = "SharedMailbox_"
$script:ADGroupSuffix = "_FullAccess"
$script:MailboxPrefix = "SharedMailbox"
$script:RetryCount = 5
$script:RetryDelaySeconds = 15

$script:Stats = @{ GroupsCreated = 0; MailboxesCreated = 0; MailboxesConfigured = 0; Skipped = 0; Errors = 0 }

#================================================================================
# --- INITIALISIERUNG & LOGGING ---
#================================================================================
$script:ExitCode = 0
try {
    Start-Transcript -Path "C:\_logs\New-SharedMailbox-$(Get-Date -f 'yyyy-MM-dd').log" -Append
}
catch {
    Write-Error "Logfile konnte nicht erstellt werden. Breche ab."
    exit 1
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]$Level,
        [string]$ConsoleColor = 'White'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = "[$timestamp] [$Level] $Message"
    Write-Host $formattedMessage -ForegroundColor $ConsoleColor
}

#================================================================================
# --- VERBINDUNGS-MANAGEMENT ---
#================================================================================
function Connect-To-Exchange {
    param([System.Management.Automation.PSCredential]$Cred)
    if (Get-Command Get-Mailbox -ErrorAction SilentlyContinue) { Write-Log -Level INFO -Message "Exchange Management Shell bereits geladen." -ConsoleColor Green; return $null }
    try {
        Write-Log -Level INFO -Message "Baue Remote-Session zu '$ExchangeServer' auf..." -ConsoleColor Cyan
        $sessionParams = @{ ConfigurationName = 'Microsoft.Exchange'; ConnectionUri = "http://$ExchangeServer/PowerShell/"; SessionOption = New-PSSessionOption -SkipRevocationCheck; ErrorAction = 'Stop' }
        if ($Cred) { $sessionParams.Credential = $Cred } else { $sessionParams.Authentication = 'Kerberos' }
        $session = New-PSSession @sessionParams; Import-PSSession $session -DisableNameChecking -AllowClobber | Out-Null
        Write-Log -Level SUCCESS -Message "Remote-Session erfolgreich hergestellt." -ConsoleColor Green
        return $session
    }
    catch { throw "Verbindung zum Exchange Server '$ExchangeServer' fehlgeschlagen." }
}
function Disconnect-From-Exchange { param([System.Management.Automation.Runspaces.PSSession]$Session) { if ($null -ne $Session) { Get-PSSession | Where-Object { $_.InstanceId -eq $Session.InstanceId } | Remove-PSSession; Write-Log -Level INFO -Message "Remote-Session getrennt." -ConsoleColor Cyan } } }

#================================================================================
# --- HAUPTSKRIPT-LOGIK ---
#================================================================================
$ExchSession = $null
try {
    $script:StartTime = Get-Date
    Import-Module ActiveDirectory
    $ExchSession = Connect-To-Exchange -Cred $Credential

    foreach ($name in $MailboxNames) {
        Write-Host "---"
        Write-Log -Level INFO -Message "Verarbeite: '$name'"

        # Namen und Pfade definieren
        $adGroupName = "$($script:ADGroupPrefix)${name}$($script:ADGroupSuffix)"
        $mailboxName = "$($script:MailboxPrefix)${name}"
        $displayName = $name
        $upn = "${mailboxName}@${UPNDomain}"
        $primarySmtpAddress = "${name}@${PrimarySmtpDomain}"

        # Schritt 1: AD-Gruppe erstellen
        if (Get-ADGroup -Filter { Name -eq $adGroupName } -ErrorAction SilentlyContinue) {
            Write-Log -Level WARN -Message "AD-Gruppe '$adGroupName' existiert bereits. Wird übersprungen." -ConsoleColor Yellow
            $script:Stats.Skipped++
        }
        else {
            if ($PSCmdlet.ShouldProcess($adGroupName, "New-ADGroup")) {
                Write-Log -Level INFO -Message "Erstelle AD-Gruppe '$adGroupName' in OU '$ADGroupOU'."
                try {
                    New-ADGroup -Path $ADGroupOU -Name $adGroupName -GroupScope Universal -GroupCategory Security -ErrorAction Stop
                    Write-Log -Level SUCCESS -Message "AD-Gruppe '$adGroupName' erfolgreich erstellt." -ConsoleColor Green
                    $script:Stats.GroupsCreated++
                }
                catch {
                    Write-Log -Level ERROR -Message "Fehler beim Erstellen der AD-Gruppe '$adGroupName': $($_.Exception.Message)" -ConsoleColor Red
                    $script:Stats.Errors++
                    continue # Nächsten Namen verarbeiten
                }
            }
        }

        # Schritt 2: Shared Mailbox erstellen
        if (Get-Recipient -Identity $mailboxName -ErrorAction SilentlyContinue) {
            Write-Log -Level WARN -Message "Postfach oder Empfänger '$mailboxName' existiert bereits. Wird übersprungen." -ConsoleColor Yellow
            $script:Stats.Skipped++
        }
        else {
            if ($PSCmdlet.ShouldProcess($mailboxName, "New-Mailbox")) {
                Write-Log -Level INFO -Message "Erstelle Shared Mailbox '$mailboxName' in OU '$MailboxOU'."
                try {
                    New-Mailbox -Shared -Name $mailboxName -DisplayName $displayName -UserPrincipalName $upn -OrganizationalUnit $MailboxOU -ErrorAction Stop
                    Write-Log -Level SUCCESS -Message "Shared Mailbox '$mailboxName' erfolgreich erstellt." -ConsoleColor Green
                    $script:Stats.MailboxesCreated++
                }
                catch {
                    Write-Log -Level ERROR -Message "Fehler beim Erstellen der Shared Mailbox '$mailboxName': $($_.Exception.Message)" -ConsoleColor Red
                    $script:Stats.Errors++
                    continue
                }
            }
        }

        # Schritt 3: Mailbox konfigurieren (mit Retry-Logik für AD-Replikation)
        if ($PSCmdlet.ShouldProcess($primarySmtpAddress, "Set-Mailbox PrimarySmtpAddress for $mailboxName")) {
            Write-Log -Level INFO -Message "Konfiguriere primäre SMTP-Adresse. Warte auf AD-Replikation..."
            $mailboxFound = $false
            for ($attempt = 1; $attempt -le $script:RetryCount; $attempt++) {
                $newMailbox = Get-Mailbox -Identity $mailboxName -ErrorAction SilentlyContinue
                if ($newMailbox) {
                    $mailboxFound = $true
                    break
                }
                Write-Log -Level INFO -Message "Postfach noch nicht gefunden. Warte $($script:RetryDelaySeconds)s (Versuch $attempt von $($script:RetryCount))." -ConsoleColor Gray
                Start-Sleep -Seconds $script:RetryDelaySeconds
            }

            if ($mailboxFound) {
                try {
                    Set-Mailbox -Identity $mailboxName -PrimarySmtpAddress $primarySmtpAddress -EmailAddressPolicyEnabled $false -ErrorAction Stop
                    Write-Log -Level SUCCESS -Message "Primäre SMTP-Adresse für '$mailboxName' erfolgreich auf '$primarySmtpAddress' gesetzt." -ConsoleColor Green
                    $script:Stats.MailboxesConfigured++
                }
                catch {
                    Write-Log -Level ERROR -Message "Fehler beim Konfigurieren der Mailbox '$mailboxName': $($_.Exception.Message)" -ConsoleColor Red
                    $script:Stats.Errors++
                }
            }
            else {
                Write-Log -Level ERROR -Message "Postfach '$mailboxName' konnte auch nach mehreren Versuchen nicht gefunden werden. Konfiguration wird übersprungen." -ConsoleColor Red
                $script:Stats.Errors++
            }
        }
    }
}
catch {
    $script:Stats.Errors++
    Write-Log -Level ERROR -Message "Ein fataler Fehler ist im Skript aufgetreten: $($_.Exception.Message)" -ConsoleColor Red
}
finally {
    # KORREKTUR: Nur trennen, wenn eine gültige Session existiert
    if ($ExchSession -is [System.Management.Automation.Runspaces.PSSession]) {
        Disconnect-From-Exchange -Session $ExchSession
    }
    $endTime = Get-Date; $duration = New-TimeSpan -Start $script:StartTime -End $endTime
    Write-Host "=============================================================================="
    Write-Log -Level INFO -Message "ZUSAMMENFASSUNG DER AUSFÜHRUNG" -ConsoleColor Cyan
    Write-Log -Level INFO -Message "---------------------------------" -ConsoleColor Cyan
    Write-Log -Level INFO -Message "Gruppen Erstellt:       $($script:Stats.GroupsCreated)" -ConsoleColor Green
    Write-Log -Level INFO -Message "Postfächer Erstellt:    $($script:Stats.MailboxesCreated)" -ConsoleColor Green
    Write-Log -Level INFO -Message "Postfächer Konfiguriert:$($script:Stats.MailboxesConfigured)" -ConsoleColor Green
    Write-Log -Level INFO -Message "Übersprungen:           $($script:Stats.Skipped)" -ConsoleColor Yellow
    Write-Log -Level INFO -Message "Aufgetretene Fehler:    $($script:Stats.Errors)" -ConsoleColor Red
    Write-Log -Level INFO -Message "Gesamtdauer:              $([math]::Round($duration.TotalSeconds, 2)) Sekunden" -ConsoleColor Cyan
    Write-Host "=============================================================================="
    if ($global:Transcript) { Stop-Transcript }
    exit $script:ExitCode
}

