# 1. Modul laden
Import-Module .\Win10Monitor.psm1 -Force

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