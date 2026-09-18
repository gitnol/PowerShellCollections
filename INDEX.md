# Skript-Index

<!-- Automatisch erzeugt von tools/Build-ScriptIndex.ps1 - nicht von Hand bearbeiten. -->

165 Skripte. 76 mit `.SYNOPSIS` (46%), 81 weitere mit einer Kurzbeschreibung aus dem ersten Kommentar.

| Markierung | Bedeutung |
| ---------- | --------- |
| _(aus Kommentar)_ | keine `.SYNOPSIS` - Text stammt aus der ersten Kommentarzeile und ist ein Hinweis, keine Beschreibung |
| `def` | enthaelt ausser Funktionsdefinitionen keinen ausfuehrbaren Code, laesst sich also gefahrlos per Dot-Sourcing laden |
| **Syntaxfehler** | die Datei parst nicht |

Davon 35 nebenwirkungsfrei, 0 mit Syntaxfehlern.

## `_inbox/playground/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [New-ADGroupInOU_with_some_stuff.ps1](_inbox/playground/New-ADGroupInOU_with_some_stuff.ps1) |  | _(aus Kommentar)_ Prüfen, ob OU existiert |

## `scripts/active-directory/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Protect-OUs.ps1](scripts/active-directory/Protect-OUs.ps1) |  | Aktiviert den Schutz vor versehentlichem Löschen für alle OUs in der Domäne. |
| [Test-DomainCredentials.ps1](scripts/active-directory/Test-DomainCredentials.ps1) | `def` | _(aus Kommentar)_ This script checks whether the user name and password are correct and returns true or false accordingly. |

## `scripts/active-directory/dns/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Find-DNSDuplicates.ps1](scripts/active-directory/dns/Find-DNSDuplicates.ps1) |  | Findet und entfernt doppelte DNS-A-Einträge zonenübergreifend. |

## `scripts/active-directory/gpo/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-GPOLinks.ps1](scripts/active-directory/gpo/Get-GPOLinks.ps1) | `def` | _(aus Kommentar)_ # Alle GPOs inkl. Links |
| [Get-GPOReportSettings.ps1](scripts/active-directory/gpo/Get-GPOReportSettings.ps1) |  | _(aus Kommentar)_ If this does not work with Powershell 7, try it as admin / elevated |
| [Get-GPPItemLevelTargeting.ps1](scripts/active-directory/gpo/Get-GPPItemLevelTargeting.ps1) |  | _(aus Kommentar)_ Diese Funktion liefert die zielgruppenbasierte Zuordnung innerhalb von GPPs bei GPOs. |
| [New-GPOAnalysis.ps1](scripts/active-directory/gpo/New-GPOAnalysis.ps1) |  | Vergleicht bei allen GPOs den konfigurierten Status mit den tatsaechlich vorhandenen Einstellungen. |

## `scripts/active-directory/group-membership/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Compare-ADGroupSidResolution.ps1](scripts/active-directory/group-membership/Compare-ADGroupSidResolution.ps1) |  | _(aus Kommentar)_ ($user.MemberOf).count |
| [Compare-ADUserGroup.ps1](scripts/active-directory/group-membership/Compare-ADUserGroup.ps1) |  | _(aus Kommentar)_ Change the two lines if you do not want to input it |
| [Copy-ADGroupMember.ps1](scripts/active-directory/group-membership/Copy-ADGroupMember.ps1) | `def` | _keine Beschreibung_ |
| [Resolve-ADGroupRecursive.ps1](scripts/active-directory/group-membership/Resolve-ADGroupRecursive.ps1) |  | _(aus Kommentar)_ CaseSensitive |

## `scripts/active-directory/group-membership/temporary/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Show-TemporaryGroupMembershipGui_v1.ps1](scripts/active-directory/group-membership/temporary/Show-TemporaryGroupMembershipGui_v1.ps1) |  | GUI zum Vergeben zeitlich begrenzter AD-Gruppenmitgliedschaften ueber das PAM-Feature (Stand v1). |
| [Show-TemporaryGroupMembershipGui_v2.ps1](scripts/active-directory/group-membership/temporary/Show-TemporaryGroupMembershipGui_v2.ps1) |  | Bietet eine grafische Benutzeroberfläche (GUI) zur Verwaltung von temporären Active Directory-Gruppenmitgliedschaften mithilfe des PAM-Features. |
| [Sync-TemporaryGroupMembershipFromCsv_v2.ps1](scripts/active-directory/group-membership/temporary/Sync-TemporaryGroupMembershipFromCsv_v2.ps1) |  | Automatisiert temporäre Active Directory-Gruppenmitgliedschaften für Auszubildende und andere Benutzer basierend auf Abteilungszuordnungen. |
| [Sync-TemporaryGroupMembershipFromCsv_v3.ps1](scripts/active-directory/group-membership/temporary/Sync-TemporaryGroupMembershipFromCsv_v3.ps1) |  | Automatisiert temporäre und permanente Active Directory-Gruppenmitgliedschaften basierend auf CSV-Dateien. |

