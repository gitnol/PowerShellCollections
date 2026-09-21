# Skript-Index

<!-- Automatisch erzeugt von tools/Build-ScriptIndex.ps1 - nicht von Hand bearbeiten. -->

144 Skripte. 144 mit `.SYNOPSIS` (100%), 0 weitere mit einer Kurzbeschreibung aus dem ersten Kommentar.

| Markierung | Bedeutung |
| ---------- | --------- |
| _(aus Kommentar)_ | keine `.SYNOPSIS` - Text stammt aus der ersten Kommentarzeile und ist ein Hinweis, keine Beschreibung |
| `def` | enthaelt ausser Funktionsdefinitionen keinen ausfuehrbaren Code, laesst sich also gefahrlos per Dot-Sourcing laden |
| **Syntaxfehler** | die Datei parst nicht |

Davon 33 nebenwirkungsfrei, 0 mit Syntaxfehlern.

## `modules/PSCollections.Connectivity/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [PSCollections.Connectivity.psm1](modules/PSCollections.Connectivity/PSCollections.Connectivity.psm1) | `def` | Prueft die Erreichbarkeit vieler Rechner parallel. |

## `scripts/active-directory/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Protect-OUs.ps1](scripts/active-directory/Protect-OUs.ps1) |  | Aktiviert den Schutz vor versehentlichem Löschen für alle OUs in der Domäne. |
| [Test-DomainCredentials.ps1](scripts/active-directory/Test-DomainCredentials.ps1) | `def` | Prueft, ob Benutzername und Passwort gegen eine Domaene gueltig sind. |

## `scripts/active-directory/dns/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Find-DNSDuplicates.ps1](scripts/active-directory/dns/Find-DNSDuplicates.ps1) |  | Findet und entfernt doppelte DNS-A-Einträge zonenübergreifend. |

## `scripts/active-directory/gpo/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-GPOLinks.ps1](scripts/active-directory/gpo/Get-GPOLinks.ps1) | `def` | Listet alle GPOs mit ihren Verknuepfungen auf und findet unverknuepfte. |
| [Get-GPOReportSettings.ps1](scripts/active-directory/gpo/Get-GPOReportSettings.ps1) |  | Liest saemtliche Einstellungen aus einem GPO-Report aus. |
| [Get-GPPItemLevelTargeting.ps1](scripts/active-directory/gpo/Get-GPPItemLevelTargeting.ps1) |  | Listet die zielgruppenbasierte Zuordnung (Item-Level Targeting) aller Gruppenrichtlinien-Einstellungen auf. |
| [New-GPOAnalysis.ps1](scripts/active-directory/gpo/New-GPOAnalysis.ps1) |  | Vergleicht bei allen GPOs den konfigurierten Status mit den tatsaechlich vorhandenen Einstellungen. |

## `scripts/active-directory/group-membership/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Compare-ADGroupSidResolution.ps1](scripts/active-directory/group-membership/Compare-ADGroupSidResolution.ps1) |  | Stellt die rekursive SID-Aufloesung von Gruppenmitgliedschaften der Ausgabe von Get-ADPrincipalGroupMembership gegenueber. |
| [Compare-ADUserGroup.ps1](scripts/active-directory/group-membership/Compare-ADUserGroup.ps1) |  | Vergleicht die Gruppenmitgliedschaften zweier AD-Benutzer. |
| [Copy-ADGroupMember.ps1](scripts/active-directory/group-membership/Copy-ADGroupMember.ps1) | `def` | Kopiert alle Mitglieder einer AD-Gruppe in eine andere. |
| [New-ADGroupInOU.ps1](scripts/active-directory/group-membership/New-ADGroupInOU.ps1) |  | Legt eine AD-Sicherheitsgruppe in einer OU an und richtet passende Ordnerberechtigungen ein. |
| [Resolve-ADGroupRecursive.ps1](scripts/active-directory/group-membership/Resolve-ADGroupRecursive.ps1) |  | Loest AD-Gruppen rekursiv auf und listet je Gruppe alle wirksamen Mitglieder. |

