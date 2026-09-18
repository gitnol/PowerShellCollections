<#
.SYNOPSIS
    Startskript fuer die Ping-Ueberwachung von Windows-10-Rechnern mit
    E-Mail-Benachrichtigung.

.DESCRIPTION
    Laedt das Modul Win10PingMonitor.psm1 aus demselben Verzeichnis, zeigt
    gaengige SMTP-Einstellungen an, nimmt die Konfiguration entgegen und
    startet die Ueberwachung.

    Faellt ein ueberwachter Rechner aus, geht eine E-Mail raus.

.NOTES
    Die SMTP-Angaben im Skript sind Platzhalter und muessen ersetzt werden.
    Bei Gmail und Microsoft 365 braucht es ein App-Passwort, nicht das
    Kontopasswort.

    Der Modulimport zeigte frueher auf ein nicht existierendes
    'Win10Monitor.psm1' und lief damit ins Leere; er laeuft jetzt ueber
    $PSScriptRoot und ist damit auch unabhaengig vom Arbeitsverzeichnis.
#>

# 1. Modul laden
Import-Module (Join-Path $PSScriptRoot 'Win10PingMonitor.psm1') -Force

# 2. Häufige SMTP-Einstellungen anzeigen
Get-CommonSMTPSettings

# 3. Konfiguration für Gmail/Outlook
$credential = Get-Credential  # E-Mail + App-Passwort eingeben
Set-MonitoringConfiguration -SMTPServer "my.mailserver.test" -SMTPPort 587 -UseSSL -FromAddress "your.email@asdfasdf.com" -ToAddress @("admin@company.com")
$Global:ModuleConfig.Credential = $credential

# 4. SMTP-Test
Test-SMTPConfiguration

# 5. Vollständiges Monitoring
Invoke-Windows10ComputerMonitoring -SendCSVAttachment