## `scripts/active-directory/inventory/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-ADComputerInventory.ps1](scripts/active-directory/inventory/Get-ADComputerInventory.ps1) |  | Inventarisiert AD-Computer parallel und aktualisiert Benutzer-, Hardware- und Kommentar-Informationen im Description-Feld. |
| [Get-ADComputerLastLogon.ps1](scripts/active-directory/inventory/Get-ADComputerLastLogon.ps1) |  | _(aus Kommentar)_ Alle DCs ermitteln |
| [Get-ADEnabledUserWithManager.ps1](scripts/active-directory/inventory/Get-ADEnabledUserWithManager.ps1) |  | _(aus Kommentar)_ Import the Active Directory module |
| [Get-ADInactiveGroupMember.ps1](scripts/active-directory/inventory/Get-ADInactiveGroupMember.ps1) |  | _(aus Kommentar)_ This Script helps to identify, which Office 365 or Microsoft 365 Licenses could perhaps be available for reuse. |
| [Get-ADUserLastLogonCache.ps1](scripts/active-directory/inventory/Get-ADUserLastLogonCache.ps1) |  | _(aus Kommentar)_ Rückgabe als Hashtable mit SamAccountName -> DateTime |

## `scripts/active-directory/ldap/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Connect-LdapServer.ps1](scripts/active-directory/ldap/Connect-LdapServer.ps1) |  | _(aus Kommentar)_ [string]$Filter = "(telephoneNumber=13*)", |
| [Test-LdapPorts.ps1](scripts/active-directory/ldap/Test-LdapPorts.ps1) |  | _(aus Kommentar)_ Ziel-IP-Adresse |

## `scripts/active-directory/logon-events/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-ADAuthEventsAllDCs.ps1](scripts/active-directory/logon-events/Get-ADAuthEventsAllDCs.ps1) | `def` | Sammelt Anmelde-Events (fehlgeschlagen, Lockout, erfolgreich) von allen Domain Controllern inkl. Quell-IP. |
| [Get-LockedOutEventsAllDCs.ps1](scripts/active-directory/logon-events/Get-LockedOutEventsAllDCs.ps1) | `def` | Sammelt Account-Lockout-Events von allen Domain Controllern in der Domäne. |
| [Get-LogonAttempts.ps1](scripts/active-directory/logon-events/Get-LogonAttempts.ps1) |  | _(aus Kommentar)_ This Script enables you to find failed logonattempts. (on german PCs... you have to adjust it to english words in the function Extract-MessageDetail) |
| [Get-UserLogonEvent.ps1](scripts/active-directory/logon-events/Get-UserLogonEvent.ps1) |  | _(aus Kommentar)_ This Script returns all logon events of specific EventIDs or user names |

## `scripts/active-directory/machine-sid/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-DuplicateMachineSIDs.ps1](scripts/active-directory/machine-sid/Get-DuplicateMachineSIDs.ps1) |  | _keine Beschreibung_ |
| [Invoke-MachineSidCheck.ps1](scripts/active-directory/machine-sid/Invoke-MachineSidCheck.ps1) |  | Prüft den Online-Status von AD-Computern und führt optional einen Neustart oder eine SID-Prüfung durch. |

## `scripts/active-directory/time-sync/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Set-PdcTimeSync.ps1](scripts/active-directory/time-sync/Set-PdcTimeSync.ps1) |  | Konfiguriert die Zeitsynchronisierung für den PDC-Emulationsmaster korrekt. Besser ist es jedoch, wenn eine GPO für die Zeitsynchronisierung verwendet wird. |

## `scripts/active-directory/token-size/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Export-KerberosTokenSize.ps1](scripts/active-directory/token-size/Export-KerberosTokenSize.ps1) |  | _(aus Kommentar)_ collects all Users of the local domain and exports their groupmember count and estimated ticketsize |
| [Get-TokenSizeReport.ps1](scripts/active-directory/token-size/Get-TokenSizeReport.ps1) |  | Ermittelt fuer alle Domaenenbenutzer die geschaetzte Kerberos-Tokengroesse und meldet die groessten. |

## `scripts/active-directory/user-photo/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Set-UserPhotoHybrid.ps1](scripts/active-directory/user-photo/Set-UserPhotoHybrid.ps1) |  | Setzt das Benutzerfoto gleichzeitig im lokalen AD (thumbnailPhoto) und in Entra ID / Teams. |

## `scripts/applications/docuware/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-DocuWareIisLog.ps1](scripts/applications/docuware/Get-DocuWareIisLog.ps1) |  | Gibt alle IIS-Logzeilen der letzten X Minuten als PSCustomObject zurück (alle Felder). |

## `scripts/applications/excel/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [ConvertFrom-ExcelClipboard.ps1](scripts/applications/excel/ConvertFrom-ExcelClipboard.ps1) |  | _(aus Kommentar)_ This function enables you to copy information from Excel to a pscustomobject |
| [Remove-ExcelSheetProtection.ps1](scripts/applications/excel/Remove-ExcelSheetProtection.ps1) |  | Entfernt den Blattschutz (Worksheet Protection) aus einer oder mehreren Tabellen einer .xlsx-Datei durch direkte XML-Manipulation. |