## `scripts/active-directory/group-membership/temporary/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Show-TemporaryGroupMembershipGui.ps1](scripts/active-directory/group-membership/temporary/Show-TemporaryGroupMembershipGui.ps1) |  | Bietet eine grafische Benutzeroberfläche (GUI) zur Verwaltung von temporären Active Directory-Gruppenmitgliedschaften mithilfe des PAM-Features. |
| [Sync-TemporaryGroupMembershipFromCsv.ps1](scripts/active-directory/group-membership/temporary/Sync-TemporaryGroupMembershipFromCsv.ps1) |  | Automatisiert temporäre und permanente Active Directory-Gruppenmitgliedschaften basierend auf CSV-Dateien. |

## `scripts/active-directory/inventory/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-ADComputerInventory.ps1](scripts/active-directory/inventory/Get-ADComputerInventory.ps1) |  | Inventarisiert AD-Computer parallel und aktualisiert Benutzer-, Hardware- und Kommentar-Informationen im Description-Feld. |
| [Get-ADComputerLastLogon.ps1](scripts/active-directory/inventory/Get-ADComputerLastLogon.ps1) |  | Ermittelt je AD-Computer die letzte Anmeldung ueber alle Domain Controller hinweg. |
| [Get-ADEnabledUserWithManager.ps1](scripts/active-directory/inventory/Get-ADEnabledUserWithManager.ps1) |  | Listet alle aktiven AD-Benutzer mit ihrem hinterlegten Vorgesetzten auf. |
| [Get-ADInactiveGroupMember.ps1](scripts/active-directory/inventory/Get-ADInactiveGroupMember.ps1) |  | Findet Mitglieder einer Gruppe, die sich seit laengerem nicht angemeldet haben - etwa zur Rueckgewinnung von Microsoft-365-Lizenzen. |
| [Get-ADUserLastLogonCache.ps1](scripts/active-directory/inventory/Get-ADUserLastLogonCache.ps1) |  | Baut eine Nachschlagetabelle SamAccountName -> letzte Anmeldung ueber alle Domain Controller. |

## `scripts/active-directory/ldap/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Connect-LdapServer.ps1](scripts/active-directory/ldap/Connect-LdapServer.ps1) |  | Baut eine LDAP-Verbindung auf und fuehrt eine Suche aus - ohne das ActiveDirectory-Modul. |
| [Test-LdapPorts.ps1](scripts/active-directory/ldap/Test-LdapPorts.ps1) |  | Prueft, ob LDAP (389) und LDAPS (636) auf einem Ziel erreichbar sind, und testet zusaetzlich einen echten LDAPS-Bind. |

## `scripts/active-directory/logon-events/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-ADAuthEventsAllDCs.ps1](scripts/active-directory/logon-events/Get-ADAuthEventsAllDCs.ps1) | `def` | Sammelt Anmelde-Events (fehlgeschlagen, Lockout, erfolgreich) von allen Domain Controllern inkl. Quell-IP. |
| [Get-LockedOutEventsAllDCs.ps1](scripts/active-directory/logon-events/Get-LockedOutEventsAllDCs.ps1) | `def` | Sammelt Account-Lockout-Events von allen Domain Controllern in der Domäne. |
| [Get-LogonAttempts.ps1](scripts/active-directory/logon-events/Get-LogonAttempts.ps1) |  | Sammelt fehlgeschlagene Anmeldeversuche aus den Sicherheitsprotokollen mehrerer Rechner. |
| [Get-UserLogonEvent.ps1](scripts/active-directory/logon-events/Get-UserLogonEvent.ps1) |  | Holt Anmelde-Events bestimmter Event-IDs oder Benutzer von allen Domain Controllern. |

## `scripts/active-directory/machine-sid/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-DuplicateMachineSIDs.ps1](scripts/active-directory/machine-sid/Get-DuplicateMachineSIDs.ps1) |  | Findet Rechner in der Domaene, die sich dieselbe Maschinen-SID teilen. |
| [Invoke-MachineSidCheck.ps1](scripts/active-directory/machine-sid/Invoke-MachineSidCheck.ps1) |  | Prüft den Online-Status von AD-Computern und führt optional einen Neustart oder eine SID-Prüfung durch. |