## `scripts/applications/filezilla/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [ConvertFrom-FileZillaLog.ps1](scripts/applications/filezilla/ConvertFrom-FileZillaLog.ps1) | `def` | _(aus Kommentar)_ $erg = Parse-FileZillaLog "D:\FILEZILLA_LOGS_bis_20250508\FILEZILLA.log" |
| [Get-FtpLoginSummary.ps1](scripts/applications/filezilla/Get-FtpLoginSummary.ps1) |  | Analysiert FileZilla Server Logs und gibt eine Zusammenfassung der erfolgreichen und fehlgeschlagenen FTP-Logins aus. |

## `scripts/applications/kyocera/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-PrinterSnmpOid.ps1](scripts/applications/kyocera/Get-PrinterSnmpOid.ps1) |  | _(aus Kommentar)_ See also here for some kyocera OIDs |

## `scripts/applications/openscape-business/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [OSBiz.psm1](scripts/applications/openscape-business/OSBiz.psm1) | `def` | Meldet sich an der OSBiz API an und gibt die Session-ID zurück. |

## `scripts/applications/teams/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Clear-TeamsCache.ps1](scripts/applications/teams/Clear-TeamsCache.ps1) |  | _(aus Kommentar)_ Beende alle laufenden Teams-Prozesse |

## `scripts/applications/teamviewer/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [ConvertFrom-TeamViewerLog.ps1](scripts/applications/teamviewer/ConvertFrom-TeamViewerLog.ps1) |  | _(aus Kommentar)_ Look here: https://medium.com/mii-cybersec/digital-forensic-artifact-of-teamviewer-application-cfd6290dc0a7 |
| [Set-TeamViewerAccess.ps1](scripts/applications/teamviewer/Set-TeamViewerAccess.ps1) | `def` | _(aus Kommentar)_ Definition der Funktion für die parallele Online-Prüfung im Begin-Block |
| [Start-TeamViewer.ps1](scripts/applications/teamviewer/Start-TeamViewer.ps1) |  | Startet TeamViewer mit verschiedenen Konfigurationsoptionen und Verbindungsparametern. |

## `scripts/applications/zammad/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-ZammadTicket.ps1](scripts/applications/zammad/Get-ZammadTicket.ps1) |  | _(aus Kommentar)_ Base URL of Zammad API |
| [Invoke-ZammadApi_v1.ps1](scripts/applications/zammad/Invoke-ZammadApi_v1.ps1) | `def` | _keine Beschreibung_ |
| [Invoke-ZammadApi_v2.ps1](scripts/applications/zammad/Invoke-ZammadApi_v2.ps1) | `def` | _(aus Kommentar)_ Zammad API PowerShell Modul |

## `scripts/databases/mssql/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-SqlServerVersion.ps1](scripts/databases/mssql/Get-SqlServerVersion.ps1) | `def` | Ermittelt die Versionen von SQL Server Instanzen auf remote Servern. |
| [Test-DbConnection.ps1](scripts/databases/mssql/Test-DbConnection.ps1) |  | Prüft eine OLE DB Datenbankverbindung mit interaktiver Passwortabfrage. |

## `scripts/filesystem/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Compress-FilesByMonth.ps1](scripts/filesystem/Compress-FilesByMonth.ps1) |  | _(aus Kommentar)_ Überprüfen, ob das Quellverzeichnis existiert |
| [Get-DllVersion.ps1](scripts/filesystem/Get-DllVersion.ps1) | `def` | _(aus Kommentar)_ Get-DllVersion -Pfad 'C:\Tools\openssl\libeay32.dll' |
| [Resolve-Links.ps1](scripts/filesystem/Resolve-Links.ps1) |  | _(aus Kommentar)_ This function searches for symlinks / junction points and hardlinks in a folder and subfolder. |

## `scripts/filesystem/permissions/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-FileserverUserPermission.ps1](scripts/filesystem/permissions/Get-FileserverUserPermission.ps1) |  | _(aus Kommentar)_ 1x alle Benutzer-Accounts in Hashtable |
| [Get-FolderPermissions.ps1](scripts/filesystem/permissions/Get-FolderPermissions.ps1) | `def` | _(aus Kommentar)_ This script looks for folder permissions recursively and lists those ones, which have (non inherited) single user permissions |

## `scripts/filesystem/search/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Find-FilesInZips.ps1](scripts/filesystem/search/Find-FilesInZips.ps1) | `def` | Durchsucht ZIP-Archive nach Dateien basierend auf einem Suchmuster. |
| [Get-TextMatchInFiles.ps1](scripts/filesystem/search/Get-TextMatchInFiles.ps1) | `def` | _(aus Kommentar)_ Verzeichnis, das durchsucht werden soll |

## `scripts/messaging/exchange/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-MailboxForwardingRules.ps1](scripts/messaging/exchange/Get-MailboxForwardingRules.ps1) |  | _(aus Kommentar)_ Make Exchange-specific commands available |
| [New-SharedMailboxWorkflow.ps1](scripts/messaging/exchange/New-SharedMailboxWorkflow.ps1) |  | Erstellt standardisierte Shared Mailboxes und die dazugehörigen AD-Sicherheitsgruppen für Berechtigungen. |
| [Sync-SharedMailboxPermission.ps1](scripts/messaging/exchange/Sync-SharedMailboxPermission.ps1) |  | Verwaltet vollautomatisch 'FullAccess'-Berechtigungen für Exchange 2019 SharedMailboxes basierend auf Active Directory Gruppenmitgliedschaften. |

## `scripts/messaging/mailstore/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Invoke-MailStoreApiScratch.ps1](scripts/messaging/mailstore/Invoke-MailStoreApiScratch.ps1) | `def` | _(aus Kommentar)_ HINWEIS: Diese Datei ist eine Arbeitskopie (frueher test.ps1) mit |
| [MailStoreApiFunctions.ps1](scripts/messaging/mailstore/MailStoreApiFunctions.ps1) | `def` | PowerShell-Huelle um die Administrations-API des MailStore Server. |
| [MailStoreSnippets_v1.ps1](scripts/messaging/mailstore/MailStoreSnippets_v1.ps1) |  | _(aus Kommentar)_ Ensure the Active Directory module is imported |
| [MailStoreSnippets_v2.ps1](scripts/messaging/mailstore/MailStoreSnippets_v2.ps1) |  | Aeltere Sammlung von MailStore-API-Funktionen samt Anwendungsbeispielen (Stand v2). |
| [New-MailStoreApiFunctionReference.ps1](scripts/messaging/mailstore/New-MailStoreApiFunctionReference.ps1) |  | Erzeugt aus der Online-Funktionsreferenz von MailStore PowerShell-Huellen fuer jede API-Methode. |

## `scripts/messaging/mailstore/api-wrapper/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [MS.PS.Lib.psm1](scripts/messaging/mailstore/api-wrapper/MS.PS.Lib.psm1) |  | Scriptblock called by "InternalMSApiCall" to handle long running API processes. |

## `scripts/messaging/mailstore/examples/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Example1.ps1](scripts/messaging/mailstore/examples/Example1.ps1) |  | _(aus Kommentar)_ Example Script 1 |
| [Example2.ps1](scripts/messaging/mailstore/examples/Example2.ps1) |  | _(aus Kommentar)_ Example Script 2 |
| [Example3.ps1](scripts/messaging/mailstore/examples/Example3.ps1) |  | _(aus Kommentar)_ Example Script 3 |
| [Example4.ps1](scripts/messaging/mailstore/examples/Example4.ps1) |  | _(aus Kommentar)_ Example Script 4 |

## `scripts/messaging/nospamproxy/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-NspUserToDomainCommunication.ps1](scripts/messaging/nospamproxy/Get-NspUserToDomainCommunication.ps1) |  | _(aus Kommentar)_ Parameter: Start- und Enddatum für den Abfragezeitraum |

## `scripts/messaging/outlook/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Invoke-OutlookAddinMaintenance.ps1](scripts/messaging/outlook/Invoke-OutlookAddinMaintenance.ps1) |  | Verwaltet Outlook Add-ins (Status prüfen, Listen, Reparieren). |

## `scripts/monitoring/ping-monitor/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Start-Win10PingMonitor.ps1](scripts/monitoring/ping-monitor/Start-Win10PingMonitor.ps1) |  | _(aus Kommentar)_ 1. Modul laden |
| [Win10PingMonitor.psm1](scripts/monitoring/ping-monitor/Win10PingMonitor.psm1) |  | Schreibt Meldungen in eine Log-Datei |

## `scripts/monitoring/prtg/ad-group-integrity/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Test-ADGroupIntegrity.ps1](scripts/monitoring/prtg/ad-group-integrity/Test-ADGroupIntegrity.ps1) |  | Überwacht die Integrität einer AD-Gruppe für PRTG und setzt einen Alarm (Latch/Breach) bei Änderungen. |
| [Test-ADGroupIntegrityMulti.ps1](scripts/monitoring/prtg/ad-group-integrity/Test-ADGroupIntegrityMulti.ps1) |  | Überwacht ALLE privilegierten AD-Gruppen (Multi-Channel) mittels SHA256. Kompatibel mit PowerShell 5.1 (Windows Server 2016/2019). |

## `scripts/monitoring/prtg/dsls/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-DslsLicenseUsage.ps1](scripts/monitoring/prtg/dsls/Get-DslsLicenseUsage.ps1) |  | PRTG-Sensor: Lizenznutzung und Restlaufzeit je Komponente auf dem DSLS. |
| [Get-DslsLogError.ps1](scripts/monitoring/prtg/dsls/Get-DslsLogError.ps1) |  | PRTG-Sensor: Anzahl der Fehlermeldungen im DSLS-Log der letzten 24 Stunden. |
| [Get-DslsOfflineLicense.ps1](scripts/monitoring/prtg/dsls/Get-DslsOfflineLicense.ps1) |  | PRTG-Sensor: Anzahl der aktuell vergebenen Offline-Lizenzen (Nomad) auf dem DSLS. |
| [PRTG.Dsls.psm1](scripts/monitoring/prtg/dsls/PRTG.Dsls.psm1) | `def` | Gemeinsame Hilfsfunktionen fuer die DSLS-Sensoren (Dassault Systemes License Server). |

## `scripts/monitoring/web-changes/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Test-WebChange.ps1](scripts/monitoring/web-changes/Test-WebChange.ps1) | `def` | Ueberwacht Webseiten auf inhaltliche Aenderungen per Hash-Vergleich. |