## `scripts/active-directory/time-sync/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Set-PdcTimeSync.ps1](scripts/active-directory/time-sync/Set-PdcTimeSync.ps1) |  | Konfiguriert die Zeitsynchronisierung für den PDC-Emulationsmaster korrekt. Besser ist es jedoch, wenn eine GPO für die Zeitsynchronisierung verwendet wird. |

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
| [ConvertFrom-ExcelClipboard.ps1](scripts/applications/excel/ConvertFrom-ExcelClipboard.ps1) |  | Wandelt aus Excel kopierte Zellen in PowerShell-Objekte um. |
| [Remove-ExcelSheetProtection.ps1](scripts/applications/excel/Remove-ExcelSheetProtection.ps1) |  | Entfernt den Blattschutz (Worksheet Protection) aus einer oder mehreren Tabellen einer .xlsx-Datei durch direkte XML-Manipulation. |

## `scripts/applications/filezilla/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [ConvertFrom-FileZillaLog.ps1](scripts/applications/filezilla/ConvertFrom-FileZillaLog.ps1) | `def` | Zerlegt ein FileZilla-Server-Logfile in auswertbare Objekte. |
| [Get-FtpLoginSummary.ps1](scripts/applications/filezilla/Get-FtpLoginSummary.ps1) |  | Analysiert FileZilla Server Logs und gibt eine Zusammenfassung der erfolgreichen und fehlgeschlagenen FTP-Logins aus. |

## `scripts/applications/kyocera/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-PrinterSnmpOid.ps1](scripts/applications/kyocera/Get-PrinterSnmpOid.ps1) |  | Fragt einen einzelnen SNMP-Wert von einem Netzwerkdrucker ab. |

## `scripts/applications/openscape-business/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [OSBiz.psm1](scripts/applications/openscape-business/OSBiz.psm1) | `def` | Meldet sich an der OSBiz API an und gibt die Session-ID zurück. |

## `scripts/applications/teams/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Clear-TeamsCache.ps1](scripts/applications/teams/Clear-TeamsCache.ps1) |  | Beendet Microsoft Teams und leert die Cache-Verzeichnisse - klassisch und neu. |

## `scripts/applications/teamviewer/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [ConvertFrom-TeamViewerLog.ps1](scripts/applications/teamviewer/ConvertFrom-TeamViewerLog.ps1) |  | Wertet TeamViewer-Logdateien forensisch aus - wer war wann mit wem verbunden. |
| [Set-TeamViewerAccess.ps1](scripts/applications/teamviewer/Set-TeamViewerAccess.ps1) |  | Setzt die TeamViewer-Zugriffssteuerung auf mehreren Rechnern gleichzeitig. |
| [Start-TeamViewer.ps1](scripts/applications/teamviewer/Start-TeamViewer.ps1) |  | Startet TeamViewer mit verschiedenen Konfigurationsoptionen und Verbindungsparametern. |

## `scripts/applications/zammad/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-ZammadTicket.ps1](scripts/applications/zammad/Get-ZammadTicket.ps1) | `def` | Holt zu einer Liste von Ticket-IDs die vollstaendigen Zammad-Ticketdaten samt Artikeln. |
| [ZammadApiFunctions.ps1](scripts/applications/zammad/ZammadApiFunctions.ps1) | `def` | Funktionsbibliothek fuer die Zammad-REST-API. |

## `scripts/databases/mssql/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-SqlServerVersion.ps1](scripts/databases/mssql/Get-SqlServerVersion.ps1) | `def` | Ermittelt die Versionen von SQL Server Instanzen auf remote Servern. |
| [Test-DbConnection.ps1](scripts/databases/mssql/Test-DbConnection.ps1) |  | Prüft eine OLE DB Datenbankverbindung mit interaktiver Passwortabfrage. |

## `scripts/filesystem/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Compress-FilesByMonth.ps1](scripts/filesystem/Compress-FilesByMonth.ps1) |  | Packt Dateien nach Entstehungsmonat in je ein ZIP-Archiv. |
| [Get-DllVersion.ps1](scripts/filesystem/Get-DllVersion.ps1) | `def` | Liest die Dateiversion einer DLL oder EXE aus. |
| [Resolve-Links.ps1](scripts/filesystem/Resolve-Links.ps1) |  | Findet Symlinks, Junctions und Hardlinks in einem Verzeichnisbaum und loest ihre Ziele auf. |