## `scripts/network/aruba/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-ArubaMacTable_v1.ps1](scripts/network/aruba/Get-ArubaMacTable_v1.ps1) |  | _(aus Kommentar)_ Just a demo script to connect to aruba switches and get the mac address table |
| [Get-ArubaMacTable_v2.ps1](scripts/network/aruba/Get-ArubaMacTable_v2.ps1) |  | _(aus Kommentar)_ iwr https://www.wireshark.org/json/manuf.json -OutFile C:\install\manuf.json |

## `scripts/network/dhcp/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-DhcpServerLease_v1.ps1](scripts/network/dhcp/Get-DhcpServerLease_v1.ps1) |  | _(aus Kommentar)_ This script get all DHCP Leases from the DHCP Server and list then together with the MAC Addresses in the valid RFC formats |
| [Get-DhcpServerLease_v2.ps1](scripts/network/dhcp/Get-DhcpServerLease_v2.ps1) |  | _(aus Kommentar)_ DHCP Leases aus allen autorisierten DHCP-Servern der Domäne abfragen und MAC-Adressen in verschiedenen Formaten ausgeben |

## `scripts/network/diagnostics/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-WebHeaders.ps1](scripts/network/diagnostics/Get-WebHeaders.ps1) |  | Liest HTTP Response-Header und Statuscode aus. |
| [Show-NetConnections.ps1](scripts/network/diagnostics/Show-NetConnections.ps1) |  | Zeigt aktive TCP/UDP-Verbindungen inkl. Prozessinformationen, ähnlich netstat -anob. |
| [Test-Port.ps1](scripts/network/diagnostics/Test-Port.ps1) |  | _(aus Kommentar)_ Funktion, um eine Verbindung zu einem Port mit Timeout zu prüfen |

## `scripts/network/firewall/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Remove-DuplicateFirewallRule.ps1](scripts/network/firewall/Remove-DuplicateFirewallRule.ps1) |  | _(aus Kommentar)_ This script removes duplicate firewall rules |

## `scripts/network/lancom/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [New-PublicSpotUser.ps1](scripts/network/lancom/New-PublicSpotUser.ps1) |  | Registers a new Public Spot user via a REST API call to a specified server. |
| [New-PublicSpotUserBulk_old.ps1](scripts/network/lancom/New-PublicSpotUserBulk_old.ps1) |  | Erstellt Public Spot Benutzer für LANCOM WLC/Router in Massenverarbeitung basierend auf einer CSV-Datei. |
| [New-PublicSpotUserBulk.ps1](scripts/network/lancom/New-PublicSpotUserBulk.ps1) |  | Erstellt Public Spot Benutzer für LANCOM WLC/Router in Massenverarbeitung basierend auf einer CSV-Datei. |

## `scripts/network/wake-on-lan/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Send-WakeOnLan.ps1](scripts/network/wake-on-lan/Send-WakeOnLan.ps1) | `def` | Sendet ein Wake-on-LAN Magic Packet an eine MAC-Adresse. |
| [Set-WakeOnLanAdapterOption.ps1](scripts/network/wake-on-lan/Set-WakeOnLanAdapterOption.ps1) |  | _keine Beschreibung_ |

## `scripts/security/bitlocker/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-BitLockerStatus_de.ps1](scripts/security/bitlocker/Get-BitLockerStatus_de.ps1) |  | _(aus Kommentar)_ Powershell Version 6 oder höher erzwingen |
| [Get-BitLockerStatus_en.ps1](scripts/security/bitlocker/Get-BitLockerStatus_en.ps1) |  | _(aus Kommentar)_ Force Usage of Powershell Version 6 or Higher |

## `scripts/security/certificates/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [New-Certificate.ps1](scripts/security/certificates/New-Certificate.ps1) |  | Requests certificates from ADCS, exports PFX to PEM, splits key/cert, and writes CA chain. |
| [Request-Certificate.ps1](scripts/security/certificates/Request-Certificate.ps1) |  | Requests a certificate from a Windows CA |
| [Set-VMwareCertificate.ps1](scripts/security/certificates/Set-VMwareCertificate.ps1) |  | Deploys certificates from New-Certificate.ps1 to VMware vCenter and ESXi hosts. |

## `scripts/security/crowdstrike/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Install-FalconSensor.ps1](scripts/security/crowdstrike/Install-FalconSensor.ps1) |  | Kopiert eine Installationsdatei (z.B. FalconSensor) auf Zielcomputer und führt sie dort remote mit Parametern aus. Das Skript muss als Administrator ausgeführt werden. |

## `scripts/security/log4j/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Find-Log4jFile_v1.ps1](scripts/security/log4j/Find-Log4jFile_v1.ps1) |  | _(aus Kommentar)_ Todo ... automatisches Löschen implementieren per Flag...ggf mit einer Filelist Denylist oder Allowlist |
| [Find-Log4jFile_v2.ps1](scripts/security/log4j/Find-Log4jFile_v2.ps1) |  | _(aus Kommentar)_ Vorbereitungen |

## `scripts/security/passwords/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Test-ADUserWeakPassword.ps1](scripts/security/passwords/Test-ADUserWeakPassword.ps1) |  | _(aus Kommentar)_ This little script checks the AD Users of specific groups, if they use a weak password |

## `scripts/security/secure-boot/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Invoke-SecureBootCertUpdate_simple.ps1](scripts/security/secure-boot/Invoke-SecureBootCertUpdate_simple.ps1) |  | Einmaliges Einleiten des Secure Boot 2023-Zertifikat-Updates (einfache Variante). |
| [Invoke-SecureBootCertUpdate.ps1](scripts/security/secure-boot/Invoke-SecureBootCertUpdate.ps1) |  | Secure Boot UEFI CA 2023 - Update Manager |
| [Test-MultipleHostsSecureBoot_v1.ps1](scripts/security/secure-boot/Test-MultipleHostsSecureBoot_v1.ps1) |  | _(aus Kommentar)_ Only Powershell 6 and above (because of ForEach-Object -Parallel) |
| [Test-MultipleHostsSecureBoot_v2.ps1](scripts/security/secure-boot/Test-MultipleHostsSecureBoot_v2.ps1) |  | _(aus Kommentar)_ Only PowerShell 7+ (ForEach-Object -Parallel) |
| [Test-SecureBootCert2023.ps1](scripts/security/secure-boot/Test-SecureBootCert2023.ps1) |  | Prüft den Secure Boot Status und das Vorhandensein des Windows UEFI CA 2023 Zertifikats. |

## `scripts/virtualization/vmware/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-VMSnapshots.ps1](scripts/virtualization/vmware/Get-VMSnapshots.ps1) | `def` | _keine Beschreibung_ |
| [Get-VMUptimes.ps1](scripts/virtualization/vmware/Get-VMUptimes.ps1) |  | _(aus Kommentar)_ -and $_.Guest.GuestFamily -match 'windows' } |
| [New-VSphereWindowsTemplate.ps1](scripts/virtualization/vmware/New-VSphereWindowsTemplate.ps1) |  | Bereitet eine Windows-VM als vSphere-Template vor. |

## `scripts/windows/activity-timeline/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-PCActivityTimeline.ps1](scripts/windows/activity-timeline/Get-PCActivityTimeline.ps1) |  | Erstellt eine vollständige Aktivitäts-Timeline eines oder mehrerer Rechner aus dem Windows-Eventlog. |
| [Test-PCActivityTimeline.ps1](scripts/windows/activity-timeline/Test-PCActivityTimeline.ps1) |  | Diagnose-Script für Get-PCActivityTimeline.ps1 Prüft Konnektivität, Audit-Richtlinien, Event-Counts und gibt rohe Properties[] der ersten Treffer jeder Event-ID aus — damit können die Property-Indices im Haupt-Script verifiziert werden. |

## `scripts/windows/autoruns/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Set-AutorunEntry.ps1](scripts/windows/autoruns/Set-AutorunEntry.ps1) |  | PowerShell script to manage Windows startup entries using Sysinternals Autoruns |

## `scripts/windows/availability/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-ComputerOnlineStatus_v1.ps1](scripts/windows/availability/Get-ComputerOnlineStatus_v1.ps1) |  | _(aus Kommentar)_ # This is also functioning for powershell 5 where "foreach-object -parallel" is missing |
| [Get-ComputerOnlineStatus_v2.ps1](scripts/windows/availability/Get-ComputerOnlineStatus_v2.ps1) |  | Prüft den Online-Status von Computern aus Active Directory und listet deren IP-Adressen auf. |

## `scripts/windows/cleanup/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Clear-OldTempFiles_v1.ps1](scripts/windows/cleanup/Clear-OldTempFiles_v1.ps1) | `def` | Gibt eine Liste bereinigungswürdiger Verzeichnispfade zurück. Bezieht sowohl systemweite als auch benutzerspezifische Pfade ein. |
| [Clear-OldTempFiles_v2.ps1](scripts/windows/cleanup/Clear-OldTempFiles_v2.ps1) |  | Erweiterte Windows-Bereinigung für temporäre Dateien und Cache-Verzeichnisse |
| [Clear-OldTempFiles_v3.ps1](scripts/windows/cleanup/Clear-OldTempFiles_v3.ps1) |  | Erweiterte Windows-Bereinigung für temporäre Dateien und Cache-Verzeichnisse |
| [Clear-OldTempFiles_v4.ps1](scripts/windows/cleanup/Clear-OldTempFiles_v4.ps1) |  | Ultimate Windows Cleanup Tool v4.0 (Fixed) - Stabile Version |
| [Remove-OldUserProfile.ps1](scripts/windows/cleanup/Remove-OldUserProfile.ps1) |  | Findet verwaiste und alte Windows-Benutzerprofile und loescht sie. |

## `scripts/windows/desktop/window-cascade/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Set-CascadedWindow_v1.ps1](scripts/windows/desktop/window-cascade/Set-CascadedWindow_v1.ps1) |  | Skript zur Wiederherstellung der "Fenster überlappend anzeigen"-Funktion unter Windows 11. |
| [Set-CascadedWindow_v2.ps1](scripts/windows/desktop/window-cascade/Set-CascadedWindow_v2.ps1) |  | Skript zur Wiederherstellung der "Fenster überlappend anzeigen"-Funktion unter Windows 11. |