## `scripts/filesystem/permissions/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-FileserverUserPermission.ps1](scripts/filesystem/permissions/Get-FileserverUserPermission.ps1) |  | Findet auf einem Dateiserver Ordner, auf denen einzelne Benutzer statt Gruppen berechtigt sind. |
| [Get-FolderPermissions.ps1](scripts/filesystem/permissions/Get-FolderPermissions.ps1) | `def` | Listet rekursiv die Ordner auf, die nicht vererbte Einzelberechtigungen tragen. |

## `scripts/filesystem/search/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Find-FilesInZips.ps1](scripts/filesystem/search/Find-FilesInZips.ps1) | `def` | Durchsucht ZIP-Archive nach Dateien basierend auf einem Suchmuster. |
| [Get-TextMatchInFiles.ps1](scripts/filesystem/search/Get-TextMatchInFiles.ps1) | `def` | Durchsucht Dateien nach Zeilen, in denen mehrere Begriffe gleichzeitig vorkommen. |

## `scripts/messaging/exchange/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-MailboxForwardingRules.ps1](scripts/messaging/exchange/Get-MailboxForwardingRules.ps1) |  | Findet Postfaecher mit eingerichteter Weiterleitung nach aussen. |
| [New-SharedMailboxWorkflow.ps1](scripts/messaging/exchange/New-SharedMailboxWorkflow.ps1) |  | Erstellt standardisierte Shared Mailboxes und die dazugehörigen AD-Sicherheitsgruppen für Berechtigungen. |
| [Sync-SharedMailboxPermission.ps1](scripts/messaging/exchange/Sync-SharedMailboxPermission.ps1) |  | Verwaltet vollautomatisch 'FullAccess'-Berechtigungen für Exchange 2019 SharedMailboxes basierend auf Active Directory Gruppenmitgliedschaften. |

## `scripts/messaging/mailstore/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Invoke-MailStoreApiScratch.ps1](scripts/messaging/mailstore/Invoke-MailStoreApiScratch.ps1) | `def` | Arbeitskopie generierter MailStore-API-Funktionen - nicht der gepflegte Stand. |
| [MailStoreApiFunctions.ps1](scripts/messaging/mailstore/MailStoreApiFunctions.ps1) | `def` | PowerShell-Huelle um die Administrations-API des MailStore Server. |
| [MailStoreSnippets.ps1](scripts/messaging/mailstore/MailStoreSnippets.ps1) |  | Aeltere Sammlung von MailStore-API-Funktionen samt Anwendungsbeispielen (Stand v2). |
| [New-MailStoreApiFunctionReference.ps1](scripts/messaging/mailstore/New-MailStoreApiFunctionReference.ps1) |  | Erzeugt aus der Online-Funktionsreferenz von MailStore PowerShell-Huellen fuer jede API-Methode. |

## `scripts/messaging/nospamproxy/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-NspUserToDomainCommunication.ps1](scripts/messaging/nospamproxy/Get-NspUserToDomainCommunication.ps1) |  | Wertet aus NoSpamProxy aus, welche Benutzer mit welchen externen Domaenen E-Mails austauschen. |

## `scripts/messaging/outlook/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Invoke-OutlookAddinMaintenance.ps1](scripts/messaging/outlook/Invoke-OutlookAddinMaintenance.ps1) |  | Verwaltet Outlook Add-ins (Status prüfen, Listen, Reparieren). |

## `scripts/monitoring/ping-monitor/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Start-Win10PingMonitor.ps1](scripts/monitoring/ping-monitor/Start-Win10PingMonitor.ps1) |  | Startskript fuer die Ping-Ueberwachung von Windows-10-Rechnern mit E-Mail-Benachrichtigung. |
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
| [Get-ArubaMacTable.ps1](scripts/network/aruba/Get-ArubaMacTable.ps1) |  | Liest die MAC-Adresstabelle von Aruba-Switches aus und loest die Hersteller auf. |