## `scripts/windows/elevation/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Invoke-RunAsElevated_old.ps1](scripts/windows/elevation/Invoke-RunAsElevated_old.ps1) | `def` | Elevate a PowerShell script to run with administrative privileges using a batch file. |
| [Invoke-RunAsElevated.ps1](scripts/windows/elevation/Invoke-RunAsElevated.ps1) | `def` | _(aus Kommentar)_ What does this function do? |

## `scripts/windows/eventlog/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Clear-EventLog.ps1](scripts/windows/eventlog/Clear-EventLog.ps1) |  | _(aus Kommentar)_ https://learn.microsoft.com/th-th/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-5.1 |
| [New-EventLogSource.ps1](scripts/windows/eventlog/New-EventLogSource.ps1) |  | Erstellt die Event Log-Quelle für ProcessMonitorService |
| [New-EventLogSourceSimple.ps1](scripts/windows/eventlog/New-EventLogSourceSimple.ps1) |  | _(aus Kommentar)_ Einfaches PowerShell Script zum Erstellen der Event Log-Quelle |

## `scripts/windows/inventory/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-ClientMonitorEDIDData.ps1](scripts/windows/inventory/Get-ClientMonitorEDIDData.ps1) | `def` | _(aus Kommentar)_ Get-ClientMonitorEDIDData -Computer "MYHOSTNAME" |
| [Get-DiskInformation.ps1](scripts/windows/inventory/Get-DiskInformation.ps1) | `def` | _(aus Kommentar)_ robust: Strings/UInt* -> int cast |
| [Get-InstalledSoftware.ps1](scripts/windows/inventory/Get-InstalledSoftware.ps1) |  | Liest installierte Software (Registry-basiert, ohne Win32_Product) |
| [New-ComputerNameByMacAddress.ps1](scripts/windows/inventory/New-ComputerNameByMacAddress.ps1) |  | Ermittelt AABBCC aus PermanentAddress (alle Trennzeichen entfernt). Suffix "-M" wenn ein WLAN-Adapter gefunden wird, sonst "-D". Setzt MYCOMPUTERNAME in aktueller Session und, falls Adminrechte vorhanden, systemweit. |

## `scripts/windows/processes/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-DomainWideProcessCpuUsage.ps1](scripts/windows/processes/Get-DomainWideProcessCpuUsage.ps1) |  | _(aus Kommentar)_ This script queries remotely the top X process and collect these. |
| [Remove-StuckProcess.ps1](scripts/windows/processes/Remove-StuckProcess.ps1) |  | _(aus Kommentar)_ Define the process name and the time interval (in seconds) |
| [Set-ProcessPriority.ps1](scripts/windows/processes/Set-ProcessPriority.ps1) |  | Setzt Prozesspriorität per Name oder PID Um es zu kompilieren, nutze PS2EXE: Install-Module PS2EXE -Scope CurrentUser Invoke-PS2EXE -inputFile "G:\AVERP\Set-ProcPriority.ps1" -outputFile "G:\AVERP\Set-ProcPriority.exe" -noConsole \\myserver\myshare\Set-ProcPriority.exe -Name MYPROCESS -Priority AboveNormal |
| [Trace-ProcessStartStop.ps1](scripts/windows/processes/Trace-ProcessStartStop.ps1) |  | Protokolliert laufend jeden Prozessstart und jedes Prozessende des lokalen Rechners nach JSON. |

## `scripts/windows/registry/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-RemoteRegistryValue.ps1](scripts/windows/registry/Get-RemoteRegistryValue.ps1) |  | _(aus Kommentar)_ Get the remote registry Value of online computers, |
| [Test-RemoteRegistry.ps1](scripts/windows/registry/Test-RemoteRegistry.ps1) |  | _(aus Kommentar)_ Test Netzwerkverbindung |

## `scripts/windows/scheduled-tasks/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Export-ScheduledTask.ps1](scripts/windows/scheduled-tasks/Export-ScheduledTask.ps1) | `def` | _keine Beschreibung_ |
| [Get-AllScheduledTasks.ps1](scripts/windows/scheduled-tasks/Get-AllScheduledTasks.ps1) |  | _(aus Kommentar)_ Set to $false, if there is something being automated... |

## `scripts/windows/services/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-TasksAndServices.ps1](scripts/windows/services/Get-TasksAndServices.ps1) |  | _(aus Kommentar)_ make sure, that you have sufficient rights on the target machine |
| [Set-ServiceStartupType.ps1](scripts/windows/services/Set-ServiceStartupType.ps1) | `def` | _(aus Kommentar)_ Mapping of abbreviations to full names |
| [Test-ServiceOnMultipleClients.ps1](scripts/windows/services/Test-ServiceOnMultipleClients.ps1) |  | _(aus Kommentar)_ Annahme: $Computer ist eine Liste/Array von Computernamen |

## `scripts/windows/sessions/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-LastInteractiveUserLogons.ps1](scripts/windows/sessions/Get-LastInteractiveUserLogons.ps1) | `def` | _keine Beschreibung_ |
| [Get-LoggedInUsersCim.ps1](scripts/windows/sessions/Get-LoggedInUsersCim.ps1) | `def` | _(aus Kommentar)_ Bug in Powershell for Version 7 (checked on Version 7.4.4) : https://github.com/PowerShell/PowerShell/issues/20829 |
| [Get-LoggedInUsersInvokeCommand.ps1](scripts/windows/sessions/Get-LoggedInUsersInvokeCommand.ps1) |  | _(aus Kommentar)_ Bug in Powershell for Version 7 (checked on Version 7.4.4) : https://github.com/PowerShell/PowerShell/issues/20829 |
| [Get-UserIdleTime.ps1](scripts/windows/sessions/Get-UserIdleTime.ps1) |  | _keine Beschreibung_ |
| [Get-WorkstationUnlockEvents.ps1](scripts/windows/sessions/Get-WorkstationUnlockEvents.ps1) |  | _(aus Kommentar)_ Beispielaufruf |
| [Test-IdleSession.ps1](scripts/windows/sessions/Test-IdleSession.ps1) |  | _(aus Kommentar)_ I have added this script to reddit on 20240803 |
| [UserSessionFunctions.ps1](scripts/windows/sessions/UserSessionFunctions.ps1) |  | _(aus Kommentar)_ This Script is able to get remote user sessions information and is able to log off the (discconnected \| connected) remote user sessions |

## `scripts/windows/shadow-copy/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Enable-ShadowCopy.ps1](scripts/windows/shadow-copy/Enable-ShadowCopy.ps1) |  | _(aus Kommentar)_ $volume = Get-CimInstance -Query "SELECT * FROM Win32_Volume WHERE DriveLetter = 'C:' AND FileSystem = 'NTFS'" |
| [Get-ShadowStorage.ps1](scripts/windows/shadow-copy/Get-ShadowStorage.ps1) |  | _(aus Kommentar)_ $shadowStorage = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ShadowStorage |
| [New-ScheduledTaskFromXml.ps1](scripts/windows/shadow-copy/New-ScheduledTaskFromXml.ps1) |  | _(aus Kommentar)_ vssadmin list shadowstorage |
| [New-SpontaneousShadowCopy.ps1](scripts/windows/shadow-copy/New-SpontaneousShadowCopy.ps1) | `def` | _(aus Kommentar)_ Beispielaufruf: |

## `scripts/windows/telemetry/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Disable-Telemetry.ps1](scripts/windows/telemetry/Disable-Telemetry.ps1) |  | Deaktiviert systemweit Windows- und Office-Telemetrie |

## `scripts/windows/updates/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-InstalledUpdatesFromEventLog.ps1](scripts/windows/updates/Get-InstalledUpdatesFromEventLog.ps1) |  | _(aus Kommentar)_ Execute the function |

## `scripts/windows/wmi/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-WmiBriefOptimized.ps1](scripts/windows/wmi/Get-WmiBriefOptimized.ps1) |  | Ruft WMI/CIM-Klasseninformationen effizient ab und stellt eine vereinfachte Schnittstelle bereit. |
| [Repair-WmiRepository.ps1](scripts/windows/wmi/Repair-WmiRepository.ps1) |  | Repariert beschädigte Windows Management Instrumentation (WMI) Repositories und Services. |
| [Set-WbemTracing.ps1](scripts/windows/wmi/Set-WbemTracing.ps1) | `def` | Liest oder ändert WBEM/WMI Tracing-Einstellungen unter HKLM:\SOFTWARE\Microsoft\WBEM\CIMOM. |

## `snippets/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [New-PSCustomObjectWithIndexColumn.ps1](snippets/New-PSCustomObjectWithIndexColumn.ps1) | `def` | _(aus Kommentar)_ DO NOT USE THIS FUNCTION, IF YOU DON'T WANT YOUR SOURCE PSCUSUTOMOBJECT!!! |
| [ScriptBlockParameters.ps1](snippets/ScriptBlockParameters.ps1) |  | _(aus Kommentar)_ Source: https://stackoverflow.com/questions/16347214/pass-arguments-to-a-scriptblock-in-powershell |

## `snippets/graph-traversal/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Invoke-BreadthFirstSearch.ps1](snippets/graph-traversal/Invoke-BreadthFirstSearch.ps1) | `def` | _(aus Kommentar)_ mit Richtung. Demo |
| [Invoke-GraphTraversal.ps1](snippets/graph-traversal/Invoke-GraphTraversal.ps1) | `def` | Funktionen zur Wegsuche in einem als JSON beschriebenen gerichteten Graphen. |

## `tools/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Build-ScriptIndex.ps1](tools/Build-ScriptIndex.ps1) |  | Erzeugt INDEX.md - eine durchsuchbare Uebersicht aller Skripte im Repo. |
| [Find-ScriptDependency.ps1](tools/Find-ScriptDependency.ps1) |  | Findet Funktionsaufrufe, die ueber Dateigrenzen hinweg gehen. |
| [Repair-ScriptEncoding.ps1](tools/Repair-ScriptEncoding.ps1) |  | Ergaenzt fehlende UTF-8-BOMs in Skripten, die Nicht-ASCII-Zeichen enthalten. |