## `scripts/network/dhcp/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-DhcpServerLease.ps1](scripts/network/dhcp/Get-DhcpServerLease.ps1) |  | Sammelt die DHCP-Leases aller autorisierten DHCP-Server der Domaene. |

## `scripts/network/diagnostics/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-WebHeaders.ps1](scripts/network/diagnostics/Get-WebHeaders.ps1) |  | Liest HTTP Response-Header und Statuscode aus. |
| [Show-NetConnections.ps1](scripts/network/diagnostics/Show-NetConnections.ps1) |  | Zeigt aktive TCP/UDP-Verbindungen inkl. Prozessinformationen, ähnlich netstat -anob. |
| [Test-Port.ps1](scripts/network/diagnostics/Test-Port.ps1) |  | Prueft einen TCP-Port mit einstellbarem Zeitlimit. |

## `scripts/network/firewall/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Remove-DuplicateFirewallRule.ps1](scripts/network/firewall/Remove-DuplicateFirewallRule.ps1) |  | Entfernt doppelte Windows-Firewall-Regeln. |

## `scripts/network/lancom/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [New-PublicSpotUser.ps1](scripts/network/lancom/New-PublicSpotUser.ps1) |  | Registers a new Public Spot user via a REST API call to a specified server. |
| [New-PublicSpotUserBulk.ps1](scripts/network/lancom/New-PublicSpotUserBulk.ps1) |  | Erstellt Public Spot Benutzer für LANCOM WLC/Router in Massenverarbeitung basierend auf einer CSV-Datei. |

## `scripts/network/wake-on-lan/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Send-WakeOnLan.ps1](scripts/network/wake-on-lan/Send-WakeOnLan.ps1) | `def` | Sendet ein Wake-on-LAN Magic Packet an eine MAC-Adresse. |
| [Set-WakeOnLanAdapterOption.ps1](scripts/network/wake-on-lan/Set-WakeOnLanAdapterOption.ps1) |  | Richtet die Netzwerkkarte fuer Wake-on-LAN ein. |

## `scripts/security/bitlocker/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-BitLockerStatus.ps1](scripts/security/bitlocker/Get-BitLockerStatus.ps1) |  | Gleicht BitLocker-Recovery-Informationen aus dem Active Directory mit den lokalen Systemen massiv parallel ab. |

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
| [Find-Log4jFile.ps1](scripts/security/log4j/Find-Log4jFile.ps1) |  | Durchsucht Datentraeger nach log4j-Bibliotheken mit der JndiLookup-Klasse - auch in verschachtelten Archiven. |

## `scripts/security/passwords/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Test-ADUserWeakPassword.ps1](scripts/security/passwords/Test-ADUserWeakPassword.ps1) |  | Prueft Mitglieder bestimmter AD-Gruppen auf schwache Passwoerter. |

## `scripts/security/secure-boot/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Invoke-SecureBootCertUpdate_simple.ps1](scripts/security/secure-boot/Invoke-SecureBootCertUpdate_simple.ps1) |  | Einmaliges Einleiten des Secure Boot 2023-Zertifikat-Updates (einfache Variante). |
| [Invoke-SecureBootCertUpdate.ps1](scripts/security/secure-boot/Invoke-SecureBootCertUpdate.ps1) |  | Secure Boot UEFI CA 2023 - Update Manager |
| [Test-LocalSecureBootVariable.ps1](scripts/security/secure-boot/Test-LocalSecureBootVariable.ps1) |  | Prüft lokal Secure Boot PK, db und KEK inkl. Handlungsempfehlung. > |
| [Test-MultipleHostsSecureBoot.ps1](scripts/security/secure-boot/Test-MultipleHostsSecureBoot.ps1) |  | Prueft auf vielen Rechnern parallel den Secure-Boot-Status und das Zertifikat 'Windows UEFI CA 2023'. |
| [Test-SecureBootCert2023.ps1](scripts/security/secure-boot/Test-SecureBootCert2023.ps1) |  | Prüft den Secure Boot Status und das Vorhandensein des Windows UEFI CA 2023 Zertifikats. |

## `scripts/virtualization/vmware/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-VMSnapshots.ps1](scripts/virtualization/vmware/Get-VMSnapshots.ps1) | `def` | Findet virtuelle Maschinen mit vorhandenen Snapshots. |
| [Get-VMUptimes.ps1](scripts/virtualization/vmware/Get-VMUptimes.ps1) |  | Ermittelt die Laufzeit seit dem letzten Neustart aller eingeschalteten VMs. |
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
| [Get-ComputerOnlineStatus.ps1](scripts/windows/availability/Get-ComputerOnlineStatus.ps1) |  | Prüft den Online-Status von Computern aus Active Directory und listet deren IP-Adressen auf. |

## `scripts/windows/cleanup/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Clear-OldTempFiles.ps1](scripts/windows/cleanup/Clear-OldTempFiles.ps1) |  | Ultimate Windows Cleanup Tool v4.0 (Fixed) - Stabile Version |
| [Remove-OldUserProfile.ps1](scripts/windows/cleanup/Remove-OldUserProfile.ps1) |  | Findet verwaiste und alte Windows-Benutzerprofile und loescht sie. |

## `scripts/windows/desktop/window-cascade/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Set-CascadedWindow.ps1](scripts/windows/desktop/window-cascade/Set-CascadedWindow.ps1) |  | Skript zur Wiederherstellung der "Fenster überlappend anzeigen"-Funktion unter Windows 11. |

## `scripts/windows/elevation/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Invoke-RunAsElevated.ps1](scripts/windows/elevation/Invoke-RunAsElevated.ps1) | `def` | Startet eine neue PowerShell-Sitzung unter einem anderen Konto mit erhoehten Rechten. |

## `scripts/windows/eventlog/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Clear-EventLog.ps1](scripts/windows/eventlog/Clear-EventLog.ps1) |  | Leert saemtliche Windows-Ereignisprotokolle des lokalen Rechners. |
| [New-EventLogSource.ps1](scripts/windows/eventlog/New-EventLogSource.ps1) |  | Erstellt die Event Log-Quelle für ProcessMonitorService |
| [New-EventLogSourceSimple.ps1](scripts/windows/eventlog/New-EventLogSourceSimple.ps1) |  | Legt die Eventlog-Quelle 'ProcessMonitorService' im Anwendungsprotokoll an - schlanke Variante. |

## `scripts/windows/inventory/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-ClientMonitorEDIDData.ps1](scripts/windows/inventory/Get-ClientMonitorEDIDData.ps1) | `def` | Liest Hersteller, Modell, Seriennummer und Anschlussart der an einem Rechner angeschlossenen Monitore aus. |
| [Get-DiskInformation.ps1](scripts/windows/inventory/Get-DiskInformation.ps1) | `def` | Ermittelt zu jedem physischen Datentraeger eines Rechners Bustyp, Medientyp und Groesse. |
| [Get-InstalledSoftware.ps1](scripts/windows/inventory/Get-InstalledSoftware.ps1) |  | Liest installierte Software (Registry-basiert, ohne Win32_Product) |
| [New-ComputerNameByMacAddress.ps1](scripts/windows/inventory/New-ComputerNameByMacAddress.ps1) |  | Ermittelt AABBCC aus PermanentAddress (alle Trennzeichen entfernt). Suffix "-M" wenn ein WLAN-Adapter gefunden wird, sonst "-D". Setzt MYCOMPUTERNAME in aktueller Session und, falls Adminrechte vorhanden, systemweit. |

## `scripts/windows/processes/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-DomainWideProcessCpuUsage.ps1](scripts/windows/processes/Get-DomainWideProcessCpuUsage.ps1) |  | Sammelt von allen Domaenenrechnern die Prozesse mit der hoechsten CPU-Last. |
| [Remove-StuckProcess.ps1](scripts/windows/processes/Remove-StuckProcess.ps1) |  | Beobachtet einen Prozess und beendet ihn, wenn er sich nicht mehr regt. |
| [Set-ProcessPriority.ps1](scripts/windows/processes/Set-ProcessPriority.ps1) |  | Setzt Prozesspriorität per Name oder PID Um es zu kompilieren, nutze PS2EXE: Install-Module PS2EXE -Scope CurrentUser Invoke-PS2EXE -inputFile "G:\AVERP\Set-ProcPriority.ps1" -outputFile "G:\AVERP\Set-ProcPriority.exe" -noConsole \\myserver\myshare\Set-ProcPriority.exe -Name MYPROCESS -Priority AboveNormal |
| [Trace-ProcessStartStop.ps1](scripts/windows/processes/Trace-ProcessStartStop.ps1) |  | Protokolliert laufend jeden Prozessstart und jedes Prozessende des lokalen Rechners nach JSON. |

## `scripts/windows/registry/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-RemoteRegistryValue.ps1](scripts/windows/registry/Get-RemoteRegistryValue.ps1) |  | Liest einen Registry-Wert von allen Domaenenrechnern aus, die sich zuletzt angemeldet haben. |
| [Test-RemoteRegistry.ps1](scripts/windows/registry/Test-RemoteRegistry.ps1) |  | Prueft, ob der Remote-Registry-Zugriff auf einen Rechner ueberhaupt moeglich ist, und richtet ihn auf Wunsch ein. |

## `scripts/windows/scheduled-tasks/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Export-ScheduledTask.ps1](scripts/windows/scheduled-tasks/Export-ScheduledTask.ps1) | `def` | Exportiert alle geplanten Aufgaben eines Rechners als XML-Dateien. |
| [Get-AllScheduledTasks.ps1](scripts/windows/scheduled-tasks/Get-AllScheduledTasks.ps1) |  | Listet alle geplanten Aufgaben eines Rechners auf, wahlweise als Gitteransicht, JSON-Datei oder Pipeline-Ausgabe. |

## `scripts/windows/services/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-TasksAndServices.ps1](scripts/windows/services/Get-TasksAndServices.ps1) |  | Sammelt von allen Domaenenrechnern die geplanten Aufgaben und Dienste, die unter einem Domaenenkonto laufen. |
| [Set-ServiceStartupType.ps1](scripts/windows/services/Set-ServiceStartupType.ps1) | `def` | Setzt den Starttyp eines Dienstes, inklusive 'Automatisch (verzoegert)'. |
| [Test-ServiceOnMultipleClients.ps1](scripts/windows/services/Test-ServiceOnMultipleClients.ps1) |  | Prueft auf mehreren Rechnern, ob mindestens einer aus einer Liste von Diensten laeuft. |

## `scripts/windows/sessions/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-LastInteractiveUserLogons.ps1](scripts/windows/sessions/Get-LastInteractiveUserLogons.ps1) | `def` | Findet die letzten interaktiven Anmeldungen und RDP-Sitzungen der letzten 90 Tage. |
| [Get-LoggedInUsersCim.ps1](scripts/windows/sessions/Get-LoggedInUsersCim.ps1) | `def` | Ermittelt die angemeldeten Benutzer mehrerer Rechner ueber CIM-Sessions und unterscheidet Konsole von RDP. |
| [Get-LoggedInUsersInvokeCommand.ps1](scripts/windows/sessions/Get-LoggedInUsersInvokeCommand.ps1) |  | Ermittelt die angemeldeten Benutzer mehrerer Rechner per Invoke-Command und unterscheidet Konsole von RDP. |
| [Get-UserIdleTime.ps1](scripts/windows/sessions/Get-UserIdleTime.ps1) |  | Ermittelt, wie lange der angemeldete Benutzer keine Eingabe mehr gemacht hat. |
| [Get-WorkstationUnlockEvents.ps1](scripts/windows/sessions/Get-WorkstationUnlockEvents.ps1) |  | Sammelt Sperr- und Entsperrvorgaenge von Arbeitsplaetzen aus dem Sicherheitsprotokoll. |
| [Test-IdleSession.ps1](scripts/windows/sessions/Test-IdleSession.ps1) |  | Stellt fest, ob auf einem Rechner alle Sitzungen im Leerlauf sind - ohne GetLastInputInfo. |
| [UserSessionFunctions.ps1](scripts/windows/sessions/UserSessionFunctions.ps1) |  | Funktionsbibliothek zum Auflisten und Abmelden von Remote-Sitzungen. |

## `scripts/windows/shadow-copy/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Enable-ShadowCopy.ps1](scripts/windows/shadow-copy/Enable-ShadowCopy.ps1) |  | Richtet Schattenkopien fuer das Laufwerk C: ein, inklusive Speicherzuweisung und Zeitplan. |
| [Get-ShadowStorage.ps1](scripts/windows/shadow-copy/Get-ShadowStorage.ps1) |  | Zeigt die vorhandenen Schattenkopien des Laufwerks C: mit Zeitpunkt und Speicherverbrauch. |
| [New-ScheduledTaskFromXml.ps1](scripts/windows/shadow-copy/New-ScheduledTaskFromXml.ps1) |  | Registriert die beiden mitgelieferten Aufgabenplanungs-Definitionen fuer taegliche Schattenkopien. |
| [New-SpontaneousShadowCopy.ps1](scripts/windows/shadow-copy/New-SpontaneousShadowCopy.ps1) | `def` | Erzeugt eine Schattenkopie von C: und haengt sie als begehbaren Ordner ein. |

## `scripts/windows/telemetry/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Disable-Telemetry.ps1](scripts/windows/telemetry/Disable-Telemetry.ps1) |  | Deaktiviert systemweit Windows- und Office-Telemetrie |

## `scripts/windows/updates/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-InstalledUpdatesFromEventLog.ps1](scripts/windows/updates/Get-InstalledUpdatesFromEventLog.ps1) |  | Liest die Installationshistorie von Windows-Updates aus dem Systemprotokoll. |

## `scripts/windows/wmi/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Get-WmiBriefOptimized.ps1](scripts/windows/wmi/Get-WmiBriefOptimized.ps1) |  | Ruft WMI/CIM-Klasseninformationen effizient ab und stellt eine vereinfachte Schnittstelle bereit. |
| [Repair-WmiRepository.ps1](scripts/windows/wmi/Repair-WmiRepository.ps1) |  | Repariert beschädigte Windows Management Instrumentation (WMI) Repositories und Services. |
| [Set-WbemTracing.ps1](scripts/windows/wmi/Set-WbemTracing.ps1) | `def` | Liest oder ändert WBEM/WMI Tracing-Einstellungen unter HKLM:\SOFTWARE\Microsoft\WBEM\CIMOM. |

## `snippets/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [New-PSCustomObjectWithIndexColumn.ps1](snippets/New-PSCustomObjectWithIndexColumn.ps1) | `def` | Ergaenzt ein PSCustomObject-Array um eine fortlaufende Indexspalte - drei Wege im Vergleich. |
| [ScriptBlockParameters.ps1](snippets/ScriptBlockParameters.ps1) |  | Zeigt, wie man Argumente an einen Scriptblock uebergibt. |

## `snippets/graph-traversal/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Invoke-BreadthFirstSearch.ps1](snippets/graph-traversal/Invoke-BreadthFirstSearch.ps1) | `def` | Kuerzeste Wege in einem JSON-beschriebenen Graphen per Breitensuche, gerichtet und ungerichtet. |
| [Invoke-GraphTraversal.ps1](snippets/graph-traversal/Invoke-GraphTraversal.ps1) | `def` | Funktionen zur Wegsuche in einem als JSON beschriebenen gerichteten Graphen. |

## `tools/`

| Skript | | Beschreibung |
| ------ | --- | ------------ |
| [Build-ScriptIndex.ps1](tools/Build-ScriptIndex.ps1) |  | Erzeugt INDEX.md - eine durchsuchbare Uebersicht aller Skripte im Repo. |
| [Find-ScriptDependency.ps1](tools/Find-ScriptDependency.ps1) |  | Findet Funktionsaufrufe, die ueber Dateigrenzen hinweg gehen. |
| [Repair-ScriptEncoding.ps1](tools/Repair-ScriptEncoding.ps1) |  | Ergaenzt fehlende UTF-8-BOMs in Skripten, die Nicht-ASCII-Zeichen enthalten. |

